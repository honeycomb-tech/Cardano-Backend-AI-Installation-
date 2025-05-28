# 🚀 Cardano Backend AI Installation

**One-click AI-powered setup for a complete Cardano dApp backend stack**

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Docker](https://img.shields.io/badge/Docker-Required-blue.svg)](https://www.docker.com/)
[![Cardano](https://img.shields.io/badge/Cardano-Mainnet-green.svg)](https://cardano.org/)

## 🎯 Overview

This project provides **two complete Cardano backend stacks** ready for dApp development, featuring different node implementations to suit your needs. Built with AI assistance and battle-tested configurations.

> **⚠️ CURRENT STATUS (January 2025)**  
> **Dolos integration is currently waiting for Ouroboros functionality to be fully implemented.** For production use and immediate deployment, we **strongly recommend using the Guild Operators stack** which is battle-tested and fully functional.

### 🏗️ What You Get

- **Complete Database Stack**: Supabase with PostgreSQL
- **Blockchain Indexing**: Carp indexer for transaction data
- **Node Options**: Choose between Dolos (modern) or Guild Operators (battle-tested)
- **Monitoring**: Built-in metrics and health checks
- **Production Ready**: Docker-based with restart policies

## ⚡ Quick Start

### Prerequisites

- **Docker & Docker Compose** installed
- **Linux/macOS** (tested on Ubuntu 24.04)
- **50GB+ free disk space** (for blockchain data)
- **8GB+ RAM** recommended

### 🔧 Setup (Required First Time)

1. **Clone the repository:**
```bash
git clone https://github.com/honeycomb-tech/Cardano-Backend-AI-Installation-.git
cd Cardano-Backend-AI-Installation-
```

2. **Configure your environment:**
```bash
# Copy the example environment file
cp .env.example .env

# Edit with your secure passwords and settings
nano .env  # or use your preferred editor
```

3. **⚠️ IMPORTANT: Update your .env file with:**
   - Secure database password (replace `YOUR_SECURE_PASSWORD_HERE`)
   - Generate JWT secrets: `openssl rand -base64 32`
   - Configure network settings (mainnet/testnet)

### 🚀 Launch Your Stack

After completing the setup above, choose your preferred node implementation:

#### ⭐ Option 1: Guild Operators Stack (RECOMMENDED)

```bash
chmod +x scripts/guild-stack/start-full-stack-guild.sh
./scripts/guild-stack/start-full-stack-guild.sh
```

**✅ Best for:** Production use, faster sync (Mithril), rich tooling, battle-tested reliability

#### Option 2: Dolos Stack (Future Development)

```bash
chmod +x scripts/dolos-stack/start-full-stack.sh
./scripts/dolos-stack/start-full-stack.sh
```

**⚠️ Note:** Currently waiting for Ouroboros functionality. Use for testing/development only.

### 🔄 Restarting Your Stack

Once everything is set up correctly, you can restart your chosen stack anytime with:

```bash
# For Dolos stack
./scripts/dolos-stack/start-full-stack.sh

# For Guild Operators stack  
./scripts/guild-stack/start-full-stack-guild.sh
```

**No additional configuration needed** - the scripts will use your `.env` settings!

## 📊 Stack Comparison

| Feature | Dolos Stack | Guild Operators Stack |
|---------|-------------|----------------------|
| **Node Type** | Modern Rust | Traditional Haskell |
| **Current Status** | ⚠️ Waiting for Ouroboros | ✅ Fully Functional |
| **Initial Sync** | Snapshot + sync to tip | Mithril snapshot (faster) |
| **Memory Usage** | Lower (~4GB) | Higher (~6-8GB) |
| **Sync Time** | ~1 hour (50min snapshot + sync) | 2-4 hours |
| **Tools** | Basic monitoring | Rich ecosystem (gLiveView, CNTools) |
| **SPO Adoption** | Growing | Widespread |
| **Production Ready** | ⚠️ Limited | ✅ Battle-tested |
| **Best For** | Future development | **Current production use** |

> **🎯 RECOMMENDATION**: Use **Guild Operators Stack** for all current deployments until Dolos Ouroboros integration is complete.

## 🏛️ Architecture

### Dolos Stack Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    Dolos Backend Stack                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │  Supabase   │    │    Dolos    │    │    Carp     │     │
│  │ (Database)  │◄───┤   (Node)    │───►│  (Indexer)  │     │
│  │             │    │             │    │             │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│       │                    │                    │          │
│   Port: 8000           Port: 18000         Socket IPC      │
│   (REST API)          (gRPC, miniBF,      (Blockchain       │
│   (GraphQL)            REST, etc.)         Processing)     │
│                                                             │
│  🔌 Access Points:                                          │
│  • Supabase API: http://localhost:8000                     │
│  • Dolos gRPC: http://localhost:50051                      │
│  • Dolos REST: http://localhost:18000                      │
│  • Dolos miniBF: http://localhost:18000/miniprotocols      │
└─────────────────────────────────────────────────────────────┘
```

### Guild Operators Stack Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                  Guild Operators Stack                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │  Supabase   │    │   Guild     │    │    Carp     │     │
│  │ (Database)  │◄───┤   Node      │───►│  (Indexer)  │     │
│  │             │    │             │    │             │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│       │                    │                    │          │
│   Port: 8000           Socket Only         Socket IPC      │
│   (REST API)          (No direct API)     (Blockchain       │
│   (GraphQL)           + Monitoring         Processing)     │
│                                                             │
│  🔌 Access Points:                                          │
│  • Supabase API: http://localhost:8000                     │
│  • Prometheus: http://localhost:12798/metrics              │
│  • EKG Stats: http://localhost:12781                       │
│  • Node Socket: /socket/node.socket (IPC only)             │
└─────────────────────────────────────────────────────────────┘
```

## 🔌 Services & Ports

### Dolos Stack (Rich API Access)
- **Dolos Node**: 
  - 50051 (gRPC API) - Direct blockchain queries
  - 18000 (REST API) - HTTP blockchain access  
  - 18000/miniprotocols (miniBF) - Mini-protocol access
  - 3000 (Admin API) - Node management
- **Supabase**: 8000 (REST/GraphQL API), 8443 (Auth), 5432 (DB)
- **Carp**: Internal indexing to PostgreSQL

**🎯 Developer Access**: Multiple API options for blockchain data

### Guild Stack (Monitoring Focus)
- **Guild Node**: 
  - 6000 (P2P networking) - Cardano network communication
  - 12798 (Prometheus) - Metrics and monitoring
  - 12781 (EKG) - Real-time statistics
  - Socket only - No direct API access
- **Supabase**: 8000 (REST/GraphQL API), 8443 (Auth), 5432 (DB)  
- **Carp**: Internal indexing to PostgreSQL

**🎯 Developer Access**: Supabase API only (blockchain data via Carp indexing)

## 📁 Project Structure

```
Cardano-Backend-AI-Installation-/
├── .env.example                     # Environment configuration template
├── scripts/
│   ├── dolos-stack/
│   │   └── start-full-stack.sh      # 🚀 Main Dolos launcher
│   ├── guild-stack/
│   │   └── start-full-stack-guild.sh # 🚀 Main Guild launcher
│   ├── carp/                        # Carp indexer config
│   └── supabase-project/            # Supabase configuration
├── docs/                            # Documentation
├── examples/                        # Usage examples
└── README.md                        # This file
```

## 🚀 Usage Examples

### Database Connection

```javascript
// Connect to your Cardano backend
const supabase = createClient(
  'http://localhost:8000',
  'your-anon-key'  // Get from your .env file
)

// Query blockchain data indexed by Carp
const { data: blocks } = await supabase
  .from('block')
  .select('*')
  .order('slot', { ascending: false })
  .limit(10)
```

### Node Socket Access

```bash
# Dolos socket (when using Dolos stack)
./data/dolos/data/dolos.socket.sock

# Guild socket (when using Guild stack)
./data/cardano-node-guild/socket/node.socket
```

## 📈 Monitoring

### Guild Operators Tools (Guild Stack Only)

```bash
# Real-time node monitoring
docker exec -it cardano-node-guild gLiveView.sh

# Node management interface
docker exec -it cardano-node-guild cntools.sh

# Prometheus metrics
curl http://localhost:12798/metrics

# EKG dashboard
curl http://localhost:12781/
```

### General Monitoring (Both Stacks)

```bash
# Check all containers
docker ps

# View logs
docker logs -f cardano-node-guild  # or dolos-daemon
docker logs -f carp-indexer
docker logs -f supabase-db
```

## 🛠️ Configuration

### Environment Variables (.env file)

Key settings you must configure:

```bash
# Database (REQUIRED - change from default!)
POSTGRES_PASSWORD=your_secure_password_here
DATABASE_URL=postgresql://postgres:your_secure_password_here@supabase-db:5432/honeycombdb

# Network
NETWORK=mainnet  # or preprod, preview

# Guild Node Settings
MITHRIL_DOWNLOAD=Y  # Enable fast sync

# Security (REQUIRED - generate new values!)
JWT_SECRET=your_jwt_secret_here
ANON_KEY=your_supabase_anon_key_here
SERVICE_ROLE_KEY=your_supabase_service_role_key_here
```

## 🔧 Troubleshooting

### Common Issues

**"Please configure your database password" error:**
```bash
# Edit your .env file and set a secure password
nano .env
# Change: POSTGRES_PASSWORD=YOUR_SECURE_PASSWORD_HERE
# To:     POSTGRES_PASSWORD=your_actual_secure_password
```

**Container won't start:**
```bash
docker logs container-name
docker system prune -f  # Clean up
```

**Slow sync:**
```bash
# For Guild stack - check sync progress
docker exec -it cardano-node-guild gLiveView.sh

# For Dolos stack - check logs
docker logs -f dolos-daemon
```

### Getting Help

1. Check container logs: `docker logs container-name`
2. Verify your `.env` configuration
3. Check disk space: `df -h`
4. Review system resources: `docker stats`
5. See detailed troubleshooting: [docs/INSTALLATION.md](docs/INSTALLATION.md)

## 🤝 Contributing

We welcome contributions! This project was built with AI assistance and community input.

### How to Contribute

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

### Areas for Improvement

- [ ] Add testnet support
- [ ] Create monitoring dashboards
- [ ] Add backup/restore scripts
- [ ] Implement health checks
- [ ] Add more node options

## 📚 Documentation

- [Installation Guide](docs/INSTALLATION.md)
- [Dolos Documentation](https://github.com/txpipe/dolos)
- [Guild Operators Guide](https://cardano-community.github.io/guild-operators/)
- [Carp Indexer](https://github.com/dcSpark/carp)
- [Supabase Docs](https://supabase.com/docs)

## 🙏 Acknowledgments

- **Guild Operators** - Battle-tested Cardano infrastructure
- **TxPipe** - Modern Dolos node implementation  
- **dcSpark** - Carp blockchain indexer
- **Supabase** - Open source database platform
- **AI Assistance** - Claude Sonnet for development support

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🌟 Support the Project

If this project helps you build amazing Cardano dApps, consider:

- ⭐ Starring the repository
- 🐛 Reporting issues
- 🔧 Contributing improvements
- 📢 Sharing with the community

---

**Built with ❤️ for the Cardano ecosystem**

**Ready to launch your Cardano backend? Choose your stack and run the script! 🚀**
