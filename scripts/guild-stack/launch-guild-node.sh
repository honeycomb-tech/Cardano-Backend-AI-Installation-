#!/bin/bash
set -e

echo "==============================================="
echo "Launching Guild Operators Cardano Node"
echo "==============================================="

# Configuration
CONTAINER_NAME="cardano-node-guild"
IMAGE="cardanocommunity/cardano-node:latest"
NETWORK="mainnet"
BASE_DIR="/root/workspace/cardano-node-guild"

# Create directories if they don't exist
mkdir -p "${BASE_DIR}"/{db,config,socket}
chmod -R 777 "${BASE_DIR}"

# Stop and remove existing container if it exists
echo "Stopping any existing Guild node container..."
docker stop "${CONTAINER_NAME}" 2>/dev/null || true
docker rm "${CONTAINER_NAME}" 2>/dev/null || true

# Pull latest image
echo "Pulling latest Guild Operators image..."
docker pull "${IMAGE}"

# Launch container
echo "Launching Guild Operators Cardano node..."
docker run --init -dit \
  --name "${CONTAINER_NAME}" \
  -e NETWORK="${NETWORK}" \
  -e MITHRIL_DOWNLOAD=Y \
  -p 6000:6000 \
  -p 12798:12798 \
  -p 12781:12781 \
  -v "${BASE_DIR}/config:/opt/cardano/cnode/priv" \
  -v "${BASE_DIR}/db:/opt/cardano/cnode/db" \
  -v "${BASE_DIR}/socket:/opt/cardano/cnode/sockets" \
  "${IMAGE}"

echo ""
echo "==============================================="
echo "Guild Operators Cardano Node Launched!"
echo "Container: ${CONTAINER_NAME}"
echo "Network: ${NETWORK}"
echo "Ports:"
echo "  - Cardano P2P: 6000"
echo "  - Prometheus: 12798"
echo "  - EKG: 12781"
echo "Socket: ${BASE_DIR}/socket/node.socket"
echo ""
echo "Monitor with:"
echo "  docker logs -f ${CONTAINER_NAME}"
echo "  docker exec -it ${CONTAINER_NAME} gLiveView.sh"
echo "===============================================" 