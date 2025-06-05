#!/usr/bin/env nu

# Nushell-centric test framework
# Provides assertion functions, test result tracking, and migration testing utilities

# Test result tracking
export def test-suite [
    name: string,
    tests: closure
] {
    print $"(ansi blue)Running test suite: ($name)(ansi reset)"
    
    let start_time = (date now)
    mut results = []
    mut passed = 0
    mut failed = 0
    
    # Execute tests and capture results
    let test_results = try {
        do $tests
    } catch { |err|
        [{name: "suite_error", status: "FAIL", error: $err.msg}]
    }
    
    # Process results
    for result in $test_results {
        if $result.status == "PASS" {
            $passed = ($passed + 1)
            print $"  (ansi green)✓ ($result.name)(ansi reset)"
        } else {
            $failed = ($failed + 1)
            print $"  (ansi red)✗ ($result.name): ($result.error)(ansi reset)"
        }
        $results = ($results | append $result)
    }
    
    let end_time = (date now)
    let duration = ($end_time - $start_time)
    
    # Return suite summary
    {
        suite: $name,
        passed: $passed,
        failed: $failed,
        duration: $duration,
        results: $results
    }
}

# Individual test assertion
export def test [
    name: string,
    test_fn: closure
] {
    try {
        do $test_fn
        {name: $name, status: "PASS"}
    } catch { |err|
        {name: $name, status: "FAIL", error: $err.msg}
    }
}

# Assertion functions
export def assert-true [
    condition: bool,
    message: string = "Assertion failed"
] {
    if not $condition {
        error make {msg: $message}
    }
}

export def assert-false [
    condition: bool,
    message: string = "Assertion failed"
] {
    if $condition {
        error make {msg: $message}
    }
}

export def assert-equal [
    actual: any,
    expected: any,
    message: string = "Values are not equal"
] {
    if $actual != $expected {
        error make {msg: $"($message): expected '($expected)', got '($actual)'"}
    }
}

export def assert-not-equal [
    actual: any,
    expected: any,
    message: string = "Values should not be equal"
] {
    if $actual == $expected {
        error make {msg: $"($message): both values are '($actual)'"}
    }
}

export def assert-contains [
    haystack: string,
    needle: string,
    message: string = "String does not contain expected value"
] {
    if not ($haystack | str contains $needle) {
        error make {msg: $"($message): '($haystack)' does not contain '($needle)'"}
    }
}

export def assert-file-exists [
    file_path: string,
    message: string = "File does not exist"
] {
    if not ($file_path | path exists) {
        error make {msg: $"($message): ($file_path)"}
    }
}

export def assert-table-exists [
    table_name: string,
    message: string = "Table does not exist"
] {
    let exists = try {
        let result = ($"SELECT EXISTS \(SELECT FROM information_schema.tables WHERE table_name = '($table_name)');" | psql -h $env.PGHOST -p $env.PGPORT -U $env.PGUSER -d $env.PGDATABASE -t)
        $result | str trim | str contains "t"
    } catch {
        false
    }
    
    if not $exists {
        error make {msg: $"($message): ($table_name)"}
    }
}

export def assert-sql-result [
    sql: string,
    expected: string,
    message: string = "SQL result does not match expected"
] {
    let actual = try {
        $sql | psql -h $env.TEST_SOCKET_DIR -p $env.PGPORT -U $env.PGUSER -d $env.PGDATABASE -t | str trim
    } catch { |err|
        error make {msg: $"SQL execution failed: ($err.msg)"}
    }
    
    if $actual != $expected {
        error make {msg: $"($message): expected '($expected)', got '($actual)'"}
    }
}

# Database helper functions and migration utilities (re-exported from src for test convenience)
use ../src/migrate.nu [db-execute, db-query, db-table-exists, db-count-rows, parse-migration-filename, validate-migration-timestamp]
export use ../src/migrate.nu [db-execute, db-query, db-table-exists, db-count-rows, parse-migration-filename, validate-migration-timestamp]

# Test fixtures creation
export def create-test-fixtures [] {
    # Create sample migration files for testing
    let fixtures_dir = $"($env.TEST_ROOT)/fixtures/migrations"
    mkdir $fixtures_dir
    
    # Core migrations
    mkdir $"($fixtures_dir)/core"
    "CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(100));" | save --force $"($fixtures_dir)/core/20231201120000_core_create_users_table.sql"
    "CREATE TABLE roles (id SERIAL PRIMARY KEY, name VARCHAR(50));" | save --force $"($fixtures_dir)/core/20231201120001_core_create_roles_table.sql"
    
    # Impl migrations  
    mkdir $"($fixtures_dir)/impl"
    "ALTER TABLE users ADD COLUMN email VARCHAR(255);" | save --force $"($fixtures_dir)/impl/20231201130000_impl_add_user_email.sql"
    
    print $"✓ Created test fixtures in ($fixtures_dir)"
}

# Test runner utilities
export def print-test-summary [
    suites: list
] {
    let total_passed = ($suites | reduce -f 0 {|suite, acc| $acc + $suite.passed})
    let total_failed = ($suites | reduce -f 0 {|suite, acc| $acc + $suite.failed})
    let total_tests = $total_passed + $total_failed
    
    print ""
    print $"(ansi cyan)Test Summary:(ansi reset)"
    print $"  Total Tests: ($total_tests)"
    print $"  Passed: (ansi green)($total_passed)(ansi reset)"
    print $"  Failed: (ansi red)($total_failed)(ansi reset)"
    
    if $total_failed == 0 {
        print $"(ansi green)All tests passed!(ansi reset)"
        exit 0
    } else {
        print $"(ansi red)($total_failed) test(s) failed!(ansi reset)"
        exit 1
    }
}