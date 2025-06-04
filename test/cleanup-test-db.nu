#!/usr/bin/env nu

# Cleanup test database environment
def main [--force (-f): bool = false] {
    print $"(ansi yellow)Cleaning up test database environment...(ansi reset)"
    
    if not $force {
        let confirm = (input "This will destroy all test data. Continue? (y/N): ")
        if $confirm != "y" and $confirm != "Y" {
            print "Cleanup cancelled"
            exit 0
        }
    }
    
    # Stop PostgreSQL server if running
    let is_running = try { 
        pg_ctl status -D $env.TEST_DB_DIR | str contains "server is running"
    } catch { 
        false 
    }
    
    if $is_running {
        print "Stopping PostgreSQL server..."
        pg_ctl stop -D $env.TEST_DB_DIR -m fast
        
        # Wait for server to stop
        let max_attempts = 10
        mut attempt = 0
        
        while $attempt < $max_attempts {
            try {
                pg_ctl status -D $env.TEST_DB_DIR | str contains "no server running" | ignore
                break
            } catch {
                sleep 1sec
                $attempt = $attempt + 1
            }
        }
        
        print "PostgreSQL server stopped"
    }
    
    # Remove test directories
    let test_dirs = [
        $env.TEST_DB_DIR,
        $env.TEST_SOCKET_DIR,
        $env.TEST_LOG_DIR
    ]
    
    for dir in $test_dirs {
        if ($dir | path exists) {
            rm -rf $dir
            print $"Removed directory: ($dir)"
        }
    }
    
    # Remove any leftover socket files
    try {
        let socket_pattern = $"/tmp/.s.PGSQL.($env.PGPORT)*"
        ls $socket_pattern | each { |file| 
            rm -f $file.name
            print $"Removed socket file: ($file.name)"
        }
    } catch {
        # Ignore errors if no socket files found
    }
    
    print $"(ansi green)Test database cleanup complete!(ansi reset)"
}