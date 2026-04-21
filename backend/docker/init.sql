-- docker/init.sql
-- Run automatically by postgres:16-alpine on first container start
-- Enables performance extensions required by the app

-- Full-text search + trigram similarity
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Faster GIN indexing on composite types  
CREATE EXTENSION IF NOT EXISTS btree_gin;

-- Query performance monitoring (viewable via pgAdmin → Statistics)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Verify
SELECT name, default_version, installed_version
FROM pg_available_extensions
WHERE name IN ('pg_trgm', 'unaccent', 'btree_gin', 'pg_stat_statements');
