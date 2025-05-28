#!/bin/bash

# Script to reset the Carp database (honeycombdb) to a clean state
set -e

echo "==============================================="
echo "Resetting Carp Database (honeycombdb)"
echo "==============================================="

# Stop Carp container first to avoid connection issues
echo "Stopping Carp container..."
docker stop carp-indexer 2>/dev/null || true
docker rm carp-indexer 2>/dev/null || true

# Connect to PostgreSQL and drop all tables
echo "Connecting to PostgreSQL and dropping all tables..."
docker exec -i supabase-db psql -U postgres -d honeycombdb << 'EOF'

-- Create a function to drop all tables
CREATE OR REPLACE FUNCTION drop_all_tables() RETURNS void AS $$
DECLARE
    stmt TEXT;
BEGIN
    -- Disable triggers temporarily
    SET session_replication_role = 'replica';
    
    -- Get a list of all tables and drop them
    FOR stmt IN 
        SELECT 'DROP TABLE IF EXISTS "' || tablename || '" CASCADE;' 
        FROM pg_tables 
        WHERE schemaname = 'public'
    LOOP
        EXECUTE stmt;
    END LOOP;
    
    -- Re-enable triggers
    SET session_replication_role = 'origin';
    
    -- Get a list of all sequences and reset them
    FOR stmt IN 
        SELECT 'ALTER SEQUENCE "' || sequence_name || '" RESTART WITH 1;' 
        FROM information_schema.sequences 
        WHERE sequence_schema = 'public'
    LOOP
        EXECUTE stmt;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Execute the function
SELECT drop_all_tables();

-- Clean up the function
DROP FUNCTION IF EXISTS drop_all_tables();

-- Report result
SELECT 'Database reset complete.' as result;
EOF

echo ""
echo "Database has been reset to a clean state."
echo "==============================================="
echo "Next steps:"
echo "1. Run the full stack script: /root/workspace/cardano-stack/start-full-stack.sh"
echo "2. Or deploy individual components as needed"
echo "===============================================" 