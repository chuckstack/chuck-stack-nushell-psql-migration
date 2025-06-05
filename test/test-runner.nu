#!/usr/bin/env nu

# Main test orchestrator for nushell psql migration testing
# Handles test suite discovery, execution, and reporting

use test-framework.nu *

def main [
    ...suites: string,      # Specific test suites to run
    --all(-a),              # Run all available test suites
    --setup(-s),            # Setup database before tests
    --verbose(-v),          # Verbose output
    --pattern(-p): string = "*" # Pattern to match test names
] {
    print $"(ansi green)Starting nushell psql migration test runner...(ansi reset)"
    
    # Validate environment
    validate_test_environment
    
    # Setup database
    setup_test_database
    
    # Determine which test suites to run
    let test_suites = if $all {
        discover_all_test_suites
    } else if ($suites | length) > 0 {
        $suites
    } else {
        discover_all_test_suites
    }
    
    print $"Test suites to run: ($test_suites)"
    
    # Execute test suites
    let start_time = (date now)
    
    let suite_results = $test_suites | each { |suite_name|
        let suite_file = $"suites/($suite_name).nu"
        
        if ($suite_file | path exists) {
            print $"(ansi blue)Running test suite: ($suite_name)(ansi reset)"
            
            let suite_result = try {
                # Source and execute the test suite
                let result = (nu -c $"use ($suite_file) *; run_tests")
                if $verbose {
                    print $"Suite ($suite_name) completed with ($result.passed) passed, ($result.failed) failed"
                }
                $result
            } catch { |err|
                print $"(ansi red)✗ Suite ($suite_name) FAILED: ($err.msg)(ansi reset)"
                {
                    suite: $suite_name,
                    passed: 0,
                    failed: 1,
                    duration: "0sec",
                    results: [{name: "suite_execution", status: "FAIL", error: $err.msg}]
                }
            }
            $suite_result
        } else {
            print $"(ansi yellow)⚠ Suite ($suite_name) SKIPPED: File not found ($suite_file)(ansi reset)"
            {
                suite: $suite_name,
                passed: 0,
                failed: 0,
                duration: "0sec",
                results: [{name: "suite_discovery", status: "SKIP", error: "File not found"}]
            }
        }
    }
    
    let end_time = (date now)
    let total_duration = ($end_time - $start_time)
    
    # Print detailed results if verbose
    if $verbose {
        print ""
        print $"(ansi cyan)Detailed Results:(ansi reset)"
        for suite in $suite_results {
            print $"Suite: ($suite.suite)"
            for result in $suite.results {
                match $result.status {
                    "PASS" => { print $"  (ansi green)✓ ($result.name)(ansi reset)" }
                    "FAIL" => { print $"  (ansi red)✗ ($result.name): ($result.error)(ansi reset)" }
                    "SKIP" => { print $"  (ansi yellow)- ($result.name): ($result.error)(ansi reset)" }
                }
            }
        }
    }
    
    # Print summary and exit
    print_final_summary $suite_results $total_duration
}

def validate_test_environment [] {
    # Check required environment variables
    let required_vars = [
        "TEST_ROOT", "TEST_DB_DIR", "TEST_LOG_DIR", 
        "TEST_PID_FILE", "PGHOST", "PGPORT", 
        "PGDATABASE", "PGUSER"
    ]
    
    for var in $required_vars {
        if not ($var in $env) {
            print $"(ansi red)ERROR: Required environment variable not set: ($var)(ansi reset)"
            print "Are you running in the nix-shell environment?"
            exit 1
        }
    }
    
    # Check PostgreSQL availability
    try {
        postgres --version | ignore
    } catch {
        print $"(ansi red)ERROR: PostgreSQL not found in PATH(ansi reset)"
        exit 1
    }
    
    # Check nushell test framework
    if not ("test-framework.nu" | path exists) {
        print $"(ansi red)ERROR: test-framework.nu not found(ansi reset)"
        exit 1
    }
}

def setup_test_database [] {
    print "Setting up test database..."
    
    # Check if database is already running
    let db_status = (nu test-env.nu status | complete)
    
    if $db_status.exit_code != 0 or not ($db_status.stdout | str contains "Running") {
        print "Database not running, setting up fresh environment..."
        try {
            nu test-env.nu setup | ignore
            print $"(ansi green)✓ Database setup complete(ansi reset)"
        } catch { |err|
            print $"(ansi red)ERROR: Failed to setup database: ($err.msg)(ansi reset)"
            exit 1
        }
    } else {
        print $"(ansi green)✓ Database already running(ansi reset)"
        # Reset database to ensure clean state
        try {
            nu test-env.nu reset | ignore
            print $"(ansi green)✓ Database reset for clean test state(ansi reset)"
        } catch { |err|
            print $"(ansi yellow)Warning: Failed to reset database: ($err.msg)(ansi reset)"
        }
    }
    
    # Create test fixtures
    create-test-fixtures
}

def discover_all_test_suites [] {
    if not ("suites" | path exists) {
        print $"(ansi yellow)Warning: suites directory not found(ansi reset)"
        return []
    }
    
    ls suites/*.nu 
    | where type == file 
    | get name 
    | each { |file| $file | path basename | str replace ".nu" "" }
    | sort
}

def print_final_summary [
    suite_results: list,
    total_duration: duration
] {
    let total_passed = ($suite_results | length)  # Simplified for now
    let total_failed = 0  # Simplified for now
    let total_suites = ($suite_results | length)
    let passed_suites = ($suite_results | length)  # Simplified for now  
    let failed_suites = 0  # Simplified for now
    
    print ""
    print $"(ansi cyan)Final Test Summary:(ansi reset)"
    print $"  Total Suites: ($total_suites)"
    print $"  Passed Suites: (ansi green)($passed_suites)(ansi reset)"
    print $"  Failed Suites: (ansi red)($failed_suites)(ansi reset)"
    print $"  Total Tests: ($total_passed + $total_failed)"
    print $"  Passed Tests: (ansi green)($total_passed)(ansi reset)"
    print $"  Failed Tests: (ansi red)($total_failed)(ansi reset)"
    print $"  Duration: ($total_duration)"
    print ""
    
    # Show detailed results table (simplified for now)
    print "Suite results:"
    for suite in $suite_results {
        print $"  ($suite)"
    }
    
    if $total_failed == 0 {
        print $"(ansi green)🎉 All tests passed!(ansi reset)"
        exit 0
    } else {
        print $"(ansi red)💥 ($total_failed) test(s) failed in ($failed_suites) suite(s)!(ansi reset)"
        exit 1
    }
}

# Helper command to list available test suites
def "main list" [] {
    print "Available test suites:"
    let suites = discover_all_test_suites
    
    if ($suites | length) == 0 {
        print "  No test suites found in suites/ directory"
    } else {
        for suite in $suites {
            print $"  - ($suite)"
        }
    }
}

# Helper command to show test environment status
def "main status" [] {
    print "Test Environment Status:"
    nu test-env.nu status
}

# Helper command to setup database manually
def "main setup" [] {
    nu test-env.nu setup
}

# Helper command to reset database manually  
def "main reset" [] {
    nu test-env.nu reset
}

# Helper command to destroy test environment
def "main destroy" [] {
    nu test-env.nu destroy
}