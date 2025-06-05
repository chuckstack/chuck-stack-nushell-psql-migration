# Nushell + PostgreSQL Best Practices

## String Interpolation Escaping Rules

When using nushell string interpolation (`$"..."`), **opening parentheses have special meaning** and must be handled carefully.

### ✅ **Correct Usage:**

#### Variable Interpolation (NO escaping needed)
```nushell
# Variables
$"SELECT * FROM ($table_name)"           # ✅ Correct
$"Database: ($env.PGDATABASE)"          # ✅ Correct

# Function calls  
$"(ansi green)Success(ansi reset)"      # ✅ Correct
$"Result: ($some_function)"             # ✅ Correct
```

#### SQL Syntax (REQUIRES escaping)
```nushell
# Subqueries
$"SELECT EXISTS \(SELECT FROM table)"   # ✅ Correct
$"WHERE id IN \(1,2,3)"                # ✅ Correct

# Column definitions
$"CREATE TABLE test \(id INT)"         # ✅ Correct

# Value lists
$"INSERT INTO table VALUES \(1, 'x')" # ✅ Correct

# Column lists
$"INSERT INTO table \(col1, col2)"    # ✅ Correct
```

### ❌ **Incorrect Usage:**

```nushell
# Missing escapes - will cause parser errors
$"SELECT EXISTS (SELECT FROM table)"   # ❌ WRONG
$"CREATE TABLE test (id INT)"          # ❌ WRONG
$"INSERT INTO table (col1, col2)"      # ❌ WRONG
```

## psql Command Best Practices

### ✅ **Use Input Piping (Recommended)**
```nushell
# Safe - no shell escaping issues
$sql | psql -h $host -p $port -U $user -d $database

# Example
$"SELECT * FROM users WHERE name = 'O''Brien'" | psql -t
```

### ❌ **Avoid -c Flag (Problematic)**
```nushell
# Dangerous - shell escaping issues
psql -c $"SELECT * FROM users WHERE name = 'O''Brien'"  # ❌ WRONG
```

## Common Patterns

### Database Queries
```nushell
# Table existence check
let sql = $"SELECT EXISTS \(SELECT FROM information_schema.tables WHERE table_name = '($table_name)');"
let exists = ($sql | psql -t | str trim | str contains "t")

# Row count
let sql = $"SELECT COUNT\(*) FROM ($table_name);"
let count = ($sql | psql -t | str trim | into int)

# Insert with values
let sql = $"INSERT INTO ($table_name) \(name, email) VALUES \('($name)', '($email)');"
$sql | psql
```

### Migration Tracking
```nushell
# Create tracking table
let sql = $"CREATE TABLE IF NOT EXISTS ($tracking_table) \(
    id SERIAL PRIMARY KEY,
    filename VARCHAR\(255) NOT NULL,
    executed_at TIMESTAMP DEFAULT NOW\(\)
);"
$sql | psql

# Insert migration record  
let sql = $"INSERT INTO ($tracking_table) \(filename, checksum) VALUES \('($filename)', '($checksum)');"
$sql | psql
```

### Complex SQL with Multiple Parentheses
```nushell
# Multiple nested parentheses
let sql = $"
SELECT u.name, COUNT\(p.id) as post_count
FROM users u 
LEFT JOIN posts p ON \(u.id = p.user_id AND p.published = true)
WHERE u.created_at > '($start_date)'
GROUP BY u.id, u.name
HAVING COUNT\(p.id) > ($min_posts)
ORDER BY post_count DESC;"

$sql | psql -t
```

## Error Messages to Watch For

If you see these errors, check your parentheses escaping:

```
Error: nu::parser::assignment_requires_variable
  x Assignment operations require a variable.
     needs to be a variable
```

This usually means an unescaped `(` in string interpolation.

## Testing Your SQL

Always test complex SQL strings before using them:

```nushell
# Debug: Print the SQL first
let sql = $"SELECT EXISTS \(SELECT FROM table WHERE name = '($name)');"
print $sql  # Verify it looks correct

# Then execute
$sql | psql -t
```

## Summary

1. **Variable interpolation**: `($variable)` - no escaping needed
2. **SQL parentheses**: `\(SQL syntax)` - always escape opening parenthesis  
3. **Use input piping**: `$sql | psql` not `psql -c $sql`
4. **Test complex strings**: Print them first to verify correctness