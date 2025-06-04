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

### Individual Tests
```bash
# Run single test
nu smoke-test.nu

# Check result programmatically
if nu smoke-test.nu | grep -q "TEST_RESULT: PASS"; then
    echo "Test passed"
else
    echo "Test failed"
fi
```

### Test Suites
```bash
# Enter test environment
nix-shell

# Setup test database
nu test/setup-test-db.nu

# Run all tests
nu test/run-tests.nu

# Cleanup
nu test/cleanup-test-db.nu
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

- **Nix Shell**: Provides isolated, reproducible environment
- **Local PostgreSQL**: Test database on port 5433 with unix sockets
- **Test Data**: Sample migrations in `test/fixtures/`
- **Configuration**: Test-specific `.psqlrc` and environment variables

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