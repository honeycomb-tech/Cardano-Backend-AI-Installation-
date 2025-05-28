#!/bin/bash

CONTAINER_NAME="cardano-node-guild"

echo "==============================================="
echo "Guild Operators Cardano Node Monitor"
echo "==============================================="

# Check if container is running
if ! docker ps | grep -q "${CONTAINER_NAME}"; then
    echo "❌ Container '${CONTAINER_NAME}' is not running!"
    echo ""
    echo "Check status with: docker ps -a | grep ${CONTAINER_NAME}"
    echo "View logs with: docker logs ${CONTAINER_NAME}"
    exit 1
fi

echo "✅ Container '${CONTAINER_NAME}' is running"
echo ""

# Show container status
echo "--- Container Status ---"
docker ps | grep "${CONTAINER_NAME}"
echo ""

# Show recent logs
echo "--- Recent Logs (last 10 lines) ---"
docker logs --tail 10 "${CONTAINER_NAME}"
echo ""

# Check if socket exists
SOCKET_PATH="/root/workspace/cardano-node-guild/socket/node.socket"
if [ -S "${SOCKET_PATH}" ]; then
    echo "✅ Node socket is available at: ${SOCKET_PATH}"
else
    echo "⚠️  Node socket not yet available at: ${SOCKET_PATH}"
fi
echo ""

# Show port status
echo "--- Port Status ---"
echo "Checking if ports are accessible..."
netstat -tuln | grep -E ":(6000|12798|12781)" || echo "Ports not yet bound (node may still be starting)"
echo ""

# Interactive options
echo "--- Available Commands ---"
echo "1. View live logs: docker logs -f ${CONTAINER_NAME}"
echo "2. Enter container: docker exec -it ${CONTAINER_NAME} bash"
echo "3. Use gLiveView: docker exec -it ${CONTAINER_NAME} gLiveView.sh"
echo "4. Check node status: docker exec -it ${CONTAINER_NAME} cntools.sh"
echo "5. View Prometheus metrics: curl http://localhost:12798/metrics"
echo "6. View EKG metrics: curl http://localhost:12781/"
echo ""

# Ask user what they want to do
read -p "Enter command number (1-6) or 'q' to quit: " choice

case $choice in
    1)
        echo "Starting live log view (Ctrl+C to exit)..."
        docker logs -f "${CONTAINER_NAME}"
        ;;
    2)
        echo "Entering container..."
        docker exec -it "${CONTAINER_NAME}" bash
        ;;
    3)
        echo "Starting gLiveView..."
        docker exec -it "${CONTAINER_NAME}" gLiveView.sh
        ;;
    4)
        echo "Starting CNTools..."
        docker exec -it "${CONTAINER_NAME}" cntools.sh
        ;;
    5)
        echo "Fetching Prometheus metrics..."
        curl -s http://localhost:12798/metrics | head -20
        ;;
    6)
        echo "Fetching EKG metrics..."
        curl -s http://localhost:12781/ | head -20
        ;;
    q|Q)
        echo "Exiting monitor..."
        ;;
    *)
        echo "Invalid choice. Exiting..."
        ;;
esac 