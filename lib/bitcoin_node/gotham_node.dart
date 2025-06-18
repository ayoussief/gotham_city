// Gotham SPV Node Module
// This file exports all the SPV client functionality

// Configuration
export 'config/gotham_chain_params.dart';

// Core Services (Consolidated & Efficient)
export 'services/gotham_daemon.dart'; // Main daemon service (includes status)
export 'services/spv_client.dart'; // SPV blockchain client
export 'services/p2p_client.dart'; // P2P network client
export 'services/wallet_backend.dart'; // Wallet operations (includes storage)
export 'services/filter_storage.dart'; // Compact filter storage
export 'services/database_service.dart'; // Database operations (consolidated)
export 'services/consensus_validator.dart'; // Lightweight validation

// Legacy Services (Deprecated - kept for compatibility)
export 'services/gotham_node_service.dart'; // @deprecated Use SPVClient
export 'services/daemon_status.dart'; // @deprecated Integrated into GothamDaemon
export 'services/wallet_storage.dart'; // Used internally by WalletBackend

// Models
export 'models/block_header.dart';
export 'models/compact_filter.dart';
export 'models/peer.dart';

// Screens
export 'screens/node_status_screen.dart'; // Full Gotham node status screen