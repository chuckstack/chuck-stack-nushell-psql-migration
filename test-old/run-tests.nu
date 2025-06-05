#!/usr/bin/env nu

# Run migration utility test suite
def main [
    --verbose (-v): bool = false,
    --test-pattern: string = "*",
    --setup: bool = true
] {
    print $"(ansi green)Running migration utility test suite...(ansi reset)"
    
    if $setup {
        print "Setting up test environment..."
        nu test/setup-test-db.nu
    }
    
    # Test configuration
    let test_config = {
        verbose: $verbose,
        pattern: $test_pattern,
        start_time: (date now)
    }
    
    print $"Test configuration: ($test_config)"
    
    # Run test suites
    let test_suites = [
        "test-basic-functionality",
        "test-multi-track", 
        "test-validation",
        "test-psql-features"
    ]
    
    mut passed = 0
    mut failed = 0
    mut results = []
    
    for suite in $test_suites {
        if ($test_pattern == "*") or ($suite | str contains $test_pattern) {
            print $"(ansi blue)Running test suite: ($suite)(ansi reset)"
            
            let suite_file = $"test/suites/($suite).nu"
            if ($suite_file | path exists) {
                try {
                    nu $suite_file
                    $passed = $passed + 1
                    $results = ($results | append {suite: $suite, status: "PASS"})
                    print $"(ansi green)✓ ($suite) PASSED(ansi reset)"
                } catch {
                    $failed = $failed + 1
                    $results = ($results | append {suite: $suite, status: "FAIL", error: $in})
                    print $"(ansi red)✗ ($suite) FAILED: ($in)(ansi reset)"
                }
            } else {
                print $"(ansi yellow)⚠ ($suite) SKIPPED: Test file not found(ansi reset)"
                $results = ($results | append {suite: $suite, status: "SKIP"})
            }
        }
    }
    
    # Print summary
    let end_time = (date now)
    let duration = ($end_time - $test_config.start_time)
    
    print ""
    print $"(ansi cyan)Test Summary:(ansi reset)"
    print $"  Passed: (ansi green)($passed)(ansi reset)"
    print $"  Failed: (ansi red)($failed)(ansi reset)"
    print $"  Duration: ($duration)"
    print ""
    
    # Show detailed results
    $results | table
    
    if $failed > 0 {
        exit 1
    } else {
        print $"(ansi green)All tests passed!(ansi reset)"
        exit 0
    }
}