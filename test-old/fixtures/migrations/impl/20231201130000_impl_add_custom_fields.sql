-- Migration: Add custom fields to users
-- Track: impl
-- Description: Implementation-specific user customizations

\set migration_name '20231201130000_impl_add_custom_fields'
\set track_name 'impl'

\echo 'Adding custom fields for track: ' :track_name

-- Check if users table exists (cross-track dependency)
SELECT EXISTS(
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'users'
) \gset users_table_exists

\if :users_table_exists
    \echo 'Users table found, adding custom fields'
\else
    \echo 'ERROR: Users table from core track must exist first'
    \q
\endif

-- Add implementation-specific columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS department VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS employee_id VARCHAR(50) UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_attributes JSONB DEFAULT '{}'::jsonb;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login TIMESTAMP;

-- Create custom fields table for flexible attributes
CREATE TABLE user_custom_fields (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    field_name VARCHAR(100) NOT NULL,
    field_value TEXT,
    field_type VARCHAR(20) DEFAULT 'text',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, field_name)
);

-- Create index for performance
CREATE INDEX idx_user_custom_fields_user_id ON user_custom_fields(user_id);
CREATE INDEX idx_user_custom_fields_name ON user_custom_fields(field_name);

\echo 'Custom fields added successfully'