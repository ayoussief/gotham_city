import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'bip39.dart';
import 'gotham_address.dart';
import '../config/gotham_chain_params.dart';

/// BIP32 Hierarchical Deterministic Wallet implementation for Gotham
class HDWallet {
  final String _mnemonic;
  final Uint8List _masterKey;
  final Uint8List _masterChainCode;
  
  HDWallet._(this._mnemonic, this._masterKey, this._masterChainCode);
  
  /// Create HD wallet from mnemonic
  static HDWallet fromMnemonic(String mnemonic, {String passphrase = ''}) {
    if (!BIP39.validateMnemonic(mnemonic)) {
      throw ArgumentError('Invalid mnemonic phrase');
    }
    
    final seed = BIP39.mnemonicToSeed(mnemonic, passphrase: passphrase);
    
    // Generate master key using HMAC-SHA512 with "Gotham seed"
    final hmac = Hmac(sha512, utf8.encode('Gotham seed'));
    final hash = hmac.convert(seed);
    
    final masterKey = Uint8List.fromList(hash.bytes.sublist(0, 32));
    final masterChainCode = Uint8List.fromList(hash.bytes.sublist(32, 64));
    
    return HDWallet._(mnemonic, masterKey, masterChainCode);
  }
  
  /// Generate new HD wallet with random mnemonic
  static HDWallet generate({int strength = 128}) {
    final mnemonic = BIP39.generateMnemonic(strength: strength);
    return fromMnemonic(mnemonic);
  }
  
  /// Get the mnemonic phrase
  String get mnemonic => _mnemonic;
  
  /// Get master private key
  Uint8List get masterPrivateKey => Uint8List.fromList(_masterKey);
  
  /// Get master chain code
  Uint8List get masterChainCode => Uint8List.fromList(_masterChainCode);
  
  /// Derive a child key using BIP32 derivation
  HDWalletNode deriveChild(List<int> path) {
    var key = _masterKey;
    var chainCode = _masterChainCode;
    var currentPath = <int>[];
    
    for (final index in path) {
      final result = _deriveChildKey(key, chainCode, index);
      key = result.key;
      chainCode = result.chainCode;
      currentPath.add(index);
    }
    
    return HDWalletNode(key, chainCode, currentPath);
  }
  
  /// Derive account key (BIP44: m/44'/coin_type'/account')
  HDWalletNode deriveAccount(int account) {
    final path = [
      0x80000000 + 44,  // purpose: 44' (BIP44)
      0x80000000 + GothamChainParams.bip44CoinType, // coin_type: Gotham's registered coin type
      0x80000000 + account, // account: account'
    ];
    return deriveChild(path);
  }
  
  /// Derive receiving address key (BIP44: m/44'/coin_type'/account'/0/address_index)
  HDWalletNode deriveReceivingAddress(int account, int addressIndex) {
    final path = [
      0x80000000 + 44,  // purpose: 44'
      0x80000000 + GothamChainParams.bip44CoinType, // coin_type'
      0x80000000 + account, // account'
      0, // external chain (receiving)
      addressIndex, // address index
    ];
    return deriveChild(path);
  }
  
  /// Derive change address key (BIP44: m/44'/coin_type'/account'/1/address_index)
  HDWalletNode deriveChangeAddress(int account, int addressIndex) {
    final path = [
      0x80000000 + 44,  // purpose: 44'
      0x80000000 + GothamChainParams.bip44CoinType, // coin_type'
      0x80000000 + account, // account'
      1, // internal chain (change)
      addressIndex, // address index
    ];
    return deriveChild(path);
  }
  
  /// Generate receiving address
  String getReceivingAddress(int account, int addressIndex, {AddressType type = AddressType.bech32}) {
    final node = deriveReceivingAddress(account, addressIndex);
    return node.getAddress(type);
  }
  
  /// Generate change address
  String getChangeAddress(int account, int addressIndex, {AddressType type = AddressType.bech32}) {
    final node = deriveChangeAddress(account, addressIndex);
    return node.getAddress(type);
  }
  
  /// Generate wallet descriptor for Gotham Core compatibility
  String generateDescriptor(int account, {bool internal = false, AddressType type = AddressType.bech32}) {
    final accountNode = deriveAccount(account);
    final accountXpub = accountNode.toXpub();
    
    final chain = internal ? 1 : 0;
    
    switch (type) {
      case AddressType.bech32:
        return 'wpkh([$accountXpub]/$chain/*)';
      case AddressType.p2pkh:
        return 'pkh([$accountXpub]/$chain/*)';
      case AddressType.p2sh:
        return 'sh(wpkh([$accountXpub]/$chain/*))';
      default:
        throw ArgumentError('Unsupported address type');
    }
  }
  
  // Private methods
  
  _ChildKeyResult _deriveChildKey(Uint8List parentKey, Uint8List parentChainCode, int index) {
    final isHardened = index >= 0x80000000;
    
    Uint8List data;
    if (isHardened) {
      // Hardened derivation: HMAC-SHA512(Key = cpar, Data = 0x00 || ser256(kpar) || ser32(i))
      data = Uint8List.fromList([0x00] + parentKey + _serializeUint32(index));
    } else {
      // Non-hardened derivation: HMAC-SHA512(Key = cpar, Data = serP(point(kpar)) || ser32(i))
      final publicKey = _privateKeyToPublicKey(parentKey);
      data = Uint8List.fromList(publicKey + _serializeUint32(index));
    }
    
    final hmac = Hmac(sha512, parentChainCode);
    final hash = hmac.convert(data);
    
    final childKey = Uint8List.fromList(hash.bytes.sublist(0, 32));
    final childChainCode = Uint8List.fromList(hash.bytes.sublist(32, 64));
    
    // Add parent key to child key (mod n)
    final combinedKey = _addPrivateKeys(parentKey, childKey);
    
    return _ChildKeyResult(combinedKey, childChainCode);
  }
  
  Uint8List _privateKeyToPublicKey(Uint8List privateKey) {
    // Simplified public key generation - in production use proper secp256k1
    final hash = sha256.convert(privateKey);
    // Create compressed public key format (0x02/0x03 + 32 bytes)
    return Uint8List.fromList([0x02] + hash.bytes);
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
  
  List<int> _serializeUint32(int value) {
    return [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
  }
}

/// Individual node in HD wallet tree
class HDWalletNode {
  final Uint8List privateKey;
  final Uint8List chainCode;
  final List<int> path;
  
  HDWalletNode(this.privateKey, this.chainCode, this.path);
  
  /// Get public key for this node
  Uint8List get publicKey {
    // Simplified - use proper secp256k1 in production
    final hash = sha256.convert(privateKey);
    return Uint8List.fromList([0x02] + hash.bytes);
  }
  
  /// Generate address from this node
  String getAddress(AddressType type) {
    switch (type) {
      case AddressType.p2pkh:
        return GothamAddress.publicKeyToP2PKH(publicKey);
      case AddressType.bech32:
        return GothamAddress.publicKeyToBech32(publicKey);
      case AddressType.p2sh:
        // For P2SH-wrapped segwit
        final witnessScript = _createWitnessScript(publicKey);
        final scriptHash = sha256.convert(witnessScript).bytes;
        return GothamAddress.scriptHashToP2SH(Uint8List.fromList(scriptHash));
      default:
        throw ArgumentError('Unsupported address type');
    }
  }
  
  /// Export as extended public key (xpub)
  String toXpub() {
    // Simplified xpub generation - implement proper BIP32 serialization
    final publicKeyHex = publicKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final chainCodeHex = chainCode.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'xpub$publicKeyHex$chainCodeHex';
  }
  
  /// Export as extended private key (xprv)
  String toXprv() {
    // Simplified xprv generation - implement proper BIP32 serialization
    final privateKeyHex = privateKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final chainCodeHex = chainCode.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'xprv$privateKeyHex$chainCodeHex';
  }
  
  /// Get derivation path string
  String get pathString {
    final pathParts = <String>[];
    for (final index in path) {
      if (index >= 0x80000000) {
        pathParts.add('${index - 0x80000000}\'');
      } else {
        pathParts.add('$index');
      }
    }
    return 'm/${pathParts.join('/')}';
  }
  
  Uint8List _createWitnessScript(Uint8List publicKey) {
    // OP_0 OP_PUSHDATA(20) <20-byte-pubkey-hash>
    final pubkeyHash = sha256.convert(publicKey).bytes.take(20).toList();
    return Uint8List.fromList([0x00, 0x14] + pubkeyHash);
  }
}

class _ChildKeyResult {
  final Uint8List key;
  final Uint8List chainCode;
  
  _ChildKeyResult(this.key, this.chainCode);
}