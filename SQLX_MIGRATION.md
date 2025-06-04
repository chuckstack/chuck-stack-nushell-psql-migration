# Migrating from sqlx-cli to Nushell PostgreSQL Migration Utility

## Overview

This document provides step-by-step instructions for replacing sqlx-cli with the nushell PostgreSQL migration utility in the stk-app-sql repository.

**Context**: Since there are no production instances and all environments are ephemeral (created/destroyed), this is a straightforward replacement without data migration concerns.

## Current sqlx-cli Usage Analysis

### Commands Used
- `sqlx migrate run` - Apply pending migrations
- `sqlx migrate add <name>` - Create new migration files

### Environment Setup
- Uses `DATABASE_URL="postgresql://$STK_SUPERUSER/$STK_SUPERUSER?host=$PGHOST"`
- Installed via nix: `pkgs.sqlx-cli`
- Integrated in `runMigrations` shell function

### Migration Files
- Location: `/migrations/` directory
- Format: `YYYYMMDDHHMMSS_description.sql`
- Content: Standard PostgreSQL SQL (no sqlx-specific syntax)
- Metadata: Stored in `_sqlx_migrations` table

## Migration Steps

### 1. Update Dependencies

**File**: `shell.nix` (both deploy-local and test environments)

**Remove**:
```nix
pkgs.sqlx-cli
```

**Add**:
```nix
# Nushell migration utility (if not already available via nushell)
# Note: The utility will be accessed via git submodule or copy
```

### 2. Add Migration Utility

**Option A: Git Submodule** (Recommended)
```bash
# In stk-app-sql repository root
git submodule add https://github.com/your-org/nushell-psql-migration.git tools/migration
```

**Option B: Direct Copy**
```bash
# Copy the src/ directory to your repository
cp -r /path/to/nushell-migration/src tools/migration
```

### 3. Update Shell Functions

**File**: `shell.nix` (in shellHook section)

**Replace**:
```bash
runMigrations() {
    echo "Running database migrations..."
    sqlx migrate run
}
```

**With**:
```bash
runMigrations() {
    echo "Running database migrations..."
    cd "$STK_PROJECT_DIR" && nu -c "use tools/migration/mod.nu; migrate run ./migrations"
}
```

### 4. Update Environment Variables

**Current variables** (keep these):
```bash
export PGHOST="$STK_TEST_DIR/pgdata"
export PGUSER="$STK_SUPERUSER"  
export PGDATABASE="stk_db"
export PGPORT="5432"
```

**Remove** (no longer needed):
```bash
export DATABASE_URL="postgresql://$STK_SUPERUSER/$STK_SUPERUSER?host=$PGHOST"
```

### 5. Test Migration

**Verify existing migrations work**:
```bash
# Enter nix-shell
nix-shell

# Test migration discovery
nu -c "use tools/migration/mod.nu; migrate status ./migrations"

# Test dry-run
nu -c "use tools/migration/mod.nu; migrate run ./migrations --dry-run"

# Run actual migrations
runMigrations
```

### 6. Update Documentation

**Update any references to**:
- sqlx-cli commands → nushell migration commands
- DATABASE_URL → standard PostgreSQL environment variables
- Migration creation process

## Command Mapping

| sqlx-cli Command | Nushell Migration Command |
|------------------|---------------------------|
| `sqlx migrate run` | `migrate run ./migrations` |
| `sqlx migrate add <name>` | `migrate add ./migrations <description>` |
| `sqlx migrate info` | `migrate status ./migrations` |
| N/A | `migrate history ./migrations` |
| N/A | `migrate validate ./migrations` |
| N/A | `migrate run ./migrations --dry-run` |

## Enhanced Capabilities

The nushell migration utility provides additional features not available in sqlx-cli:

### Better Status Reporting
```bash
# Detailed migration status
nu -c "use tools/migration/mod.nu; migrate status ./migrations"

# Migration history with timing
nu -c "use tools/migration/mod.nu; migrate history ./migrations"
```

### Dry-Run Testing
```bash
# Test migrations without applying
nu -c "use tools/migration/mod.nu; migrate run ./migrations --dry-run"
```

### Validation Support
Create optional `.nu` validation files alongside SQL files:
```bash
# Create migration with validation
nu -c "use tools/migration/mod.nu; migrate add ./migrations create_users_table --with-validation"
```

### Multi-Track Support (Future)
Ready for organizing migrations into tracks (core, implementation, customer):
```
migrations/
├── core/           # Core functionality
├── impl/           # Implementation customizations  
└── customer/       # Customer-specific changes
```

## File Compatibility

### Existing Migration Files
✅ **No changes required** - existing SQL files work as-is:
- Keep current naming: `20241009214146_stk-seed-schema.sql`
- Keep current content: Standard PostgreSQL SQL
- Keep current location: `/migrations/` directory

### Metadata Storage
- **sqlx-cli**: Uses `_sqlx_migrations` table
- **nushell**: Creates `migrations_core` table (or track-specific)
- **Impact**: Fresh environments will use new metadata table
- **Migration**: Not needed since no production instances exist

## Verification Checklist

After completing the migration:

- [ ] `nix-shell` enters environment successfully
- [ ] `nu -c "use tools/migration/mod.nu; migrate status ./migrations"` shows pending migrations
- [ ] `runMigrations` executes without errors
- [ ] All existing SQL migrations apply successfully
- [ ] Database schema matches expected state
- [ ] Application starts and functions correctly

## Troubleshooting

### Common Issues

**Module not found error**:
```bash
# Ensure correct path to migration utility
nu -c "use tools/migration/mod.nu; help commands | where name =~ migrate"
```

**Permission issues**:
```bash
# Ensure migration utility files are executable
chmod +x tools/migration/*.nu
```

**Environment variable issues**:
```bash
# Verify PostgreSQL connection works
psql -h $PGHOST -U $PGUSER -d $PGDATABASE -c "SELECT 1"
```

**Migration execution issues**:
```bash
# Use dry-run to test
nu -c "use tools/migration/mod.nu; migrate run ./migrations --dry-run"

# Check migration status
nu -c "use tools/migration/mod.nu; migrate status ./migrations"
```

## Rollback Plan

If issues arise, rollback is simple:

1. **Restore sqlx-cli dependency** in shell.nix
2. **Restore original runMigrations function**
3. **Restore DATABASE_URL environment variable**
4. **Remove migration utility files**

Since environments are ephemeral, no data migration is needed.

## Benefits of Migration

### Immediate Benefits
- ✅ **Consistent tooling**: Aligns with nushell module ecosystem
- ✅ **Better visibility**: Status and history commands
- ✅ **Validation support**: Pre-flight checks when needed
- ✅ **Dry-run testing**: Safe migration testing

### Future Benefits
- 🚀 **Multi-track support**: Ready for complex deployment scenarios
- 🔧 **Enhanced features**: Advanced migration management
- 📊 **Better reporting**: Structured output for automation
- 🛡️ **Robust error handling**: Atomic transactions and rollback

## Timeline

**Estimated effort**: 1-2 hours
- 30 minutes: Code changes and testing
- 30 minutes: Documentation updates  
- 30 minutes: Verification and cleanup

**Risk level**: Low (ephemeral environments, easy rollback)

## Next Steps

1. Review this document
2. Create backup branch of stk-app-sql
3. Implement changes in test environment first
4. Verify full workflow
5. Apply to deploy-local environment
6. Update documentation
7. Remove sqlx-cli references

The migration is straightforward and low-risk given the ephemeral nature of current environments.