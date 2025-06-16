# Gotham City - Bitcoin Job Network

A Flutter mobile application for a decentralized Bitcoin-based job network with a dark, Gotham City themed UI.

## Features

### ✅ Implemented (UI + Mini Node)
- **🔑 Wallet Management**: Create new wallet or import existing wallet
- **💰 Balance Display**: Shows Bitcoin balance and USD equivalent
- **📜 Transaction History**: View recent transactions with details
- **💼 Job Management**: View and manage jobs with different types
- **➕ Post Jobs**: Create new jobs with rewards
- **🎨 Dark Theme**: Gotham City inspired dark UI with gold accents
- **🦇 Adaptive Icon**: Circular adaptive icon using custom arkham.png
- **🌐 Mini Bitcoin Node**: Lightweight node that syncs block headers only
- **📊 Node Status**: Real-time blockchain and network information
- **💾 Smart Caching**: Keeps only latest 144 blocks (~24 hours)
- **🔄 Auto Cleanup**: Automatic cache management to keep app lightweight

### 🔄 Planned (Backend Integration)
- **⛓ Sync Status**: Real-time blockchain synchronization
- **🔒 Taproot Signing**: Advanced Bitcoin transaction signing
- **🧾 Job History**: Complete job lifecycle tracking
- **💸 Refunds**: Automatic refund processing
- **🌐 Network**: P2P job distribution network

## Screenshots

The app features:
- **Wallet Screen**: Balance display, address management, quick actions
- **Jobs Screen**: Job listings with status indicators and details
- **Transactions Screen**: Transaction history with confirmations
- **Post Job Screen**: Create jobs with different types (Computation, Storage, Network, Custom)
- **Node Status Screen**: Real-time blockchain sync, peer connections, and cache statistics

## Technical Stack

- **Frontend**: Flutter (Dart)
- **Backend**: C++ (planned)
- **Blockchain**: Bitcoin with Taproot support
- **Theme**: Custom dark theme with Gotham City aesthetics
- **Database**: SQLite for local block header cache
- **Networking**: HTTP RPC client for Bitcoin node communication

## Job Types

1. **Computation**: CPU/GPU intensive tasks
2. **Storage**: File storage and retrieval services
3. **Network**: Network relay and routing services
4. **Custom**: Custom algorithms and specialized tasks

## Mini Bitcoin Node

Gotham City includes a lightweight Bitcoin node implementation that:

### 🔧 **Core Features**
- **Header-Only Sync**: Downloads only block headers, not full blocks
- **Smart Caching**: Keeps latest 144 blocks (~24 hours) in local SQLite database
- **Auto Cleanup**: Automatically removes old headers every hour
- **Real-time Updates**: Live blockchain and network statistics
- **Peer Management**: Tracks and displays connected peers

### 📊 **Node Status Screen**
- **Connection Status**: Shows if connected to your Bitcoin fork
- **Blockchain Info**: Current height, sync progress, difficulty
- **Network Stats**: Peer connections, data transfer, ping times
- **Local Cache**: Database size, cached headers count
- **Recent Headers**: List of recently synced block headers

### ⚙️ **Configuration**
- **RPC Settings**: Configure host, port, username, password
- **Auto Sync**: Syncs every 30 seconds when connected
- **Batch Processing**: Downloads headers in batches of 100
- **Error Handling**: Graceful handling of connection issues

### 💾 **Storage Management**
- **Lightweight**: Only stores essential header data
- **Efficient**: SQLite database with optimized indexes
- **Automatic**: No manual intervention required
- **Scalable**: Designed to handle continuous operation

## Installation

1. Download the APK from the releases
2. Install on Android device
3. Create or import your Bitcoin wallet
4. Start posting or accepting jobs

## Development

```bash
# Get dependencies
flutter pub get

# Run in debug mode
flutter run

# Build APK
flutter build apk

# Run tests
flutter test
```

## App Info

- **Name**: Gotham City
- **Package**: com.example.gotham_city
- **Version**: 1.0.0+1
- **Size**: ~23.2MB
- **Platform**: Android (iOS support planned)

## Security

- Private keys are handled securely (backend integration pending)
- All transactions use Bitcoin's security model
- Taproot support for enhanced privacy and efficiency

## Future Roadmap

1. **Phase 1**: Complete C++ backend integration
2. **Phase 2**: Real Bitcoin network integration
3. **Phase 3**: P2P job distribution network
4. **Phase 4**: Advanced features (multi-sig, lightning network)
5. **Phase 5**: iOS version and web interface

---

*"In the darkness of Gotham, opportunities shine like gold."* 🦇✨
