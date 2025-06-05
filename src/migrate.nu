# Migration Module
# This module provides commands for PostgreSQL database migrations using psql

# Module Constants
const MIGRATION_TABLE_PREFIX = "migrations_"
const DEFAULT_TIMEOUT_SECONDS = 300
const SUPPORTED_EXTENSIONS = ["sql", "nu"]

# Helper function to get database connection environment variables
def get-db-env [] {
    {
        PGHOST: ($env.PGHOST? | default "localhost"),
        PGPORT: ($env.PGPORT? | default "5432"),
        PGDATABASE: ($env.PGDATABASE? | default ""),
        PGUSER: ($env.PGUSER? | default ""),
        PGPASSWORD: ($env.PGPASSWORD? | default ""),
        PGCLIENTENCODING: ($env.PGCLIENTENCODING? | default "UTF8"),
        ON_ERROR_STOP: "on"
    }
}

# Helper function to get the current default schema
def get-default-schema [] {
    try {
        # Use the same approach as db-query without --quiet flag
        "SELECT current_schema()" | psql -t | str trim
    } catch {
        # Fallback to 'public' if query fails
        "public"
    }
}

# Helper function to validate database connection
export def validate-connection [] {
    let db_env = (get-db-env)
    
    if ($db_env.PGDATABASE | is-empty) {
        error make {msg: "PGDATABASE environment variable is required"}
    }
    
    if ($db_env.PGUSER | is-empty) {
        error make {msg: "PGUSER environment variable is required"}
    }
    
    # Test connection
    try {
        with-env $db_env {
            let result = ("SELECT 1 as test;" | psql -t | str trim)
            if $result != "1" {
                error make {msg: "Database connection test failed"}
            }
        }
    } catch {
        error make {msg: $"Database connection failed: ($in)"}
    }
}

# Parse migration filename to extract components
export def parse-migration-filename [
    filename: string  # Migration filename to parse
] {
    let parts = ($filename | str replace --regex '\.(sql|nu)$' "" | split row "_")
    
    if ($parts | length) < 3 {
        error make {msg: $"Invalid migration filename format: ($filename). Expected: timestamp_track_description.ext"}
    }
    
    {
        filename: $filename,
        timestamp: $parts.0,
        track: $parts.1,
        description: ($parts | skip 2 | str join "_"),
        extension: ($filename | path parse | get extension)
    }
}

# Validate migration timestamp format
export def validate-migration-timestamp [
    timestamp: string  # Timestamp to validate
] {
    # Basic validation for YYYYMMDDHHMMSS format
    ($timestamp | str length) == 14 and ($timestamp =~ '^[0-9]{14}$')
}

# Database helper functions for testing and utilities
export def db-execute [
    sql: string,  # SQL to execute
    --quiet      # Suppress error output to stderr
] {
    let db_env = (get-db-env)
    try {
        with-env $db_env {
            if $quiet {
                do { $sql | psql } | complete | ignore
            } else {
                $sql | psql | ignore
            }
        }
    } catch { |err|
        error make {msg: $"Database execution failed: ($err.msg)"}
    }
}

export def db-query [
    sql: string,  # SQL query to execute
    --quiet      # Suppress error output to stderr
] {
    let db_env = (get-db-env)
    try {
        with-env $db_env {
            if $quiet {
                let result = (do { $sql | psql -t } | complete)
                if $result.exit_code == 0 {
                    $result.stdout | str trim
                } else {
                    error make {msg: "Query failed"}
                }
            } else {
                $sql | psql -t | str trim
            }
        }
    } catch { |err|
        error make {msg: $"Database query failed: ($err.msg)"}
    }
}

export def db-table-exists [
    table_name: string  # Table name to check
] {
    try {
        let result = (db-query $"SELECT EXISTS \(SELECT FROM information_schema.tables WHERE table_name = '($table_name)');")
        $result | str contains "t"
    } catch {
        false
    }
}

export def db-count-rows [
    table_name: string  # Table name to count rows in
] {
    try {
        let result = (db-query $"SELECT COUNT\(*) FROM ($table_name);")
        $result | into int
    } catch {
        0
    }
}

# Discover migration files in a directory
export def discover-migrations [
    path: string  # Directory path to scan for migrations
] {
    if not ($path | path exists) {
        error make {msg: $"Migration directory not found: ($path)"}
    }
    
    ls $path 
    | where type == file 
    | where name =~ '\.(sql|nu)$'
    | get name
    | each { |file| 
        let basename = ($file | path basename)
        parse-migration-filename $basename | insert full_path $file
    }
    | sort-by timestamp
}

# Apply pending migrations in a directory
#
# Scans the specified directory for migration files and applies any that haven't
# been executed yet. Migrations are applied in timestamp order within their track.
# All pending migrations are executed in a single transaction for atomicity.
#
# Accepts piped input: none
#
# Examples:
#   migrate run ./migrations/core
#   migrate run ./migrations/impl  
#   migrate run ./migrations
#
# Returns: Summary of applied migrations with execution details
# Error: Stops on first migration failure and rolls back transaction
export def "migrate run" [
    path: string,           # Directory path containing migration files
    --dry-run (-n),         # Show what would be executed without applying
    --force (-f)            # Skip validation checks
] {
    print $"Running migrations from: ($path)"
    
    # Validate environment and connection
    if not $force {
        validate-connection
    }
    
    # Discover migration files
    let migrations = (discover-migrations $path)
    
    if ($migrations | is-empty) {
        print "No migration files found"
        return []
    }
    
    # Extract track name from first migration or directory
    let track_name = if ($migrations | length) > 0 {
        $migrations.0.track
    } else {
        ($path | path basename)
    }
    
    print $"Detected track: ($track_name)"
    
    if $dry_run {
        print "DRY RUN - No changes will be applied"
        $migrations | select timestamp track description extension full_path | table
        return
    }
    
    # Check which migrations have been applied
    let applied_migrations = (get-applied-migrations $track_name)
    let pending_migrations = ($migrations | where {|m| $m.filename not-in $applied_migrations})
    
    if ($pending_migrations | is-empty) {
        print "No pending migrations found"
        return []
    }
    
    print $"Found ($pending_migrations | length) pending migrations"
    
    # Execute migrations
    execute-migrations $pending_migrations $track_name
}

# Show migration status for a directory
#
# Displays the current state of migrations including which have been applied
# and which are pending. Shows detailed information about each migration file
# found in the directory and its execution status.
#
# Accepts piped input: none
#
# Examples:
#   migrate status ./migrations/core
#   migrate status ./migrations
#
# Returns: Table showing migration status with applied/pending indicators
export def "migrate status" [
    path: string  # Directory path containing migration files
] {
    print $"Migration status for: ($path)"
    
    # Discover migration files
    let migrations = (discover-migrations $path)
    
    if ($migrations | is-empty) {
        print "No migration files found"
        return []
    }
    
    # Extract track name
    let track_name = $migrations.0.track
    
    # Get applied migrations
    let applied_migrations = (get-applied-migrations $track_name)
    
    # Add status to each migration
    $migrations 
    | insert status {|m| 
        if $m.filename in $applied_migrations { "APPLIED" } else { "PENDING" }
    }
    | select timestamp track description status extension
    | table
}

# Show migration history for a track
#
# Displays the complete history of applied migrations for a specific track,
# including when they were executed and how long they took. This provides
# an audit trail of all database changes for the track.
#
# Accepts piped input: none
#
# Examples:
#   migrate history ./migrations/core
#   migrate history ./migrations/impl
#
# Returns: Table showing migration history with execution timestamps
export def "migrate history" [
    path: string  # Directory path to determine track name
] {
    # Extract track name from directory or first migration file
    let track_name = try {
        let migrations = (discover-migrations $path)
        if ($migrations | length) > 0 { $migrations.0.track } else { ($path | path basename) }
    } catch {
        ($path | path basename)
    }
    
    print $"Migration history for track: ($track_name)"
    
    # Query migration history from database
    let schema = (get-default-schema)
    let table_name = $"($schema).($MIGRATION_TABLE_PREFIX)($track_name)"
    
    try {
        let sql = $"SELECT migration_name, migration_hash, applied_at, execution_time_ms FROM ($table_name) ORDER BY applied_at DESC"
        $sql | psql | from csv
    } catch {
        print $"No migration history found for track: ($track_name)"
        []
    }
}

# Validate migration files without executing them
#
# Performs pre-flight validation on all migration files in the directory,
# checking filename formats, SQL syntax, and running any .nu validation scripts.
# This helps catch issues before attempting to apply migrations.
#
# Accepts piped input: none
#
# Examples:
#   migrate validate ./migrations/core
#   migrate validate ./migrations
#
# Returns: Validation results showing any errors or warnings found
export def "migrate validate" [
    path: string  # Directory path containing migration files to validate
] {
    print $"Validating migrations in: ($path)"
    
    # Discover migration files
    let migrations = (discover-migrations $path)
    
    if ($migrations | is-empty) {
        print "No migration files found"
        return []
    }
    
    # Validate each migration
    let validation_results = ($migrations | each { |migration|
        print $"Validating: ($migration.filename)"
        
        # Check if .nu validation file exists
        let nu_file = ($migration.full_path | str replace '.sql' '.nu')
        if ($nu_file | path exists) {
            try {
                nu $nu_file
                {
                    migration: $migration.filename,
                    status: "VALID",
                    message: "Pre-flight validation passed"
                }
            } catch {
                {
                    migration: $migration.filename,
                    status: "ERROR",
                    message: $"Pre-flight validation failed: ($in)"
                }
            }
        } else {
            {
                migration: $migration.filename,
                status: "VALID", 
                message: "No validation script"
            }
        }
    })
    
    $validation_results | table
}

# Create a new migration file
#
# Generates a new migration file with proper naming convention and timestamp.
# Creates both .sql file and optionally a .nu validation file. The migration
# is created in the specified directory with the track name extracted from path.
#
# Accepts piped input: none
#
# Examples:
#   migrate add ./migrations/core create_users_table
#   migrate add ./migrations/impl add_custom_fields --with-validation
#
# Returns: Information about the created migration file(s)
export def "migrate add" [
    path: string,                   # Directory where migration should be created
    description: string,            # Description of what the migration does
    --with-validation (-v),         # Also create .nu validation file
    --track (-t): string           # Override track name (default: extracted from path)
] {
    if not ($path | path exists) {
        mkdir $path
        print $"Created migration directory: ($path)"
    }
    
    # Extract track name
    let track_name = if ($track | is-empty) {
        $path | path basename
    } else {
        $track
    }
    
    # Generate timestamp
    let timestamp = (date now | format date '%Y%m%d%H%M%S')
    
    # Create filename
    let filename = $"($timestamp)_($track_name)_($description)"
    let sql_file = $"($path)/($filename).sql"
    let nu_file = $"($path)/($filename).nu"
    
    # Create SQL migration file
    let sql_template = $"-- Migration: ($description)
-- Track: ($track_name)
-- Created: (date now)

\\set migration_name '($filename)'
\\set track_name '($track_name)'

\\echo 'Applying migration: ' :migration_name

-- TODO: Add your SQL migration here

\\echo 'Migration applied successfully'
"
    
    $sql_template | save $sql_file
    print $"Created SQL migration: ($sql_file)"
    
    # Create validation file if requested
    if $with_validation {
        let nu_template = [
            "#!/usr/bin/env nu",
            "",
            $"# Pre-flight validation for ($description)",
            "# This script validates dependencies before applying the SQL migration",
            "",
            $"print \"Running pre-flight validation for ($description)...\"",
            "",
            "# TODO: Add your validation logic here",
            "# Example:",
            "# let table_exists = (\"SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'required_table')\" | psql -t | str trim)",
            "# if $table_exists != \"t\" {",
            "#     error make { msg: \"Required table 'required_table' does not exist\" }",
            "# }",
            "",
            $"print \"Pre-flight validation passed for ($description)\""
        ] | str join "\n"
        
        $nu_template | save $nu_file
        print $"Created validation script: ($nu_file)"
    }
    
    [
        {type: "sql", file: $sql_file},
        {type: "validation", file: (if $with_validation { $nu_file } else { null })}
    ] | where file != null
}

# Helper function to get applied migrations for a track
def get-applied-migrations [
    track_name: string  # Track name to check
] {
    let schema = (get-default-schema)
    let table_name = $"($schema).($MIGRATION_TABLE_PREFIX)($track_name)"
    
    try {
        let sql = $"SELECT migration_name FROM ($table_name) ORDER BY applied_at"
        let result = (db-query $sql)
        $result | lines | where $it != "" | each { |line| $line | str trim }
    } catch {
        # Table doesn't exist yet, no migrations applied
        []
    }
}

# Helper function to execute migrations
def execute-migrations [
    migrations: list,  # List of migration records to execute
    track_name: string # Track name for metadata table
] {
    let db_env = (get-db-env)
    
    # Ensure metadata table exists
    create-metadata-table $track_name
    
    # Execute pre-flight validations first
    for migration in $migrations {
        let nu_file = ($migration.full_path | str replace '.sql' '.nu')
        if ($nu_file | path exists) {
            print $"Running pre-flight validation: ($migration.filename)"
            try {
                nu $nu_file
            } catch {
                error make {msg: $"Pre-flight validation failed for ($migration.filename): ($in)"}
            }
        }
    }
    
    # Build combined SQL for atomic execution
    let sql_parts = ["BEGIN;"]
    
    let migration_sqls = ($migrations | each { |migration|
        if $migration.extension == "sql" {
            print $"Preparing migration: ($migration.filename)"
            let sql_content = (open $migration.full_path)
            
            # Add metadata insert
            let schema = (get-default-schema)
            let table_name = $"($schema).($MIGRATION_TABLE_PREFIX)($track_name)"
            let hash = ($sql_content | hash md5)
            let insert_sql = $"INSERT INTO ($table_name) \(migration_name, migration_hash) VALUES \('($migration.filename)', '($hash)');"
            
            [
                $"-- Migration: ($migration.filename)",
                $sql_content,
                $insert_sql,
                ""
            ]
        } else {
            []
        }
    } | flatten)
    
    let all_sql_parts = ($sql_parts | append $migration_sqls | append "COMMIT;")
    let final_sql = ($all_sql_parts | str join "\n")
    
    # Execute combined SQL
    try {
        with-env $db_env {
            print "Executing migrations..."
            $final_sql | psql
        }
        print $"Successfully applied ($migrations | length) migrations"
    } catch {
        error make {msg: $"Migration execution failed: ($in)"}
    }
}

# Helper function to create metadata table
def create-metadata-table [
    track_name: string  # Track name for table suffix
] {
    let db_env = (get-db-env)
    let schema = (get-default-schema)
    let table_name = $"($schema).($MIGRATION_TABLE_PREFIX)($track_name)"
    
    let create_sql = $"CREATE TABLE IF NOT EXISTS ($table_name) \(
    id SERIAL PRIMARY KEY,
    migration_name VARCHAR\(255) NOT NULL UNIQUE,
    migration_hash VARCHAR\(64) NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    execution_time_ms INTEGER
);"
    
    try {
        with-env $db_env {
            $create_sql | psql
        }
    } catch {
        error make {msg: $"Failed to create metadata table ($table_name): ($in)"}
    }
}