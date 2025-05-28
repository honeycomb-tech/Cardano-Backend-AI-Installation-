-- NOTE: change to your own passwords for production environments
\set pgpass 'fQpUUR6Azw1eJcjktNMfYHxPnzYADauVJEyxKWMVYic='

-- Create or modify the required roles with the proper password
DO
$$
BEGIN
  -- supabase_admin
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_admin') THEN
    CREATE ROLE supabase_admin LOGIN PASSWORD 'fQpUUR6Azw1eJcjktNMfYHxPnzYADauVJEyxKWMVYic=';
  ELSE
    ALTER ROLE supabase_admin WITH PASSWORD 'fQpUUR6Azw1eJcjktNMfYHxPnzYADauVJEyxKWMVYic=';
  END IF;

  -- supabase_auth_admin
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    CREATE ROLE supabase_auth_admin LOGIN PASSWORD 'fQpUUR6Azw1eJcjktNMfYHxPnzYADauVJEyxKWMVYic=';
  ELSE
    ALTER ROLE supabase_auth_admin WITH PASSWORD 'fQpUUR6Azw1eJcjktNMfYHxPnzYADauVJEyxKWMVYic=';
  END IF;

  -- authenticator
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator LOGIN PASSWORD 'fQpUUR6Azw1eJcjktNMfYHxPnzYADauVJEyxKWMVYic=';
  ELSE
    ALTER ROLE authenticator WITH PASSWORD 'fQpUUR6Azw1eJcjktNMfYHxPnzYADauVJEyxKWMVYic=';
  END IF;

  -- pgbouncer
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'pgbouncer') THEN
    CREATE ROLE pgbouncer LOGIN PASSWORD 'fQpUUR6Azw1eJcjktNMfYHxPnzYADauVJEyxKWMVYic=';
  ELSE
    ALTER ROLE pgbouncer WITH PASSWORD 'fQpUUR6Azw1eJcjktNMfYHxPnzYADauVJEyxKWMVYic=';
  END IF;

  -- supabase_storage_admin
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_storage_admin') THEN
    CREATE ROLE supabase_storage_admin LOGIN PASSWORD 'fQpUUR6Azw1eJcjktNMfYHxPnzYADauVJEyxKWMVYic=';
  ELSE
    ALTER ROLE supabase_storage_admin WITH PASSWORD 'fQpUUR6Azw1eJcjktNMfYHxPnzYADauVJEyxKWMVYic=';
  END IF;

  -- supabase_functions_admin
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_functions_admin') THEN
    CREATE ROLE supabase_functions_admin LOGIN PASSWORD 'fQpUUR6Azw1eJcjktNMfYHxPnzYADauVJEyxKWMVYic=';
  ELSE
    ALTER ROLE supabase_functions_admin WITH PASSWORD 'fQpUUR6Azw1eJcjktNMfYHxPnzYADauVJEyxKWMVYic=';
  END IF;

  -- anon
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon;
  END IF;
END
$$;

-- Create required schemas if they don't exist
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS storage;
CREATE SCHEMA IF NOT EXISTS graphql_public;
CREATE SCHEMA IF NOT EXISTS _supavisor;
CREATE SCHEMA IF NOT EXISTS _realtime;

-- Grant necessary privileges
GRANT ALL ON SCHEMA auth TO supabase_auth_admin;
GRANT ALL ON SCHEMA storage TO supabase_storage_admin;
GRANT ALL ON SCHEMA public TO authenticator;
GRANT ALL ON SCHEMA public TO anon;
GRANT ALL ON SCHEMA _supavisor TO supabase_admin;
GRANT ALL ON SCHEMA _realtime TO authenticator;

-- Set search paths
ALTER DATABASE honeycombdb SET search_path = public, auth, storage, _supavisor, _realtime;
ALTER ROLE supabase_auth_admin SET search_path = public, auth;
ALTER ROLE supabase_storage_admin SET search_path = public, storage;
ALTER ROLE authenticator SET search_path = public, auth, storage, _supavisor, _realtime;
ALTER ROLE anon SET search_path = public, auth, storage, _supavisor, _realtime;

ALTER USER authenticator WITH PASSWORD :'pgpass';
ALTER USER pgbouncer WITH PASSWORD :'pgpass';
ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_functions_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_storage_admin WITH PASSWORD :'pgpass';
