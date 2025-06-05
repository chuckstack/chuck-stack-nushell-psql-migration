#!/usr/bin/env nu

# Smoke test for migration utility - tests basic functionality without database
# Expected output: "TEST_RESULT: PASS" for success, "TEST_RESULT: FAIL" for failure
use ../src/mod.nu *

try {
    # Test migration discovery and parsing
    migrate status fixtures/migrations/core | ignore
    
    # If we get here, the test passed
    print "TEST_RESULT: PASS"
} catch {
    print "TEST_RESULT: FAIL"
    exit 1
}