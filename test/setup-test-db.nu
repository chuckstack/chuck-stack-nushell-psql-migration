#!/usr/bin/env nu

# Setup test database environment
def main [] {
    print $"(ansi green)Setting up test database environment...(ansi reset)"
    
    # Check if PostgreSQL is available
    try {
        let version = (postgres --version | str trim)
        print $"Found PostgreSQL: ($version)"
    } catch {
        print $"(ansi red)Error: PostgreSQL not found in PATH(ansi reset)"
        exit 1
    }
    
    # Create necessary directories
    let test_dirs = [
        $env.TEST_DB_DIR,
        $env.TEST_SOCKET_DIR, 
        $env.TEST_LOG_DIR
    ]
    
    for dir in $test_dirs {
        if not ($dir | path exists) {
            mkdir $dir
            print $"Created directory: ($dir)"
        }
    }
    
    # Initialize PostgreSQL cluster if not exists
    if not ($"($env.TEST_DB_DIR)/postgresql.conf" | path exists) {
        print "Initializing PostgreSQL cluster..."
        
        # Initialize database cluster
        initdb -D $env.TEST_DB_DIR --auth-local=trust --auth-host=trust
        
        # Configure PostgreSQL for testing
        let config_additions = [
            $"unix_socket_directories = '($env.TEST_SOCKET_DIR)'",
            $"port = ($env.PGPORT)",
            "log_statement = 'all'",
            "log_destination = 'stderr'",
            "logging_collector = off",
            "log_min_duration_statement = 0",
            "max_connections = 20"
        ]
        
        for config in $config_additions {
            $"($config)\n" | save --append $"($env.TEST_DB_DIR)/postgresql.conf"
        }
        
        print "PostgreSQL cluster initialized"
    }
    
    # Start PostgreSQL if not running
    let is_running = try { 
        pg_ctl status -D $env.TEST_DB_DIR | str contains "server is running"
    } catch { 
        false 
    }
    
    if not $is_running {
        print "Starting PostgreSQL server..."
        pg_ctl start -D $env.TEST_DB_DIR -l $"($env.TEST_LOG_DIR)/postgres.log" -o $"-k ($env.TEST_SOCKET_DIR) -p ($env.PGPORT)"
        
        # Wait for server to be ready
        let max_attempts = 30
        mut attempt = 0
        
        while $attempt < $max_attempts {
            try {
                pg_isready -h $env.TEST_SOCKET_DIR -p $env.PGPORT | ignore
                break
            } catch {
                sleep 1sec
            }
            $attempt = ($attempt + 1)
        }
        
        if $attempt >= $max_attempts {
            print $"(ansi red)Error: PostgreSQL server failed to start within 30 seconds(ansi reset)"
            exit 1
        }
        
        print "PostgreSQL server started"
    }
    
    # Create test user if not exists (using OS user as initial superuser)
    let current_user = $env.USER
    print $"Checking if test user ($env.PGUSER) exists using superuser: ($current_user)"
    
    let user_exists = try {
        psql -h $env.TEST_SOCKET_DIR -p $env.PGPORT -U $current_user -d postgres -tc $"SELECT 1 FROM pg_roles WHERE rolname = '($env.PGUSER)'" --quiet | str trim | str length
    } catch { |e|
        print $"Error checking user existence: ($e)"
        0
    }
    
    if ($user_exists | into int) == 0 {
        print $"Creating test user: ($env.PGUSER)"
        try {
            psql -h $env.TEST_SOCKET_DIR -p $env.PGPORT -U $current_user -d postgres -c $"CREATE USER ($env.PGUSER) WITH CREATEDB LOGIN" --quiet
            print $"Test user created successfully"
        } catch { |e|
            print $"Error creating user: ($e)"
            exit 1
        }
    } else {
        print $"Test user ($env.PGUSER) already exists"
    }
    
    # Create test database if not exists
    let db_exists = try {
        psql -h $env.TEST_SOCKET_DIR -p $env.PGPORT -U $env.PGUSER -d postgres -tc $"SELECT 1 FROM pg_database WHERE datname = '($env.PGDATABASE)'" | str trim | str length
    } catch {
        0
    }
    
    if ($db_exists | into int) == 0 {
        print $"Creating test database: ($env.PGDATABASE)"
        createdb -h $env.TEST_SOCKET_DIR -p $env.PGPORT -U $env.PGUSER $env.PGDATABASE
    }
    
    # Test connection
    try {
        let result = (psql -h $env.TEST_SOCKET_DIR -p $env.PGPORT -U $env.PGUSER -d $env.PGDATABASE -c "SELECT 'Connection successful' as status;" | str trim)
        print $"(ansi green)Database connection test: ($result)(ansi reset)"
    } catch {
        print $"(ansi red)Error: Failed to connect to test database(ansi reset)"
        exit 1
    }
    
    print $"(ansi green)Test database setup complete!(ansi reset)"
    print $"Connect with: psql -h ($env.TEST_SOCKET_DIR) -p ($env.PGPORT) -U ($env.PGUSER) -d ($env.PGDATABASE)"
}