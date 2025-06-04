-- Migration: Create roles table
-- Track: core
-- Description: User roles and permissions

\set migration_name '20231201120001_core_create_roles_table'
\set track_name 'core'

\echo 'Creating roles table for track: ' :track_name

-- Check if users table exists (dependency)
SELECT EXISTS(
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'users'
) \gset users_table_exists

\if :users_table_exists
    \echo 'Users table found, proceeding with roles table creation'
\else
    \echo 'ERROR: Users table must exist before creating roles table'
    \q
\endif

CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    permissions JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create user_roles junction table
CREATE TABLE user_roles (
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigned_by INTEGER REFERENCES users(id),
    PRIMARY KEY (user_id, role_id)
);

-- Insert default roles
INSERT INTO roles (name, description, permissions) VALUES 
    ('admin', 'System administrator', '["user.create", "user.delete", "role.manage"]'::jsonb),
    ('user', 'Regular user', '["profile.edit"]'::jsonb),
    ('readonly', 'Read-only access', '["data.read"]'::jsonb);

\echo 'Roles and user_roles tables created successfully'