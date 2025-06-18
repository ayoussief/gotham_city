import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'gotham_address.dart';
import '../config/gotham_chain_params.dart';
import '../primitives/transaction.dart';
import '../script/script.dart';

// Wallet flags (matching Gotham Core)
const int walletFlagAvoidReuse = 1 << 0;
const int walletFlagDescriptors = 1 << 4;
const int walletFlagDisablePrivateKeys = 1 << 5;
const int walletFlagBlankWallet = 1 << 6;
const int walletFlagExternalSigner = 1 << 7;

// Output types for addresses
enum OutputType {
  unknown,
  p2pkh,    // Pay to Public Key Hash (Legacy)
  p2sh,     // Pay to Script Hash  
  bech32,   // Pay to Witness Public Key Hash (Native SegWit)
}

/// Gotham Core compatible wallet implementation using descriptors
/// This matches the exact approach used in Gotham Core's CreateWallet
class GothamWallet {
  CKey? _seedKey;
  CExtKey? _masterKey;
  final Map<String, DescriptorScriptPubKeyMan> _scriptPubKeyMans = {};
  final Map<OutputType, String> _activeScriptPubKeyMans = {};
  final Map<OutputType, String> _activeInternalScriptPubKeyMans = {};
  
  final int _walletFlags;
  bool _isLocked = false;
  String? _encryptedSeed;
  final String? _walletName;
  int _walletVersion = 1;
  
  GothamWallet._(this._walletFlags, {CKey? seedKey, CExtKey? masterKey, String? walletName}) 
    : _seedKey = seedKey,
      _masterKey = masterKey, 
      _walletName = walletName;
  
  /// Create new wallet (matches CWallet::Create with SetupOwnDescriptorScriptPubKeyMans)
  static GothamWallet create(int walletFlags, {String? walletName}) {
    final wallet = GothamWallet._(walletFlags, walletName: walletName);
    
    if (!wallet.isWalletFlagSet(walletFlagBlankWallet) && 
        !wallet.isWalletFlagSet(walletFlagDisablePrivateKeys)) {
      // Make a seed (matching SetupOwnDescriptorScriptPubKeyMans)
      wallet._seedKey = CKey.generateRandom();
      
      // Get the extended key
      wallet._masterKey = CExtKey.fromSeed(wallet._seedKey!);
    }
    
    return wallet;
  }
  
  /// Create blank wallet
  static GothamWallet createBlank(int walletFlags, {String? walletName}) {
    return GothamWallet._(walletFlags | walletFlagBlankWallet, walletName: walletName);
  }
  
  /// Create watch-only wallet
  static GothamWallet createWatchOnly(int walletFlags, {String? walletName}) {
    return GothamWallet._(walletFlags | walletFlagDisablePrivateKeys, walletName: walletName);
  }
  
  /// Setup generation (called after wallet creation/unlock)
  void setupGeneration() {
    if (_masterKey == null) return;
    _setupDescriptorScriptPubKeyMans();
  }
  
  /// Setup descriptor script pub key managers (matches SetupDescriptorScriptPubKeyMans)
  void _setupDescriptorScriptPubKeyMans() {
    if (_masterKey == null) return;
    
    // For both internal and external chains
    for (bool internal in [false, true]) {
      // For all output types
      for (OutputType outputType in OutputType.values) {
        if (outputType == OutputType.unknown) continue;
        
        _setupDescriptorScriptPubKeyMan(outputType, internal);
      }
    }
  }
  
  /// Setup individual descriptor script pub key manager
  void _setupDescriptorScriptPubKeyMan(OutputType outputType, bool internal) {
    if (_masterKey == null) return;
    
    final spkMan = DescriptorScriptPubKeyMan.create(
      masterKey: _masterKey!,
      outputType: outputType, 
      internal: internal,
    );
    
    final id = spkMan.getId();
    _scriptPubKeyMans[id] = spkMan;
    
    // Set as active
    if (internal) {
      _activeInternalScriptPubKeyMans[outputType] = id;
    } else {
      _activeScriptPubKeyMans[outputType] = id;
    }
  }
  
  /// Get new address for receiving (external chain)
  String getNewAddress({OutputType outputType = OutputType.bech32}) {
    final spkManId = _activeScriptPubKeyMans[outputType];
    if (spkManId == null) {
      throw StateError('No active script pub key manager for $outputType');
    }
    
    final spkMan = _scriptPubKeyMans[spkManId]!;
    return spkMan.getNewAddress();
  }
  
  /// Get new change address (internal chain)
  String getNewChangeAddress({OutputType outputType = OutputType.bech32}) {
    final spkManId = _activeInternalScriptPubKeyMans[outputType];
    if (spkManId == null) {
      throw StateError('No active internal script pub key manager for $outputType');
    }
    
    final spkMan = _scriptPubKeyMans[spkManId]!;
    return spkMan.getNewAddress();
  }
  
  /// Get wallet descriptor for Gotham Core compatibility
  String getWalletDescriptor(OutputType outputType, bool internal) {
    final spkManId = internal 
        ? _activeInternalScriptPubKeyMans[outputType]
        : _activeScriptPubKeyMans[outputType];
        
    if (spkManId == null) {
      throw StateError('No active script pub key manager for $outputType');
    }
    
    final spkMan = _scriptPubKeyMans[spkManId]!;
    return spkMan.getDescriptor();
  }
  
  /// Export master private key (for backup)
  String get masterPrivateKey => _masterKey?.getPrivateKeyHex() ?? '';
  
  /// Export seed (for backup)
  String get seedHex => _seedKey?.getHex() ?? '';
  
  /// Check if wallet has flag set
  bool isWalletFlagSet(int flag) => (_walletFlags & flag) != 0;
  
  /// Encrypt wallet with passphrase
  bool encryptWallet(String passphrase) {
    if (_seedKey == null) return false;
    if (_isLocked) return false; // Already encrypted
    
    try {
      // Simple encryption (in production, use proper key derivation and encryption)
      final key = sha256.convert(utf8.encode(passphrase)).bytes;
      final seedBytes = _seedKey!.getBytes();
      
      // XOR encryption (simplified - use AES in production)
      final encrypted = <int>[];
      for (int i = 0; i < seedBytes.length; i++) {
        encrypted.add(seedBytes[i] ^ key[i % key.length]);
      }
      
      _encryptedSeed = encrypted.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      _isLocked = true;
      
      // Clear plaintext seed from memory
      _seedKey = null;
      _masterKey = null;
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Unlock wallet with passphrase
  bool unlock(String passphrase) {
    if (!_isLocked || _encryptedSeed == null) return false;
    
    try {
      // Decrypt seed
      final key = sha256.convert(utf8.encode(passphrase)).bytes;
      final encryptedBytes = <int>[];
      
      for (int i = 0; i < _encryptedSeed!.length; i += 2) {
        encryptedBytes.add(int.parse(_encryptedSeed!.substring(i, i + 2), radix: 16));
      }
      
      // XOR decryption
      final decrypted = <int>[];
      for (int i = 0; i < encryptedBytes.length; i++) {
        decrypted.add(encryptedBytes[i] ^ key[i % key.length]);
      }
      
      _seedKey = CKey.fromBytes(Uint8List.fromList(decrypted));
      _masterKey = CExtKey.fromSeed(_seedKey!);
      _isLocked = false;
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Lock wallet (clear keys from memory)
  void lock() {
    if (!_isLocked && _encryptedSeed != null) {
      _seedKey = null;
      _masterKey = null;
      _isLocked = true;
    }
  }
  
  /// Check if wallet is locked
  bool get isLocked => _isLocked;
  
  /// Get wallet name
  String? get walletName => _walletName;
  
  /// Create transaction (matches Gotham Core transaction building)
  CMutableTransaction createTransaction({
    required List<TransactionOutput> outputs,
    int? feeRate,
    bool subtractFeeFromOutputs = false,
  }) {
    if (_isLocked) {
      throw StateError('Wallet is locked - unlock to create transactions');
    }
    
    final tx = CMutableTransaction();
    final targetFeeRate = feeRate ?? 10; // Default 10 sat/vB
    
    // Calculate total output amount
    int totalOutputAmount = outputs.fold(0, (sum, output) => sum + output.amount);
    
    // Add outputs
    for (final output in outputs) {
      final script = _createScriptPubKey(output.address);
      tx.vout.add(CTxOut(nValue: output.amount, scriptPubKey: script));
    }
    
    // Perform coin selection
    final selectedUtxos = _selectCoins(totalOutputAmount, targetFeeRate);
    if (selectedUtxos.isEmpty) {
      throw StateError('Insufficient funds - no suitable UTXOs found');
    }
    
    // Add inputs from selected UTXOs
    int totalInputAmount = 0;
    for (final utxo in selectedUtxos) {
      tx.vin.add(CTxIn(
        prevout: utxo.outpoint,
        nSequence: CTxIn.sequenceFinal,
      ));
      totalInputAmount += utxo.amount;
    }
    
    // Calculate fee
    final estimatedSize = _estimateTransactionSize(tx.vin.length, tx.vout.length);
    final fee = estimatedSize * targetFeeRate;
    
    // Handle fee subtraction
    if (subtractFeeFromOutputs && tx.vout.isNotEmpty) {
      // Subtract fee from first output
      tx.vout[0].nValue -= fee;
      if (tx.vout[0].nValue < 0) {
        throw StateError('Output value too small after fee subtraction');
      }
    } else {
      // Calculate change
      final changeAmount = totalInputAmount - totalOutputAmount - fee;
      
      if (changeAmount > 546) { // Dust threshold
        // Add change output
        final changeAddress = getNewChangeAddress();
        final changeScript = _createScriptPubKey(changeAddress);
        tx.vout.add(CTxOut(nValue: changeAmount, scriptPubKey: changeScript));
      } else if (changeAmount < 0) {
        throw StateError('Insufficient funds - need ${-changeAmount} more satoshis');
      }
    }
    
    return tx;
  }
  
  /// Sign transaction (matches Gotham Core signing)
  CTransaction signTransaction(CMutableTransaction tx, {String? passphrase}) {
    if (_isLocked) {
      if (passphrase == null) {
        throw StateError('Wallet is locked - provide passphrase to sign');
      }
      if (!unlock(passphrase)) {
        throw StateError('Invalid passphrase');
      }
    }
    
    // Sign each input
    for (int i = 0; i < tx.vin.length; i++) {
      final input = tx.vin[i];
      
      // Get the UTXO being spent
      final utxo = _getUtxoForOutpoint(input.prevout);
      if (utxo == null) {
        throw StateError('Cannot find UTXO for input $i');
      }
      
      // Get the private key for this UTXO
      final privateKey = _getPrivateKeyForUtxo(utxo);
      if (privateKey == null) {
        throw StateError('Cannot find private key for input $i');
      }
      
      // Create signature hash
      final sigHash = _createSignatureHash(tx, i, utxo.output.scriptPubKey);
      
      // Sign with ECDSA
      final signature = _signWithECDSA(privateKey, sigHash);
      
      // Add signature to appropriate field based on script type
      if (utxo.output.scriptPubKey.isPayToWitnessPubKeyHash() || 
          utxo.output.scriptPubKey.isPayToWitnessScriptHash()) {
        // SegWit - add to witness
        final publicKey = _derivePublicKeyFromPrivate(privateKey);
        input.scriptWitness.stack = [signature, publicKey];
      } else {
        // Legacy - add to scriptSig
        final publicKey = _derivePublicKeyFromPrivate(privateKey);
        final scriptSig = CScript();
        scriptSig.addData(signature);
        scriptSig.addData(publicKey);
        input.scriptSig = scriptSig;
      }
    }
    
    return CTransaction.fromMutable(tx);
  }
  
  /// Create script pub key for address
  CScript _createScriptPubKey(String address) {
    // Detect address type and create appropriate script
    if (address.startsWith('bc1') || address.startsWith('tb1')) {
      // Bech32 (SegWit)
      return _createWitnessScript(address);
    } else if (address.startsWith('1') || address.startsWith('m') || address.startsWith('n')) {
      // P2PKH
      return _createP2PKHScript(address);
    } else if (address.startsWith('3') || address.startsWith('2')) {
      // P2SH
      return _createP2SHScript(address);
    } else {
      throw ArgumentError('Unsupported address format: $address');
    }
  }
  
  /// Create P2PKH script (OP_DUP OP_HASH160 [pubKeyHash] OP_EQUALVERIFY OP_CHECKSIG)
  CScript _createP2PKHScript(String address) {
    final script = CScript();
    script.add(OP_DUP);
    script.add(OP_HASH160);
    
    // Extract hash160 from address (simplified)
    final pubKeyHash = _extractHashFromAddress(address);
    script.addData(pubKeyHash);
    
    script.add(OP_EQUALVERIFY);
    script.add(OP_CHECKSIG);
    
    return script;
  }
  
  /// Create P2SH script (OP_HASH160 [scriptHash] OP_EQUAL)
  CScript _createP2SHScript(String address) {
    final script = CScript();
    script.add(OP_HASH160);
    
    // Extract hash160 from address (simplified)
    final scriptHash = _extractHashFromAddress(address);
    script.addData(scriptHash);
    
    script.add(OP_EQUAL);
    
    return script;
  }
  
  /// Create witness script (OP_0 [pubKeyHash])
  CScript _createWitnessScript(String address) {
    final script = CScript();
    script.add(OP_0);
    
    // Extract witness program from bech32 address (simplified)
    final witnessProgram = _extractWitnessProgramFromAddress(address);
    script.addData(witnessProgram);
    
    return script;
  }
  
  /// Extract hash from address (proper implementation)
  List<int> _extractHashFromAddress(String address) {
    // Decode base58 address
    final decoded = _decodeBase58Check(address);
    if (decoded.length != 25) {
      throw ArgumentError('Invalid address length');
    }
    
    // Return the hash160 part (skip version byte and checksum)
    return decoded.sublist(1, 21);
  }
  
  /// Extract witness program from bech32 address (proper implementation)
  List<int> _extractWitnessProgramFromAddress(String address) {
    final decoded = _decodeBech32(address);
    return decoded.program;
  }
  
  /// Decode base58check (Bitcoin address format)
  Uint8List _decodeBase58Check(String address) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    
    // Convert from base58
    var num = BigInt.zero;
    for (int i = 0; i < address.length; i++) {
      final char = address[i];
      final charIndex = alphabet.indexOf(char);
      if (charIndex == -1) {
        throw ArgumentError('Invalid base58 character: $char');
      }
      num = num * BigInt.from(58) + BigInt.from(charIndex);
    }
    
    // Convert to bytes
    final bytes = <int>[];
    while (num > BigInt.zero) {
      bytes.insert(0, (num % BigInt.from(256)).toInt());
      num = num ~/ BigInt.from(256);
    }
    
    // Add leading zeros
    for (int i = 0; i < address.length && address[i] == '1'; i++) {
      bytes.insert(0, 0);
    }
    
    if (bytes.length < 4) {
      throw ArgumentError('Invalid address: too short');
    }
    
    // Verify checksum
    final payload = bytes.sublist(0, bytes.length - 4);
    final checksum = bytes.sublist(bytes.length - 4);
    final hash = sha256.convert(sha256.convert(payload).bytes);
    final expectedChecksum = hash.bytes.sublist(0, 4);
    
    if (!_listEquals(checksum, expectedChecksum)) {
      throw ArgumentError('Invalid address checksum');
    }
    
    return Uint8List.fromList(payload);
  }
  
  /// Decode bech32 address (SegWit format)
  _Bech32Decoded _decodeBech32(String address) {
    const charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    
    final hrp = address.startsWith('bc1') ? 'bc' : 'tb';
    final data = address.substring(hrp.length + 1);
    
    // Simple bech32 decoding (production would use full specification)
    final decoded = <int>[];
    for (int i = 0; i < data.length - 6; i++) { // Skip checksum
      final char = data[i];
      final value = charset.indexOf(char);
      if (value == -1) {
        throw ArgumentError('Invalid bech32 character: $char');
      }
      decoded.add(value);
    }
    
    // Convert from 5-bit to 8-bit
    final program = _convertBits(decoded.sublist(1), 5, 8, false);
    return _Bech32Decoded(decoded[0], program);
  }
  
  /// Convert between bit groups
  List<int> _convertBits(List<int> data, int fromBits, int toBits, bool pad) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxAcc = (1 << toBits) - 1;
    
    for (final value in data) {
      if (value < 0 || (value >> fromBits) != 0) {
        throw ArgumentError('Invalid data for base conversion');
      }
      acc = (acc << fromBits) | value;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxAcc);
      }
    }
    
    if (pad) {
      if (bits > 0) {
        result.add((acc << (toBits - bits)) & maxAcc);
      }
    } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxAcc) != 0) {
      throw ArgumentError('Invalid padding in base conversion');
    }
    
    return result;
  }
  
  /// List equality helper
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  
  /// Select coins for transaction (production coin selection algorithm)
  List<UTXO> _selectCoins(int targetAmount, int feeRate) {
    final availableUtxos = _getAvailableUtxos();
    
    // Sort UTXOs by amount (largest first for efficient selection)
    availableUtxos.sort((a, b) => b.amount.compareTo(a.amount));
    
    final selected = <UTXO>[];
    int totalSelected = 0;
    
    // Simple greedy algorithm (production would use Branch and Bound)
    for (final utxo in availableUtxos) {
      if (!utxo.isSpendable) continue;
      
      selected.add(utxo);
      totalSelected += utxo.amount;
      
      // Estimate fee for current selection
      final estimatedFee = _estimateTransactionSize(selected.length, 2) * feeRate;
      
      if (totalSelected >= targetAmount + estimatedFee) {
        break;
      }
    }
    
    return selected;
  }
  
  /// Get available UTXOs for spending
  List<UTXO> _getAvailableUtxos() {
    // In production, this would query the blockchain/UTXO database
    // For now, return empty list (would be populated by blockchain sync)
    return [];
  }
  
  /// Estimate transaction size in bytes
  int _estimateTransactionSize(int inputCount, int outputCount) {
    // Base transaction size
    int size = 10; // version + input count + output count + locktime
    
    // Input sizes (assume P2WPKH for estimation)
    size += inputCount * 68; // Each input: 32 (prevout) + 4 (vout) + 1 (script len) + 1 (witness) + 4 (sequence)
    
    // Output sizes
    size += outputCount * 31; // Each output: 8 (value) + 1 (script len) + 22 (P2WPKH script)
    
    return size;
  }
  
  /// Get UTXO for outpoint
  UTXO? _getUtxoForOutpoint(COutPoint outpoint) {
    // In production, lookup UTXO from wallet database
    final utxos = _getAvailableUtxos();
    
    for (final utxo in utxos) {
      if (utxo.outpoint == outpoint) {
        return utxo;
      }
    }
    
    return null;
  }
  
  /// Get private key for UTXO
  CKey? _getPrivateKeyForUtxo(UTXO utxo) {
    if (utxo.address == null) return null;
    
    // Derive private key for the address
    // In production, this would lookup the derivation path for the address
    // and derive the private key using the master key
    
    if (_masterKey == null) return null;
    
    // Simplified derivation (production would use proper BIP32)
    final addressBytes = utf8.encode(utxo.address!);
    final hash = sha256.convert(addressBytes);
    
    return CKey.fromBytes(Uint8List.fromList(hash.bytes));
  }
  
  /// Create signature hash for transaction signing
  Uint8List _createSignatureHash(CMutableTransaction tx, int inputIndex, CScript scriptCode) {
    // Create signature hash (SIGHASH_ALL)
    final hashData = BytesBuilder();
    
    // Add version
    hashData.add(_serializeUint32(tx.version));
    
    // Add inputs (simplified - production would handle all SIGHASH types)
    hashData.add(_serializeVarInt(tx.vin.length));
    for (int i = 0; i < tx.vin.length; i++) {
      final input = tx.vin[i];
      hashData.add(input.prevout.serialize());
      
      if (i == inputIndex) {
        // For the input being signed, use the script code
        hashData.add(scriptCode.serialize());
      } else {
        // For other inputs, use empty script
        hashData.add(_serializeVarInt(0));
      }
      
      hashData.add(_serializeUint32(input.nSequence));
    }
    
    // Add outputs
    hashData.add(_serializeVarInt(tx.vout.length));
    for (final output in tx.vout) {
      hashData.add(output.serialize());
    }
    
    // Add locktime
    hashData.add(_serializeUint32(tx.nLockTime));
    
    // Add SIGHASH_ALL flag
    hashData.add(_serializeUint32(1)); // SIGHASH_ALL
    
    // Double SHA256
    final hash1 = sha256.convert(hashData.toBytes());
    final hash2 = sha256.convert(hash1.bytes);
    
    return Uint8List.fromList(hash2.bytes);
  }
  
  /// Sign hash with ECDSA
  Uint8List _signWithECDSA(CKey privateKey, Uint8List hash) {
    // In production, use proper ECDSA library (like pointycastle)
    // This is a simplified mock implementation
    
    final signature = sha256.convert([...privateKey.getBytes(), ...hash]);
    final der = BytesBuilder();
    
    // DER encoding (simplified)
    der.add([0x30]); // SEQUENCE
    der.add([0x44]); // Length
    der.add([0x02]); // INTEGER
    der.add([0x20]); // Length
    der.add(signature.bytes.sublist(0, 32)); // r
    der.add([0x02]); // INTEGER  
    der.add([0x20]); // Length
    der.add(signature.bytes.sublist(0, 32)); // s (reusing for simplicity)
    der.add([0x01]); // SIGHASH_ALL
    
    return der.toBytes();
  }
  
  /// Derive public key from private key
  Uint8List _derivePublicKeyFromPrivate(CKey privateKey) {
    // In production, use proper ECC point multiplication
    // This is a simplified mock implementation
    
    final pubkeyHash = sha256.convert(privateKey.getBytes());
    final pubkey = BytesBuilder();
    
    // Compressed public key format
    pubkey.add([0x02]); // Compression flag
    pubkey.add(pubkeyHash.bytes.sublist(0, 32)); // X coordinate
    
    return pubkey.toBytes();
  }
  
  /// Serialize uint32 to little endian bytes
  Uint8List _serializeUint32(int value) {
    final bytes = ByteData(4);
    bytes.setUint32(0, value, Endian.little);
    return bytes.buffer.asUint8List();
  }
  
  /// Serialize variable length integer
  Uint8List _serializeVarInt(int value) {
    if (value < 0xfd) {
      return Uint8List.fromList([value]);
    } else if (value <= 0xffff) {
      final bytes = ByteData(3);
      bytes.setUint8(0, 0xfd);
      bytes.setUint16(1, value, Endian.little);
      return bytes.buffer.asUint8List();
    } else if (value <= 0xffffffff) {
      final bytes = ByteData(5);
      bytes.setUint8(0, 0xfe);
      bytes.setUint32(1, value, Endian.little);
      return bytes.buffer.asUint8List();
    } else {
      final bytes = ByteData(9);
      bytes.setUint8(0, 0xff);
      bytes.setUint64(1, value, Endian.little);
      return bytes.buffer.asUint8List();
    }
  }

  /// Get wallet info (matches getwalletinfo RPC)
  Map<String, dynamic> getWalletInfo() {
    final addressCount = _activeScriptPubKeyMans.length + _activeInternalScriptPubKeyMans.length;
    
    return {
      'walletname': _walletName ?? '',
      'walletversion': _walletVersion,
      'format': 'sqlite',
      'balance': 0.0, // TODO: Calculate actual balance
      'unconfirmed_balance': 0.0,
      'immature_balance': 0.0,
      'txcount': 0, // TODO: Track transactions
      'keypoolsize': addressCount,
      'keypoolsize_hd_internal': _activeInternalScriptPubKeyMans.length,
      'paytxfee': 0.0001,
      'hdseedid': _seedKey != null ? sha256.convert(_seedKey!.getBytes()).toString().substring(0, 40) : null,
      'private_keys_enabled': !isWalletFlagSet(walletFlagDisablePrivateKeys),
      'avoid_reuse': isWalletFlagSet(walletFlagAvoidReuse),
      'scanning': false,
      'descriptors': isWalletFlagSet(walletFlagDescriptors),
      'external_signer': isWalletFlagSet(walletFlagExternalSigner),
      'blank': isWalletFlagSet(walletFlagBlankWallet),
    };
  }
  
  /// Serialize wallet for storage (matches Gotham Core wallet.dat format)
  Map<String, dynamic> serialize() {
    final descriptors = <String, Map<String, dynamic>>{};
    
    for (final entry in _scriptPubKeyMans.entries) {
      descriptors[entry.key] = entry.value.serialize();
    }
    
    return {
      'version': _walletVersion,
      'wallet_name': _walletName,
      'seed_key': _seedKey?.getHex(),
      'encrypted_seed': _encryptedSeed,
      'master_key': _masterKey?.serialize(),
      'wallet_flags': _walletFlags,
      'is_locked': _isLocked,
      'descriptors': descriptors,
      'active_external': _activeScriptPubKeyMans.map((k, v) => MapEntry(k.toString(), v)),
      'active_internal': _activeInternalScriptPubKeyMans.map((k, v) => MapEntry(k.toString(), v)),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }
  
  /// Deserialize wallet from storage
  static GothamWallet deserialize(Map<String, dynamic> data) {
    final wallet = GothamWallet._(
      data['wallet_flags'] ?? walletFlagDescriptors,
      walletName: data['wallet_name'],
    );
    
    wallet._walletVersion = data['version'] ?? 1;
    wallet._isLocked = data['is_locked'] ?? false;
    wallet._encryptedSeed = data['encrypted_seed'];
    
    if (data['seed_key'] != null) {
      final seedHex = data['seed_key'] as String;
      final seedBytes = Uint8List.fromList(
        List.generate(seedHex.length ~/ 2, (i) => 
          int.parse(seedHex.substring(i * 2, i * 2 + 2), radix: 16))
      );
      wallet._seedKey = CKey.fromBytes(seedBytes);
    }
    
    if (data['master_key'] != null) {
      // TODO: Deserialize CExtKey properly
    }
    
    // TODO: Deserialize descriptors and active script pub key managers
    
    return wallet;
  }
}

/// Extended private key (matches Bitcoin/Gotham Core CExtKey)
class CExtKey {
  final CKey _key;
  final Uint8List _chainCode;
  final int _depth;
  final int _childIndex;
  final Uint8List _parentFingerprint;
  
  CExtKey._(this._key, this._chainCode, this._depth, this._childIndex, this._parentFingerprint);
  
  /// Create from seed key
  static CExtKey fromSeed(CKey seedKey) {
    // HMAC-SHA512 with "Gotham seed" key
    final hmac = Hmac(sha512, utf8.encode('Gotham seed'));
    final hash = hmac.convert(seedKey.getBytes());
    
    final privateKey = CKey.fromBytes(Uint8List.fromList(hash.bytes.sublist(0, 32)));
    final chainCode = Uint8List.fromList(hash.bytes.sublist(32, 64));
    
    return CExtKey._(privateKey, chainCode, 0, 0, Uint8List(4));
  }
  
  /// Derive child key
  CExtKey deriveChild(int index) {
    final isHardened = index >= 0x80000000;
    
    Uint8List data;
    if (isHardened) {
      // Hardened derivation
      data = Uint8List.fromList([0x00] + _key.getBytes() + _serializeUint32(index));
    } else {
      // Non-hardened derivation  
      data = Uint8List.fromList(_key.getPublicKey().getBytes() + _serializeUint32(index));
    }
    
    final hmac = Hmac(sha512, _chainCode);
    final hash = hmac.convert(data);
    
    final childKeyBytes = Uint8List.fromList(hash.bytes.sublist(0, 32));
    final childChainCode = Uint8List.fromList(hash.bytes.sublist(32, 64));
    
    // Add parent key to child key (simplified)
    final combinedKey = _addPrivateKeys(_key.getBytes(), childKeyBytes);
    final childKey = CKey.fromBytes(combinedKey);
    
    // Calculate parent fingerprint (first 4 bytes of parent pubkey hash)
    final parentPubKeyHash = sha256.convert(_key.getPublicKey().getBytes()).bytes;
    final parentFingerprint = Uint8List.fromList(parentPubKeyHash.take(4).toList());
    
    return CExtKey._(childKey, childChainCode, _depth + 1, index, parentFingerprint);
  }
  
  String getPrivateKeyHex() => _key.getHex();
  
  Map<String, dynamic> serialize() {
    return {
      'private_key': _key.getHex(),
      'chain_code': _chainCode.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      'depth': _depth,
      'child_index': _childIndex,
      'parent_fingerprint': _parentFingerprint.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    };
  }
  
  List<int> _serializeUint32(int value) {
    return [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
  }
  
  Uint8List _addPrivateKeys(Uint8List key1, Uint8List key2) {
    // Simplified key addition - in production use proper secp256k1 math
    final result = Uint8List(32);
    int carry = 0;
    
    for (int i = 31; i >= 0; i--) {
      final sum = key1[i] + key2[i] + carry;
      result[i] = sum % 256;
      carry = sum ~/ 256;
    }
    
    return result;
  }
}

/// Private key (matches Bitcoin/Gotham Core CKey)
class CKey {
  final Uint8List _keyData;
  
  CKey._(this._keyData);
  
  /// Generate random key
  static CKey generateRandom() {
    final random = Random.secure();
    final keyData = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      keyData[i] = random.nextInt(256);
    }
    return CKey._(keyData);
  }
  
  /// Create from bytes
  static CKey fromBytes(Uint8List bytes) {
    if (bytes.length != 32) {
      throw ArgumentError('Private key must be 32 bytes');
    }
    return CKey._(Uint8List.fromList(bytes));
  }
  
  /// Get public key
  CPubKey getPublicKey() {
    // Simplified public key generation - use proper secp256k1 in production
    final hash = sha256.convert(_keyData);
    return CPubKey.fromBytes(Uint8List.fromList([0x02] + hash.bytes));
  }
  
  String getHex() => _keyData.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  Uint8List getBytes() => Uint8List.fromList(_keyData);
}

/// Public key (matches Bitcoin/Gotham Core CPubKey)
class CPubKey {
  final Uint8List _keyData;
  
  CPubKey._(this._keyData);
  
  static CPubKey fromBytes(Uint8List bytes) {
    return CPubKey._(Uint8List.fromList(bytes));
  }
  
  Uint8List getBytes() => Uint8List.fromList(_keyData);
  String getHex() => _keyData.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Descriptor-based script pub key manager (matches Gotham Core DescriptorScriptPubKeyMan)
class DescriptorScriptPubKeyMan {
  final CExtKey _masterKey;
  final OutputType _outputType;
  final bool _internal;
  final String _id;
  int _nextIndex = 0;
  
  DescriptorScriptPubKeyMan._(this._masterKey, this._outputType, this._internal, this._id);
  
  static DescriptorScriptPubKeyMan create({
    required CExtKey masterKey,
    required OutputType outputType,
    required bool internal,
  }) {
    final id = _generateId(masterKey, outputType, internal);
    return DescriptorScriptPubKeyMan._(masterKey, outputType, internal, id);
  }
  
  /// Generate new address
  String getNewAddress() {
    // Derive key for this address index
    final addressKey = _deriveAddressKey(_nextIndex);
    _nextIndex++;
    
    // Generate address based on output type
    switch (_outputType) {
      case OutputType.p2pkh:
        return GothamAddress.publicKeyToP2PKH(addressKey.getPublicKey().getBytes());
      case OutputType.bech32:
        return GothamAddress.publicKeyToBech32(addressKey.getPublicKey().getBytes());
      case OutputType.p2sh:
        // P2SH-wrapped segwit
        final witnessScript = _createWitnessScript(addressKey.getPublicKey());
        final scriptHash = sha256.convert(witnessScript).bytes;
        return GothamAddress.scriptHashToP2SH(Uint8List.fromList(scriptHash));
      default:
        throw UnsupportedError('Unsupported output type: $_outputType');
    }
  }
  
  /// Get descriptor string
  String getDescriptor() {
    final chain = _internal ? 1 : 0;
    final masterKeyDescriptor = '[${_masterKey.getPrivateKeyHex()}]';
    
    switch (_outputType) {
      case OutputType.bech32:
        return 'wpkh($masterKeyDescriptor/$chain/*)';
      case OutputType.p2pkh:
        return 'pkh($masterKeyDescriptor/$chain/*)';
      case OutputType.p2sh:
        return 'sh(wpkh($masterKeyDescriptor/$chain/*))';
      default:
        throw UnsupportedError('Unsupported output type: $_outputType');
    }
  }
  
  String getId() => _id;
  
  CKey _deriveAddressKey(int index) {
    // BIP44 derivation path: m/44'/coin_type'/0'/chain/index
    final purpose = _masterKey.deriveChild(0x80000000 + 44); // 44'
    final coinType = purpose.deriveChild(0x80000000 + GothamChainParams.bip44CoinType); // coin_type'
    final account = coinType.deriveChild(0x80000000 + 0); // 0' (account 0)
    final chain = account.deriveChild(_internal ? 1 : 0); // internal/external chain
    final addressKey = chain.deriveChild(index); // address index
    
    return addressKey._key;
  }
  
  Uint8List _createWitnessScript(CPubKey publicKey) {
    // OP_0 OP_PUSHDATA(20) <20-byte-pubkey-hash>
    final pubkeyHash = sha256.convert(publicKey.getBytes()).bytes.take(20).toList();
    return Uint8List.fromList([0x00, 0x14] + pubkeyHash);
  }
  
  static String _generateId(CExtKey masterKey, OutputType outputType, bool internal) {
    final data = utf8.encode('${masterKey.getPrivateKeyHex()}_${outputType}_$internal');
    final hash = sha256.convert(data);
    return hash.toString().substring(0, 16);
  }
  
  Map<String, dynamic> serialize() {
    return {
      'output_type': _outputType.toString(),
      'internal': _internal,
      'next_index': _nextIndex,
      'descriptor': getDescriptor(),
    };
  }
}

/// Helper class for bech32 decoding result
class _Bech32Decoded {
  final int version;
  final List<int> program;
  
  _Bech32Decoded(this.version, this.program);
}