import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wallet.dart';
import '../models/transaction.dart';
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
      // Initialize SPV client and wallet backend
      await _spvClient.initialize();
      await _walletBackend.initialize();
      
      // Load existing wallet if any
      await _loadExistingWallet();
      
      // Start SPV sync if we have a wallet
      if (_currentWallet != null) {
        await _spvClient.startSync();
        _setupSyncListeners();
      }
      
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize wallet service: $e');
    }
  }

  Future<void> _loadExistingWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final walletData = prefs.getString('gotham_wallet');
    
    if (walletData != null) {
      try {
        final data = jsonDecode(walletData);
        _currentWallet = Wallet.fromJson(data);
        
        // Load wallet into backend
        if (_currentWallet!.seedPhrase != null) {
          await _walletBackend.restoreFromSeed(_currentWallet!.seedPhrase!);
        }
        
        _walletController.add(_currentWallet);
        await _updateBalance();
      } catch (e) {
        print('Error loading existing wallet: $e');
      }
    }
  }

  Future<Wallet> createNewWallet() async {
    if (!_isInitialized) await initialize();

    try {
      // Generate new HD wallet
      final seedPhrase = await _walletBackend.createNewWallet();
      final address = await _walletBackend.getNewAddress();
      
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

      // Save wallet
      await _saveWallet();
      
      // Start SPV sync
      await _spvClient.startSync();
      _setupSyncListeners();
      
      _walletController.add(_currentWallet);
      return _currentWallet!;
    } catch (e) {
      throw Exception('Failed to create wallet: $e');
    }
  }

  Future<Wallet> importWalletFromSeed(String seedPhrase) async {
    if (!_isInitialized) await initialize();

    try {
      // Validate and restore from seed
      await _walletBackend.restoreFromSeed(seedPhrase);
      final address = await _walletBackend.getNewAddress();
      
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
      
      // Start SPV sync
      await _spvClient.startSync();
      _setupSyncListeners();
      
      _walletController.add(_currentWallet);
      await _updateBalance();
      
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

  void dispose() {
    _walletController.close();
    _balanceController.close();
    _transactionsController.close();
    _syncStatusController.close();
  }
}