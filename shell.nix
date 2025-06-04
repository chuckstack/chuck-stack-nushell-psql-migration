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

    # Set up test environment variables
    export TEST_ROOT="$(pwd)/test"
    export TEST_DB_DIR="$TEST_ROOT/tmp/postgres"
    export TEST_SOCKET_DIR="$TEST_ROOT/tmp/sockets"
    export TEST_LOG_DIR="$TEST_ROOT/tmp/logs"
    
    # PostgreSQL configuration for testing
    export PGDATA="$TEST_DB_DIR"
    export PGHOST="$TEST_SOCKET_DIR"
    export PGPORT="5433"
    export PGDATABASE="migration_test"
    export PGUSER="test_user"
    export PGPASSWORD="test_password"
    
    # psql configuration
    export PSQLRC="$TEST_ROOT/.psqlrc"
    export PGOPTIONS="-c log_statement=all -c log_destination=stderr"
    export PGCLIENTENCODING="UTF8"
    
    # Migration tool configuration
    export MIGRATION_CONFIG="$TEST_ROOT/migration-config.json"
    
    # Create test directories if they don't exist
    mkdir -p "$TEST_DB_DIR" "$TEST_SOCKET_DIR" "$TEST_LOG_DIR"
    
    echo -e "''${YELLOW}Test environment configured:''${NC}"
    echo -e "  DB Dir: $TEST_DB_DIR"
    echo -e "  Socket: $TEST_SOCKET_DIR"
    echo -e "  Config: $MIGRATION_CONFIG"
    echo ""
    echo -e "''${GREEN}Run 'nu test/setup-test-db.nu' to initialize test database''${NC}"
    echo -e "''${GREEN}Run 'nu test/run-tests.nu' to execute test suite''${NC}"
    echo -e "''${GREEN}Run 'nu test/cleanup-test-db.nu' to clean up test database''${NC}"
  '';
}