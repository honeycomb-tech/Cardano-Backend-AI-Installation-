#!/bin/bash
set -e

echo "==============================================="
echo "Starting Full Cardano Stack: Supabase -> Carp -> Dolos"
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
RUST_LOG=${RUST_LOG:-"info"}

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
DOLOS_DIR="${DOLOS_DATA_DIR:-$PROJECT_ROOT/data/dolos}"
CARP_DIR="$BASE_DIR/../carp"

echo "Using configuration:"
echo "  Project Root: $PROJECT_ROOT"
echo "  Dolos Data Dir: $DOLOS_DIR"
echo "  Network: $NETWORK"
echo "  Rust Log Level: $RUST_LOG"

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

# --- Step 3: Set up Dolos ---
echo ""
echo "--- Phase 3: Setting up Dolos ---"

# Create Dolos directories if they don't exist
mkdir -p "${DOLOS_DIR}/data"

# Check if Dolos configuration needs updating
cd "$DOLOS_DIR"

# Copy default Dolos configuration if it doesn't exist
if [ ! -f "dolos.toml" ]; then
    echo "Creating default Dolos configuration..."
    # Copy from the repository template
    if [ -f "$BASE_DIR/dolos/dolos.toml" ]; then
        cp "$BASE_DIR/dolos/dolos.toml" .
    else
        echo "⚠️  No dolos.toml template found. You may need to create one manually."
    fi
fi

# Ensure correct socket path in dolos.toml
if [ -f "dolos.toml" ] && grep -q "listen_path = \"dolos.socket.sock\"" dolos.toml; then
  echo "Updating socket path in dolos.toml..."
  sed -i 's|listen_path = "dolos.socket.sock"|listen_path = "data/dolos.socket.sock"|g' dolos.toml
  echo "Socket path updated in dolos.toml"
fi

# Stop any existing Dolos container
echo "Stopping any existing Dolos containers..."
docker stop dolos-daemon 2>/dev/null || true
docker rm dolos-daemon 2>/dev/null || true

# Run bootstrap command for initialization
echo "Running Dolos bootstrap initialization..."
docker run -it --rm -v $(pwd):/app -w /app ghcr.io/txpipe/dolos:latest bootstrap --config /app/dolos.toml

# Start Dolos daemon with the correct configuration
echo "Starting Dolos daemon..."
docker run -d --name dolos-daemon \
  --restart unless-stopped \
  -v $(pwd):/app \
  -w /app \
  -p 50051:50051 \
  -p 3000:3000 \
  -p 18000:8000 \
  -e RUST_LOG="$RUST_LOG" \
  ghcr.io/txpipe/dolos:latest daemon --config /app/dolos.toml

# Check if the container started successfully
if docker ps | grep -q dolos-daemon; then
  echo "Dolos daemon started successfully!"
else
  echo "ERROR: Failed to start Dolos daemon."
  docker logs dolos-daemon
  exit 1
fi

# Wait for the socket to be created
echo "Waiting for Dolos socket to be created (up to 60 seconds)..."
SOCKET_PATH="data/dolos.socket.sock"
MAX_WAIT=60
WAIT_COUNT=0

while [ ! -S "$SOCKET_PATH" ] && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
  echo -n "."
  sleep 1
  WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ -S "$SOCKET_PATH" ]; then
  echo ""
  echo "Socket created successfully at $SOCKET_PATH"
else
  echo ""
  echo "ERROR: Socket was not created within the timeout period."
  echo "Check Dolos logs for errors: docker logs dolos-daemon"
  exit 1
fi

# --- Step 4: Start Carp Indexer ---
echo ""
echo "--- Phase 4: Starting Carp Indexer ---"

# Create a clean work directory for Carp config and entrypoint
echo "Setting up Carp indexer environment..."
WORK_DIR="/tmp/carp-run-$(date +%s)"
mkdir -p "${WORK_DIR}"

# Copy the fixed YAML config or create one
if [ -f "$CARP_DIR/fixed-config.yml" ]; then
    cp "$CARP_DIR/fixed-config.yml" "${WORK_DIR}/config.yml"
else
    # Create a basic config if template doesn't exist
    cat > "${WORK_DIR}/config.yml" << EOF
source:
  type: oura
  socket: "/app/dolos.socket.sock"
  bearer: Unix

sink:
  type: cardano
  db:
    type: postgres
    database_url: $DATABASE_URL
  network: $NETWORK

start_block: 
EOF
fi

chmod 644 "${WORK_DIR}/config.yml"

# Create a custom entrypoint script
cat > "${WORK_DIR}/entrypoint.sh" << 'EOF'
#!/bin/bash
set -e

cd /app
echo "Starting Carp with YAML config..."
RUST_LOG=info RUST_BACKTRACE=1 ./carp --config-path /config/config.yml
EOF

chmod +x "${WORK_DIR}/entrypoint.sh"

# Verify the config file
echo "Verifying the Carp configuration:"
cat "${WORK_DIR}/config.yml"
echo ""

# Get the Dolos socket path
DOLOS_SOCKET_PATH="$DOLOS_DIR/data/dolos.socket.sock"

# Run the container with our custom setup and mount the Dolos node socket
echo "Starting Carp indexer container..."
docker run -d --name carp-indexer \
  --network supabase_default \
  --restart unless-stopped \
  -e DATABASE_URL="$DATABASE_URL" \
  -e RUST_LOG="$RUST_LOG" \
  -v "${WORK_DIR}/config.yml:/config/config.yml" \
  -v "$CARP_DIR/execution_plans:/app/execution_plans" \
  -v "$DOLOS_SOCKET_PATH:/app/dolos.socket.sock" \
  -v "${WORK_DIR}/entrypoint.sh:/entrypoint.sh" \
  --entrypoint "/entrypoint.sh" \
  dcspark/carp:3.0.0

echo ""
echo "==============================================="
echo "🎉 Full stack startup complete!"
echo "==============================================="
echo "✅ Supabase/PostgreSQL: Database 'honeycombdb' ready"
echo "✅ Dolos node: Running with socket at $DOLOS_SOCKET_PATH"
echo "✅ Carp indexer: Connected to both Dolos and the Supabase database"
echo ""
echo "📊 Monitor logs:"
echo "  Supabase DB: docker logs -f supabase-db"
echo "  Dolos:       docker logs -f dolos-daemon"
echo "  Carp:        docker logs -f carp-indexer"
echo ""
echo "🔄 To restart this stack in the future, simply run:"
echo "   ./scripts/dolos-stack/start-full-stack.sh"
echo ""
echo "📚 For troubleshooting, see: docs/INSTALLATION.md"
echo "===============================================" 