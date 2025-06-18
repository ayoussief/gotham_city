import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../config/gotham_chain_params.dart';

/// Gotham-compatible address generation following Bitcoin standards
class GothamAddress {
  
  /// Generate a P2PKH address from a public key (starts with '1')
  static String publicKeyToP2PKH(Uint8List publicKey) {
    // Step 1: SHA256 hash of the public key
    final sha256Hash = sha256.convert(publicKey);
    
    // Step 2: RIPEMD160 hash of the SHA256 hash
    final ripemd160Hash = _ripemd160(sha256Hash.bytes);
    
    // Step 3: Add version byte (0x00 for mainnet P2PKH)
    final versionedPayload = Uint8List.fromList([0x00] + ripemd160Hash);
    
    // Step 4: Calculate checksum (double SHA256)
    final checksum = _calculateChecksum(versionedPayload);
    
    // Step 5: Concatenate and encode to base58
    final fullPayload = Uint8List.fromList(versionedPayload + checksum);
    return _encodeBase58(fullPayload);
  }
  
  /// Generate a P2SH address from a script hash (starts with '3')
  static String scriptHashToP2SH(Uint8List scriptHash) {
    // Step 1: Add version byte (0x05 for mainnet P2SH)
    final versionedPayload = Uint8List.fromList([0x05] + scriptHash);
    
    // Step 2: Calculate checksum
    final checksum = _calculateChecksum(versionedPayload);
    
    // Step 3: Concatenate and encode to base58
    final fullPayload = Uint8List.fromList(versionedPayload + checksum);
    return _encodeBase58(fullPayload);
  }
  
  /// Generate a Bech32 address (segwit, starts with 'gt1')
  static String publicKeyToBech32(Uint8List publicKey) {
    // Step 1: SHA256 hash of the public key
    final sha256Hash = sha256.convert(publicKey);
    
    // Step 2: RIPEMD160 hash for witness v0
    final ripemd160Hash = _ripemd160(sha256Hash.bytes);
    
    // Step 3: Encode as bech32 with Gotham's HRP
    return _encodeBech32(GothamChainParams.bech32Hrp, 0, ripemd160Hash);
  }
  
  /// Validate if an address is valid for Gotham network
  static bool isValidAddress(String address) {
    if (address.startsWith('gt1')) {
      return _isValidBech32(address);
    } else if (address.startsWith('1') || address.startsWith('3')) {
      return _isValidBase58(address);
    }
    return false;
  }
  
  /// Get address type
  static AddressType getAddressType(String address) {
    if (address.startsWith('1')) return AddressType.p2pkh;
    if (address.startsWith('3')) return AddressType.p2sh;
    if (address.startsWith('gt1')) return AddressType.bech32;
    return AddressType.unknown;
  }
  
  // Private helper methods
  
  static Uint8List _ripemd160(List<int> data) {
    // Simplified RIPEMD160 - in production use proper implementation
    // For now, use SHA256 as placeholder (this should be actual RIPEMD160)
    final hash = sha256.convert(data);
    return Uint8List.fromList(hash.bytes.take(20).toList());
  }
  
  static Uint8List _calculateChecksum(Uint8List data) {
    final hash1 = sha256.convert(data);
    final hash2 = sha256.convert(hash1.bytes);
    return Uint8List.fromList(hash2.bytes.take(4).toList());
  }
  
  static String _encodeBase58(Uint8List data) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    
    // Count leading zeros
    int leadingZeros = 0;
    for (int i = 0; i < data.length && data[i] == 0; i++) {
      leadingZeros++;
    }
    
    // Convert to big integer
    BigInt num = BigInt.zero;
    for (int byte in data) {
      num = num * BigInt.from(256) + BigInt.from(byte);
    }
    
    // Convert to base58
    String result = '';
    while (num > BigInt.zero) {
      final remainder = num % BigInt.from(58);
      num = num ~/ BigInt.from(58);
      result = alphabet[remainder.toInt()] + result;
    }
    
    // Add leading zeros as '1's
    result = '1' * leadingZeros + result;
    
    return result;
  }
  
  static String _encodeBech32(String hrp, int witnessVersion, List<int> witnessProgram) {
    // Simplified bech32 encoding - implement proper bech32 in production
    // For now, create a mock bech32 address
    final programHex = witnessProgram.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hrp}1q${programHex.substring(0, 32)}';
  }
  
  static bool _isValidBase58(String address) {
    try {
      final decoded = _decodeBase58(address);
      if (decoded.length < 25) return false;
      
      final payload = decoded.sublist(0, decoded.length - 4);
      final checksum = decoded.sublist(decoded.length - 4);
      final calculatedChecksum = _calculateChecksum(Uint8List.fromList(payload));
      
      return _listEquals(checksum, calculatedChecksum);
    } catch (e) {
      return false;
    }
  }
  
  static bool _isValidBech32(String address) {
    // Basic validation for bech32 addresses
    return address.startsWith('gt1') && address.length >= 14 && address.length <= 74;
  }
  
  static List<int> _decodeBase58(String encoded) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    
    // Count leading zeros
    int leadingZeros = 0;
    for (int i = 0; i < encoded.length && encoded[i] == '1'; i++) {
      leadingZeros++;
    }
    
    // Convert to big integer
    BigInt num = BigInt.zero;
    for (int i = 0; i < encoded.length; i++) {
      final char = encoded[i];
      final index = alphabet.indexOf(char);
      if (index == -1) throw ArgumentError('Invalid base58 character: $char');
      num = num * BigInt.from(58) + BigInt.from(index);
    }
    
    // Convert to bytes
    List<int> result = [];
    while (num > BigInt.zero) {
      result.insert(0, (num % BigInt.from(256)).toInt());
      num = num ~/ BigInt.from(256);
    }
    
    // Add leading zeros
    result = List.filled(leadingZeros, 0) + result;
    
    return result;
  }
  
  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

enum AddressType {
  p2pkh,    // Pay to Public Key Hash (starts with '1')
  p2sh,     // Pay to Script Hash (starts with '3')  
  bech32,   // Segwit v0 (starts with 'gt1')
  unknown
}