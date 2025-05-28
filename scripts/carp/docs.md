# Carp Indexer Status & Setup Guide

## Overall Status: Progressing - Specific Byron Block Processing Error

We have made significant progress in setting up a reproducible Cardano stack using Dolos as the node and Carp as the indexer.

1. **Dolos Node** - ✅ Successfully Deployed & Operational
   * Running as Docker container (`dolos-daemon`).
   * Initialized with `mainnet` known network and bootstrap dialog.
   * Actively syncing with the Cardano mainnet from genesis.
   * Ouroboros node socket available at `/root/workspace/cardano-stack/dolos/data/dolos.socket.sock`.
   * Exposing gRPC (50051), MiniBF (3000), and TRP (18000) interfaces.
   * Configured via `workspace/cardano-stack/dolos/dolos.toml`.

2. **Supabase Stack (PostgreSQL)** - ✅ Successfully Deployed & Operational
   * PostgreSQL database (`honeycombdb`) running via `supabase-db` container.
   * All schemas and migrations successfully applied.
   * Accessible for Carp.

3. **Carp Indexer Process** - ⚠️ Byron Block Processing Error
   * Running as Docker container (`carp-indexer`) using `dcspark/carp:3.0.0`.
   * Configuration (`fixed-config.yml`) successfully parsed (YAML format).
   * Database migrations run successfully.
   * Execution plans (`execution_plans/default.toml`) loaded.
   * Genesis data successfully inserted into database.
   * Successfully connects to the Dolos node socket.
   * **Current Issue:** Carp crashes with an error in Byron block processing:
     ```
     thread '<unnamed>' panicked at tasks/src/byron/byron_block.rs:11:1:
     called `Result::unwrap()` on an `Err` value: Query("error occurred while decoding: Null")
     ```

## Current Setup & Deployment

The stack is deployed using Docker containers with comprehensive automation scripts.

### Key Configuration Files:
* **Dolos Config:** `workspace/cardano-stack/dolos/dolos.toml`
* **Carp Config (YAML):** `workspace/cardano-stack/carp/fixed-config.yml`
* **Carp Execution Plan:** `workspace/cardano-stack/carp/execution_plans/default.toml`

### Deployment Scripts:
1. **Main Deployment Script:** `workspace/cardano-stack/start-full-stack.sh`
   * Orchestrates the entire stack setup in the correct order
   * Starts Supabase, runs Carp migrations, initializes Dolos, starts Carp

2. **Database Reset:** `workspace/cardano-stack/carp/reset-database.sh`
   * Completely resets the database to a clean state
   * Drops all tables and resets sequences

3. **Dolos Setup:** `workspace/cardano-stack/dolos/setup-dolos.sh`
   * Initializes and configures Dolos properly
   * Creates the socket file in the correct location

**To run the full stack:**
```bash
/root/workspace/cardano-stack/start-full-stack.sh
```

**To reset the database:**
```bash
/root/workspace/cardano-stack/carp/reset-database.sh
```

## Current Troubleshooting Focus: Byron Block Processing Error

The immediate next step is to resolve the Byron block processing error:

1. **Error Details:** 
   * The error occurs in the Byron block processing code in Carp
   * It appears to be failing to decode a null value in the Byron block data coming from Dolos

2. **Potential Solutions:**
   * Wait for Dolos to sync more of the blockchain to see if the issue resolves
   * Investigate if there's a way to configure Carp to start from a later point (after Byron era)
   * Look for newer versions of Carp or Oura that might fix this issue
   * Debug the specific Byron block processing code in Carp

3. **Current Database State:**
   * The database has the schema properly set up
   * Genesis data has been successfully inserted
   * No blocks beyond genesis have been processed due to the error

This setup has progressed significantly, and we are now dealing with a specific issue in Carp's processing of Byron blocks from Dolos. This is a different error than the previously encountered `IntersectionNotFound` issue.
