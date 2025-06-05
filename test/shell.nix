{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # Core tools
    nushell
    postgresql
    
    # Development tools
    git
    curl
    jq
    
    # Testing utilities
    coreutils
    procps
    
    # Optional: For debugging
    gdb
    valgrind
  ];

  shellHook = ''
    # Colors for output
    export RED='\033[0;31m'
    export GREEN='\033[0;32m'
    export YELLOW='\033[1;33m'
    export BLUE='\033[0;34m'
    export NC='\033[0m' # No Color

    echo -e "''${GREEN}Entering nushell psql migration testing environment''${NC}"
    echo -e "''${BLUE}PostgreSQL version: $(postgres --version)''${NC}"
    echo -e "''${BLUE}Nushell version: $(nu --version)''${NC}"

    # Set up test environment variables (matching reference system pattern)
    export TEST_ROOT="$(pwd)"
    export TEST_DB_DIR="$TEST_ROOT/tmp/postgres"
    export TEST_LOG_DIR="$TEST_ROOT/tmp/logs"
    export TEST_PID_FILE="$TEST_ROOT/tmp/postgres.pid"
    
    # PostgreSQL configuration for testing (socket dir = data dir like reference)
    export PGDATA="$TEST_DB_DIR"
    export PGHOST="$TEST_DB_DIR"
    export PGPORT="5433"
    export PGDATABASE="migration_test"
    export PGUSER="test_user"
    export PGPASSWORD="test_password"
    
    # psql configuration
    export PSQLRC="$TEST_ROOT/.psqlrc"
    export PGOPTIONS=""
    export PGCLIENTENCODING="UTF8"
    
    # Migration tool configuration
    export MIGRATION_CONFIG="$TEST_ROOT/migration-config.json"
    
    # PRE-CHECK: Completely remove any existing test remnants for true clean slate
    if [ -d "$TEST_ROOT/tmp" ] || [ -f "$TEST_PID_FILE" ]; then
      echo -e "''${YELLOW}Removing existing test remnants for clean slate...''${NC}"
      rm -rf "$TEST_ROOT/tmp/" 2>/dev/null || true
      echo -e "''${GREEN}✓ Previous test data removed''${NC}"
    fi
    
    # SUCCESS: Clean environment confirmed
    echo -e "''${GREEN}✓ Clean environment confirmed''${NC}"
    
    # Nuclear cleanup function
    destroy_all_test_data() {
      echo -e "''${YELLOW}Destroying all test data...''${NC}"
      
      # Kill database if running
      if [ -f "$TEST_PID_FILE" ]; then
        local pid=$(cat "$TEST_PID_FILE" 2>/dev/null)
        if [ -n "$pid" ]; then
          kill "$pid" 2>/dev/null || true
          echo -e "''${GREEN}✓ Killed database process $pid''${NC}"
        fi
      fi
      
      # Nuclear option: remove everything
      rm -rf "$TEST_ROOT/tmp/" 2>/dev/null || true
      echo -e "''${GREEN}✓ All test data destroyed''${NC}"
    }
    
    # Set up exit traps for cleanup
    trap 'destroy_all_test_data' EXIT INT TERM
    
    echo -e "''${YELLOW}Test environment configured:''${NC}"
    echo -e "  DB Dir: $TEST_DB_DIR"
    echo -e "  Socket: $PGHOST (same as DB dir)"
    echo -e "  PID File: $TEST_PID_FILE"
    echo -e "  Config: $MIGRATION_CONFIG"
    echo ""
    echo -e "''${GREEN}Interactive mode:''${NC}"
    echo -e "  nu test-env.nu setup        # Setup fresh database"
    echo -e "  nu test-runner.nu           # Run all tests"
    echo ""
    echo -e "''${GREEN}Batch mode examples:''${NC}"
    echo -e "  nix-shell --run 'nu test-runner.nu --all'"
    echo -e "  nix-shell --run 'nu test-runner.nu basic validation'"
    echo ""
    echo -e "''${BLUE}Exit will automatically destroy all test data''${NC}"
  '';
}