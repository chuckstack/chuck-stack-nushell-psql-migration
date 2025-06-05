# Migration Utility Testing

## Quick Start

The fastest way to test the migration utility:

```bash
# 1. Enter test environment
nix-shell

# 2. Run smoke test (no database required)
nu smoke-test.nu

# 3. For full testing with database
nu test/setup-test-db.nu    # Setup
nu test/run-tests.nu        # Run tests  
nu test/cleanup-test-db.nu  # Cleanup
```

## Test Output Standard

**All tests output exactly one line:**
- `TEST_RESULT: PASS` for success (exit code 0)
- `TEST_RESULT: FAIL` for failure (exit code 1)

This enables reliable automation: `nu test.nu | grep -q "TEST_RESULT: PASS"`

See [TESTING.md](../TESTING.md) for complete testing guidelines.

## Test Categories

### Smoke Tests (Project Root)
- **No dependencies**: Work without database or setup
- **Quick validation**: Basic functionality checks
- **Pattern**: `smoke-test*.nu`
- **Example**: `nu smoke-test.nu`

### Integration Tests (test/suites/)
- **Full workflow**: Database connectivity required
- **Comprehensive**: End-to-end migration testing
- **Pattern**: `test/suites/test-*.nu`
- **Example**: `nu test/run-tests.nu`

## Testing Environment

### Nix Shell Environment
Provides isolated, reproducible testing with:
- PostgreSQL 17.5 on port 5433
- Nushell with migration utility
- Unix socket connections
- Test-specific configuration

### Test Database
- **Host**: Unix socket (`/test/tmp/sockets`)
- **Port**: 5433 (no conflicts with system PostgreSQL)
- **Database**: `migration_test`  
- **User**: `test_user`
- **Data**: Isolated in `test/tmp/` (ignored by git)

### Sample Migrations
Realistic test data in `test/fixtures/migrations/`:
- **core/**: User authentication, roles, permissions
- **impl/**: Custom fields, audit trails
- **acme/**: Company-specific branding

## Directory Structure

```
test/
├── README.md                    # This file
├── .psqlrc                      # Test PostgreSQL configuration
├── migration-config.json       # Migration tool test config
├── setup-test-db.nu            # Database initialization
├── cleanup-test-db.nu          # Database cleanup  
├── run-tests.nu                # Test suite runner
├── fixtures/                   # Test data
│   └── migrations/
│       ├── core/               # Core migrations
│       ├── impl/               # Implementation migrations  
│       └── acme/               # Customer migrations
├── suites/                     # Integration test suites
│   ├── test-basic-functionality.nu
│   ├── test-multi-track.nu
│   ├── test-validation.nu
│   └── test-psql-features.nu
└── tmp/                        # Runtime data (git ignored)
    ├── postgres/               # PostgreSQL data
    ├── sockets/                # Unix sockets
    └── logs/                   # PostgreSQL logs
```

## Common Commands

```bash
# Quick smoke test (no setup required)
nu smoke-test.nu

# Full test environment setup
nix-shell
nu test/setup-test-db.nu

# Run specific test suite  
nu test/suites/test-basic-functionality.nu

# Run all tests
nu test/run-tests.nu

# Run tests with pattern matching
nu test/run-tests.nu --test-pattern "basic"

# Manual database access
psql -h $TEST_SOCKET_DIR -p $PGPORT -U $PGUSER -d $PGDATABASE

# Check test database status
pg_ctl status -D $TEST_DB_DIR

# View PostgreSQL logs
tail -f test/tmp/logs/postgres.log

# Complete cleanup
nu test/cleanup-test-db.nu
```

## Writing Tests

Follow the standard test pattern from [TESTING.md](../TESTING.md):

```nushell
#!/usr/bin/env nu

# Test description and expected output
use src/mod.nu *

try {
    # Test logic - suppress output with | ignore
    migrate status test/fixtures/migrations/core | ignore
    
    print "TEST_RESULT: PASS"
} catch {
    print "TEST_RESULT: FAIL"
    exit 1
}
```

## Troubleshooting

### Database Connection Issues
```bash
# Check if PostgreSQL is running
pg_ctl status -D $TEST_DB_DIR

# Restart database
nu test/cleanup-test-db.nu --force
nu test/setup-test-db.nu
```

### Port Conflicts  
The test uses port 5433 to avoid conflicts. If needed, change `PGPORT` in `shell.nix`.

### Permission Issues
Ensure test directories are writable:
```bash
chmod -R 755 test/tmp/
```

### Nix Shell Issues
If dependencies are missing:
```bash
nix-shell --pure  # Clean environment
nix-collect-garbage  # Clear cache if needed
```

## CI/CD Integration

Example GitHub Actions workflow:
```yaml
- name: Run Migration Tests
  run: |
    nix-shell --run "
      nu smoke-test.nu | grep -q 'TEST_RESULT: PASS' &&
      nu test/setup-test-db.nu &&
      nu test/run-tests.nu | grep -q 'TEST_RESULT: PASS'
    "
```

## Performance Considerations

- **Smoke tests**: ~1 second (no database)
- **Database setup**: ~10-30 seconds
- **Integration tests**: ~30-60 seconds  
- **Full test suite**: ~2-5 minutes

For faster development, use smoke tests for quick validation and integration tests for comprehensive checks.