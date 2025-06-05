# Testing Guidelines

## Overview
This document defines the testing standards and practices for the nushell PostgreSQL migration utility.

## Test Output Standard

All tests must follow a consistent output format for reliable automation and CI/CD integration.

### Required Output Format

**Success:**
```
TEST_RESULT: PASS
```

**Failure:**
```
TEST_RESULT: FAIL
```

### Requirements
1. **Single Line Output**: Test result must be exactly one line
2. **Exit Codes**: `0` for PASS, `1` for FAIL  
3. **Suppress Normal Output**: Use `| ignore` to suppress command output
4. **Grep-Friendly**: `grep "TEST_RESULT: PASS"` must reliably detect success

### Standard Test Pattern
```nushell
#!/usr/bin/env nu

# Test description and expected output
use src/mod.nu *

try {
    # Test logic here - suppress output with | ignore
    test_command | ignore
    
    # If we reach here, test passed
    print "TEST_RESULT: PASS"
} catch {
    print "TEST_RESULT: FAIL"
    exit 1
}
```

## Test Categories

### Smoke Tests
- **Purpose**: Basic functionality without external dependencies
- **Pattern**: `smoke-test*.nu`
- **Location**: Project root
- **Example**: Database-free migration file discovery

### Integration Tests  
- **Purpose**: Full workflow with database connectivity
- **Pattern**: `test/suites/test-*.nu`
- **Location**: `test/suites/`
- **Example**: End-to-end migration execution

### Unit Tests
- **Purpose**: Individual function testing
- **Pattern**: `test/unit/test-*.nu` 
- **Location**: `test/unit/`
- **Example**: Migration filename parsing

## Running Tests

### Prerequisites
**IMPORTANT**: All tests must be run within the nix-shell environment to ensure proper environment variables and dependencies are available.

```bash
# Enter the test environment (required first step)
cd test/
nix-shell

# You should see output confirming the environment setup:
# "Entering nushell psql migration testing environment"
# "✓ Clean environment confirmed"
```

### Smoke Test (No Database Required)
The smoke test validates core functionality without requiring a database connection:

```bash
# Run smoke test (from test directory, no nix-shell needed)
cd test/
nu smoke-test.nu

# Check result programmatically
if nu smoke-test.nu | grep -q "TEST_RESULT: PASS"; then
    echo "Test passed"
else
    echo "Test failed"
fi
```

**Use smoke test for**:
- Quick validation that basic migration parsing works
- CI/CD first-stage checks
- Environments without PostgreSQL access
- Verifying core module functionality

### Test Suites
```bash
# Enter test environment (required)
cd test/
nix-shell

# Run all test suites (database setup is automatic)
nu test-runner.nu

# Run specific test suites
nu test-runner.nu basic validation

# Run with verbose output
nu test-runner.nu --verbose

# Manual database management (if needed)
nu test-env.nu setup    # Setup fresh database
nu test-env.nu status   # Check database status
nu test-env.nu reset    # Reset database to clean state
nu test-env.nu destroy  # Completely destroy test data
```

### Batch Mode (CI/CD)
```bash
# Run tests non-interactively
cd test/
nix-shell --run 'nu test-runner.nu --all'

# Run specific suites
nix-shell --run 'nu test-runner.nu basic validation'
```

### CI/CD Integration
```bash
# Run all tests and fail on first failure
for test in smoke-test*.nu; do
    if ! nu $test | grep -q "TEST_RESULT: PASS"; then
        echo "Test $test failed"
        exit 1
    fi
done
```

## Best Practices

1. **Fail Fast**: Exit immediately on first error
2. **Clean Output**: Suppress normal command output in tests
3. **Clear Names**: Use descriptive test file names
4. **Self-Contained**: Each test should be independent
5. **Document Expected Behavior**: Include comments explaining test purpose

## Test Environment

The testing environment is managed through nix-shell and provides:

- **Nix Shell**: Isolated, reproducible environment with PostgreSQL and Nushell
- **Local PostgreSQL**: Test database on port 5433 using unix sockets (socket dir = data dir)
- **Test Database**: `migration_test` database with `test_user` credentials
- **Test Data**: Sample migrations automatically created in `test/fixtures/migrations/`
- **Environment Variables**: All required PostgreSQL and test configuration
- **Auto-cleanup**: Exit handler automatically destroys test data on shell exit

### Environment Variables Set by nix-shell:
```
TEST_ROOT          # Test directory root
TEST_DB_DIR        # PostgreSQL data directory (also socket directory)  
PGHOST             # Socket directory (same as TEST_DB_DIR)
PGPORT=5433        # PostgreSQL port
PGDATABASE=migration_test
PGUSER=test_user
```

## Troubleshooting

### Common Issues

**"Required environment variable not set: TEST_ROOT"**
- Solution: You must run tests from within nix-shell
- Run: `cd test/ && nix-shell` first

**"PostgreSQL not found in PATH"**
- Solution: Ensure you're in the nix-shell environment
- Nix-shell provides PostgreSQL automatically

**Database connection errors**
- Run: `nu test-env.nu status` to check database status
- Run: `nu test-env.nu setup` to create fresh database
- Run: `nu test-env.nu destroy` then `nu test-env.nu setup` for complete reset

**Test failures due to leftover data**
- The test environment automatically resets the database between runs
- If issues persist, exit nix-shell and re-enter for complete cleanup

**Socket connection issues**
- Tests use unix sockets in the database data directory
- Ensure `$PGHOST` points to the database directory (set by nix-shell)

## Validation

To verify a test follows the standard:
```bash
result=$(nu test-name.nu)
if [[ "$result" == "TEST_RESULT: PASS" || "$result" == "TEST_RESULT: FAIL" ]]; then
    echo "✓ Test follows standard"
else
    echo "✗ Non-compliant output: $result"
fi
```