#!/usr/bin/env nu

# Database environment management for testing
# Handles fresh database creation, PID tracking, and lifecycle management

def main [
    action: string = "status"  # setup, status, reset, destroy
] {
    match $action {
        "setup" => { setup_fresh_database }
        "status" => { check_database_status }
        "reset" => { reset_database }
        "destroy" => { destroy_database }
        _ => {
            print $"(ansi red)Unknown action: ($action)(ansi reset)"
            print "Available actions: setup, status, reset, destroy"
            exit 1
        }
    }
}

# Setup completely fresh database from scratch
def setup_fresh_database [] {
    print $"(ansi green)Setting up fresh test database environment...(ansi reset)"
    
    # Ensure completely clean environment - force remove any remnants
    if ($"($env.TEST_ROOT)/tmp" | path exists) {
        print $"(ansi yellow)Removing existing test remnants for true clean slate...(ansi reset)"
        rm -rf $"($env.TEST_ROOT)/tmp"
        print $"(ansi green)✓ Previous test data removed(ansi reset)"
    }
    
    # Check PostgreSQL availability
    try {
        let version = (postgres --version | str trim)
        print $"Found PostgreSQL: ($version)"
    } catch {
        print $"(ansi red)ERROR: PostgreSQL not found in PATH(ansi reset)"
        exit 1
    }
    
    # Create necessary directories
    mkdir $env.TEST_DB_DIR
    mkdir $env.TEST_LOG_DIR
    print $"Created directories in ($env.TEST_ROOT)/tmp/"
    
    # Initialize PostgreSQL cluster
    print "Initializing PostgreSQL cluster..."
    initdb -D $env.TEST_DB_DIR --auth-local=trust --auth-host=trust --username=postgres
    
    # Configure PostgreSQL for testing (unix socket only - minimal config like reference)
    # Only set the essential listen_addresses setting in config file
    "listen_addresses = ''\n" | save --append $"($env.TEST_DB_DIR)/postgresql.conf"
    
    # Start PostgreSQL server (matching reference system approach)
    print "Starting PostgreSQL server..."
    pg_ctl start -D $env.TEST_DB_DIR -o $"-k ($env.PGHOST) -p ($env.PGPORT)" -l $"($env.TEST_LOG_DIR)/postgres.log"
    
    # Get and save PID
    let server_pid = (pg_ctl status -D $env.TEST_DB_DIR | lines | where ($it | str contains "PID:") | first | str replace --all --regex ".*PID: (\\d+).*" "${1}")
    $server_pid | save $env.TEST_PID_FILE
    print $"PostgreSQL server started with PID: ($server_pid)"
    
    # Wait for server to be ready
    wait_for_server_ready
    
    # Create test database and user (using postgres superuser initially)
    print $"Creating test database: ($env.PGDATABASE)"
    createdb -h $env.PGHOST -p $env.PGPORT -U postgres $env.PGDATABASE
    
    # Create test user role with necessary permissions
    print $"Creating test user: ($env.PGUSER)"
    psql -h $env.PGHOST -p $env.PGPORT -U postgres -d $env.PGDATABASE -c $"CREATE ROLE ($env.PGUSER) LOGIN CREATEDB;"
    psql -h $env.PGHOST -p $env.PGPORT -U postgres -d $env.PGDATABASE -c $"GRANT CREATE ON SCHEMA public TO ($env.PGUSER);"
    psql -h $env.PGHOST -p $env.PGPORT -U postgres -d $env.PGDATABASE -c $"GRANT USAGE ON SCHEMA public TO ($env.PGUSER);"
    
    # Test connection
    test_database_connection
    
    print $"(ansi green)✓ Fresh test database setup complete!(ansi reset)"
    print $"Connect with: psql -h ($env.PGHOST) -p ($env.PGPORT) -U ($env.PGUSER) -d ($env.PGDATABASE)"
}

# Check current database status
def check_database_status [] {
    print "Database Status:"
    
    if not ($env.TEST_DB_DIR | path exists) {
        print $"  Database cluster: (ansi red)Not created(ansi reset)"
        return
    }
    
    if not ($env.TEST_PID_FILE | path exists) {
        print $"  Database process: (ansi red)No PID file(ansi reset)"
        return
    }
    
    let pid = (open $env.TEST_PID_FILE | str trim)
    let is_running = try {
        ps | where pid == ($pid | into int) | length
    } catch {
        0
    }
    
    if $is_running > 0 {
        print $"  Database process: (ansi green)Running (PID: ($pid))(ansi reset)"
        print $"  Database cluster: (ansi green)Exists(ansi reset)"
        
        # Test connection
        let connection_test = try {
            "SELECT 'OK' as status;" | psql -h $env.TEST_SOCKET_DIR -p $env.PGPORT -U $env.PGUSER -d $env.PGDATABASE | str contains "OK"
        } catch {
            false
        }
        
        if $connection_test {
            print $"  Database connection: (ansi green)OK(ansi reset)"
        } else {
            print $"  Database connection: (ansi red)Failed(ansi reset)"
        }
    } else {
        print $"  Database process: (ansi red)Not running(ansi reset)"
    }
}

# Reset database (drop and recreate test database, keep server running)
def reset_database [] {
    print $"(ansi yellow)Resetting test database...(ansi reset)"
    
    if not database_is_running {
        print $"(ansi red)ERROR: Database server is not running(ansi reset)"
        exit 1
    }
    
    # Drop and recreate test database
    try {
        dropdb -h $env.TEST_SOCKET_DIR -p $env.PGPORT -U $env.PGUSER $env.PGDATABASE --if-exists
        createdb -h $env.TEST_SOCKET_DIR -p $env.PGPORT -U $env.PGUSER $env.PGDATABASE
        print $"(ansi green)✓ Database reset complete(ansi reset)"
    } catch {
        print $"(ansi red)ERROR: Failed to reset database(ansi reset)"
        exit 1
    }
}

# Completely destroy all test data
def destroy_database [] {
    print $"(ansi yellow)Destroying all test data...(ansi reset)"
    
    # Kill database process if running
    if ($env.TEST_PID_FILE | path exists) {
        let pid = (open $env.TEST_PID_FILE | str trim)
        try {
            kill $pid
            print $"✓ Killed database process ($pid)"
        } catch {
            print $"⚠ Database process ($pid) may already be dead"
        }
    }
    
    # Remove all test directories
    if ($"($env.TEST_ROOT)/tmp" | path exists) {
        rm -rf $"($env.TEST_ROOT)/tmp"
        print $"✓ Removed all test data"
    }
    
    print $"(ansi green)✓ All test data destroyed(ansi reset)"
}

# Helper functions

def wait_for_server_ready [] {
    print "Waiting for server to be ready..."
    let max_attempts = 30
    mut attempt = 0
    
    while $attempt < $max_attempts {
        try {
            pg_isready -h $env.PGHOST -p $env.PGPORT | ignore
            print $"✓ Server ready after ($attempt + 1) attempts"
            return
        } catch {
            sleep 1sec
        }
        $attempt = ($attempt + 1)
    }
    
    print $"(ansi red)ERROR: PostgreSQL server failed to start within 30 seconds(ansi reset)"
    exit 1
}

def test_database_connection [] {
    try {
        let result = ("SELECT 'Connection successful' as status;" | psql -h $env.PGHOST -p $env.PGPORT -U $env.PGUSER -d $env.PGDATABASE | str trim)
        print $"✓ Database connection test successful"
    } catch {
        print $"(ansi red)ERROR: Failed to connect to test database(ansi reset)"
        exit 1
    }
}

def database_is_running [] {
    if not ($env.TEST_PID_FILE | path exists) {
        return false
    }
    
    let pid = (open $env.TEST_PID_FILE | str trim)
    let is_running = try {
        ps | where pid == ($pid | into int) | length
    } catch {
        0
    }
    
    $is_running > 0
}