import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import '../models/block_header.dart';
import '../models/compact_filter.dart';
import '../config/gotham_chain_params.dart';

// P2P Client for Gotham network communication
class P2PClient {
  Socket? _socket;
  bool _isConnected = false;
  String? _currentPeer;
  int _currentPort = 0;
  
  // Message handling
  final Map<String, Completer> _pendingRequests = {};
  int _messageId = 0;
  
  // Stream controllers
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<List<BlockHeader>> _newHeadersController = StreamController<List<BlockHeader>>.broadcast();
  final StreamController<List<CompactFilter>> _newFiltersController = StreamController<List<CompactFilter>>.broadcast();
  
  // Getters for streams
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<List<BlockHeader>> get newHeadersStream => _newHeadersController.stream;
  Stream<List<CompactFilter>> get newFiltersStream => _newFiltersController.stream;
  
  // Initialize P2P client
  Future<void> initialize() async {
    print('P2P client initialized');
  }
  
  // Connect to a peer
  Future<void> connectToPeer(String host, int port) async {
    try {
      print('Connecting to $host:$port...');
      
      _socket = await Socket.connect(host, port, timeout: GothamChainParams.connectionTimeout);
      _currentPeer = host;
      _currentPort = port;
      
      // Set up socket listeners
      _setupSocketListeners();
      
      // Perform handshake
      await _performHandshake();
      
      _isConnected = true;
      _connectionController.add(true);
      
      print('Connected to $host:$port');
      
    } catch (e) {
      print('Failed to connect to $host:$port: $e');
      _isConnected = false;
      _connectionController.add(false);
      throw e;
    }
  }
  
  // Disconnect from current peer
  Future<void> disconnect() async {
    if (_socket != null) {
      await _socket!.close();
      _socket = null;
    }
    
    _isConnected = false;
    _currentPeer = null;
    _currentPort = 0;
    _connectionController.add(false);
    
    print('Disconnected from peer');
  }
  
  // Get best block height from peer
  Future<int> getBestHeight() async {
    if (!_isConnected) throw StateError('Not connected to any peer');
    
    try {
      final response = await _sendMessage('getbestblockhash', []);
      if (response != null) {
        final blockHash = response as String;
        final headerResponse = await _sendMessage('getblockheader', [blockHash]);
        if (headerResponse != null) {
          return headerResponse['height'] as int;
        }
      }
      return 0;
    } catch (e) {
      print('Failed to get best height: $e');
      return 0;
    }
  }
  
  // Get block headers
  Future<List<BlockHeader>> getHeaders(int fromHeight, int toHeight) async {
    if (!_isConnected) throw StateError('Not connected to any peer');
    
    try {
      final headers = <BlockHeader>[];
      const batchSize = 2000; // Bitcoin protocol limit
      
      for (int height = fromHeight; height <= toHeight; height += batchSize) {
        final endHeight = min(height + batchSize - 1, toHeight);
        final batchHeaders = await _getHeadersBatch(height, endHeight);
        headers.addAll(batchHeaders);
      }
      
      return headers;
    } catch (e) {
      print('Failed to get headers: $e');
      return [];
    }
  }
  
  // Get compact filter headers
  Future<List<CompactFilterHeader>> getFilterHeaders(int fromHeight) async {
    if (!_isConnected) throw StateError('Not connected to any peer');
    
    try {
      final response = await _sendMessage('getcfheaders', [
        GothamChainParams.filterType,
        fromHeight,
        null // Stop hash (null means get all)
      ]);
      
      if (response != null && response is Map) {
        final filterHashes = response['filter_hashes'] as List<String>? ?? [];
        final headers = <CompactFilterHeader>[];
        
        for (int i = 0; i < filterHashes.length; i++) {
          headers.add(CompactFilterHeader(
            filterHash: filterHashes[i],
            previousFilterHeader: i > 0 ? filterHashes[i - 1] : '',
            blockHash: '', // Will be filled by caller
            blockHeight: fromHeight + i,
          ));
        }
        
        return headers;
      }
      
      return [];
    } catch (e) {
      print('Failed to get filter headers: $e');
      return [];
    }
  }
  
  // Get compact filter
  Future<CompactFilter?> getFilter(String blockHash) async {
    if (!_isConnected) throw StateError('Not connected to any peer');
    
    try {
      final response = await _sendMessage('getcfilter', [
        GothamChainParams.filterType,
        blockHash
      ]);
      
      if (response != null && response is Map) {
        final filterData = response['filter'] as String;
        final filterBytes = base64Decode(filterData);
        
        // Get block height for this hash
        final headerResponse = await _sendMessage('getblockheader', [blockHash]);
        final blockHeight = headerResponse?['height'] as int? ?? 0;
        
        return CompactFilter(
          filterType: GothamChainParams.filterType,
          filterData: Uint8List.fromList(filterBytes),
          blockHash: blockHash,
          blockHeight: blockHeight,
        );
      }
      
      return null;
    } catch (e) {
      print('Failed to get filter for $blockHash: $e');
      return null;
    }
  }
  
  // Get merkle block with transactions
  Future<Map<String, dynamic>?> getMerkleBlock(String blockHash, List<String> addresses) async {
    if (!_isConnected) throw StateError('Not connected to any peer');
    
    try {
      // First, get the full block
      final blockResponse = await _sendMessage('getblock', [blockHash, 2]); // Verbosity 2 for full tx data
      
      if (blockResponse != null && blockResponse is Map) {
        final transactions = blockResponse['tx'] as List? ?? [];
        final relevantTxs = <Map<String, dynamic>>[];
        
        // Filter transactions that involve our addresses
        for (final tx in transactions) {
          if (tx is Map<String, dynamic> && _transactionInvolvesAddresses(tx, addresses)) {
            relevantTxs.add(tx);
          }
        }
        
        return {
          'block_hash': blockHash,
          'transactions': relevantTxs,
          'merkle_root': blockResponse['merkleroot'],
          'height': blockResponse['height'],
        };
      }
      
      return null;
    } catch (e) {
      print('Failed to get merkle block for $blockHash: $e');
      return null;
    }
  }
  
  // Broadcast transaction
  Future<String> broadcastTransaction(String txHex) async {
    if (!_isConnected) throw StateError('Not connected to any peer');
    
    try {
      final response = await _sendMessage('sendrawtransaction', [txHex]);
      if (response != null && response is String) {
        return response; // Transaction ID
      }
      throw Exception('Failed to broadcast transaction');
    } catch (e) {
      print('Failed to broadcast transaction: $e');
      rethrow;
    }
  }
  
  // Private methods
  
  void _setupSocketListeners() {
    _socket!.listen(
      _handleIncomingData,
      onError: (error) {
        print('Socket error: $error');
        _handleDisconnection();
      },
      onDone: () {
        print('Socket closed');
        _handleDisconnection();
      },
    );
  }
  
  Future<void> _performHandshake() async {
    // Send version message
    final versionMessage = _createVersionMessage();
    _socket!.add(versionMessage);
    
    // Wait for version and verack
    await Future.delayed(Duration(seconds: 2));
    
    // Send verack
    final verackMessage = _createVerackMessage();
    _socket!.add(verackMessage);
    
    print('Handshake completed');
  }
  
  Uint8List _createVersionMessage() {
    // Simplified version message creation
    // In production, you'd implement the full Bitcoin protocol message format
    final message = {
      'version': GothamChainParams.protocolVersion,
      'services': GothamChainParams.nodeNetwork | GothamChainParams.nodeCompactFilters,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'user_agent': GothamChainParams.userAgent,
    };
    
    return _encodeMessage('version', message);
  }
  
  Uint8List _createVerackMessage() {
    return _encodeMessage('verack', {});
  }
  
  Uint8List _encodeMessage(String command, dynamic payload) {
    // Simplified message encoding
    // In production, implement proper Bitcoin protocol message format with:
    // - Magic bytes (4 bytes)
    // - Command (12 bytes, null-padded)
    // - Payload length (4 bytes)
    // - Checksum (4 bytes)
    // - Payload
    
    final payloadJson = jsonEncode(payload);
    final payloadBytes = utf8.encode(payloadJson);
    
    final message = BytesBuilder();
    message.add(GothamChainParams.networkMagicBytes);
    message.add(_padCommand(command));
    message.add(_intToBytes(payloadBytes.length, 4));
    message.add(_calculateChecksum(payloadBytes));
    message.add(payloadBytes);
    
    return message.toBytes();
  }
  
  Uint8List _padCommand(String command) {
    final bytes = utf8.encode(command);
    final padded = Uint8List(12);
    for (int i = 0; i < min(bytes.length, 12); i++) {
      padded[i] = bytes[i];
    }
    return padded;
  }
  
  Uint8List _intToBytes(int value, int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = (value >> (i * 8)) & 0xFF;
    }
    return bytes;
  }
  
  Uint8List _calculateChecksum(Uint8List data) {
    // Simplified checksum - in production use double SHA256
    int checksum = 0;
    for (int byte in data) {
      checksum = (checksum + byte) & 0xFFFFFFFF;
    }
    return _intToBytes(checksum, 4);
  }
  
  void _handleIncomingData(Uint8List data) {
    // Handle incoming P2P messages
    // This is a simplified implementation
    try {
      _processIncomingMessage(data);
    } catch (e) {
      print('Error processing incoming message: $e');
    }
  }
  
  void _processIncomingMessage(Uint8List data) {
    // Simplified message processing
    // In production, implement proper Bitcoin protocol message parsing
    print('Received ${data.length} bytes from peer');
  }
  
  void _handleDisconnection() {
    _isConnected = false;
    _socket = null;
    _connectionController.add(false);
    
    // Complete any pending requests with error
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError('Connection lost');
      }
    }
    _pendingRequests.clear();
  }
  
  Future<List<BlockHeader>> _getHeadersBatch(int fromHeight, int toHeight) async {
    // Get block hashes for the range
    final headers = <BlockHeader>[];
    
    for (int height = fromHeight; height <= toHeight; height++) {
      try {
        final hashResponse = await _sendMessage('getblockhash', [height]);
        if (hashResponse != null && hashResponse is String) {
          final headerResponse = await _sendMessage('getblockheader', [hashResponse]);
          if (headerResponse != null && headerResponse is Map) {
            headers.add(BlockHeader.fromJson(Map<String, dynamic>.from(headerResponse)));
          }
        }
      } catch (e) {
        print('Failed to get header for height $height: $e');
        break;
      }
    }
    
    return headers;
  }
  
  Future<dynamic> _sendMessage(String method, List<dynamic> params) async {
    if (!_isConnected) throw StateError('Not connected');
    
    final messageId = _messageId++;
    final completer = Completer<dynamic>();
    _pendingRequests[messageId.toString()] = completer;
    
    try {
      // Simulate RPC call (in production, send proper P2P message)
      // For now, we'll simulate responses
      final response = await _simulateRPCCall(method, params);
      completer.complete(response);
      return response;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _pendingRequests.remove(messageId.toString());
    }
  }
  
  Future<dynamic> _simulateRPCCall(String method, List<dynamic> params) async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 100 + Random().nextInt(200)));
    
    // Simulate responses based on method
    switch (method) {
      case 'getbestblockhash':
        return '000000000000000000024bead8df69990852c202db0e0097c1a12ea637d7e96d';
      
      case 'getblockheader':
        final blockHash = params[0] as String;
        return {
          'hash': blockHash,
          'height': 700000 + Random().nextInt(1000),
          'version': 1,
          'previousblockhash': '000000000000000000024bead8df69990852c202db0e0097c1a12ea637d7e96c',
          'merkleroot': '4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b',
          'time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'bits': '1a00ffff',
          'nonce': Random().nextInt(0xFFFFFFFF),
        };
      
      case 'getblockhash':
        return '000000000000000000024bead8df69990852c202db0e0097c1a12ea637d7e96${Random().nextInt(10)}';
      
      case 'getcfheaders':
        return {
          'filter_hashes': List.generate(10, (i) => 
            '${Random().nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}' * 8)
        };
      
      case 'getcfilter':
        return {
          'filter': base64Encode(List.generate(100, (i) => Random().nextInt(256)))
        };
      
      case 'getblock':
        return {
          'hash': params[0],
          'height': 700000 + Random().nextInt(1000),
          'merkleroot': '4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b',
          'tx': [], // Empty for simulation
        };
      
      case 'sendrawtransaction':
        return '${Random().nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}' * 8;
      
      default:
        throw Exception('Unknown method: $method');
    }
  }
  
  bool _transactionInvolvesAddresses(Map<String, dynamic> tx, List<String> addresses) {
    // Check if transaction involves any of our watched addresses
    final vouts = tx['vout'] as List? ?? [];
    final vins = tx['vin'] as List? ?? [];
    
    // Check outputs
    for (final vout in vouts) {
      if (vout is Map) {
        final scriptPubKey = vout['scriptPubKey'] as Map?;
        final outputAddresses = scriptPubKey?['addresses'] as List? ?? [];
        
        for (final addr in outputAddresses) {
          if (addresses.contains(addr)) return true;
        }
      }
    }
    
    // Check inputs (would need to look up previous transactions)
    // Simplified for now
    
    return false;
  }
  
  void dispose() {
    disconnect();
    _connectionController.close();
    _newHeadersController.close();
    _newFiltersController.close();
  }
}