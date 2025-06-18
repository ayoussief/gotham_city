import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wallet.dart';
import '../models/transaction.dart';
import '../models/address_info.dart';
import '../bitcoin_node/services/spv_client.dart';
import '../bitcoin_node/services/wallet_backend.dart';
import '../bitcoin_node/config/gotham_chain_params.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  final SPVClient _spvClient = SPVClient();
  final WalletBackend _walletBackend = WalletBackend();
  
  Wallet? _currentWallet;
  bool _isInitialized = false;
  
  // Streams for real-time updates
  final StreamController<Wallet?> _walletController = StreamController<Wallet?>.broadcast();
  final StreamController<double> _balanceController = StreamController<double>.broadcast();
  final StreamController<List<Transaction>> _transactionsController = StreamController<List<Transaction>>.broadcast();
  final StreamController<bool> _syncStatusController = StreamController<bool>.broadcast();

  Stream<Wallet?> get walletStream => _walletController.stream;
  Stream<double> get balanceStream => _balanceController.stream;
  Stream<List<Transaction>> get transactionsStream => _transactionsController.stream;
  Stream<bool> get syncStatusStream => _syncStatusController.stream;

  Wallet? get currentWallet => _currentWallet;
  bool get isInitialized => _isInitialized;
  bool get hasSyncedWallet => _currentWallet != null && _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('WalletService: Starting initialization...');
      
      // Initialize wallet backend first (more critical)
      print('WalletService: Initializing wallet backend...');
      await _walletBackend.initialize().timeout(const Duration(seconds: 15));
      
      // Initialize SPV client (less critical, can fail)
      print('WalletService: Initializing SPV client...');
      try {
        await _spvClient.initialize().timeout(const Duration(seconds: 10));
      } catch (e) {
        print('WalletService: SPV client initialization failed (non-critical): $e');
        // Continue without SPV for now
      }
      
      // Load existing wallet if any
      print('WalletService: Loading existing wallet...');
      await _loadExistingWallet();
      
      // Start SPV sync if we have a wallet (but don't wait for completion)
      if (_currentWallet != null) {
        print('WalletService: Starting SPV sync (non-blocking)...');
        _spvClient.startSync().catchError((e) {
          print('SPV sync error (non-blocking): $e');
        });
        _setupSyncListeners();
      }
      
      _isInitialized = true;
      print('WalletService: Initialization completed successfully');
    } catch (e) {
      print('WalletService: Initialization failed: $e');
      // Set initialized to true even if failed to prevent blocking the UI
      _isInitialized = true;
      throw Exception('Failed to initialize wallet service: $e');
    }
  }

  Future<void> _loadExistingWallet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final walletData = prefs.getString('gotham_wallet');
      
      if (walletData != null) {
        print('WalletService: Found existing wallet data, parsing...');
        try {
          final data = jsonDecode(walletData);
          _currentWallet = Wallet.fromJson(data);
          print('WalletService: Wallet parsed successfully: ${_currentWallet!.address}');
          
          // Load wallet into backend with timeout
          if (_currentWallet!.seedPhrase != null) {
            print('WalletService: Restoring wallet from seed...');
            await _walletBackend.restoreFromSeed(_currentWallet!.seedPhrase!)
                .timeout(const Duration(seconds: 15));
            print('WalletService: Wallet restored from seed');
          }
          
          _walletController.add(_currentWallet);
          print('WalletService: Wallet loaded successfully');
          
          // Update balance asynchronously (don't block initialization)
          _updateBalance().catchError((e) {
            print('WalletService: Balance update error (non-blocking): $e');
          });
        } catch (e) {
          print('WalletService: Error parsing wallet data: $e');
          // Clear corrupted wallet data
          await prefs.remove('gotham_wallet');
        }
      } else {
        print('WalletService: No existing wallet found');
      }
    } catch (e) {
      print('WalletService: Error loading existing wallet: $e');
    }
  }

  Future<Wallet> createNewWallet() async {
    print('WalletService: Starting wallet creation...');
    
    if (!_isInitialized) {
      print('WalletService: Initializing...');
      await initialize();
    }

    try {
      print('WalletService: Generating HD wallet...');
      // Generate new HD wallet
      final seedPhrase = await _walletBackend.createNewWallet();
      print('WalletService: Seed phrase generated');
      
      print('WalletService: Getting new address...');
      final address = await _walletBackend.getReceivingAddress();
      print('WalletService: Address generated: $address');
      
      // Create wallet model
      _currentWallet = Wallet(
        address: address,
        balance: 0.0,
        privateKey: '', // Not exposed for HD wallets
        isImported: false,
        seedPhrase: seedPhrase,
        createdAt: DateTime.now(),
        network: GothamChainParams.networkName,
      );
      print('WalletService: Wallet model created');

      // Save wallet
      print('WalletService: Saving wallet...');
      await _saveWallet();
      print('WalletService: Wallet saved');
      
      // Start SPV sync (but don't wait for it to complete)
      print('WalletService: Starting SPV sync...');
      _spvClient.startSync().catchError((e) {
        print('SPV sync error (non-blocking): $e');
      });
      _setupSyncListeners();
      print('WalletService: SPV sync started');
      
      _walletController.add(_currentWallet);
      print('WalletService: Wallet creation completed successfully');
      return _currentWallet!;
    } catch (e) {
      print('WalletService: Error creating wallet: $e');
      throw Exception('Failed to create wallet: $e');
    }
  }

  Future<Wallet> importWalletFromSeed(String seedPhrase) async {
    if (!_isInitialized) await initialize();

    try {
      // Import using our BIP39 implementation
      await _walletBackend.restoreFromSeed(seedPhrase);
      final address = await _walletBackend.getReceivingAddress();
      
      // Create wallet model
      _currentWallet = Wallet(
        address: address,
        balance: 0.0,
        privateKey: '', // Not exposed for HD wallets
        isImported: true,
        seedPhrase: seedPhrase,
        createdAt: DateTime.now(),
        network: GothamChainParams.networkName,
      );

      // Save wallet
      await _saveWallet();
      
      // Start SPV sync (non-blocking)
      _spvClient.startSync().catchError((e) {
        print('SPV sync error after import (non-blocking): $e');
      });
      _setupSyncListeners();
      
      _walletController.add(_currentWallet);
      
      // Update balance asynchronously (don't block import)
      _updateBalance().catchError((e) {
        print('Balance update error after import (non-blocking): $e');
      });
      
      return _currentWallet!;
    } catch (e) {
      throw Exception('Failed to import wallet: $e');
    }
  }

  Future<Wallet> importWalletFromPrivateKey(String privateKey) async {
    if (!_isInitialized) await initialize();

    try {
      // Import single private key (not HD)
      final address = await _walletBackend.importPrivateKey(privateKey);
      
      // Create wallet model
      _currentWallet = Wallet(
        address: address,
        balance: 0.0,
        privateKey: privateKey,
        isImported: true,
        seedPhrase: null,
        createdAt: DateTime.now(),
        network: GothamChainParams.networkName,
      );

      // Save wallet
      await _saveWallet();
      
      // Start SPV sync
      await _spvClient.startSync();
      _setupSyncListeners();
      
      _walletController.add(_currentWallet);
      await _updateBalance();
      
      return _currentWallet!;
    } catch (e) {
      throw Exception('Failed to import wallet from private key: $e');
    }
  }

  Future<void> _saveWallet() async {
    if (_currentWallet == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gotham_wallet', jsonEncode(_currentWallet!.toJson()));
  }

  Future<void> _updateBalance() async {
    if (_currentWallet == null) return;

    try {
      final balance = await _walletBackend.getBalance();
      _currentWallet = _currentWallet!.copyWith(balance: balance);
      
      _walletController.add(_currentWallet);
      _balanceController.add(balance);
      
      await _saveWallet();
    } catch (e) {
      print('Error updating balance: $e');
    }
  }

  Future<void> _updateTransactions() async {
    if (_currentWallet == null) return;

    try {
      final history = await _walletBackend.getTransactionHistory();
      final transactions = history.map((tx) => Transaction(
        txid: tx['txid'] ?? '',
        amount: (tx['amount'] ?? 0.0).toDouble(),
        fee: (tx['fee'] ?? 0.0).toDouble(),
        confirmations: tx['confirmations'] ?? 0,
        timestamp: DateTime.fromMillisecondsSinceEpoch((tx['timestamp'] ?? 0) * 1000),
        type: (tx['amount'] ?? 0.0) > 0 ? TransactionType.received : TransactionType.sent,
        status: (tx['confirmations'] ?? 0) > 0 ? TransactionStatus.confirmed : TransactionStatus.pending,
        fromAddress: tx['from'] ?? '',
        toAddress: tx['to'] ?? '',
      )).toList();
      
      _transactionsController.add(transactions);
    } catch (e) {
      print('Error updating transactions: $e');
    }
  }

  void _setupSyncListeners() {
    // Listen to SPV sync status
    _spvClient.syncStatusStream.listen((status) {
      _syncStatusController.add(status.isSyncing);
      
      // Update balance and transactions when sync progresses
      if (status.syncProgress > 0.5) { // Update when we have significant progress
        _updateBalance();
        _updateTransactions();
      }
    });

    // Listen to new transactions
    _spvClient.newTransactionsStream.listen((txids) {
      if (txids.isNotEmpty) {
        _updateBalance();
        _updateTransactions();
      }
    });
  }

  Future<String> getNewReceiveAddress() async {
    if (_currentWallet == null) throw Exception('No wallet loaded');
    
    try {
      final address = await _walletBackend.getNewAddress();
      
      // Update current wallet address
      _currentWallet = _currentWallet!.copyWith(address: address);
      _walletController.add(_currentWallet);
      await _saveWallet();
      
      return address;
    } catch (e) {
      throw Exception('Failed to generate new address: $e');
    }
  }

  Future<String> sendTransaction({
    required String toAddress,
    required double amount,
    double? feeRate,
  }) async {
    if (_currentWallet == null) throw Exception('No wallet loaded');
    
    try {
      final txid = await _walletBackend.sendTransaction(
        toAddress,
        amount,
        feeRate ?? GothamChainParams.defaultFeePerByte.toDouble(),
      );
      
      // Update balance and transactions
      await _updateBalance();
      await _updateTransactions();
      
      return txid;
    } catch (e) {
      throw Exception('Failed to send transaction: $e');
    }
  }

  Future<double> estimateFee({
    required String toAddress,
    required double amount,
    double? feeRate,
  }) async {
    if (_currentWallet == null) throw Exception('No wallet loaded');
    
    try {
      // Estimate transaction size (simplified)
      const inputSize = 148; // bytes per input
      const outputSize = 34; // bytes per output
      const overhead = 10; // transaction overhead
      
      final utxos = await _walletBackend.getUTXOs();
      final inputCount = _calculateRequiredInputs(utxos, amount);
      const outputCount = 2; // recipient + change
      
      final txSize = (inputCount * inputSize) + (outputCount * outputSize) + overhead;
      final fee = txSize * (feeRate ?? GothamChainParams.defaultFeePerByte.toDouble());
      
      return fee / 100000000; // Convert satoshis to GTC
    } catch (e) {
      throw Exception('Failed to estimate fee: $e');
    }
  }

  int _calculateRequiredInputs(List<Map<String, dynamic>> utxos, double amount) {
    double total = 0;
    int count = 0;
    
    // Sort UTXOs by value (largest first)
    utxos.sort((a, b) => (b['value'] ?? 0.0).compareTo(a['value'] ?? 0.0));
    
    for (final utxo in utxos) {
      total += (utxo['value'] ?? 0.0);
      count++;
      if (total >= amount) break;
    }
    
    return count;
  }

  Future<List<Transaction>> getTransactionHistory() async {
    if (_currentWallet == null) return [];
    
    try {
      final history = await _walletBackend.getTransactionHistory();
      return history.map((tx) => Transaction(
        txid: tx['txid'] ?? '',
        amount: (tx['amount'] ?? 0.0).toDouble(),
        fee: (tx['fee'] ?? 0.0).toDouble(),
        confirmations: tx['confirmations'] ?? 0,
        timestamp: DateTime.fromMillisecondsSinceEpoch((tx['timestamp'] ?? 0) * 1000),
        type: (tx['amount'] ?? 0.0) > 0 ? TransactionType.received : TransactionType.sent,
        status: (tx['confirmations'] ?? 0) > 0 ? TransactionStatus.confirmed : TransactionStatus.pending,
        fromAddress: tx['from'] ?? '',
        toAddress: tx['to'] ?? '',
      )).toList();
    } catch (e) {
      print('Error getting transaction history: $e');
      return [];
    }
  }

  Future<void> refreshWallet() async {
    if (_currentWallet == null) return;
    
    await _updateBalance();
    await _updateTransactions();
  }

  Future<void> deleteWallet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gotham_wallet');
    
    _currentWallet = null;
    _walletController.add(null);
    
    // Stop SPV client
    await _spvClient.stopSync();
  }

  Future<Map<String, dynamic>> getWalletInfo() async {
    if (_currentWallet == null) return {};
    
    try {
      final balance = await _walletBackend.getBalance();
      final utxos = await _walletBackend.getUTXOs();
      final syncStatus = _spvClient.syncStatus;
      
      return {
        'balance': balance,
        'utxo_count': utxos.length,
        'sync_height': syncStatus.currentHeight,
        'sync_progress': syncStatus.syncProgress,
        'is_syncing': syncStatus.isSyncing,
        'network': GothamChainParams.networkName,
        'address_type': _currentWallet!.address.startsWith('gt1') ? 'Bech32' : 'Legacy',
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Generate a new Bitcoin address using real secp256k1 cryptography
  Future<Map<String, String>> generateNewAddress(String label) async {
    try {
      // Generate a real Bitcoin address using our secp256k1 implementation
      final addressInfo = await _walletBackend.generateNewAddress(label);
      
      return {
        'address': addressInfo['address'] ?? '',
        'publicKey': addressInfo['publicKey'] ?? '',
        'privateKey': addressInfo['privateKey'] ?? '',
        'label': label,
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to generate address: $e');
    }
  }
  
  /// Broadcast a test transaction using real Bitcoin validation
  Future<String> broadcastTestTransaction(String toAddress, double amount) async {
    try {
      if (_currentWallet == null) {
        throw Exception('No wallet loaded');
      }
      
      // Create transaction using our real Bitcoin implementation
      final txId = await _walletBackend.createAndBroadcastTransaction(
        toAddress: toAddress,
        amount: (amount * 100000000).toInt(), // Convert to satoshis
        fromAddress: _currentWallet!.address,
      );
      
      // Update wallet balance and transactions
      await refreshWallet();
      
      return txId;
    } catch (e) {
      throw Exception('Failed to broadcast transaction: $e');
    }
  }
  
  /// Get detailed cryptographic information about the wallet
  Future<Map<String, dynamic>> getWalletCryptoInfo() async {
    try {
      if (_currentWallet == null) {
        throw Exception('No wallet loaded');
      }
      
      final cryptoInfo = await _walletBackend.getCryptographicInfo(_currentWallet!.address);
      
      return {
        'address': _currentWallet!.address,
        'publicKey': cryptoInfo['publicKey'] ?? '',
        'addressType': _currentWallet!.address.startsWith('bc1') ? 'P2WPKH (Bech32)' : 'P2PKH (Legacy)',
        'compressed': true, // We always use compressed public keys
        'network': GothamChainParams.networkName,
        'derivationPath': cryptoInfo['derivationPath'] ?? 'm/44\'/0\'/0\'/0/0',
        'scriptType': _currentWallet!.address.startsWith('bc1') ? 'witness_v0_keyhash' : 'pubkeyhash',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to get crypto info: $e');
    }
  }
  
  /// Test the secp256k1 implementation with known test vectors
  Future<Map<String, dynamic>> testSecp256k1Implementation() async {
    try {
      final testResults = await _walletBackend.runSecp256k1Tests();
      
      return {
        'success': testResults['success'] ?? false,
        'testsPassed': testResults['testsPassed'] ?? 0,
        'totalTests': testResults['totalTests'] ?? 0,
        'details': testResults['details'] ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to run secp256k1 tests: $e');
    }
  }

  // Address Management Methods
  Future<List<AddressInfo>> getAllAddresses() async {
    try {
      // Get all watch addresses from wallet backend
      final watchAddresses = await _walletBackend.getWatchAddresses();
      final addressInfoList = <AddressInfo>[];

      for (final address in watchAddresses) {
        // Get balance for each address
        final balance = await _walletBackend.getAddressBalance(address);
        
        // Get transaction count (simplified - in real implementation would query database)
        final transactions = await getAddressTransactions(address);
        final transactionCount = transactions.length;
        
        // Determine address type
        String addressType = 'unknown';
        if (address.startsWith('gt1')) {
          addressType = 'bech32';
        } else if (address.startsWith('3')) {
          addressType = 'p2sh';
        } else if (address.startsWith('1')) {
          addressType = 'p2pkh';
        }

        // Check if it's a change address (simplified logic)
        final isChange = await _isChangeAddress(address);
        
        // Get stored label
        final label = await _getAddressLabel(address);
        
        // Get creation date (simplified)
        final createdAt = DateTime.now().subtract(Duration(days: Random().nextInt(30)));
        
        addressInfoList.add(AddressInfo(
          address: address,
          balance: balance,
          label: label,
          isChange: isChange,
          transactionCount: transactionCount,
          createdAt: createdAt,
          addressType: addressType,
        ));
      }

      return addressInfoList;
    } catch (e) {
      print('Error getting all addresses: $e');
      throw Exception('Failed to load addresses: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAddressTransactions(String address) async {
    try {
      // Get transactions from wallet backend
      final allTransactions = await _walletBackend.getTransactionHistory();
      
      // Filter transactions for this specific address
      final addressTransactions = <Map<String, dynamic>>[];
      
      for (final tx in allTransactions) {
        // Parse transaction data to check if it involves this address
        final txData = tx['tx_data'] as String?;
        if (txData != null && txData.contains(address)) {
          // Determine if it's incoming or outgoing for this address
          final balanceChange = tx['balance_change'] as double? ?? 0.0;
          
          addressTransactions.add({
            'txid': tx['txid'],
            'type': balanceChange > 0 ? 'received' : 'sent',
            'amount': balanceChange.abs(),
            'confirmations': tx['confirmations'] ?? 0,
            'timestamp': tx['timestamp'],
            'block_height': tx['block_height'],
          });
        }
      }
      
      // Sort by timestamp (newest first)
      addressTransactions.sort((a, b) {
        final aTime = a['timestamp'] as int? ?? 0;
        final bTime = b['timestamp'] as int? ?? 0;
        return bTime.compareTo(aTime);
      });
      
      return addressTransactions;
    } catch (e) {
      print('Error getting address transactions: $e');
      return [];
    }
  }

  Future<void> updateAddressLabel(String address, String? label) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'address_label_$address';
      
      if (label == null || label.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, label);
      }
    } catch (e) {
      print('Error updating address label: $e');
      throw Exception('Failed to update address label: $e');
    }
  }

  Future<String?> _getAddressLabel(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('address_label_$address');
    } catch (e) {
      print('Error getting address label: $e');
      return null;
    }
  }

  Future<bool> _isChangeAddress(String address) async {
    try {
      // In a real implementation, this would check the derivation path
      // For now, we'll use a simple heuristic or stored data
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('address_is_change_$address') ?? false;
    } catch (e) {
      print('Error checking if change address: $e');
      return false;
    }
  }

  Future<AddressInfo?> getAddressInfo(String address) async {
    try {
      final allAddresses = await getAllAddresses();
      return allAddresses.firstWhere(
        (addr) => addr.address == address,
        orElse: () => throw Exception('Address not found'),
      );
    } catch (e) {
      print('Error getting address info: $e');
      return null;
    }
  }

  Future<List<AddressInfo>> getUnusedAddresses() async {
    try {
      final allAddresses = await getAllAddresses();
      return allAddresses.where((addr) => !addr.isUsed).toList();
    } catch (e) {
      print('Error getting unused addresses: $e');
      return [];
    }
  }

  Future<List<AddressInfo>> getUsedAddresses() async {
    try {
      final allAddresses = await getAllAddresses();
      return allAddresses.where((addr) => addr.isUsed).toList();
    } catch (e) {
      print('Error getting used addresses: $e');
      return [];
    }
  }

  Future<double> getTotalBalance() async {
    try {
      final allAddresses = await getAllAddresses();
      return allAddresses.fold<double>(0.0, (sum, addr) => sum + addr.balance);
    } catch (e) {
      print('Error getting total balance: $e');
      return 0.0;
    }
  }

  Future<Map<String, int>> getAddressStats() async {
    try {
      final allAddresses = await getAllAddresses();
      final totalAddresses = allAddresses.length;
      final usedAddresses = allAddresses.where((addr) => addr.isUsed).length;
      final changeAddresses = allAddresses.where((addr) => addr.isChange).length;
      final labeledAddresses = allAddresses.where((addr) => addr.label != null).length;

      return {
        'total': totalAddresses,
        'used': usedAddresses,
        'unused': totalAddresses - usedAddresses,
        'change': changeAddresses,
        'receiving': totalAddresses - changeAddresses,
        'labeled': labeledAddresses,
      };
    } catch (e) {
      print('Error getting address stats: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    try {
      // Get transaction history from wallet backend
      final transactions = await _walletBackend.getTransactionHistory();
      
      // Enhance transactions with additional data
      final enhancedTransactions = <Map<String, dynamic>>[];
      
      for (final tx in transactions) {
        // Parse the stored transaction data
        final txData = tx['tx_data'] as String? ?? '';
        final balanceChange = tx['balance_change'] as double? ?? 0.0;
        
        enhancedTransactions.add({
          'txid': tx['txid'] ?? '',
          'type': balanceChange > 0 ? 'received' : 'sent',
          'balance_change': balanceChange,
          'confirmations': tx['confirmations'] ?? 0,
          'timestamp': tx['timestamp'],
          'block_height': tx['block_height'],
          'tx_data': txData,
        });
      }
      
      // Sort by timestamp (newest first)
      enhancedTransactions.sort((a, b) {
        final aTime = a['timestamp'] as int? ?? 0;
        final bTime = b['timestamp'] as int? ?? 0;
        return bTime.compareTo(aTime);
      });
      
      return enhancedTransactions;
    } catch (e) {
      print('Error getting transaction history: $e');
      return [];
    }
  }

  void dispose() {
    _walletController.close();
    _balanceController.close();
    _transactionsController.close();
    _syncStatusController.close();
  }
}