# 📦 Cardano Backend Installation Guide

Complete setup guide for the Cardano Backend AI Installation stack.

> **⚠️ CURRENT STATUS (January 2025)**  
> **Dolos integration is currently waiting for Ouroboros functionality to be fully implemented.** For production use and immediate deployment, we **strongly recommend using the Guild Operators stack** which is battle-tested and fully functional.

## 🎯 Overview

## System Requirements

### Minimum Requirements
- **OS**: Ubuntu 20.04+ / Debian 11+ / macOS 12+
- **RAM**: 8GB (16GB recommended)
- **Storage**: 50GB free space (200GB+ recommended)
- **CPU**: 4 cores (8+ recommended)
- **Network**: Stable internet connection

### Recommended Requirements
- **OS**: Ubuntu 24.04 LTS
- **RAM**: 32GB
- **Storage**: 500GB SSD
- **CPU**: 16+ cores (AMD Ryzen 9 or Intel i9)
- **Network**: 100Mbps+ connection

## Prerequisites Installation

### 1. Install Docker

#### Ubuntu/Debian
```bash
# Update package index
sudo apt update

# Install required packages
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

#### macOS
```bash
# Install using Homebrew
brew install --cask docker

# Or download from https://www.docker.com/products/docker-desktop
```

### 2. Verify Installation
```bash
# Check Docker version
docker --version
docker compose version

# Test Docker
docker run hello-world
```

## Quick Installation

### Option 1: Dolos Stack (Recommended for Development)

```bash
# Clone repository
git clone https://github.com/honeycomb-tech/Cardano-Backend-AI-Installation-.git
cd Cardano-Backend-AI-Installation-

# Make script executable
chmod +x scripts/dolos-stack/start-full-stack.sh

# Run installation
./scripts/dolos-stack/start-full-stack.sh
```

**Expected Timeline**: 2-3 hours for full sync

### Option 2: Guild Operators Stack (Recommended for Production)

```bash
# Clone repository
git clone https://github.com/honeycomb-tech/Cardano-Backend-AI-Installation-.git
cd Cardano-Backend-AI-Installation-

# Make script executable
chmod +x scripts/guild-stack/start-full-stack-guild.sh

# Run installation
./scripts/guild-stack/start-full-stack-guild.sh
```

**Expected Timeline**: 1-2 hours (thanks to Mithril snapshot)

## Manual Installation

### 1. Prepare Environment
```bash
# Create working directory
mkdir -p ~/cardano-backend
cd ~/cardano-backend

# Clone repository
git clone https://github.com/honeycomb-tech/Cardano-Backend-AI-Installation-.git
cd Cardano-Backend-AI-Installation-
```

### 2. Configure Environment Variables
```bash
# Copy example environment file
cp examples/.env.example .env

# Edit configuration
nano .env
```

### 3. Start Services Individually

#### Start Supabase
```bash
cd scripts/supabase-project
docker compose up -d
```

#### Start Node (Choose One)

**Dolos Node:**
```bash
cd ../dolos-stack
./setup-dolos.sh
```

**Guild Node:**
```bash
cd ../guild-stack
./launch-guild-node.sh
```

#### Start Carp Indexer
```bash
# Wait for node socket to be available
# Then start Carp with appropriate configuration
```

## Post-Installation

### 1. Verify Services
```bash
# Check all containers
docker ps

# Expected containers:
# - supabase-db (healthy)
# - cardano-node-guild OR dolos-daemon
# - carp-indexer
# - supabase-* (various services)
```

### 2. Test Connections

#### Database Connection
```bash
# Connect to PostgreSQL
docker exec -it supabase-db psql -U postgres -d honeycombdb

# List tables
\dt
```

#### Node Socket
```bash
# Check Dolos socket
ls -la /root/workspace/cardano-stack/dolos/data/dolos.socket.sock

# Check Guild socket
ls -la /root/workspace/cardano-node-guild/socket/node.socket
```

#### API Endpoints
```bash
# Supabase API
curl http://localhost:8000/rest/v1/

# Guild Prometheus (if using Guild stack)
curl http://localhost:12798/metrics

# Guild EKG (if using Guild stack)
curl http://localhost:12781/
```

### 3. Monitor Sync Progress

#### Guild Stack
```bash
# Real-time monitoring
docker exec -it cardano-node-guild gLiveView.sh
```

#### Dolos Stack
```bash
# Check logs
docker logs -f dolos-daemon
```

## Troubleshooting

### Common Issues

#### Port Conflicts
```bash
# Check what's using ports
sudo netstat -tulpn | grep :8000
sudo netstat -tulpn | grep :5432

# Kill conflicting processes
sudo kill -9 PID
```

#### Insufficient Disk Space
```bash
# Check disk usage
df -h

# Clean Docker
docker system prune -a -f
docker volume prune -f
```

#### Memory Issues
```bash
# Check memory usage
free -h
docker stats

# Increase swap if needed
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

#### Permission Issues
```bash
# Fix Docker permissions
sudo chmod 666 /var/run/docker.sock

# Fix file permissions
sudo chown -R $USER:$USER ~/cardano-backend
```

### Getting Help

1. **Check logs**: `docker logs container-name`
2. **Verify system resources**: `docker stats`
3. **Check network**: `docker network ls`
4. **Review configuration**: Check `.env` and config files
5. **Community support**: Open an issue on GitHub

## Performance Optimization

### System Tuning
```bash
# Increase file descriptor limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Optimize network settings
echo "net.core.rmem_max = 134217728" | sudo tee -a /etc/sysctl.conf
echo "net.core.wmem_max = 134217728" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Docker Optimization
```bash
# Configure Docker daemon
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl restart docker
```

## Security Considerations

### Firewall Configuration
```bash
# Allow only necessary ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 6000/tcp  # Guild P2P (if using Guild)
sudo ufw allow 8000/tcp  # Supabase API (if exposing)
sudo ufw enable
```

### Access Control
- Change default passwords
- Use environment variables for secrets
- Restrict database access
- Enable SSL/TLS for production

## Backup and Recovery

### Database Backup
```bash
# Backup Supabase database
docker exec supabase-db pg_dump -U postgres honeycombdb > backup.sql

# Restore database
docker exec -i supabase-db psql -U postgres honeycombdb < backup.sql
```

### Configuration Backup
```bash
# Backup configurations
tar -czf cardano-backend-config.tar.gz scripts/ .env
```

## Updating

### Update Docker Images
```bash
# Pull latest images
docker compose pull

# Restart services
docker compose up -d
```

### Update Scripts
```bash
# Pull latest repository changes
git pull origin main

# Restart services with new configurations
./scripts/dolos-stack/start-full-stack.sh  # or guild version
``` 