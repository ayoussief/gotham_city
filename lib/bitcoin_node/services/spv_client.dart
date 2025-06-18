import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import '../models/block_header.dart';
import '../models/compact_filter.dart';
import '../models/peer.dart';
import '../config/gotham_chain_params.dart';
import 'p2p_client.dart';
import 'filter_storage.dart';
import 'wallet_backend.dart';

// SPV Client implementing BIP157/158 Neutrino protocol
class SPVClient {
  static final SPVClient _instance = SPVClient._internal();
  factory SPVClient() => _instance;
  SPVClient._internal();

  final P2PClient _p2pClient = P2PClient();
  final FilterStorage _filterStorage = FilterStorage();
  final WalletBackend _walletBackend = WalletBackend();
  
  // State management
  bool _isInitialized = false;
  bool _isSyncing = false;
  bool _isConnected = false;
  
  // Sync progress
  int _currentHeight = 0;
  int _targetHeight = 0;
  int _filtersDownloaded = 0;
  
  // Stream controllers for real-time updates
  final StreamController<SPVSyncStatus> _syncStatusController = StreamController<SPVSyncStatus>.broadcast();
  final StreamController<List<BlockHeader>> _newHeadersController = StreamController<List<BlockHeader>>.broadcast();
  final StreamController<List<String>> _newTransactionsController = StreamController<List<String>>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  // Getters for streams
  Stream<SPVSyncStatus> get syncStatusStream => _syncStatusController.stream;
  Stream<List<BlockHeader>> get newHeadersStream => _newHeadersController.stream;
  Stream<List<String>> get newTransactionsStream => _newTransactionsController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  
  // Getters for state
  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;
  bool get isConnected => _isConnected;
  int get currentHeight => _currentHeight;
  int get targetHeight => _targetHeight;
  double get syncProgress => _targetHeight > 0 ? _currentHeight / _targetHeight : 0.0;
  
  SPVSyncStatus get syncStatus => SPVSyncStatus(
    isConnected: _isConnected,
    isSyncing: _isSyncing,
    currentHeight: _currentHeight,
    targetHeight: _targetHeight,
    syncProgress: syncProgress,
    filtersDownloaded: 0, // Add proper filter count if available
  );
  
  Future<void> stopSync() async {
    await stop();
  }
  
  // Initialize the SPV client
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('Initializing SPV client...');
      
      // Initialize storage
      await _filterStorage.initialize();
      await _walletBackend.initialize();
      
      // Load stored state
      await _loadStoredState();
      
      // Initialize P2P client
      await _p2pClient.initialize();
      
      // Set up P2P event handlers
      _setupP2PHandlers();
      
      _isInitialized = true;
      print('SPV client initialized successfully');
      
    } catch (e) {
      print('Failed to initialize SPV client: $e');
      throw e;
    }
  }
  
  // Start syncing with the network
  Future<void> startSync() async {
    if (!_isInitialized) {
      throw StateError('SPV client not initialized');
    }
    
    if (_isSyncing) {
      print('Sync already in progress');
      return;
    }
    
    try {
      _isSyncing = true;
      _updateSyncStatus();
      
      print('Starting SPV sync...');
      
      // Connect to peers
      await _connectToPeers();
      
      // Start header sync
      await _syncHeaders();
      
      // Start filter sync
      await _syncFilters();
      
      // Start transaction monitoring
      await _startTransactionMonitoring();
      
      print('SPV sync completed');
      
    } catch (e) {
      print('SPV sync failed: $e');
      throw e;
    } finally {
      _isSyncing = false;
      _updateSyncStatus();
    }
  }
  
  // Stop syncing and disconnect
  Future<void> stop() async {
    _isSyncing = false;
    await _p2pClient.disconnect();
    _isConnected = false;
    _connectionController.add(false);
    _updateSyncStatus();
  }
  
  // Add addresses to watch
  Future<void> addWatchAddresses(List<String> addresses) async {
    await _walletBackend.addWatchAddresses(addresses);
    
    // Trigger rescan of recent filters
    await _rescanRecentFilters();
  }
  
  // Get wallet balance
  Future<double> getBalance() async {
    return await _walletBackend.getBalance();
  }
  
  // Get transaction history
  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    return await _walletBackend.getTransactionHistory();
  }
  
  // Send transaction
  Future<String> sendTransaction(String toAddress, double amount, double feeRate) async {
    // Build transaction
    final txHex = await _walletBackend.buildTransaction(toAddress, amount, feeRate);
    
    // Broadcast transaction
    final txid = await _p2pClient.broadcastTransaction(txHex);
    
    return txid;
  }
  
  // Private methods
  
  Future<void> _loadStoredState() async {
    final latestHeader = await _filterStorage.getLatestHeader();
    if (latestHeader != null) {
      _currentHeight = latestHeader.height;
    }
    
    final checkpoint = GothamChainParams.getClosestCheckpoint(_currentHeight);
    if (checkpoint != null && _currentHeight < checkpoint.key) {
      _currentHeight = checkpoint.key;
    }
  }
  
  void _setupP2PHandlers() {
    _p2pClient.connectionStream.listen((connected) {
      _isConnected = connected;
      _connectionController.add(connected);
    });
    
    _p2pClient.newHeadersStream.listen((headers) {
      _handleNewHeaders(headers);
    });
    
    _p2pClient.newFiltersStream.listen((filters) {
      _handleNewFilters(filters);
    });
  }
  
  Future<void> _connectToPeers() async {
    print('Connecting to Gotham peers...');
    
    // Try DNS seeds first
    for (String seed in GothamChainParams.dnsSeeds) {
      try {
        await _p2pClient.connectToPeer(seed, GothamChainParams.defaultPort);
        if (_isConnected) break;
      } catch (e) {
        print('Failed to connect to DNS seed $seed: $e');
      }
    }
    
    // Fallback to bootstrap peers
    if (!_isConnected) {
      for (String peer in GothamChainParams.bootstrapPeers) {
        try {
          final parts = peer.split(':');
          await _p2pClient.connectToPeer(parts[0], int.parse(parts[1]));
          if (_isConnected) break;
        } catch (e) {
          print('Failed to connect to bootstrap peer $peer: $e');
        }
      }
    }
    
    if (!_isConnected) {
      throw StateError('Failed to connect to any Gotham peers');
    }
    
    print('Connected to Gotham network');
  }
  
  Future<void> _syncHeaders() async {
    print('Syncing block headers...');
    
    // Get current best height from peers
    _targetHeight = await _p2pClient.getBestHeight();
    _updateSyncStatus();
    
    // Request headers from current height
    final headers = await _p2pClient.getHeaders(_currentHeight, _targetHeight);
    
    // Validate and store headers
    for (final header in headers) {
      if (_validateHeader(header)) {
        await _filterStorage.storeHeader(header);
        _currentHeight = header.height;
      }
    }
    
    _newHeadersController.add(headers);
    _updateSyncStatus();
    
    print('Header sync completed. Current height: $_currentHeight');
  }
  
  Future<void> _syncFilters() async {
    print('Syncing compact filters...');
    
    // Get filter headers first
    final filterHeaders = await _p2pClient.getFilterHeaders(_currentHeight);
    
    // Download and store filters
    for (final filterHeader in filterHeaders) {
      final filter = await _p2pClient.getFilter(filterHeader.blockHash);
      if (filter != null) {
        await _filterStorage.storeFilter(filter);
        _filtersDownloaded++;
        _updateSyncStatus();
      }
    }
    
    print('Filter sync completed. Downloaded $_filtersDownloaded filters');
  }
  
  Future<void> _startTransactionMonitoring() async {
    print('Starting transaction monitoring...');
    
    // Get watch addresses from wallet
    final watchAddresses = await _walletBackend.getWatchAddresses();
    
    // Check recent filters for matches
    await _checkFiltersForMatches(watchAddresses);
  }
  
  Future<void> _checkFiltersForMatches(List<String> addresses) async {
    final recentFilters = await _filterStorage.getRecentFilters(144); // Last 24 hours
    
    for (final filter in recentFilters) {
      final addressBytes = addresses.map((addr) => _addressToBytes(addr)).toList();
      
      if (filter.matchAny(addressBytes)) {
        print('Filter match found for block ${filter.blockHeight}');
        
        // Request merkle block and transactions
        final merkleBlock = await _p2pClient.getMerkleBlock(filter.blockHash, addresses);
        if (merkleBlock != null) {
          await _processMerkleBlock(merkleBlock);
        }
      }
    }
  }
  
  Future<void> _rescanRecentFilters() async {
    final watchAddresses = await _walletBackend.getWatchAddresses();
    await _checkFiltersForMatches(watchAddresses);
  }
  
  bool _validateHeader(BlockHeader header) {
    // Basic validation
    if (header.height <= 0) return false;
    if (header.hash.isEmpty) return false;
    
    // Check proof of work
    if (!header.verifyProofOfWork()) return false;
    
    // Check against checkpoints
    if (!GothamChainParams.isValidCheckpoint(header.height, header.hash)) {
      return false;
    }
    
    return true;
  }
  
  void _handleNewHeaders(List<BlockHeader> headers) {
    for (final header in headers) {
      if (_validateHeader(header)) {
        _currentHeight = max(_currentHeight, header.height);
      }
    }
    _updateSyncStatus();
    _newHeadersController.add(headers);
  }
  
  void _handleNewFilters(List<CompactFilter> filters) async {
    final watchAddresses = await _walletBackend.getWatchAddresses();
    final addressBytes = watchAddresses.map((addr) => _addressToBytes(addr)).toList();
    
    for (final filter in filters) {
      if (filter.matchAny(addressBytes)) {
        // Request full block data for matched filter
        final merkleBlock = await _p2pClient.getMerkleBlock(filter.blockHash, watchAddresses);
        if (merkleBlock != null) {
          await _processMerkleBlock(merkleBlock);
        }
      }
    }
  }
  
  Future<void> _processMerkleBlock(Map<String, dynamic> merkleBlock) async {
    // Process transactions in the merkle block
    final transactions = merkleBlock['transactions'] as List<Map<String, dynamic>>? ?? [];
    final newTxids = <String>[];
    
    for (final tx in transactions) {
      final txid = tx['txid'] as String;
      
      // Update wallet with new transaction
      await _walletBackend.processTransaction(tx);
      newTxids.add(txid);
    }
    
    if (newTxids.isNotEmpty) {
      _newTransactionsController.add(newTxids);
    }
  }
  
  Uint8List _addressToBytes(String address) {
    // Convert address to bytes for filter matching
    // This is a simplified implementation
    return Uint8List.fromList(address.codeUnits);
  }
  
  void _updateSyncStatus() {
    final status = SPVSyncStatus(
      isConnected: _isConnected,
      isSyncing: _isSyncing,
      currentHeight: _currentHeight,
      targetHeight: _targetHeight,
      syncProgress: syncProgress,
      filtersDownloaded: _filtersDownloaded,
    );
    
    _syncStatusController.add(status);
  }
  
  // Cleanup
  void dispose() {
    _syncStatusController.close();
    _newHeadersController.close();
    _newTransactionsController.close();
    _connectionController.close();
    _p2pClient.dispose();
  }
}

// SPV sync status model
class SPVSyncStatus {
  final bool isConnected;
  final bool isSyncing;
  final int currentHeight;
  final int targetHeight;
  final double syncProgress;
  final int filtersDownloaded;
  
  SPVSyncStatus({
    required this.isConnected,
    required this.isSyncing,
    required this.currentHeight,
    required this.targetHeight,
    required this.syncProgress,
    required this.filtersDownloaded,
  });
  
  @override
  String toString() {
    return 'SPVSyncStatus(connected: $isConnected, syncing: $isSyncing, progress: ${(syncProgress * 100).toStringAsFixed(1)}%)';
  }
}