# Test-New: Clean Slate Testing System

A completely redesigned testing system for the nushell psql migration tool with strict clean-slate requirements and automatic lifecycle management.

## Key Features

- **Clean Slate Guarantee**: Every test run starts completely fresh, no data contamination
- **Automatic Lifecycle**: nix-shell manages database startup, PID tracking, and complete cleanup
- **Nushell-Centric**: All testing logic written in nushell with rich assertion framework
- **Nuclear Cleanup**: Exit trap ensures ALL test data is destroyed, no remnants left behind

## Architecture

```
test-new/
├── shell.nix              # Enhanced nix-shell with lifecycle management
├── test-env.nu           # Database lifecycle management
├── test-framework.nu     # Nushell test assertions and utilities  
├── test-runner.nu        # Main test orchestrator
├── migration-config.json # Test configuration
├── suites/               # Test suites
│   ├── basic.nu         # Basic functionality tests
│   └── validation.nu    # Validation and error handling tests
└── tmp/                 # Created fresh each run, destroyed on exit
    ├── postgres/        # PostgreSQL cluster
    ├── postgres.pid     # PID tracking for cleanup
    ├── sockets/         # Unix sockets
    └── logs/           # PostgreSQL logs
```

## Usage

### Interactive Mode
```bash
cd test-new
nix-shell                    # Enters environment, sets up clean state
nu test-env.nu setup        # Setup fresh database
nu test-runner.nu           # Run all tests
exit                         # Automatic cleanup destroys everything
```

### Batch Mode
```bash
cd test-new

# Run all tests
nix-shell --run "nu test-runner.nu --all"

# Run specific test suites  
nix-shell --run "nu test-runner.nu basic validation"

# Verbose output
nix-shell --run "nu test-runner.nu --all --verbose"
```

### Manual Database Management
```bash
# Within nix-shell:
nu test-env.nu status       # Check database status
nu test-env.nu setup        # Fresh database setup
nu test-env.nu reset        # Reset database (keep server running)
nu test-env.nu destroy      # Nuclear cleanup

# Test runner helpers:
nu test-runner.nu status    # Environment status
nu test-runner.nu list      # Available test suites
nu test-runner.nu setup     # Setup database
nu test-runner.nu destroy   # Cleanup everything
```

## Safety Features

### Pre-Entry Check
- nix-shell fails if ANY test remnants exist
- Forces manual cleanup: `rm -rf test-new/tmp/`
- Prevents data contamination between runs

### Exit Trap Cleanup
- Automatically kills database processes (tracked by PID)
- Removes ALL files in `tmp/` directory
- Triggered on: normal exit, Ctrl+C, shell termination

### Nuclear Option
- `destroy_all_test_data()` function removes everything
- Can be called manually via `nu test-env.nu destroy`
- Guaranteed complete cleanup

## Test Framework

### Assertion Functions
```nushell
assert-true $condition "message"
assert-equal $actual $expected "message"
assert-file-exists "path/to/file"
assert-table-exists "table_name" 
assert-sql-result "SELECT 1" "1"
```

### Database Helpers
```nushell
db-execute "CREATE TABLE test (id INT)"
db-query "SELECT COUNT(*) FROM test"
db-table-exists "table_name"
db-count-rows "table_name"
```

### Migration Utilities
```nushell
parse-migration-filename "20231201120000_core_create_table.sql"
validate-migration-timestamp "20231201120000"
execute-migration-file "path/to/migration.sql"
```

## Configuration

Environment variables are automatically set by nix-shell:
- `TEST_ROOT`: Base directory (test-new/)
- `TEST_DB_DIR`: PostgreSQL cluster location  
- `TEST_PID_FILE`: Database process ID file
- `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`: Database connection
- `MIGRATION_CONFIG`: Test configuration file

## Writing Tests

Create new test suites in `suites/` directory:

```nushell
#!/usr/bin/env nu
# suites/my-test.nu

use ../test-framework.nu *

export def run_tests [] {
    test-suite "My Test Suite" {
        [
            (test "Test description" { test_function }),
            (test "Another test" { another_test_function })
        ]
    }
}

def test_function [] {
    # Your test logic here
    assert-true true "This should pass"
}
```

Run with: `nu test-runner.nu my-test`

## Clean Slate Philosophy

This system is designed around the principle that **every test run should start from a completely clean state**:

1. **No persistent state**: Database and all files are created fresh each time
2. **No contamination**: Previous test runs cannot affect current runs  
3. **Nuclear cleanup**: Exit trap ensures no traces are left behind
4. **Fail-fast**: System refuses to start if remnants are detected
5. **Deterministic**: Same environment every time = reproducible results

This approach trades some performance for absolute reliability and debuggability.