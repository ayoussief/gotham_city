import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../gotham_node/consensus/amount.dart';
import '../models/gotham_wallet.dart';
import '../models/address_info.dart';
import '../models/transaction.dart';
import 'database_service.dart';
import '../gotham_node/crypto/hd_wallet.dart';
import '../gotham_node/crypto/gotham_address.dart';

/// Gotham Wallet Manager - Based on Gotham Core wallet architecture
/// 
/// This service manages wallets and their addresses separately, following
/// the same pattern as Gotham Core where a wallet is a container that
/// manages multiple addresses.
class GothamWalletManager {
  static final GothamWalletManager _instance = GothamWalletManager._internal();
  factory GothamWalletManager() => _instance;
  GothamWalletManager._internal();

  final DatabaseService _databaseService = DatabaseService();
  
  // Current state
  GothamWallet? _currentWallet;
  final Map<String, List<AddressInfo>> _walletAddresses = {};
  final Map<String, List<Transaction>> _walletTransactions = {};
  
  // Streams for reactive updates
  final StreamController<GothamWallet?> _walletController = StreamController<GothamWallet?>.broadcast();
  final StreamController<List<AddressInfo>> _addressesController = StreamController<List<AddressInfo>>.broadcast();
  final StreamController<List<Transaction>> _transactionsController = StreamController<List<Transaction>>.broadcast();
  final StreamController<bool> _syncStatusController = StreamController<bool>.broadcast();

  // Public streams
  Stream<GothamWallet?> get walletStream => _walletController.stream;
  Stream<List<AddressInfo>> get addressesStream => _addressesController.stream;
  Stream<List<Transaction>> get transactionsStream => _transactionsController.stream;
  Stream<bool> get syncStatusStream => _syncStatusController.stream;

  // Getters
  GothamWallet? get currentWallet => _currentWallet;
  List<AddressInfo> get currentAddresses => _currentWallet != null 
      ? _walletAddresses[_currentWallet!.name] ?? []
      : [];
  List<Transaction> get currentTransactions => _currentWallet != null 
      ? _walletTransactions[_currentWallet!.name] ?? []
      : [];

  /// Initialize the wallet manager
  Future<void> initialize() async {
    print('GothamWalletManager: Initializing...');
    
    try {
      await _databaseService.initialize();
      
      // Load existing wallets
      final wallets = await _loadWallets();
      print('GothamWalletManager: Found ${wallets.length} existing wallets');
      
      if (wallets.isNotEmpty) {
        // Load the most recently used wallet
        final lastWallet = wallets.reduce((a, b) => 
            (a.lastUsed ?? a.createdAt).isAfter(b.lastUsed ?? b.createdAt) ? a : b);
        await loadWallet(lastWallet.name);
      }
      
      print('GothamWalletManager: Initialization completed');
    } catch (e) {
      print('GothamWalletManager: Initialization failed: $e');
      rethrow;
    }
  }

  /// Create a new HD wallet
  Future<GothamWallet> createWallet({
    required String name,
    String? description,
    String? seedPhrase,
  }) async {
    print('GothamWalletManager: Creating wallet: $name');
    
    try {
      // Check if wallet already exists
      final existingWallets = await _loadWallets();
      if (existingWallets.any((w) => w.name == name)) {
        throw Exception('Wallet with name "$name" already exists');
      }

      // Generate seed phrase if not provided
      final actualSeedPhrase = seedPhrase ?? HDWallet.generateMnemonic();
      
      // Create HD wallet
      final hdWallet = HDWallet.fromMnemonic(actualSeedPhrase);
      
      // Create wallet model
      final wallet = GothamWallet(
        name: name,
        description: description,
        isHD: true,
        seedPhrase: actualSeedPhrase,
        createdAt: DateTime.now(),
        network: 'gotham',
      );

      // Save wallet to database
      await _saveWallet(wallet);
      
      // Generate initial receiving addresses (following Gotham Core pattern)
      await _generateInitialAddresses(wallet, hdWallet);
      
      // Set as current wallet
      await loadWallet(name);
      
      print('GothamWalletManager: Wallet created successfully: $name');
      return wallet;
    } catch (e) {
      print('GothamWalletManager: Failed to create wallet: $e');
      rethrow;
    }
  }

  /// Import wallet from seed phrase
  Future<GothamWallet> importWallet({
    required String name,
    required String seedPhrase,
    String? description,
  }) async {
    print('GothamWalletManager: Importing wallet: $name');
    
    try {
      // Validate seed phrase
      if (!HDWallet.validateMnemonic(seedPhrase)) {
        throw Exception('Invalid seed phrase');
      }

      // Check if wallet already exists
      final existingWallets = await _loadWallets();
      if (existingWallets.any((w) => w.name == name)) {
        throw Exception('Wallet with name "$name" already exists');
      }

      // Create HD wallet from seed
      final hdWallet = HDWallet.fromMnemonic(seedPhrase);
      
      // Create wallet model
      final wallet = GothamWallet(
        name: name,
        description: description,
        isHD: true,
        seedPhrase: seedPhrase,
        createdAt: DateTime.now(),
        network: 'gotham',
      );

      // Save wallet to database
      await _saveWallet(wallet);
      
      // Generate initial addresses and scan for existing transactions
      await _generateInitialAddresses(wallet, hdWallet);
      await _scanWalletAddresses(wallet);
      
      // Set as current wallet
      await loadWallet(name);
      
      print('GothamWalletManager: Wallet imported successfully: $name');
      return wallet;
    } catch (e) {
      print('GothamWalletManager: Failed to import wallet: $e');
      rethrow;
    }
  }

  /// Load a specific wallet
  Future<void> loadWallet(String walletName) async {
    print('GothamWalletManager: Loading wallet: $walletName');
    
    try {
      final wallets = await _loadWallets();
      final wallet = wallets.firstWhere(
        (w) => w.name == walletName,
        orElse: () => throw Exception('Wallet not found: $walletName'),
      );

      _currentWallet = wallet;
      
      // Load addresses for this wallet
      await _loadWalletAddresses(walletName);
      
      // Load transactions for this wallet
      await _loadWalletTransactions(walletName);
      
      // Update last used time
      final updatedWallet = wallet.copyWith(lastUsed: DateTime.now());
      await _saveWallet(updatedWallet);
      _currentWallet = updatedWallet;
      
      // Notify listeners
      _walletController.add(_currentWallet);
      _addressesController.add(currentAddresses);
      _transactionsController.add(currentTransactions);
      
      print('GothamWalletManager: Wallet loaded successfully: $walletName');
    } catch (e) {
      print('GothamWalletManager: Failed to load wallet: $e');
      rethrow;
    }
  }

  /// Get new receiving address (similar to Gotham Core's getnewaddress)
  Future<AddressInfo> getNewAddress({String? label}) async {
    if (_currentWallet == null) {
      throw Exception('No wallet loaded');
    }

    print('GothamWalletManager: Generating new address for wallet: ${_currentWallet!.name}');
    
    try {
      // Get next derivation index
      final addresses = currentAddresses.where((a) => !a.isChange).toList();
      final nextIndex = addresses.isEmpty ? 0 : addresses.map((a) => a.derivationIndex).reduce(max) + 1;
      
      // Generate address using HD wallet
      final hdWallet = HDWallet.fromMnemonic(_currentWallet!.seedPhrase!);
      final keyPair = hdWallet.deriveReceivingAddress(nextIndex);
      final address = GothamAddress.fromPublicKey(keyPair.publicKey);
      
      // Create address info
      final addressInfo = AddressInfo(
        address: address.address,
        balance: 0.0,
        label: label,
        isChange: false,
        derivationIndex: nextIndex,
        derivationPath: "m/44'/0'/0'/0/$nextIndex",
        addressType: address.type,
        walletName: _currentWallet!.name,
        publicKey: keyPair.publicKey,
        privateKey: keyPair.privateKey, // Store securely in production
        createdAt: DateTime.now(),
      );

      // Save address to database
      await _saveAddress(addressInfo);
      
      // Update local cache
      _walletAddresses[_currentWallet!.name] = [...currentAddresses, addressInfo];
      
      // Update wallet statistics
      await _updateWalletStats(_currentWallet!.name);
      
      // Notify listeners
      _addressesController.add(currentAddresses);
      
      print('GothamWalletManager: New address generated: ${address.address}');
      return addressInfo;
    } catch (e) {
      print('GothamWalletManager: Failed to generate new address: $e');
      rethrow;
    }
  }

  /// Get new change address (internal address)
  Future<AddressInfo> getNewChangeAddress() async {
    if (_currentWallet == null) {
      throw Exception('No wallet loaded');
    }

    print('GothamWalletManager: Generating new change address for wallet: ${_currentWallet!.name}');
    
    try {
      // Get next change derivation index
      final changeAddresses = currentAddresses.where((a) => a.isChange).toList();
      final nextIndex = changeAddresses.isEmpty ? 0 : changeAddresses.map((a) => a.derivationIndex).reduce(max) + 1;
      
      // Generate change address using HD wallet
      final hdWallet = HDWallet.fromMnemonic(_currentWallet!.seedPhrase!);
      final keyPair = hdWallet.deriveChangeAddress(nextIndex);
      final address = GothamAddress.fromPublicKey(keyPair.publicKey);
      
      // Create address info
      final addressInfo = AddressInfo(
        address: address.address,
        balance: 0.0,
        label: 'Change #$nextIndex',
        isChange: true,
        derivationIndex: nextIndex,
        derivationPath: "m/44'/0'/0'/1/$nextIndex",
        addressType: address.type,
        walletName: _currentWallet!.name,
        publicKey: keyPair.publicKey,
        privateKey: keyPair.privateKey,
        createdAt: DateTime.now(),
      );

      // Save address to database
      await _saveAddress(addressInfo);
      
      // Update local cache
      _walletAddresses[_currentWallet!.name] = [...currentAddresses, addressInfo];
      
      // Update wallet statistics
      await _updateWalletStats(_currentWallet!.name);
      
      // Notify listeners
      _addressesController.add(currentAddresses);
      
      print('GothamWalletManager: New change address generated: ${address.address}');
      return addressInfo;
    } catch (e) {
      print('GothamWalletManager: Failed to generate change address: $e');
      rethrow;
    }
  }

  /// Get all wallets
  Future<List<GothamWallet>> getAllWallets() async {
    return await _loadWallets();
  }

  /// Get all addresses for current wallet
  Future<List<AddressInfo>> getAllAddresses() async {
    if (_currentWallet == null) {
      throw Exception('No wallet loaded');
    }
    
    await _loadWalletAddresses(_currentWallet!.name);
    return currentAddresses;
  }

  /// Refresh wallet data (rescan blockchain)
  Future<void> refreshWallet() async {
    if (_currentWallet == null) {
      throw Exception('No wallet loaded');
    }

    print('GothamWalletManager: Refreshing wallet: ${_currentWallet!.name}');
    
    try {
      _syncStatusController.add(true);
      
      // Rescan all addresses for transactions and balances
      await _scanWalletAddresses(_currentWallet!);
      
      // Update wallet statistics
      await _updateWalletStats(_currentWallet!.name);
      
      // Reload wallet data
      await loadWallet(_currentWallet!.name);
      
      print('GothamWalletManager: Wallet refreshed successfully');
    } catch (e) {
      print('GothamWalletManager: Failed to refresh wallet: $e');
      rethrow;
    } finally {
      _syncStatusController.add(false);
    }
  }

  // Private helper methods

  Future<List<GothamWallet>> _loadWallets() async {
    final walletsData = await _databaseService.getWallets();
    return walletsData.map((data) => GothamWallet.fromJson(data)).toList();
  }

  Future<void> _saveWallet(GothamWallet wallet) async {
    await _databaseService.saveWallet(wallet.toJson());
  }

  Future<void> _loadWalletAddresses(String walletName) async {
    final addressesData = await _databaseService.getAddressesForWallet(walletName);
    final addresses = addressesData.map((data) => AddressInfo.fromJson(data)).toList();
    _walletAddresses[walletName] = addresses;
  }

  Future<void> _saveAddress(AddressInfo address) async {
    await _databaseService.saveAddress(address.toJson());
  }

  Future<void> _loadWalletTransactions(String walletName) async {
    final transactionsData = await _databaseService.getTransactionsForWallet(walletName);
    final transactions = transactionsData.map((data) => Transaction.fromJson(data)).toList();
    _walletTransactions[walletName] = transactions;
  }

  Future<void> _generateInitialAddresses(GothamWallet wallet, HDWallet hdWallet) async {
    print('GothamWalletManager: Generating initial addresses for wallet: ${wallet.name}');
    
    // Generate first 20 receiving addresses (Gotham Core default)
    for (int i = 0; i < 20; i++) {
      final keyPair = hdWallet.deriveReceivingAddress(i);
      final address = GothamAddress.fromPublicKey(keyPair.publicKey);
      
      final addressInfo = AddressInfo(
        address: address.address,
        balance: 0.0,
        isChange: false,
        derivationIndex: i,
        derivationPath: "m/44'/0'/0'/0/$i",
        addressType: address.type,
        walletName: wallet.name,
        publicKey: keyPair.publicKey,
        privateKey: keyPair.privateKey,
        createdAt: DateTime.now(),
      );

      await _saveAddress(addressInfo);
    }

    // Generate first 20 change addresses
    for (int i = 0; i < 20; i++) {
      final keyPair = hdWallet.deriveChangeAddress(i);
      final address = GothamAddress.fromPublicKey(keyPair.publicKey);
      
      final addressInfo = AddressInfo(
        address: address.address,
        balance: 0.0,
        isChange: true,
        derivationIndex: i,
        derivationPath: "m/44'/0'/0'/1/$i",
        addressType: address.type,
        walletName: wallet.name,
        publicKey: keyPair.publicKey,
        privateKey: keyPair.privateKey,
        createdAt: DateTime.now(),
      );

      await _saveAddress(addressInfo);
    }
  }

  Future<void> _scanWalletAddresses(GothamWallet wallet) async {
    print('GothamWalletManager: Scanning addresses for wallet: ${wallet.name}');
    
    // In a real implementation, this would:
    // 1. Query the blockchain for each address
    // 2. Update balances and transaction counts
    // 3. Discover new transactions
    // 4. Update address usage status
    
    // For now, we'll simulate some activity
    final addresses = _walletAddresses[wallet.name] ?? [];
    for (final address in addresses.take(5)) {
      // Simulate some balance and transactions for demo
      final random = Random();
      if (random.nextBool()) {
        final updatedAddress = address.copyWith(
          balance: random.nextDouble() * 0.1,
          confirmedBalance: random.nextDouble() * 0.08,
          transactionCount: random.nextInt(5),
          lastUsed: DateTime.now().subtract(Duration(days: random.nextInt(30))),
        );
        await _saveAddress(updatedAddress);
      }
    }
  }

  Future<void> _updateWalletStats(String walletName) async {
    final addresses = _walletAddresses[walletName] ?? [];
    final transactions = _walletTransactions[walletName] ?? [];
    
    final totalBalance = addresses.fold<GAmount>(0, (sum, addr) => sum + addr.balance);
    final confirmedBalance = addresses.fold<GAmount>(0, (sum, addr) => sum + addr.confirmedBalance);
    final unconfirmedBalance = addresses.fold<GAmount>(0, (sum, addr) => sum + addr.unconfirmedBalance);
    
    final usedAddresses = addresses.where((a) => a.isUsed).length;
    final changeAddresses = addresses.where((a) => a.isChange).length;
    
    final updatedWallet = _currentWallet!.copyWith(
      totalBalance: totalBalance,
      confirmedBalance: confirmedBalance,
      unconfirmedBalance: unconfirmedBalance,
      addressCount: addresses.length,
      usedAddressCount: usedAddresses,
      changeAddressCount: changeAddresses,
      transactionCount: transactions.length,
      lastTransactionTime: transactions.isNotEmpty 
          ? transactions.map((t) => t.timestamp).reduce((a, b) => a.isAfter(b) ? a : b)
          : null,
    );

    await _saveWallet(updatedWallet);
    _currentWallet = updatedWallet;
    _walletController.add(_currentWallet);
  }

  /// Dispose resources
  void dispose() {
    _walletController.close();
    _addressesController.close();
    _transactionsController.close();
    _syncStatusController.close();
  }
}