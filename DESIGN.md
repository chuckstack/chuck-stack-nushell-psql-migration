# Nushell PostgreSQL Migration Utility Design Document

## Overview

A nushell-based database migration utility that executes PostgreSQL migrations using the `psql` command-line tool. The system supports multiple migration tracks for ERP-like environments where core functionality and implementation-specific customizations need separate migration paths.

## Core Design Principles

- **Path-based execution**: Commands operate on directory paths rather than requiring track flags
- **Multi-track support**: Support unlimited migration tracks for multiple implementors
- **Hybrid file approach**: Support both simple SQL files and nushell pre-flight validation
- **Atomic operations**: Execute multiple migrations in single psql transactions for rollback capability
- **Explicit environment control**: Use environment variables to ensure predictable psql behavior
- **Unix socket support**: Full support for PostgreSQL unix socket connections

## Inspired By

- **sqlx-cli**: Command structure and migration workflow
- **Flyway**: Migration versioning and metadata management
- **Multi-track requirement**: ERP environments with core + implementation tracks

## Migration File Format

### File Naming Convention
```
{timestamp}_{track}_{description}.{ext}

Examples:
20231201120000_core_create_users_table.sql
20231201120100_impl_add_custom_fields.sql
20231201120200_acme_company_settings.sql
```

### Hybrid File Approach
For each migration, users can provide:
- **Required**: `{timestamp}_{track}_{description}.sql` - Contains SQL migration
- **Optional**: `{timestamp}_{track}_{description}.nu` - Contains pre-flight validation logic

### Execution Flow
1. **Discovery**: Scan directory for pending .sql files (not yet applied to database)
2. **Pre-flight validation**: Execute corresponding .nu files for pending migrations
3. **Validation gate**: If any .nu file throws error, stop completely
4. **Atomic execution**: Concatenate all pending .sql files and execute in single psql transaction

## Command Interface

### Core Commands
```bash
# Apply migrations in directory
migrate run ./migrations/core

# Apply migrations in directory tree (all tracks)
migrate run ./migrations

# Show migration status for directory
migrate status ./migrations/core

# Create new migration
migrate add ./migrations/core create_users_table

# Show migration history
migrate history ./migrations/core

# Validate migration files without executing
migrate validate ./migrations
```

### Migration Creation
```bash
# Creates timestamped SQL file
migrate add ./migrations/core create_users_table
# → 20231201120000_core_create_users_table.sql

# Optional: Create with pre-flight validation
migrate add ./migrations/core create_users_table --with-validation
# → 20231201120000_core_create_users_table.sql
# → 20231201120000_core_create_users_table.nu
```

## Directory Structure

### Recommended Organization
```
migrations/
├── core/                    # Core ERP functionality
│   ├── 20231201120000_core_create_users.sql
│   ├── 20231201120001_core_create_permissions.sql
│   └── 20231201120002_core_add_audit_trail.nu
│       20231201120002_core_add_audit_trail.sql
├── impl/                    # Implementation customizations
│   ├── 20231201130000_impl_custom_fields.sql
│   └── 20231201130001_impl_custom_reports.sql
└── acme/                    # Customer-specific (another implementor)
    ├── 20231201140000_acme_branding.sql
    └── 20231201140001_acme_integrations.sql
```

### Implementation Flexibility
While the recommended practice is one track per directory, the tool will attempt to support mixed directories by parsing track names from filenames. This this design proved problematic, we will revert to a required one-track-per-directory format.

## Migration Metadata

### Database Tables
Each track maintains its own metadata table:
- `migrations_core`
- `migrations_impl` 
- `migrations_acme`
- etc.

### Schema Assumptions
- Migration metadata tables are created in the default schema (typically `public`)
- Migrations can target any schema via their SQL content
- No explicit schema configuration required for the migration tool itself

### Metadata Schema
```sql
CREATE TABLE migrations_{track} (
    id SERIAL PRIMARY KEY,
    migration_name VARCHAR(255) NOT NULL UNIQUE,
    migration_hash VARCHAR(64) NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    execution_time_ms INTEGER
);
```

## Environment Variable Control

### PostgreSQL Connection Variables
The tool explicitly controls these environment variables to ensure predictable behavior:

```bash
# Connection
PGHOST=localhost                    # or /var/run/postgresql for unix socket
PGPORT=5432
PGDATABASE=myapp
PGUSER=postgres
PGPASSWORD=secret                   # or use .pgpass file

# psql Behavior
PGOPTIONS="-c statement_timeout=300s"
ON_ERROR_STOP=on                    # Critical for atomic operations
PSQL_EDITOR=/usr/bin/nano

# Output Control
PGCLIENTENCODING=UTF8
```

### Environment Variable Strategy
- **Tool-controlled**: Variables that affect migration safety and atomicity
- **User-provided**: Connection details and credentials
- **Documented**: Clear specification of which variables the tool sets vs. expects

## Pre-flight Validation (.nu files)

### Purpose
- Validate migration dependencies (cross-track or within-track)
- Check required database objects exist
- Verify data conditions before migration
- Validate external system dependencies

### Example .nu File
```nushell
# 20231201120002_core_add_audit_trail.nu

# Check that users table exists (from previous migration)
let table_exists = (
    psql -c "SELECT 1 FROM information_schema.tables WHERE table_name = 'users'" 
    | str trim 
    | str length
) > 0

if not $table_exists {
    error make { msg: "users table must exist before adding audit trail" }
}

# Check that impl track has been applied up to certain point
let impl_migration_count = (
    psql -c "SELECT COUNT(*) FROM migrations_impl WHERE migration_name LIKE '2023120113%'"
    | str trim
    | into int
)

if $impl_migration_count < 2 {
    error make { msg: "impl track must be up to date before adding audit trail" }
}

print "Pre-flight validation passed for audit trail migration"
```

## Execution Order and Dependencies

### Default Execution Order
1. **Core migrations** applied first
2. **Implementation migrations** applied after core
3. **Additional tracks** in alphabetical order

### Future Consideration: Cross-track Dependencies
The design notes but does not initially implement explicit dependency management between tracks. This feature would allow migrations to declare dependencies on specific migrations from other tracks.

## Atomic Operations and Rollback

### Transaction Management
- All pending migrations in a single directory execution are wrapped in one transaction
- Uses psql's transaction capabilities for atomic commit/rollback
- Environment variable `ON_ERROR_STOP=on` ensures transaction rollback on any error

### Rollback Strategy
```bash
# All SQL files concatenated and executed as:
BEGIN;
-- Migration 1 SQL content
-- Migration 2 SQL content  
-- Migration N SQL content
COMMIT;
```

If any migration fails, the entire transaction rolls back, leaving the database in its previous state.

## Leveraging psql Advanced Features

### psql Variable System
Since migrations execute through `psql`, we can leverage its powerful variable and conditional features:

#### Variable Definition and Usage
```sql
-- Set migration-specific variables
\set migration_version 20231201120000
\set track_name core
\set table_prefix app_

-- Use variables in SQL statements
CREATE TABLE :table_prefix:track_name_data (
    id SERIAL PRIMARY KEY,
    version VARCHAR(50) DEFAULT ':migration_version',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert migration metadata using variables
INSERT INTO migrations_:track_name (migration_name) VALUES (':migration_version_:track_name_create_data_table');
```

#### Conditional Migrations
```sql
-- Check if table exists and store result in variable
SELECT EXISTS(
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'users'
) \gset user_table_exists

-- Conditional execution based on database state
\if :user_table_exists
    \echo 'Users table exists, adding new column'
    ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login TIMESTAMP;
\else
    \echo 'Users table missing, creating it'
    CREATE TABLE users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(255) UNIQUE NOT NULL,
        last_login TIMESTAMP
    );
\endif
```

#### Dynamic SQL Generation
```sql
-- Set environment-specific values
\set env_suffix _dev

-- Create environment-specific objects
CREATE TABLE app_config:env_suffix (
    key VARCHAR(255) PRIMARY KEY,
    value TEXT
);

-- Loop-like behavior using psql includes
\set migration_tables 'users roles permissions'
\echo 'Creating audit tables for: ' :migration_tables
-- Could include separate files for each table type
```

#### Tool Integration with psql Variables
The migration tool can inject variables before executing SQL:
- `migration_name` - Current migration filename
- `track_name` - Extracted track name
- `migration_timestamp` - Migration timestamp
- `execution_id` - Unique execution identifier

### Benefits of psql Features
- **Environment awareness**: Migrations can adapt to different database states
- **Reduced duplication**: Variables eliminate repeated values
- **Safer migrations**: Conditional logic prevents destructive operations
- **Better logging**: Echo statements provide execution feedback
- **Dynamic behavior**: Migrations can respond to runtime conditions

## Configuration

### Migration Configuration File
```json
{
  "database": {
    "host": "${PGHOST:-localhost}",
    "port": "${PGPORT:-5432}", 
    "database": "${PGDATABASE}",
    "user": "${PGUSER}",
    "password": "${PGPASSWORD}"
  },
  "migration": {
    "timeout_seconds": 300,
    "table_prefix": "migrations_",
    "hash_algorithm": "sha256"
  },
  "psql": {
    "additional_options": ["-v", "ON_ERROR_STOP=1"],
    "environment_overrides": {
      "PGCLIENTENCODING": "UTF8"
    }
  }
}
```

## Implementation Phases

### Phase 1: Core Functionality
- Basic migration discovery and execution
- Simple SQL file support
- Single track support
- Basic metadata tracking

### Phase 2: Multi-track Support  
- Multiple track discovery and execution
- Track-specific metadata tables
- Path-based command interface

### Phase 3: Pre-flight Validation
- .nu file support for validation
- Pre-flight execution before SQL
- Error handling and rollback

### Phase 4: Advanced Features
- Migration creation utilities
- Comprehensive status reporting
- Performance optimization
- Enhanced error messages

## Security Considerations

- **Environment isolation**: Explicit environment variable control prevents config inheritance
- **Connection security**: Support for SSL and unix socket connections
- **SQL injection prevention**: No dynamic SQL construction in tool itself
- **Credential management**: Support for .pgpass files and environment variables
- **Audit trail**: Complete migration history with timestamps and hashes

## Error Handling

### Pre-flight Validation Errors
- Any .nu file error stops entire migration process
- Clear error messages indicate which validation failed
- No database changes made if validation fails

### SQL Execution Errors
- Transaction rollback ensures database consistency
- Detailed error reporting from psql
- Migration marked as failed in metadata

### Recovery Procedures
- Manual intervention required for failed migrations
- Tool provides status commands to assess current state
- Failed migrations must be manually resolved before continuing

## Future Enhancements

1. **Cross-track dependency management**: Explicit dependency declarations between migrations
2. **Parallel execution**: Safe concurrent execution where dependencies allow
3. **Migration templates**: Common migration patterns and generators
4. **Schema diffing**: Compare database state to expected schema
5. **Backup integration**: Automatic backups before major migrations
6. **CI/CD integration**: Standardized exit codes and output formats

## Dependencies

- **Nushell**: Core shell environment (v0.80+)
- **PostgreSQL psql**: Command-line client tool
- **PostgreSQL server**: Target database (v12+)
- **Standard Unix tools**: Basic file system operations

## Conclusion

This design provides a robust, multi-track migration system that leverages nushell's strengths while maintaining PostgreSQL best practices. The hybrid file approach and explicit environment control ensure both flexibility and reliability for ERP environments requiring multiple implementation tracks.
