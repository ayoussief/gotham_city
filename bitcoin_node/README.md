# Gotham SPV Node

This directory contains the lightweight SPV (Simplified Payment Verification) client for the Gotham City application, implementing the Neutrino protocol (BIP157/158).

## Structure

- `config/` - Gotham chain parameters and network configuration
- `services/` - Core SPV services (P2P, filters, wallet)
- `models/` - Bitcoin/Gotham-related data models
- `screens/` - SPV node UI screens

## Features

### SPV Client (Neutrino Protocol)
- **Compact Block Filters (BIP157/158)** - Download only ~10KB filters per block instead of full blocks
- **Header-only sync** - Validate proof-of-work without downloading full blockchain
- **Privacy-preserving** - No bloom filter address leakage
- **Mobile-optimized** - Minimal bandwidth and storage requirements

### Wallet Backend
- **HD Wallet** - Hierarchical deterministic key derivation
- **UTXO Management** - Track unspent transaction outputs
- **Transaction Building** - Construct and sign transactions
- **Address Generation** - Generate receiving addresses on demand

### P2P Network
- **Gotham Protocol** - Connect directly to Gotham network peers
- **Peer Discovery** - DNS seeds and bootstrap peer support
- **Message Handling** - Bitcoin protocol message parsing and creation

### Local Storage
- **SQLite Database** - Efficient storage of headers, filters, and wallet data
- **Filter Matching** - Local filter queries for relevant transactions
- **Cache Management** - Automatic cleanup of old data

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   SPV Client    │────│   P2P Client    │────│  Gotham Peers   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         │              ┌─────────────────┐
         │              │ Filter Storage  │
         │              └─────────────────┘
         │
┌─────────────────┐    ┌─────────────────┐
│ Wallet Backend  │────│   UI Screens    │
└─────────────────┘    └─────────────────┘
```

## Usage

### Initialization
```dart
final spvClient = SPVClient();
await spvClient.initialize();
await spvClient.startSync();
```

### Wallet Operations
```dart
final walletBackend = WalletBackend();
final balance = await walletBackend.getBalance();
final newAddress = await walletBackend.getNewAddress();
```

### Configuration

The Gotham chain parameters are configured in `config/gotham_chain_params.dart`:
- Network magic bytes
- Genesis block information
- DNS seeds and bootstrap peers
- Protocol version and service flags
- BIP157/158 filter parameters

### Mobile Optimization

- **Background Sync** - Uses WorkManager (Android) / BackgroundTasks (iOS)
- **Battery Efficient** - Minimal CPU usage with filter-based scanning
- **Storage Efficient** - ~20MB for full sync vs. hundreds of GB for full node
- **Bandwidth Efficient** - ~100MB initial sync vs. hundreds of GB

## Security Features

- **SPV Security** - Validates proof-of-work and merkle proofs
- **Checkpoint Validation** - Hardcoded checkpoints prevent long-range attacks
- **Secure Storage** - Private keys encrypted with device keystore
- **Reorg Handling** - Automatic handling of blockchain reorganizations

## Dependencies

- `crypto` - Cryptographic operations (SHA256, etc.)
- `convert` - Data encoding/decoding
- `sqflite` - Local SQLite database
- `shared_preferences` - Configuration storage

## Network Protocol

Implements Bitcoin P2P protocol with Gotham-specific parameters:
- Version handshake with Gotham magic bytes
- `getcfheaders` - Request compact filter headers
- `getcfilter` - Request compact filters
- `getdata` - Request merkle blocks and transactions
- `inv`/`tx` - Transaction broadcasting

## Privacy

- **No Address Reuse** - HD wallet generates new addresses
- **Filter Privacy** - No direct address queries to peers
- **Peer Rotation** - Connect to different peers over time
- **Batch Requests** - Group filter requests to reduce fingerprinting