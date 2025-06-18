import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure wallet storage similar to Bitcoin Core's wallet.dat
/// Stores wallet descriptors, keys, and metadata
class WalletStorage {
  static final WalletStorage _instance = WalletStorage._internal();
  factory WalletStorage() => _instance;
  WalletStorage._internal();

  static const String _walletFileName = 'wallet.dat';
  static const String _walletBackupSuffix = '.bak';
  
  String? _walletDir;
  Map<String, dynamic>? _walletData;
  bool _isLoaded = false;

  /// Initialize wallet storage and create wallet directory
  Future<void> initialize() async {
    await _ensureWalletDirectory();
    await _loadWalletData();
  }

  /// Get the wallet directory path (similar to Bitcoin Core's datadir)
  Future<String> get walletDirectory async {
    if (_walletDir != null) return _walletDir!;
    
    // Get application documents directory
    final prefs = await SharedPreferences.getInstance();
    String? customPath = prefs.getString('wallet_directory');
    
    if (customPath != null && await Directory(customPath).exists()) {
      _walletDir = customPath;
    } else {
      // Default to user's home directory + .gotham
      final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
      _walletDir = join(homeDir, '.gotham');
    }
    
    return _walletDir!;
  }

  /// Ensure wallet directory exists
  Future<void> _ensureWalletDirectory() async {
    final dir = Directory(await walletDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      print('Created wallet directory: ${dir.path}');
    }
  }

  /// Get wallet.dat file path
  Future<String> get walletFilePath async {
    return join(await walletDirectory, _walletFileName);
  }

  /// Get wallet backup file path
  Future<String> get walletBackupPath async {
    return join(await walletDirectory, '$_walletFileName$_walletBackupSuffix');
  }

  /// Load wallet data from wallet.dat
  Future<void> _loadWalletData() async {
    try {
      final walletFile = File(await walletFilePath);
      
      if (await walletFile.exists()) {
        final encryptedData = await walletFile.readAsString();
        _walletData = _decryptWalletData(encryptedData);
        print('Loaded wallet.dat with ${_walletData?.keys.length ?? 0} entries');
      } else {
        _walletData = _createEmptyWalletData();
        print('Created new wallet.dat structure');
      }
      
      _isLoaded = true;
    } catch (e) {
      print('Error loading wallet.dat: $e');
      _walletData = _createEmptyWalletData();
      _isLoaded = true;
    }
  }

  /// Create empty wallet data structure
  Map<String, dynamic> _createEmptyWalletData() {
    return {
      'version': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'network': 'gotham',
      'wallet_descriptor': null,
      'master_seed': null,
      'master_private_key': null,
      'address_index': 0,
      'addresses': <String, Map<String, dynamic>>{},
      'private_keys': <String, String>{},
      'public_keys': <String, String>{},
      'watch_addresses': <String>[],
      'transactions': <String, Map<String, dynamic>>{},
      'utxos': <String, Map<String, dynamic>>{},
      'metadata': <String, dynamic>{
        'label': 'Gotham City Wallet',
        'last_backup': null,
        'last_sync': null,
      },
    };
  }

  /// Save wallet data to wallet.dat with backup
  Future<void> saveWalletData() async {
    if (!_isLoaded || _walletData == null) return;

    try {
      final walletFile = File(await walletFilePath);
      final backupFile = File(await walletBackupPath);
      
      // Create backup of existing wallet.dat
      if (await walletFile.exists()) {
        await walletFile.copy(await walletBackupPath);
      }
      
      // Update metadata
      _walletData!['metadata']['last_backup'] = DateTime.now().millisecondsSinceEpoch;
      
      // Encrypt and save wallet data
      final encryptedData = _encryptWalletData(_walletData!);
      await walletFile.writeAsString(encryptedData);
      
      print('Saved wallet.dat (${encryptedData.length} bytes)');
    } catch (e) {
      print('Error saving wallet.dat: $e');
      throw Exception('Failed to save wallet: $e');
    }
  }

  /// Store wallet descriptor (HD wallet seed phrase and derivation info)
  Future<void> storeWalletDescriptor({
    required String seedPhrase,
    required String masterPrivateKey,
    String? label,
  }) async {
    if (!_isLoaded) await _loadWalletData();
    
    _walletData!['wallet_descriptor'] = {
      'type': 'hd',
      'seed_phrase': seedPhrase,
      'derivation_path': "m/44'/0'/0'", // BIP44 standard
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'label': label ?? 'HD Wallet',
    };
    
    _walletData!['master_seed'] = seedPhrase;
    _walletData!['master_private_key'] = masterPrivateKey;
    
    await saveWalletData();
  }

  /// Store address with its keys and metadata
  Future<void> storeAddress({
    required String address,
    required String privateKey,
    required String publicKey,
    int? derivationIndex,
    String? label,
    bool isChange = false,
  }) async {
    if (!_isLoaded) await _loadWalletData();
    
    _walletData!['addresses'][address] = {
      'private_key': privateKey,
      'public_key': publicKey,
      'derivation_index': derivationIndex,
      'label': label,
      'is_change': isChange,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'first_seen': null,
      'last_used': null,
    };
    
    _walletData!['private_keys'][address] = privateKey;
    _walletData!['public_keys'][address] = publicKey;
    
    await saveWalletData();
  }

  /// Add watch-only address
  Future<void> addWatchAddress(String address, {String? label}) async {
    if (!_isLoaded) await _loadWalletData();
    
    final watchAddresses = List<String>.from(_walletData!['watch_addresses']);
    if (!watchAddresses.contains(address)) {
      watchAddresses.add(address);
      _walletData!['watch_addresses'] = watchAddresses;
      
      // Store metadata for watch address
      _walletData!['addresses'][address] = {
        'watch_only': true,
        'label': label,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };
      
      await saveWalletData();
    }
  }

  /// Store transaction
  Future<void> storeTransaction(Map<String, dynamic> transaction) async {
    if (!_isLoaded) await _loadWalletData();
    
    final txid = transaction['txid'] as String;
    _walletData!['transactions'][txid] = {
      ...transaction,
      'stored_at': DateTime.now().millisecondsSinceEpoch,
    };
    
    await saveWalletData();
  }

  /// Store UTXO
  Future<void> storeUTXO({
    required String txid,
    required int vout,
    required String address,
    required int amount,
    required String scriptPubKey,
    int? blockHeight,
  }) async {
    if (!_isLoaded) await _loadWalletData();
    
    final utxoKey = '$txid:$vout';
    _walletData!['utxos'][utxoKey] = {
      'txid': txid,
      'vout': vout,
      'address': address,
      'amount': amount,
      'script_pubkey': scriptPubKey,
      'block_height': blockHeight,
      'spent': false,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
    
    await saveWalletData();
  }

  /// Mark UTXO as spent
  Future<void> markUTXOSpent(String txid, int vout) async {
    if (!_isLoaded) await _loadWalletData();
    
    final utxoKey = '$txid:$vout';
    if (_walletData!['utxos'].containsKey(utxoKey)) {
      _walletData!['utxos'][utxoKey]['spent'] = true;
      _walletData!['utxos'][utxoKey]['spent_at'] = DateTime.now().millisecondsSinceEpoch;
      await saveWalletData();
    }
  }

  /// Get wallet descriptor
  Map<String, dynamic>? getWalletDescriptor() {
    return _walletData?['wallet_descriptor'];
  }

  /// Get all addresses
  Map<String, Map<String, dynamic>> getAddresses() {
    if (!_isLoaded) return {};
    return Map<String, Map<String, dynamic>>.from(_walletData!['addresses']);
  }

  /// Get private key for address
  String? getPrivateKey(String address) {
    return _walletData?['private_keys']?[address];
  }

  /// Get all UTXOs
  List<Map<String, dynamic>> getUTXOs({bool includeSpent = false}) {
    if (!_isLoaded) return [];
    
    final utxos = <Map<String, dynamic>>[];
    final utxoMap = Map<String, dynamic>.from(_walletData!['utxos']);
    
    for (final entry in utxoMap.entries) {
      final utxo = Map<String, dynamic>.from(entry.value);
      if (includeSpent || !utxo['spent']) {
        utxos.add(utxo);
      }
    }
    
    return utxos;
  }

  /// Get wallet info (similar to Bitcoin Core's getwalletinfo RPC)
  Map<String, dynamic> getWalletInfo() {
    if (!_isLoaded) return {};
    
    final addresses = getAddresses();
    final utxos = getUTXOs();
    final transactions = Map<String, dynamic>.from(_walletData!['transactions']);
    
    return {
      'wallet_name': 'wallet.dat',
      'wallet_version': _walletData!['version'],
      'format': 'gotham',
      'balance': utxos.fold<int>(0, (sum, utxo) => sum + (utxo['amount'] as int)),
      'unconfirmed_balance': 0, // TODO: Calculate from pending transactions
      'immature_balance': 0,
      'tx_count': transactions.length,
      'key_pool_oldest': _walletData!['created_at'],
      'key_pool_size': addresses.length,
      'unlocked_until': null, // TODO: Implement wallet encryption
      'pay_tx_fee': 0.0001, // Default fee rate
      'hd_seed_id': _walletData!['master_seed'] != null ? 
        sha256.convert(utf8.encode(_walletData!['master_seed'])).toString().substring(0, 40) : null,
      'private_keys_enabled': true,
      'avoid_reuse': false,
      'scanning': false,
    };
  }

  /// Backup wallet to specified path
  Future<void> backupWallet(String backupPath) async {
    final walletFile = File(await walletFilePath);
    if (await walletFile.exists()) {
      await walletFile.copy(backupPath);
      print('Wallet backed up to: $backupPath');
    } else {
      throw Exception('Wallet file does not exist');
    }
  }

  /// Simple encryption (in production, use proper encryption)
  String _encryptWalletData(Map<String, dynamic> data) {
    final jsonString = jsonEncode(data);
    final bytes = utf8.encode(jsonString);
    return base64Encode(bytes);
  }

  /// Simple decryption (in production, use proper decryption)
  Map<String, dynamic> _decryptWalletData(String encryptedData) {
    try {
      final bytes = base64Decode(encryptedData);
      final jsonString = utf8.decode(bytes);
      return jsonDecode(jsonString);
    } catch (e) {
      throw Exception('Failed to decrypt wallet data: $e');
    }
  }

  /// Check if wallet exists
  Future<bool> walletExists() async {
    final walletFile = File(await walletFilePath);
    return await walletFile.exists();
  }

  /// Delete wallet (use with caution!)
  Future<void> deleteWallet() async {
    final walletFile = File(await walletFilePath);
    final backupFile = File(await walletBackupPath);
    
    if (await walletFile.exists()) {
      await walletFile.delete();
    }
    if (await backupFile.exists()) {
      await backupFile.delete();
    }
    
    _walletData = null;
    _isLoaded = false;
    
    print('Wallet deleted');
  }

  /// Update address index (for HD wallets)
  Future<void> updateAddressIndex(int index) async {
    if (!_isLoaded) await _loadWalletData();
    
    _walletData!['address_index'] = index;
    await saveWalletData();
  }

  /// Get current address index
  int getAddressIndex() {
    return _walletData?['address_index'] ?? 0;
  }

  /// Update sync status
  Future<void> updateSyncStatus(int blockHeight) async {
    if (!_isLoaded) await _loadWalletData();
    
    _walletData!['metadata']['last_sync'] = DateTime.now().millisecondsSinceEpoch;
    _walletData!['metadata']['sync_height'] = blockHeight;
    await saveWalletData();
  }
}