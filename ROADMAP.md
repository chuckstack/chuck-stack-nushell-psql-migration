# Implementation Roadmap

## Overview
This roadmap breaks down the nushell psql migration utility implementation into manageable milestones, each building on the previous phase.

## Milestone 1: Foundation (MVP) ✅ COMPLETED
**Goal**: Basic single-track migration execution with psql integration

### 1.1 Project Structure ✅
- [x] Create basic nushell module structure
- [x] Set up main entry point (`migrate.nu`)
- [x] Create core migration functionality in `src/` directory
- [x] Establish working module system

### 1.2 Configuration System ✅
- [x] Implement environment variable handling
- [x] Create configuration loading from JSON
- [x] Add validation for required PostgreSQL connection variables
- [x] Test connection establishment with psql

### 1.3 Migration Discovery ✅
- [x] Implement file scanning for `.sql` files in directory
- [x] Parse migration filenames (timestamp, track, description)
- [x] Validate filename format and structure
- [x] Sort migrations by timestamp

### 1.4 Basic Migration Execution ✅
- [x] Create metadata table for single track
- [x] Check which migrations have been applied
- [x] Execute pending migrations via psql
- [x] Record successful migrations in metadata table
- [x] Implement basic error handling and rollback

### 1.5 Core Commands (Phase 1) ✅
- [x] `migrate status ./path` - Show applied vs pending migrations
- [x] `migrate run ./path` - Execute pending migrations
- [x] `migrate history ./path` - Show migration history

### Milestone 1 Definition of Done ✅
- [x] Single track migrations work end-to-end
- [x] Basic error handling and transaction rollback
- [x] Core commands functional for single directory
- [x] Configuration via environment variables

---

## Testing System: Clean-Slate Nushell Framework ✅ COMPLETED
**Goal**: Complete testing infrastructure with clean-slate guarantees

### Test Infrastructure ✅
- [x] Unix socket only PostgreSQL configuration
- [x] Nuclear cleanup on exit (complete data destruction)
- [x] PID tracking and process management
- [x] Clean slate validation (fails if remnants exist)
- [x] nix-shell lifecycle management with traps

### Test Framework ✅
- [x] Nushell-centric test framework with assertions
- [x] Database helper functions (db-execute, db-query, etc.)
- [x] Migration testing utilities
- [x] Test suite discovery and execution
- [x] Structured test reporting with pass/fail counts

### Test Execution Modes ✅
- [x] Interactive mode: `cd test-new && nix-shell`
- [x] Batch mode: `nix-shell --run "nu test-runner.nu --all"`
- [x] Individual suites: `nix-shell --run "nu test-runner.nu basic"`
- [x] Verbose output and detailed reporting

### Current Test Results ✅
- [x] **11 tests passing** (ALL tests now passing - significant improvement from 7)
- [x] Database infrastructure fully functional
- [x] Migration file execution working
- [x] Error handling and rollback working
- [x] Path resolution issues resolved
- [x] Database connection tests improved
- [x] Migration ordering boundary conditions fixed
- [x] Complete test suite reliability achieved

### Recently Completed Testing Improvements ✅
- [x] Fix path resolution for test fixture discovery
- [x] Improve database connection test assertions  
- [x] Fix migration ordering test boundary conditions
- [x] Directory structure cleanup (test-old removed, test/ is now official)
- [x] All 11 tests consistently passing in both suites

### Next Steps for Testing System
- [ ] Add more comprehensive test suites for multi-track scenarios
- [ ] Create performance benchmarks for migration execution

---

## Milestone 2: Multi-Track Support
**Goal**: Support multiple migration tracks with path-based execution

### 2.1 Multi-Track Architecture
- [ ] Extract track name from filename
- [ ] Create track-specific metadata tables
- [ ] Implement track discovery from directory paths
- [ ] Support track-specific migration execution

### 2.2 Enhanced Directory Handling
- [ ] Support subdirectory scanning
- [ ] Implement one-track-per-directory validation
- [ ] Add mixed directory support as fallback
- [ ] Create directory structure validation

### 2.3 Cross-Track Operations
- [ ] Implement execution order (core first, then others alphabetically)
- [ ] Support running all tracks in directory tree
- [ ] Add track filtering capabilities
- [ ] Create track status reporting

### 2.4 Enhanced Commands
- [ ] Update all commands to support multi-track scenarios
- [ ] Add track-specific status reporting
- [ ] Implement tree-wide migration execution
- [ ] Add validation for track consistency

### Milestone 2 Definition of Done
- Multiple tracks work independently
- Core-first execution order implemented
- Directory tree operations functional
- All commands support multi-track scenarios

---

## Milestone 3: Pre-flight Validation
**Goal**: Add nushell script validation before SQL execution

### 3.1 Nushell Script Integration
- [ ] Detect `.nu` files alongside `.sql` files
- [ ] Execute `.nu` files before SQL execution
- [ ] Implement error propagation from validation scripts
- [ ] Add validation script output handling

### 3.2 Validation Framework
- [ ] Create validation utilities for common checks
- [ ] Implement database state checking helpers
- [ ] Add cross-track dependency validation
- [ ] Create validation result reporting

### 3.3 Atomic Execution with Validation
- [ ] Integrate pre-flight validation into execution flow
- [ ] Ensure validation errors prevent SQL execution
- [ ] Maintain transaction atomicity after validation
- [ ] Add validation timing and logging

### 3.4 Migration Creation with Validation
- [ ] Add `--with-validation` flag to `migrate add`
- [ ] Create validation script templates
- [ ] Implement validation script generation
- [ ] Add validation best practices documentation

### Milestone 3 Definition of Done
- Pre-flight validation prevents invalid migrations
- Validation scripts can check dependencies
- Atomic execution preserved with validation
- Migration creation supports validation scripts

---

## Milestone 4: Advanced psql Features
**Goal**: Leverage psql variables and conditional execution

### 4.1 Variable Injection
- [ ] Inject migration metadata as psql variables
- [ ] Add track name and timestamp variables
- [ ] Implement execution ID generation
- [ ] Create variable documentation and examples

### 4.2 psql Feature Examples
- [ ] Create example migrations using variables
- [ ] Demonstrate conditional migration patterns
- [ ] Add dynamic SQL generation examples
- [ ] Document psql feature integration

### 4.3 Enhanced Migration Templates
- [ ] Update migration creation to include variable examples
- [ ] Add conditional migration templates
- [ ] Create complex migration pattern examples
- [ ] Document best practices for psql features

### 4.4 Testing and Validation
- [ ] Test variable injection across different scenarios
- [ ] Validate conditional migration execution
- [ ] Test error handling with psql features
- [ ] Add integration tests for advanced features

### Milestone 4 Definition of Done
- Migration tool injects useful variables
- Example migrations demonstrate psql features
- Migration creation includes advanced templates
- Comprehensive testing of psql integration

---

## Milestone 5: Production Features
**Goal**: Production-ready features for reliability and usability

### 5.1 Enhanced Error Handling
- [ ] Improve error messages and diagnostics
- [ ] Add recovery procedures documentation
- [ ] Implement detailed logging
- [ ] Create troubleshooting guide

### 5.2 Migration Creation Tools
- [ ] Implement `migrate add` command
- [ ] Add migration templates and generators
- [ ] Create migration naming validation
- [ ] Support custom migration templates

### 5.3 Validation and Safety
- [ ] Add `migrate validate` command for dry-run testing
- [ ] Implement migration file integrity checking
- [ ] Add dependency validation warnings
- [ ] Create migration safety checks

### 5.4 Status and Reporting
- [ ] Enhanced status reporting with track breakdown
- [ ] Add migration timing and performance data
- [ ] Implement history with detailed metadata
- [ ] Create export capabilities for status data

### 5.5 Documentation and Examples
- [ ] Complete user documentation
- [ ] Create migration pattern examples
- [ ] Add troubleshooting guide
- [ ] Document best practices

### Milestone 5 Definition of Done
- Production-ready error handling and logging
- Complete command set implemented
- Comprehensive documentation
- Ready for real-world usage

---

## Implementation Notes

### Development Approach
- Each milestone should be fully functional before moving to the next
- Write tests for each component as it's implemented
- Maintain backward compatibility between milestones
- Document decisions and trade-offs in each phase

### Testing Strategy
- Unit tests for individual functions and modules
- Integration tests for full migration workflows
- End-to-end tests with real PostgreSQL databases
- Test with various PostgreSQL versions and configurations

### Risk Mitigation
- Start with simple, well-understood functionality
- Validate assumptions early with small test cases
- Plan for rollback and recovery at each milestone
- Document known limitations and workarounds

### Success Criteria
Each milestone should be evaluated on:
- Functional completeness of planned features
- Code quality and maintainability
- Test coverage and reliability
- Documentation completeness
- User experience and usability

## Getting Started
Begin with Milestone 1 by setting up the basic project structure and implementing the core configuration system. This foundation will support all subsequent features and provide early validation of the overall approach.