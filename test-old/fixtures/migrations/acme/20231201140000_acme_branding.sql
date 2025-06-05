-- Migration: ACME Corp branding customizations
-- Track: acme
-- Description: Company-specific branding and configuration

\set migration_name '20231201140000_acme_branding'
\set track_name 'acme'
\set company_name 'ACME Corporation'

\echo 'Setting up branding for: ' :company_name

-- Create company configuration table
CREATE TABLE company_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value TEXT,
    config_type VARCHAR(20) DEFAULT 'string',
    description TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert ACME-specific branding configuration
INSERT INTO company_config (config_key, config_value, config_type, description) VALUES
    ('company.name', :company_name, 'string', 'Company display name'),
    ('company.logo_url', '/assets/acme-logo.png', 'string', 'Company logo URL'),
    ('company.primary_color', '#FF6B35', 'string', 'Primary brand color'),
    ('company.secondary_color', '#004E89', 'string', 'Secondary brand color'),
    ('company.support_email', 'support@acme.corp', 'string', 'Customer support email'),
    ('features.custom_reports', 'true', 'boolean', 'Enable custom reporting module'),
    ('features.advanced_analytics', 'true', 'boolean', 'Enable advanced analytics'),
    ('limits.max_users', '500', 'integer', 'Maximum number of users'),
    ('limits.storage_gb', '1000', 'integer', 'Storage limit in GB');

-- Create company-specific user preferences
CREATE TABLE user_preferences (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    preference_key VARCHAR(100) NOT NULL,
    preference_value TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, preference_key)
);

-- Add ACME-specific columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS acme_employee_id VARCHAR(20) UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS acme_department VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS acme_cost_center VARCHAR(20);

-- Create index for ACME-specific lookups
CREATE INDEX idx_users_acme_employee_id ON users(acme_employee_id) WHERE acme_employee_id IS NOT NULL;

\echo 'ACME branding configuration completed'