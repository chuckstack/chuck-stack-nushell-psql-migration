# Nushell PostgreSQL Migration Tool

A lightweight database migration utility built with Nushell that executes PostgreSQL migrations using `psql`. Supports multi-track migrations for ERP environments with core and implementation-specific tracks.

The reason this repository exists:

- Needed a CLI-centric solution
- Evaluated sqlx-cli; however, the project determined they would rigidly limit migrations to a single track
- Evaluated flyway; however, they do not natively support unix sockets

## Why Multiple Tracks?

In an enterprise setting like ERP where multiple actors contribute to a resulting installation (core + integrators + customers), maintaining a single migration repository/table/track is not acceptable. Core improvements go into the 'core' track maintained by the core team. Implementation firms place improvements in the 'impl' track. Etc...

You may name any track as you deem appropriate. 'core' and 'impl' are simply offered for reference. You may have as many tracks as you wish.

Generally, 'core' team track migrations are executed first as part of any release. Then following tracks are executed as deemed appropriate.

## Quick Start

1. **Install dependencies:**
   - [Nushell](https://nushell.sh) (v0.80+)
   - PostgreSQL with `psql` client

2. **Add to your project:**
   ```bash
   # Copy src/ directory to your project
   cp -r src/ /path/to/your/project/migration-tool/
   ```

3. **Set database connection:**
   ```bash
   export PGHOST=localhost
   export PGPORT=5432
   export PGDATABASE=your_app_db
   export PGUSER=postgres
   export PGPASSWORD=your_password
   ```

4. **Create migration directories:**
   ```bash
   mkdir -p migrations/core migrations/impl
   ```

5. **Run migrations:**
   ```bash
   nu migration-tool/migrate.nu run migrations/core
   nu migration-tool/migrate.nu run migrations/impl
   ```

## Migration Files

Create timestamped SQL files following this naming pattern:
```
{timestamp}_{track}_{description}.sql

Examples:
migrations/core/20231201120000_core_create_users_table.sql
migrations/impl/20231201130000_impl_add_custom_fields.sql
```

## Commands

```bash
# Apply migrations in directory
nu migrate.nu run ./migrations/core

# Show migration status
nu migrate.nu status ./migrations/core

# Create new migration
nu migrate.nu add ./migrations/core create_users_table

# Show migration history
nu migrate.nu history ./migrations/core

# Validate migrations without running
nu migrate.nu validate ./migrations
```

## Multi-Track Architecture

Organize migrations into separate tracks for different concerns:

```
migrations/
├── core/     # Base application migrations
├── impl/     # Implementation customizations  
└── customer/ # Customer-specific migrations
```

Each track maintains its own metadata table (`migrations_core`, `migrations_impl`, etc.).

## Example Usage

See <https://github.com/chuckstack/stk-app-sql> for an example project using this migration tool.

## Development & Testing

Run the test suite:
```bash
cd test/
nix-shell --run "nu test-runner.nu --all"
```

For detailed testing information, see `test/README.md`.

## Features

- **Atomic migrations:** All pending migrations execute in a single transaction
- **Multi-track support:** Separate migration paths for different concerns
- **Unix socket support:** Full PostgreSQL unix socket compatibility
- **Environment isolation:** Explicit control of psql environment variables
- **Pre-flight validation:** Optional Nushell validation scripts (`.nu` files)
