# Testing Framework

## Overview
This testing framework provides isolated, fast, and reproducible testing for the nushell psql migration utility using nix-shell and local PostgreSQL instances.

## Directory Structure

```
test/
├── README.md                    # This file
├── .psqlrc                      # Test-specific psqlrc configuration
├── migration-config.json       # Test configuration for migration tool
├── setup-test-db.nu            # Initialize test database
├── cleanup-test-db.nu          # Cleanup test database
├── run-tests.nu                # Test runner
├── fixtures/                   # Test data and sample migrations
│   └── migrations/
│       ├── core/               # Core track test migrations
│       ├── impl/               # Implementation track test migrations
│       └── acme/               # Customer-specific test migrations
├── suites/                     # Test suite modules
│   ├── test-basic-functionality.nu
│   ├── test-multi-track.nu
│   ├── test-validation.nu
│   └── test-psql-features.nu
└── tmp/                        # Runtime test data (auto-created)
    ├── postgres/               # PostgreSQL data directory
    ├── sockets/                # Unix socket directory
    └── logs/                   # PostgreSQL logs
```

## Getting Started

### 1. Enter the test environment
```bash
nix-shell
```

### 2. Initialize test database
```bash
nu test/setup-test-db.nu
```

### 3. Run tests
```bash
# Run all tests
nu test/run-tests.nu

# Run specific test pattern
nu test/run-tests.nu --test-pattern "basic"

# Run with verbose output
nu test/run-tests.nu --verbose
```

### 4. Cleanup (when done)
```bash
nu test/cleanup-test-db.nu
```

## Test Environment Configuration

### Environment Variables
The nix-shell automatically sets up these test-specific environment variables:

- `TEST_ROOT`: Base test directory
- `TEST_DB_DIR`: PostgreSQL data directory  
- `TEST_SOCKET_DIR`: Unix socket directory
- `TEST_LOG_DIR`: Log file directory
- `PGDATA`, `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`: PostgreSQL connection
- `PSQLRC`: Points to test-specific .psqlrc
- `MIGRATION_CONFIG`: Points to test configuration file

### PostgreSQL Configuration
- **Port**: 5433 (avoids conflicts with system PostgreSQL)
- **Socket**: `/test/tmp/sockets` (isolated from system)
- **Database**: `migration_test`
- **User**: `test_user`
- **Authentication**: Trust for local connections

## Test Fixtures

### Sample Migrations
The `fixtures/migrations/` directory contains realistic sample migrations that demonstrate:

- **Core track**: Basic user authentication and roles
- **Implementation track**: Custom fields and audit trails
- **Customer track**: Company-specific branding and configuration

### Migration Features Tested
- Basic SQL execution
- psql variables and conditional logic
- Cross-track dependencies
- Pre-flight validation with .nu files
- Complex schema changes
- Performance considerations

## Test Suites

### test-basic-functionality.nu
- Migration file discovery and parsing
- Basic SQL execution and connection testing
- Error handling and cleanup

### test-multi-track.nu
- Multi-track migration discovery
- Track-specific metadata tables
- Execution order (core first, then others)
- Cross-track operations

### test-validation.nu
- Pre-flight validation with .nu files
- Dependency checking
- Error propagation and rollback
- Validation script execution

### test-psql-features.nu
- Variable injection and usage
- Conditional migration execution  
- Dynamic SQL generation
- Advanced psql feature integration

## Writing Tests

### Test Structure
Each test suite should:
1. Print clear test descriptions
2. Use descriptive assertions with helpful error messages
3. Clean up any test data
4. Use the shared database connection environment

### Example Test Function
```nushell
def test_example [] {
    print "Test: Example functionality"
    
    # Setup
    let test_data = "some setup"
    
    # Execute
    let result = (some_command $test_data)
    
    # Assert
    if $result != $expected {
        error make { 
            msg: $"Expected ($expected), got ($result)" 
        }
    }
    
    print "  ✓ Example test passed"
    
    # Cleanup
    cleanup_test_data
}
```

### Common Utilities
Use these patterns for consistent testing:

```nushell
# Database connection test
psql -h $env.TEST_SOCKET_DIR -p $env.PGPORT -U $env.PGUSER -d $env.PGDATABASE -c "SELECT 1"

# Check if table exists
let table_exists = (psql -t -c "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'tablename')" | str trim)

# Count rows in migration metadata
let migration_count = (psql -t -c "SELECT COUNT(*) FROM migrations_core" | str trim | into int)
```

## Debugging

### Manual Database Access
Connect to the test database for manual inspection:
```bash
psql -h $TEST_SOCKET_DIR -p $PGPORT -U $PGUSER -d $PGDATABASE
```

### Log Files
PostgreSQL logs are written to `test/tmp/logs/postgres.log`

### Verbose Mode
Run tests with `--verbose` flag for detailed output

## CI/CD Integration

The test framework is designed to work in CI environments:
- Uses nix for reproducible dependencies
- Self-contained with no external dependencies
- Fast setup and teardown
- Clear exit codes (0 for success, 1 for failure)

### Example CI Usage
```bash
nix-shell --run "nu test/run-tests.nu"
```

## Performance Testing

The framework supports performance testing by:
- Timing migration execution
- Testing with large datasets
- Measuring database growth
- Validating index performance

Performance tests should be in a separate suite and may take longer to execute.

## Best Practices

1. **Isolation**: Each test should be independent and not rely on previous test state
2. **Cleanup**: Always clean up test data, even if tests fail
3. **Descriptive**: Use clear test names and error messages
4. **Fast**: Keep individual tests quick for rapid feedback
5. **Realistic**: Use realistic migration scenarios in fixtures
6. **Coverage**: Test both success and failure scenarios