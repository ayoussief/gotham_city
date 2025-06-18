import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'filter_storage.dart';
import '../config/gotham_chain_params.dart';

// Wallet backend for SPV client
class WalletBackend {
  static final WalletBackend _instance = WalletBackend._internal();
  factory WalletBackend() => _instance;
  WalletBackend._internal();

  final FilterStorage _storage = FilterStorage();
  
  // HD wallet state
  String? _masterSeed;
  String? _masterPrivateKey;
  int _addressIndex = 0;
  
  // Address derivation cache
  final Map<String, String> _addressToPrivateKey = {};
  final Map<String, String> _addressToPublicKey = {};
  
  Future<void> initialize() async {
    await _storage.initialize();
    await _loadWalletState();
    print('Wallet backend initialized');
  }
  
  // Wallet creation and restoration
  Future<String> createNewWallet() async {
    final seed = _generateSeed();
    await _initializeFromSeed(seed);
    return seed;
  }
  
  Future<void> restoreFromSeed(String seed) async {
    await _initializeFromSeed(seed);
  }
  
  Future<void> _initializeFromSeed(String seed) async {
    _masterSeed = seed;
    _masterPrivateKey = _derivePrivateKeyFromSeed(seed);
    _addressIndex = 0;
    
    // Generate initial addresses
    await _generateInitialAddresses();
    
    await _saveWalletState();
  }
  
  // Address management
  Future<String> getNewAddress() async {
    final address = await _deriveAddress(_addressIndex);
    _addressIndex++;
    await _saveWalletState();
    return address;
  }
  
  Future<List<String>> getWatchAddresses() async {
    return await _storage.getWatchAddresses();
  }
  
  Future<void> addWatchAddresses(List<String> addresses) async {
    await _storage.addWatchAddresses(addresses);
  }
  
  // Balance and UTXO management
  Future<double> getBalance() async {
    final balanceSatoshis = await _storage.getBalance();
    return balanceSatoshis / 100000000.0; // Convert to BTC
  }
  
  Future<double> getAddressBalance(String address) async {
    final balanceSatoshis = await _storage.getBalance(address: address);
    return balanceSatoshis / 100000000.0;
  }
  
  Future<List<Map<String, dynamic>>> getUTXOs({String? address}) async {
    return await _storage.getUnspentUTXOs(address: address);
  }
  
  // Transaction building
  Future<String> buildTransaction(String toAddress, double amount, double feeRate) async {
    final amountSatoshis = (amount * 100000000).round();
    final feeRateSatoshisPerByte = (feeRate * 100000000).round();
    
    // Select UTXOs
    final utxos = await _selectUTXOs(amountSatoshis, feeRateSatoshisPerByte);
    if (utxos.isEmpty) {
      throw Exception('Insufficient funds');
    }
    
    // Calculate total input amount
    final totalInput = utxos.fold<int>(0, (sum, utxo) => sum + (utxo['amount'] as int));
    
    // Estimate transaction size
    final txSize = _estimateTransactionSize(utxos.length, 2); // 2 outputs (recipient + change)
    final fee = txSize * feeRateSatoshisPerByte;
    
    if (totalInput < amountSatoshis + fee) {
      throw Exception('Insufficient funds for transaction and fee');
    }
    
    // Build transaction
    final tx = await _buildRawTransaction(
      utxos: utxos,
      outputs: [
        {'address': toAddress, 'amount': amountSatoshis},
        {'address': await getNewAddress(), 'amount': totalInput - amountSatoshis - fee}, // Change
      ],
    );
    
    return tx;
  }
  
  // Transaction processing
  Future<void> processTransaction(Map<String, dynamic> tx) async {
    final txid = tx['txid'] as String;
    final vouts = tx['vout'] as List? ?? [];
    final vins = tx['vin'] as List? ?? [];
    
    // Store transaction
    await _storage.storeTransaction(tx);
    
    // Process outputs (new UTXOs)
    for (int i = 0; i < vouts.length; i++) {
      final vout = vouts[i] as Map<String, dynamic>;
      final scriptPubKey = vout['scriptPubKey'] as Map<String, dynamic>? ?? {};
      final addresses = scriptPubKey['addresses'] as List? ?? [];
      final value = ((vout['value'] as double) * 100000000).round();
      
      for (final address in addresses) {
        if (await _isOurAddress(address as String)) {
          await _storage.addUTXO(
            txid: txid,
            vout: i,
            address: address,
            amount: value,
            scriptPubKey: scriptPubKey.toString(),
            blockHeight: tx['block_height'] as int?,
          );
        }
      }
    }
    
    // Process inputs (spent UTXOs)
    for (final vin in vins) {
      if (vin is Map<String, dynamic>) {
        final prevTxid = vin['txid'] as String?;
        final prevVout = vin['vout'] as int?;
        
        if (prevTxid != null && prevVout != null) {
          await _storage.markUTXOSpent(prevTxid, prevVout);
        }
      }
    }
  }
  
  // Transaction history
  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    final transactions = await _storage.getTransactions(limit: 100);
    
    // Enhance with balance changes
    final enhancedTxs = <Map<String, dynamic>>[];
    
    for (final tx in transactions) {
      final txData = _parseTransactionData(tx['tx_data'] as String);
      final balanceChange = await _calculateBalanceChange(txData);
      
      enhancedTxs.add({
        ...tx,
        'balance_change': balanceChange,
        'type': balanceChange > 0 ? 'received' : 'sent',
      });
    }
    
    return enhancedTxs;
  }
  
  // Fee estimation
  Future<double> estimateFee(int inputCount, int outputCount, double feeRate) async {
    final txSize = _estimateTransactionSize(inputCount, outputCount);
    final feeSatoshis = txSize * (feeRate * 100000000).round();
    return feeSatoshis / 100000000.0;
  }
  
  // Private methods
  
  String _generateSeed() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Encode(bytes);
  }
  
  String _derivePrivateKeyFromSeed(String seed) {
    final seedBytes = base64Decode(seed);
    final hash = sha256.convert(seedBytes);
    return hash.toString();
  }
  
  Future<String> _deriveAddress(int index) async {
    // Simplified address derivation (BIP44)
    // In production, implement proper HD wallet derivation
    final privateKey = _derivePrivateKey(index);
    final publicKey = _derivePublicKey(privateKey);
    final address = _publicKeyToAddress(publicKey);
    
    _addressToPrivateKey[address] = privateKey;
    _addressToPublicKey[address] = publicKey;
    
    // Add to watch list
    await _storage.addWatchAddress(address);
    
    return address;
  }
  
  String _derivePrivateKey(int index) {
    // Simplified derivation
    final combined = '$_masterPrivateKey$index';
    final hash = sha256.convert(utf8.encode(combined));
    return hash.toString();
  }
  
  String _derivePublicKey(String privateKey) {
    // Simplified public key derivation
    // In production, use proper elliptic curve cryptography
    final hash = sha256.convert(utf8.encode(privateKey));
    return hash.toString();
  }
  
  String _publicKeyToAddress(String publicKey) {
    // Simplified address generation
    // In production, implement proper Bitcoin address encoding
    final hash = sha256.convert(utf8.encode(publicKey));
    final addressHash = hash.toString().substring(0, 40);
    return '${GothamChainParams.addressPrefix}1$addressHash';
  }
  
  Future<void> _generateInitialAddresses() async {
    // Generate first 20 addresses
    for (int i = 0; i < 20; i++) {
      await _deriveAddress(i);
    }
    _addressIndex = 20;
  }
  
  Future<bool> _isOurAddress(String address) async {
    final watchAddresses = await _storage.getWatchAddresses();
    return watchAddresses.contains(address);
  }
  
  Future<List<Map<String, dynamic>>> _selectUTXOs(int targetAmount, int feeRatePerByte) async {
    final utxos = await _storage.getUnspentUTXOs();
    
    // Sort by amount (largest first for efficiency)
    utxos.sort((a, b) => (b['amount'] as int).compareTo(a['amount'] as int));
    
    final selectedUTXOs = <Map<String, dynamic>>[];
    int totalAmount = 0;
    
    for (final utxo in utxos) {
      selectedUTXOs.add(utxo);
      totalAmount += utxo['amount'] as int;
      
      // Estimate fee with current UTXO count
      final estimatedFee = _estimateTransactionSize(selectedUTXOs.length, 2) * feeRatePerByte;
      
      if (totalAmount >= targetAmount + estimatedFee) {
        break;
      }
    }
    
    return selectedUTXOs;
  }
  
  int _estimateTransactionSize(int inputCount, int outputCount) {
    // Simplified transaction size estimation
    // Input: ~148 bytes each (compressed pubkey)
    // Output: ~34 bytes each
    // Overhead: ~10 bytes
    return (inputCount * 148) + (outputCount * 34) + 10;
  }
  
  Future<String> _buildRawTransaction({
    required List<Map<String, dynamic>> utxos,
    required List<Map<String, dynamic>> outputs,
  }) async {
    // Simplified transaction building
    // In production, implement proper Bitcoin transaction format
    
    final tx = {
      'version': 1,
      'inputs': utxos.map((utxo) => {
        'txid': utxo['txid'],
        'vout': utxo['vout'],
        'script_sig': await _createScriptSig(utxo),
      }).toList(),
      'outputs': outputs.map((output) => {
        'address': output['address'],
        'amount': output['amount'],
        'script_pubkey': _createScriptPubKey(output['address'] as String),
      }).toList(),
      'locktime': 0,
    };
    
    // Serialize transaction to hex
    return _serializeTransaction(tx);
  }
  
  Future<String> _createScriptSig(Map<String, dynamic> utxo) async {
    // Create signature script for spending UTXO
    // This is a placeholder - implement proper signing
    final address = utxo['address'] as String;
    final privateKey = _addressToPrivateKey[address];
    
    if (privateKey == null) {
      throw Exception('Private key not found for address $address');
    }
    
    // Simplified signature creation
    return 'signature_placeholder_$privateKey';
  }
  
  String _createScriptPubKey(String address) {
    // Create output script for address
    // Simplified implementation
    return 'OP_DUP OP_HASH160 ${address.substring(3)} OP_EQUALVERIFY OP_CHECKSIG';
  }
  
  String _serializeTransaction(Map<String, dynamic> tx) {
    // Serialize transaction to hex string
    // This is a placeholder - implement proper Bitcoin transaction serialization
    final txJson = jsonEncode(tx);
    final txBytes = utf8.encode(txJson);
    return txBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
  
  Map<String, dynamic> _parseTransactionData(String txData) {
    // Parse stored transaction data
    try {
      return jsonDecode(txData);
    } catch (e) {
      return {};
    }
  }
  
  Future<double> _calculateBalanceChange(Map<String, dynamic> tx) async {
    double change = 0.0;
    
    // Calculate received amount
    final vouts = tx['vout'] as List? ?? [];
    for (final vout in vouts) {
      if (vout is Map<String, dynamic>) {
        final scriptPubKey = vout['scriptPubKey'] as Map<String, dynamic>? ?? {};
        final addresses = scriptPubKey['addresses'] as List? ?? [];
        final value = vout['value'] as double? ?? 0.0;
        
        for (final address in addresses) {
          if (await _isOurAddress(address as String)) {
            change += value;
          }
        }
      }
    }
    
    // Calculate sent amount (simplified)
    final vins = tx['vin'] as List? ?? [];
    for (final vin in vins) {
      if (vin is Map<String, dynamic>) {
        // Would need to look up previous transaction to get sent amount
        // Simplified for now
      }
    }
    
    return change;
  }
  
  Future<void> _loadWalletState() async {
    // Load wallet state from storage
    // This would typically load from secure storage
  }
  
  Future<void> _saveWalletState() async {
    // Save wallet state to storage
    // This would typically save to secure storage
  }
}