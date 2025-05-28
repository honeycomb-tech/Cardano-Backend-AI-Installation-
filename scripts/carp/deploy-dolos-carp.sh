#!/bin/bash

# Script to deploy Carp with Dolos node
set -e

echo "==============================================="
echo "Deploying Cardano Stack (Dolos + Carp)"
echo "==============================================="

# === Phase 1: Setup Dolos Node ===
echo "--- Phase 1: Setting up Dolos Node ---"
DOLOS_SETUP_SCRIPT="/root/workspace/cardano-stack/dolos/setup-dolos.sh"

if [ ! -x "$DOLOS_SETUP_SCRIPT" ]; then
  echo "ERROR: Dolos setup script not found or not executable at $DOLOS_SETUP_SCRIPT"
  exit 1
fi

cd /root/workspace/cardano-stack/dolos
$DOLOS_SETUP_SCRIPT

# === Phase 2: Setup Carp Indexer ===
echo "--- Phase 2: Setting up Carp Indexer ---"

# Ensure Dolos socket path is correct
DOLOS_SOCKET_PATH="/root/workspace/cardano-stack/dolos/data/dolos.socket.sock"

if [ ! -S "$DOLOS_SOCKET_PATH" ]; then
  echo "ERROR: Dolos socket not found at $DOLOS_SOCKET_PATH after setup. Cannot continue."
  exit 1
fi
echo "Dolos socket found at $DOLOS_SOCKET_PATH."

# Stop any existing containers
echo "Stopping any existing Carp containers..."
docker stop carp-indexer 2>/dev/null || true
docker rm carp-indexer 2>/dev/null || true

# Create a clean work directory for Carp config and entrypoint
echo "Setting up a temporary environment for Carp container..."
WORK_DIR="/tmp/carp-run-$(date +%s)"
mkdir -p "${WORK_DIR}"
# execution_plans will be mounted directly from the project, no need to copy to WORK_DIR

# Copy the fixed YAML config
cp /root/workspace/cardano-stack/carp/fixed-config.yml "${WORK_DIR}/config.yml"

# Set permissions for the temp config
chmod 644 "${WORK_DIR}/config.yml"

# Create a custom entrypoint script that prints debug info
cat > "${WORK_DIR}/entrypoint.sh" << 'EOF'
#!/bin/bash
set -e

cd /app
echo "Running database migrations..."
./migration up

echo "DEBUG: Config file contents (YAML):"
cat /config/config.yml

echo "Starting Carp with YAML config..."
RUST_LOG=info RUST_BACKTRACE=1 ./carp --config-path /config/config.yml
EOF

chmod +x "${WORK_DIR}/entrypoint.sh"

# Verify the config file
echo "Verifying the configuration file to be used:"
cat "${WORK_DIR}/config.yml"
echo ""

# Run the container with our custom setup and mount the Dolos node socket
echo "Starting Carp container..."
docker run -d --name carp-indexer \
  --network supabase_default \
  --restart unless-stopped \
  -e DATABASE_URL="postgresql://postgres:fQpUUR6Azw1eJcjktNMfYHxPnzYADauVJEyxKWMVYic=@supabase-db:5432/honeycombdb" \
  -e RUST_LOG=info \
  -v "${WORK_DIR}/config.yml:/config/config.yml" \
  -v "/root/workspace/cardano-stack/carp/execution_plans:/app/execution_plans" \
  -v "${DOLOS_SOCKET_PATH}:/app/dolos.socket.sock" \
  -v "${WORK_DIR}/entrypoint.sh:/entrypoint.sh" \
  --entrypoint "/entrypoint.sh" \
  dcspark/carp:3.0.0

echo ""
echo "Carp deployment complete!"
echo "To check logs, run: docker logs -f carp-indexer"
echo ""
echo "Container status:"
docker ps | grep carp-indexer

echo ""
echo "==============================================="
echo "Cardano Stack deployment complete!"
echo "- Dolos node is running with socket at $DOLOS_SOCKET_PATH"
echo "- Carp indexer is connected to Dolos and the Supabase database"
echo "===============================================" 