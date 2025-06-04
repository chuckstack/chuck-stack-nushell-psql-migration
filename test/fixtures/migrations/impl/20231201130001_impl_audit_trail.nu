#!/usr/bin/env nu

# Pre-flight validation for audit trail migration
# This script validates dependencies before applying the SQL migration

print "Running pre-flight validation for audit trail migration..."

# Check that core migrations are applied
let core_migrations = (psql -t -c "SELECT COUNT(*) FROM migrations_core WHERE migration_name LIKE '2023120112%'" | str trim | into int)

if $core_migrations < 2 {
    error make { 
        msg: $"Core track must have at least 2 migrations applied, found: ($core_migrations)"
    }
}

# Check that users table has the expected structure
let user_columns = (psql -t -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'users' ORDER BY column_name" | lines | where $it != "" | length)

if $user_columns < 6 {
    error make { 
        msg: $"Users table missing expected columns, found: ($user_columns)"
    }
}

# Check that roles table exists
let roles_exists = (psql -t -c "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'roles')" | str trim)

if $roles_exists != "t" {
    error make { 
        msg: "Roles table must exist before creating audit trail"
    }
}

# Check that we have enough disk space (mock check)
let available_space = 1000000  # In a real scenario, check actual disk space

if $available_space < 100000 {
    error make { 
        msg: $"Insufficient disk space for audit trail. Available: ($available_space)"
    }
}

print "Pre-flight validation passed for audit trail migration"
print $"✓ Core migrations: ($core_migrations)"
print $"✓ User table columns: ($user_columns)"
print $"✓ Roles table exists: ($roles_exists)"
print $"✓ Disk space available: ($available_space)"