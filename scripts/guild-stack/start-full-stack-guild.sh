#!/bin/bash
set -e

echo "==============================================="
echo "Starting Full Cardano Stack: Supabase -> Carp -> Guild Node"
echo "==============================================="

# Load environment variables if .env file exists
if [ -f "../../.env" ]; then
    echo "Loading environment variables from .env file..."
    export $(grep -v '^#' ../../.env | xargs)
elif [ -f ".env" ]; then
    echo "Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
else
    echo "⚠️  No .env file found. Using default values."
    echo "   Copy .env.example to .env and configure your settings!"
fi

# Configuration with defaults
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"YOUR_SECURE_PASSWORD_HERE"}
DATABASE_URL=${DATABASE_URL:-"postgresql://postgres:${POSTGRES_PASSWORD}@supabase-db:5432/honeycombdb"}
NETWORK=${NETWORK:-"mainnet"}
MITHRIL_DOWNLOAD=${MITHRIL_DOWNLOAD:-"Y"}

# Validate required configuration
if [ "$POSTGRES_PASSWORD" = "YOUR_SECURE_PASSWORD_HERE" ]; then
    echo "❌ ERROR: Please configure your database password in .env file!"
    echo "   Copy .env.example to .env and set POSTGRES_PASSWORD"
    exit 1
fi

# Get the directory of this script
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$BASE_DIR/../.." &> /dev/null && pwd )"
SUPABASE_DIR="$BASE_DIR/../supabase-project"
GUILD_DIR="${GUILD_DATA_DIR:-$PROJECT_ROOT/data/cardano-node-guild}"
CARP_DIR="$BASE_DIR/../carp"

echo "Using configuration:"
echo "  Project Root: $PROJECT_ROOT"
echo "  Guild Data Dir: $GUILD_DIR"
echo "  Network: $NETWORK"
echo "  Mithril Download: $MITHRIL_DOWNLOAD"

# --- Step 1: Start Supabase ---
echo ""
echo "--- Phase 1: Starting Supabase ---"
cd "$SUPABASE_DIR"
if docker compose ps | grep -q "supabase-db"; then
  echo "Supabase 'supabase-db' container already running. Ensuring all Supabase services are up..."
  docker compose up -d # Ensures all services are up if some were down
else
  echo "Starting Supabase services..."
  docker compose up -d
fi

echo "Waiting for Supabase database (supabase-db) to be healthy (up to 120 seconds)..."
timeout=120
db_ready=false
for i in $(seq 1 $timeout); do
  if docker ps --filter "name=supabase-db" --filter "health=healthy" | grep -q "healthy"; then
    echo "✅ Supabase database is healthy."
    db_ready=true
    break
  fi
  if ! docker ps --filter "name=supabase-db" --filter "status=running" | grep -q "running"; then
      echo "❌ Supabase database container (supabase-db) is not running or has exited."
      exit 1
  fi
  echo -n "."
  sleep 1
done

if [ "$db_ready" = false ]; then
  echo "❌ Supabase database did not become healthy in time. Please check logs: docker compose logs supabase-db"
  exit 1
fi
echo "Supabase services started."

# Ensure honeycombdb database exists (Carp will write here)
DB_NAME_TO_CHECK="honeycombdb"
# Check if db exists using psql. The command returns 0 if successful (db exists), 1 otherwise.
if docker exec supabase-db psql -U postgres -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME_TO_CHECK"; then
    echo "✅ Database '$DB_NAME_TO_CHECK' already exists."
else
    echo "Database '$DB_NAME_TO_CHECK' does not exist. Creating it..."
    if docker exec supabase-db createdb -U postgres "$DB_NAME_TO_CHECK"; then
        echo "✅ Database '$DB_NAME_TO_CHECK' created successfully."
    else
        echo "❌ Failed to create database '$DB_NAME_TO_CHECK'."
        exit 1 # This should be a fatal error if Carp needs it
    fi
fi

# --- Step 2: Prepare Carp Database Migrations ---
echo ""
echo "--- Phase 2: Preparing Carp Database Migrations ---"

# Stop any existing Carp container
echo "Stopping any existing Carp containers..."
docker stop carp-indexer 2>/dev/null || true
docker rm carp-indexer 2>/dev/null || true

# Set up Carp migration container
echo "Setting up temporary Carp container for database migrations..."
WORK_DIR="/tmp/carp-migration-$(date +%s)"
mkdir -p "${WORK_DIR}"

# Create migration script
cat > "${WORK_DIR}/run-migrations.sh" << 'EOF'
#!/bin/bash
set -e

cd /app
echo "Running Carp database migrations..."
./migration up
echo "✅ Migrations completed successfully."
exit 0
EOF

chmod +x "${WORK_DIR}/run-migrations.sh"

# Run migrations
echo "Running Carp database migrations..."
docker run --rm \
  --name carp-migrations \
  --network supabase_default \
  -e DATABASE_URL="$DATABASE_URL" \
  -v "${WORK_DIR}/run-migrations.sh:/run-migrations.sh" \
  --entrypoint "/run-migrations.sh" \
  dcspark/carp:3.0.0

# Clean up
rm -rf "${WORK_DIR}"
echo "Carp database migrations complete."

# --- Step 3: Set up Guild Operators Node ---
echo ""
echo "--- Phase 3: Setting up Guild Operators Node ---"

# Create Guild directories if they don't exist
mkdir -p "${GUILD_DIR}"/{db,config,socket}
chmod -R 777 "${GUILD_DIR}"

# Stop any existing Guild node container
echo "Stopping any existing Guild node containers..."
docker stop cardano-node-guild 2>/dev/null || true
docker rm cardano-node-guild 2>/dev/null || true

# Pull latest Guild image
echo "Pulling latest Guild Operators image..."
docker pull cardanocommunity/cardano-node:latest

# Start Guild Operators node with Mithril download
echo "Starting Guild Operators Cardano node with Mithril snapshot..."
docker run --init -dit \
  --name cardano-node-guild \
  -e NETWORK="$NETWORK" \
  -e MITHRIL_DOWNLOAD="$MITHRIL_DOWNLOAD" \
  -p 6000:6000 \
  -p 12798:12798 \
  -p 12781:12781 \
  -v "${GUILD_DIR}/config:/opt/cardano/cnode/priv" \
  -v "${GUILD_DIR}/db:/opt/cardano/cnode/db" \
  -v "${GUILD_DIR}/socket:/opt/cardano/cnode/sockets" \
  cardanocommunity/cardano-node:latest

# Check if the container started successfully
if docker ps | grep -q cardano-node-guild; then
  echo "Guild Operators node started successfully!"
else
  echo "ERROR: Failed to start Guild Operators node."
  docker logs cardano-node-guild
  exit 1
fi

# Wait for the socket to be created
echo "Waiting for Guild node socket to be created (up to 300 seconds for Mithril download + sync)..."
SOCKET_PATH="${GUILD_DIR}/socket/node.socket"
MAX_WAIT=300
WAIT_COUNT=0

while [ ! -S "$SOCKET_PATH" ] && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
  echo -n "."
  sleep 5
  WAIT_COUNT=$((WAIT_COUNT + 5))
  
  # Show progress every 30 seconds
  if [ $((WAIT_COUNT % 30)) -eq 0 ]; then
    echo ""
    echo "Still waiting... (${WAIT_COUNT}s elapsed)"
    echo "Mithril download progress:"
    docker logs --tail 3 cardano-node-guild | grep -E "(GiB|%|Downloading|Starting)" || echo "  (checking logs...)"
  fi
done

if [ -S "$SOCKET_PATH" ]; then
  echo ""
  echo "Socket created successfully at $SOCKET_PATH"
else
  echo ""
  echo "WARNING: Socket was not created within the timeout period."
  echo "Guild node may still be downloading Mithril snapshot or syncing."
  echo "Check Guild node logs: docker logs -f cardano-node-guild"
  echo "Continuing with Carp setup - it will connect when socket becomes available."
fi

# --- Step 4: Start Carp Indexer ---
echo ""
echo "--- Phase 4: Starting Carp Indexer ---"

# Create a clean work directory for Carp config and entrypoint
echo "Setting up Carp indexer environment..."
WORK_DIR="/tmp/carp-run-$(date +%s)"
mkdir -p "${WORK_DIR}"

# Create Guild-specific Carp config
cat > "${WORK_DIR}/config.yml" << EOF
source:
  type: oura
  socket: "/app/guild-node.socket"
  bearer: Unix

sink:
  type: cardano
  db:
    type: postgres
    database_url: $DATABASE_URL
  network: $NETWORK

start_block: 
EOF

chmod 644 "${WORK_DIR}/config.yml"

# Create a custom entrypoint script
cat > "${WORK_DIR}/entrypoint.sh" << 'EOF'
#!/bin/bash
set -e

cd /app
echo "Starting Carp with Guild node socket..."
RUST_LOG=info RUST_BACKTRACE=1 ./carp --config-path /config/config.yml
EOF

chmod +x "${WORK_DIR}/entrypoint.sh"

# Verify the config file
echo "Verifying the Carp configuration:"
cat "${WORK_DIR}/config.yml"
echo ""

# Get the Guild socket path
GUILD_SOCKET_PATH="${GUILD_DIR}/socket/node.socket"

# Run the container with our custom setup and mount the Guild node socket
echo "Starting Carp indexer container..."
docker run -d --name carp-indexer \
  --network supabase_default \
  --restart unless-stopped \
  -e DATABASE_URL="$DATABASE_URL" \
  -e RUST_LOG=info \
  -v "${WORK_DIR}/config.yml:/config/config.yml" \
  -v "$CARP_DIR/execution_plans:/app/execution_plans" \
  -v "$GUILD_SOCKET_PATH:/app/guild-node.socket" \
  -v "${WORK_DIR}/entrypoint.sh:/entrypoint.sh" \
  --entrypoint "/entrypoint.sh" \
  dcspark/carp:3.0.0

echo ""
echo "==============================================="
echo "🎉 Full stack startup complete!"
echo "==============================================="
echo "✅ Supabase/PostgreSQL: Database 'honeycombdb' ready"
echo "✅ Guild Operators node: Running with socket at $GUILD_SOCKET_PATH"
echo "✅ Carp indexer: Connected to both Guild node and the Supabase database"
echo ""
echo "📊 Monitor logs:"
echo "  Supabase DB: docker logs -f supabase-db"
echo "  Guild Node:  docker logs -f cardano-node-guild"
echo "  Carp:        docker logs -f carp-indexer"
echo ""
echo "🛠️  Guild Node Tools:"
echo "  gLiveView:   docker exec -it cardano-node-guild gLiveView.sh"
echo "  CNTools:     docker exec -it cardano-node-guild cntools.sh"
echo "  Prometheus:  curl http://localhost:12798/metrics"
echo "  EKG:         curl http://localhost:12781/"
echo ""
echo "🔄 To restart this stack in the future, simply run:"
echo "   ./scripts/guild-stack/start-full-stack-guild.sh"
echo ""
echo "📚 For troubleshooting, see: docs/INSTALLATION.md"
echo "===============================================" 