import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/block_header.dart';
import '../models/peer.dart';
import 'database_service.dart';

class GothamNodeService {
  static final GothamNodeService _instance = GothamNodeService._internal();
  factory GothamNodeService() => _instance;
  GothamNodeService._internal();

  final DatabaseService _db = DatabaseService();
  
  // Node configuration
  String _rpcHost = 'localhost';
  int _rpcPort = 8332;
  String _rpcUser = '';
  String _rpcPassword = '';
  
  // Connection state
  bool _isConnected = false;
  bool _isSyncing = false;
  Timer? _syncTimer;
  Timer? _cleanupTimer;
  
  // Stream controllers for real-time updates
  final StreamController<BlockchainInfo> _blockchainInfoController = StreamController<BlockchainInfo>.broadcast();
  final StreamController<List<BlockHeader>> _blockHeadersController = StreamController<List<BlockHeader>>.broadcast();
  final StreamController<NetworkStats> _networkStatsController = StreamController<NetworkStats>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();

  // Getters for streams
  Stream<BlockchainInfo> get blockchainInfoStream => _blockchainInfoController.stream;
  Stream<List<BlockHeader>> get blockHeadersStream => _blockHeadersController.stream;
  Stream<NetworkStats> get networkStatsStream => _networkStatsController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  // Getters for state
  bool get isConnected => _isConnected;
  bool get isSyncing => _isSyncing;

  // Initialize the node service
  Future<void> initialize() async {
    await _loadConfiguration();
    await _startPeriodicTasks();
  }

  // Load configuration from shared preferences
  Future<void> _loadConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    _rpcHost = prefs.getString('rpc_host') ?? 'localhost';
    _rpcPort = prefs.getInt('rpc_port') ?? 8332;
    _rpcUser = prefs.getString('rpc_user') ?? '';
    _rpcPassword = prefs.getString('rpc_password') ?? '';
  }

  // Save configuration to shared preferences
  Future<void> saveConfiguration({
    required String host,
    required int port,
    required String user,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rpc_host', host);
    await prefs.setInt('rpc_port', port);
    await prefs.setString('rpc_user', user);
    await prefs.setString('rpc_password', password);
    
    _rpcHost = host;
    _rpcPort = port;
    _rpcUser = user;
    _rpcPassword = password;
  }

  // Start periodic tasks
  Future<void> _startPeriodicTasks() async {
    // Sync every 30 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _syncBlockHeaders();
    });

    // Cleanup every hour
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _performCleanup();
    });

    // Initial sync
    await _syncBlockHeaders();
  }

  // Make RPC call to Gotham node
  Future<Map<String, dynamic>?> _makeRpcCall(String method, [List<dynamic>? params]) async {
    try {
      final uri = Uri.parse('http://$_rpcHost:$_rpcPort/');
      final credentials = base64Encode(utf8.encode('$_rpcUser:$_rpcPassword'));
      
      final body = jsonEncode({
        'jsonrpc': '2.0',
        'id': DateTime.now().millisecondsSinceEpoch,
        'method': method,
        'params': params ?? [],
      });

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $credentials',
        },
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['error'] != null) {
          print('RPC Error: ${jsonResponse['error']}');
          return null;
        }
        
        if (!_isConnected) {
          _isConnected = true;
          _connectionController.add(true);
        }
        
        return jsonResponse['result'];
      } else {
        print('HTTP Error: ${response.statusCode}');
        _handleConnectionError();
        return null;
      }
    } catch (e) {
      print('Connection Error: $e');
      _handleConnectionError();
      return null;
    }
  }

  void _handleConnectionError() {
    if (_isConnected) {
      _isConnected = false;
      _connectionController.add(false);
    }
  }

  // Get blockchain information
  Future<BlockchainInfo?> getBlockchainInfo() async {
    final result = await _makeRpcCall('getblockchaininfo');
    if (result != null) {
      final info = BlockchainInfo.fromJson(result);
      _blockchainInfoController.add(info);
      return info;
    }
    return null;
  }

  // Get block header by hash
  Future<BlockHeader?> getBlockHeader(String blockHash) async {
    final result = await _makeRpcCall('getblockheader', [blockHash]);
    if (result != null) {
      return BlockHeader.fromJson(result);
    }
    return null;
  }

  // Get block hash by height
  Future<String?> getBlockHash(int height) async {
    final result = await _makeRpcCall('getblockhash', [height]);
    return result as String?;
  }

  // Get best block hash
  Future<String?> getBestBlockHash() async {
    final result = await _makeRpcCall('getbestblockhash');
    return result as String?;
  }

  // Get peer information
  Future<List<Peer>> getPeerInfo() async {
    final result = await _makeRpcCall('getpeerinfo');
    if (result != null && result is List) {
      return (result as List).map((peerData) => Peer.fromJson(peerData as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // Get network information
  Future<NetworkStats?> getNetworkInfo() async {
    final networkResult = await _makeRpcCall('getnetworkinfo');
    final peers = await getPeerInfo();
    
    if (networkResult != null) {
      final stats = NetworkStats.fromJson(networkResult, peers);
      _networkStatsController.add(stats);
      return stats;
    }
    return null;
  }

  // Sync block headers
  Future<void> _syncBlockHeaders() async {
    if (_isSyncing) return;
    
    try {
      _isSyncing = true;
      
      final blockchainInfo = await getBlockchainInfo();
      if (blockchainInfo == null) return;

      final latestLocalHeight = await _db.getLatestBlockHeight();
      final targetHeight = blockchainInfo.headers;
      
      print('Syncing headers: local=$latestLocalHeight, target=$targetHeight');

      // Sync in batches of 100 blocks
      const batchSize = 100;
      int currentHeight = latestLocalHeight + 1;
      
      while (currentHeight <= targetHeight) {
        final endHeight = (currentHeight + batchSize - 1).clamp(currentHeight, targetHeight);
        final headers = <BlockHeader>[];
        
        for (int height = currentHeight; height <= endHeight; height++) {
          final blockHash = await getBlockHash(height);
          if (blockHash != null) {
            final header = await getBlockHeader(blockHash);
            if (header != null) {
              headers.add(header);
            }
          }
        }
        
        if (headers.isNotEmpty) {
          await _db.insertBlockHeaders(headers);
          _blockHeadersController.add(headers);
          print('Synced ${headers.length} headers (${headers.first.height}-${headers.last.height})');
        }
        
        currentHeight = endHeight + 1;
        
        // Small delay to prevent overwhelming the node
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
    } catch (e) {
      print('Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Perform cleanup of old blocks
  Future<void> _performCleanup() async {
    try {
      // Keep only the latest 144 blocks (approximately 24 hours)
      await _db.cleanupKeepLatestBlocks(144);
      
      // Vacuum database to reclaim space
      await _db.vacuum();
      
      print('Cleanup completed');
    } catch (e) {
      print('Cleanup error: $e');
    }
  }

  // Get local block headers
  Future<List<BlockHeader>> getLocalBlockHeaders({int limit = 50}) async {
    return await _db.getRecentBlockHeaders(limit);
  }

  // Get local blockchain stats
  Future<Map<String, dynamic>> getLocalStats() async {
    final dbStats = await _db.getDatabaseStats();
    final latestHeader = await _db.getLatestBlockHeader();
    
    return {
      ...dbStats,
      'latest_block_time': latestHeader?.timestamp,
      'latest_block_hash': latestHeader?.hash,
      'is_connected': _isConnected,
      'is_syncing': _isSyncing,
    };
  }

  // Test connection to node
  Future<bool> testConnection() async {
    final result = await _makeRpcCall('getblockchaininfo');
    return result != null;
  }

  // Start manual sync
  Future<void> startSync() async {
    await _syncBlockHeaders();
  }

  // Stop the service
  void stop() {
    _syncTimer?.cancel();
    _cleanupTimer?.cancel();
    _blockchainInfoController.close();
    _blockHeadersController.close();
    _networkStatsController.close();
    _connectionController.close();
  }

  // Get sync progress
  Future<double> getSyncProgress() async {
    final blockchainInfo = await getBlockchainInfo();
    if (blockchainInfo == null) return 0.0;
    
    return blockchainInfo.syncPercentage;
  }

  // Check if node is synced
  Future<bool> isSynced() async {
    final blockchainInfo = await getBlockchainInfo();
    if (blockchainInfo == null) return false;
    
    return blockchainInfo.isSynced;
  }

  // Get mempool information
  Future<Map<String, dynamic>?> getMempoolInfo() async {
    return await _makeRpcCall('getmempoolinfo');
  }

  // Get mining information
  Future<Map<String, dynamic>?> getMiningInfo() async {
    return await _makeRpcCall('getmininginfo');
  }

  // Estimate smart fee
  Future<double?> estimateSmartFee(int confTarget) async {
    final result = await _makeRpcCall('estimatesmartfee', [confTarget]);
    if (result != null && result['feerate'] != null) {
      return (result['feerate'] as num).toDouble();
    }
    return null;
  }

  // Send raw transaction
  Future<String?> sendRawTransaction(String hexString) async {
    final result = await _makeRpcCall('sendrawtransaction', [hexString]);
    return result as String?;
  }

  // Get transaction
  Future<Map<String, dynamic>?> getTransaction(String txid) async {
    return await _makeRpcCall('gettransaction', [txid]);
  }

  // Get raw transaction
  Future<Map<String, dynamic>?> getRawTransaction(String txid, {bool verbose = true}) async {
    return await _makeRpcCall('getrawtransaction', [txid, verbose]);
  }
}