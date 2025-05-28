#!/bin/bash

# Script to check the status of the Carp indexer

echo "==============================================="
echo "Carp Indexer Status"
echo "==============================================="

# Check if the container is running
echo "Container status:"
docker ps | grep carp-indexer || echo "Container not running"

echo ""
echo "Recent logs (last 30 lines):"
docker logs --tail 30 carp-indexer 2>&1 || echo "Could not retrieve logs"

echo ""
echo "Database connectivity:"
docker exec -i supabase-db psql -U postgres -d carpdb -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" 2>&1 || echo "Could not connect to database"

echo ""
echo "===============================================" 
 
 
 
 
 
 