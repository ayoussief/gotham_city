import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'spv_client.dart';
import 'wallet_storage.dart';

/// Daemon status service similar to Bitcoin Core's daemon
/// Provides RPC-like interface and status monitoring
/// @deprecated Integrated into GothamDaemon for better efficiency
@Deprecated('Integrated into GothamDaemon for better efficiency')
class DaemonStatus {
  static final DaemonStatus _instance = DaemonStatus._internal();
  factory DaemonStatus() => _instance;
  DaemonStatus._internal();

  final SPVClient _spvClient = SPVClient();
  final WalletStorage _walletStorage = WalletStorage();
  
  bool _isDaemonRunning = false;
  DateTime? _startTime;
  String? _dataDir;
  
  // Status streams
  final StreamController<Map<String, dynamic>> _statusController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;
  
  /// Initialize daemon status service
  Future<void> initialize() async {
    _startTime = DateTime.now();
    _dataDir = await _walletStorage.walletDirectory;
    _isDaemonRunning = true;
    
    // Listen to SPV client status changes
    _spvClient.syncStatusStream.listen((status) {
      _statusController.add(_buildStatusInfo());
    });
    
    print('Daemon status service initialized');
  }
  
  /// Get daemon info (similar to Bitcoin Core's getinfo RPC)
  Map<String, dynamic> getDaemonInfo() {
    return _buildStatusInfo();
  }
  
  /// Get network info (similar to Bitcoin Core's getnetworkinfo RPC)
  Map<String, dynamic> getNetworkInfo() {
    final spvStatus = _spvClient.syncStatus;
    
    return {
      'version': 1000000, // Version 1.0.0
      'subversion': '/Gotham:1.0.0/',
      'protocol_version': 70015,
      'local_services': '0000000000000409',
      'local_services_names': ['NETWORK', 'WITNESS', 'NETWORK_LIMITED'],
      'local_relay': true,
      'time_offset': 0,
      'connections': spvStatus.isConnected ? 1 : 0,
      'connections_in': 0,
      'connections_out': spvStatus.isConnected ? 1 : 0,
      'network_active': spvStatus.isConnected,
      'networks': [
        {
          'name': 'gotham',
          'limited': false,
          'reachable': true,
          'proxy': '',
          'proxy_randomize_credentials': false,
        }
      ],
      'relay_fee': 0.00001000,
      'incremental_fee': 0.00001000,
      'local_addresses': [],
      'warnings': '',
    };
  }
  
  /// Get blockchain info (similar to Bitcoin Core's getblockchaininfo RPC)
  Map<String, dynamic> getBlockchainInfo() {
    final spvStatus = _spvClient.syncStatus;
    final walletInfo = _walletStorage.getWalletInfo();
    
    return {
      'chain': 'gotham',
      'blocks': spvStatus.currentHeight,
      'headers': spvStatus.targetHeight,
      'best_block_hash': '', // Would need to track this
      'difficulty': 1.0,
      'median_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'verification_progress': spvStatus.syncProgress,
      'initial_block_download': spvStatus.isSyncing,
      'chain_work': '0000000000000000000000000000000000000000000000000000000000000000',
      'size_on_disk': 0, // SPV doesn't store full blocks
      'pruned': true, // SPV is essentially pruned
      'softforks': {},
      'warnings': spvStatus.isSyncing ? 'Syncing with network...' : '',
    };
  }
  
  /// Get wallet info (similar to Bitcoin Core's getwalletinfo RPC)
  Map<String, dynamic> getWalletInfo() {
    return _walletStorage.getWalletInfo();
  }
  
  /// Get sync status (custom method for SPV sync monitoring)
  Map<String, dynamic> getSyncStatus() {
    final spvStatus = _spvClient.syncStatus;
    
    return {
      'is_syncing': spvStatus.isSyncing,
      'is_connected': spvStatus.isConnected,
      'current_height': spvStatus.currentHeight,
      'target_height': spvStatus.targetHeight,
      'sync_progress': spvStatus.syncProgress,
      'sync_progress_percent': (spvStatus.syncProgress * 100).toStringAsFixed(2),
      'filters_downloaded': spvStatus.filtersDownloaded,
      'estimated_time_remaining': _estimateTimeRemaining(spvStatus),
    };
  }
  
  /// Check if daemon is running (similar to checking if gothamd is running)
  bool isDaemonRunning() {
    return _isDaemonRunning;
  }
  
  /// Get uptime in seconds
  int getUptime() {
    if (_startTime == null) return 0;
    return DateTime.now().difference(_startTime!).inSeconds;
  }
  
  /// Stop daemon
  Future<void> stopDaemon() async {
    _isDaemonRunning = false;
    await _spvClient.stopSync();
    _statusController.add(_buildStatusInfo());
    print('Daemon stopped');
  }
  
  /// Create a status file (similar to Bitcoin Core's .lock file)
  Future<void> createStatusFile() async {
    if (_dataDir == null) return;
    
    final statusFile = File(join(_dataDir!, '.gotham_daemon_status'));
    final statusData = {
      'pid': pid,
      'start_time': _startTime?.millisecondsSinceEpoch,
      'data_dir': _dataDir,
      'is_running': _isDaemonRunning,
    };
    
    await statusFile.writeAsString(jsonEncode(statusData));
  }
  
  /// Remove status file
  Future<void> removeStatusFile() async {
    if (_dataDir == null) return;
    
    final statusFile = File(join(_dataDir!, '.gotham_daemon_status'));
    if (await statusFile.exists()) {
      await statusFile.delete();
    }
  }
  
  /// Build comprehensive status info
  Map<String, dynamic> _buildStatusInfo() {
    final spvStatus = _spvClient.syncStatus;
    final walletInfo = _walletStorage.getWalletInfo();
    
    return {
      'daemon': {
        'running': _isDaemonRunning,
        'uptime': getUptime(),
        'start_time': _startTime?.millisecondsSinceEpoch,
        'data_dir': _dataDir,
        'pid': pid,
      },
      'network': {
        'connected': spvStatus.isConnected,
        'connections': spvStatus.isConnected ? 1 : 0,
        'network_active': spvStatus.isConnected,
      },
      'sync': {
        'is_syncing': spvStatus.isSyncing,
        'current_height': spvStatus.currentHeight,
        'target_height': spvStatus.targetHeight,
        'progress': spvStatus.syncProgress,
        'progress_percent': (spvStatus.syncProgress * 100).toStringAsFixed(2),
        'filters_downloaded': spvStatus.filtersDownloaded,
        'estimated_time_remaining': _estimateTimeRemaining(spvStatus),
      },
      'wallet': {
        'loaded': walletInfo.isNotEmpty,
        'balance': walletInfo['balance'] ?? 0,
        'tx_count': walletInfo['tx_count'] ?? 0,
        'address_count': walletInfo['key_pool_size'] ?? 0,
      },
      'version': {
        'version': '1.0.0',
        'protocol_version': 70015,
        'wallet_version': walletInfo['wallet_version'] ?? 1,
      },
    };
  }
  
  /// Estimate time remaining for sync
  String _estimateTimeRemaining(SPVSyncStatus status) {
    if (!status.isSyncing || status.syncProgress <= 0) {
      return 'Unknown';
    }
    
    if (status.syncProgress >= 1.0) {
      return 'Complete';
    }
    
    // Simple estimation based on progress
    final remainingProgress = 1.0 - status.syncProgress;
    final estimatedSeconds = (remainingProgress * 3600).round(); // Rough estimate
    
    if (estimatedSeconds < 60) {
      return '${estimatedSeconds}s';
    } else if (estimatedSeconds < 3600) {
      return '${(estimatedSeconds / 60).round()}m';
    } else {
      return '${(estimatedSeconds / 3600).round()}h';
    }
  }
  
  void dispose() {
    _statusController.close();
  }
}

