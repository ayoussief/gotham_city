# 🦇 Gotham Services Architecture

## 🚀 **Core Services (Active & Efficient)**

### **1. GothamDaemon** (`gotham_daemon.dart`)
- **Main daemon service** - equivalent to `./gothamd -daemon`
- **Integrates**: Status monitoring, daemon lifecycle, real-time stats
- **Replaces**: `daemon_status.dart` (deprecated)
- **Usage**: Primary entry point for daemon operations

### **2. SPVClient** (`spv_client.dart`)
- **SPV blockchain client** - BIP157/158 Neutrino protocol
- **Features**: Header sync, filter sync, transaction monitoring
- **Replaces**: `gotham_node_service.dart` for lightweight operations
- **Usage**: Blockchain synchronization and validation

### **3. WalletBackend** (`wallet_backend.dart`)
- **Wallet operations** - HD wallet, transaction building
- **Integrates**: `wallet_storage.dart` internally
- **Features**: Address generation, transaction signing, balance tracking
- **Usage**: All wallet-related operations

### **4. P2PClient** (`p2p_client.dart`)
- **P2P network client** - Gotham network communication
- **Features**: Peer connection, message handling, transaction broadcast
- **Usage**: Network layer communication

### **5. FilterStorage** (`filter_storage.dart`)
- **Compact filter storage** - BIP157/158 filter management
- **Features**: Filter caching, header storage, efficient queries
- **Usage**: SPV filter operations

### **6. DatabaseService** (`database_service.dart`)
- **Database operations** - Cross-platform SQLite
- **Consolidates**: `database_helper.dart` (removed)
- **Features**: Block headers, transactions, cross-platform support
- **Usage**: Persistent data storage

### **7. ConsensusValidator** (`consensus_validator.dart`)
- **Lightweight validation** - Essential consensus rules
- **Features**: Header validation, transaction validation, PoW checks
- **Usage**: SPV security validation

## 📱 **Flutter UI Integration**

### **DaemonControlScreen** (`screens/daemon_control_screen.dart`)
- **Flutter UI** for daemon control
- **Features**: Start/stop buttons, real-time stats, logs, events
- **No CLI needed** - Beautiful UI with buttons! 🎮

## 🗂️ **Legacy Services (Deprecated)**

### **❌ GothamNodeService** (`gotham_node_service.dart`)
- **@deprecated** - Use `SPVClient` instead
- **Purpose**: Legacy RPC client for external Bitcoin Core nodes
- **Status**: Kept for compatibility only

### **❌ DaemonStatus** (`daemon_status.dart`)
- **@deprecated** - Integrated into `GothamDaemon`
- **Purpose**: Separate daemon status monitoring
- **Status**: Functionality moved to main daemon

### **⚙️ WalletStorage** (`wallet_storage.dart`)
- **Internal use only** - Used by `WalletBackend`
- **Purpose**: Secure wallet file management
- **Status**: Not deprecated, but used internally

## 🏗️ **Service Dependencies**

```
GothamDaemon (Main)
├── SPVClient
│   ├── P2PClient
│   ├── FilterStorage
│   └── ConsensusValidator
├── WalletBackend
│   └── WalletStorage (internal)
└── DatabaseService
```

## 🎯 **Usage Examples**

### **Start Daemon (Flutter Button)**
```dart
final daemon = GothamDaemon();
await daemon.startDaemon();
```

### **Monitor Real-time Stats**
```dart
daemon.statsStream.listen((stats) {
  print('Current height: ${stats['current_height']}');
  print('Sync progress: ${stats['sync_progress']}%');
});
```

### **Send Transaction**
```dart
final txid = await daemon.sendTransaction(
  'gt1qw508d6qejxtdg4y5r3zarvary0c5xw7k8txqgv',
  0.001,
  0.00001
);
```

## 🧹 **Cleanup Summary**

- **Removed**: `database_helper.dart` (consolidated into `database_service.dart`)
- **Deprecated**: `gotham_node_service.dart` (use `SPVClient`)
- **Deprecated**: `daemon_status.dart` (integrated into `GothamDaemon`)
- **Consolidated**: Database operations into single service
- **Integrated**: Daemon status into main daemon service

## 🚀 **Result**

- **7 active services** (down from 10+)
- **No duplicate functionality**
- **Better performance** through consolidation
- **Cleaner architecture** with clear responsibilities
- **Flutter-first design** with beautiful UI controls