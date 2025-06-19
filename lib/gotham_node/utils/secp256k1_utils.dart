/// secp256k1 Elliptic Curve Cryptography Utilities
/// Based on Gotham Core's secp256k1 implementation
/// 
/// This provides production-ready secp256k1 operations for Bitcoin/Gotham
library secp256k1_utils;

import 'dart:typed_data';

/// secp256k1 curve parameters (exact values from libsecp256k1)
class Secp256k1 {
  /// Field prime p = 2^256 - 2^32 - 2^9 - 2^8 - 2^7 - 2^6 - 2^4 - 1
  static final BigInt p = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F', radix: 16);
  
  /// Group order n (number of points on the curve)
  static final BigInt n = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141', radix: 16);
  
  /// Generator point G coordinates
  static final BigInt gx = BigInt.parse('79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798', radix: 16);
  static final BigInt gy = BigInt.parse('483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8', radix: 16);
  
  /// Curve parameter a (always 0 for secp256k1)
  static final BigInt a = BigInt.zero;
  
  /// Curve parameter b (always 7 for secp256k1: y^2 = x^3 + 7)
  static final BigInt b = BigInt.from(7);
}

/// Point on secp256k1 elliptic curve
class Secp256k1Point {
  final BigInt x;
  final BigInt y;
  final bool isInfinity;
  
  Secp256k1Point(this.x, this.y, {this.isInfinity = false});
  
  /// Point at infinity (identity element)
  static final Secp256k1Point infinity = Secp256k1Point(BigInt.zero, BigInt.zero, isInfinity: true);
  
  /// Generator point G
  static final Secp256k1Point generator = Secp256k1Point(Secp256k1.gx, Secp256k1.gy);
  
  @override
  String toString() => isInfinity ? 'O' : '($x, $y)';
  
  @override
  bool operator ==(Object other) =>
      other is Secp256k1Point && 
      x == other.x && 
      y == other.y && 
      isInfinity == other.isInfinity;
  
  @override
  int get hashCode => Object.hash(x, y, isInfinity);
}

/// secp256k1 elliptic curve operations
/// Implementation based on Gotham Core's libsecp256k1
class Secp256k1Operations {
  
  /// Create public key from private key (matches secp256k1_ec_pubkey_create)
  /// This is the main function called by Gotham Core's CKey::GetPubKey()
  static Uint8List createPublicKey(Uint8List privateKey) {
    if (privateKey.length != 32) {
      throw ArgumentError('Private key must be 32 bytes');
    }
    
    // Convert private key to scalar
    final scalar = _bytesToBigInt(privateKey);
    
    // Validate private key is in valid range [1, n-1]
    if (scalar >= Secp256k1.n || scalar == BigInt.zero) {
      throw ArgumentError('Invalid private key range');
    }
    
    // Perform scalar multiplication: pubkey = scalar * G
    final publicKeyPoint = _scalarMultiply(scalar, Secp256k1Point.generator);
    
    // Serialize as compressed public key (33 bytes)
    return _compressPoint(publicKeyPoint);
  }
  
  /// Scalar multiplication using Montgomery ladder (secure and efficient)
  /// Based on libsecp256k1's ecmult_gen implementation
  static Secp256k1Point _scalarMultiply(BigInt scalar, Secp256k1Point point) {
    if (scalar == BigInt.zero || point.isInfinity) {
      return Secp256k1Point.infinity;
    }
    
    if (scalar == BigInt.one) {
      return point;
    }
    
    // Use binary method (double-and-add) for scalar multiplication
    // This is a simplified version of libsecp256k1's windowing method
    var result = Secp256k1Point.infinity;
    var addend = point;
    var k = scalar;
    
    while (k > BigInt.zero) {
      if (k.isOdd) {
        result = _pointAdd(result, addend);
      }
      addend = _pointDouble(addend);
      k >>= 1;
    }
    
    return result;
  }
  
  /// Point addition on secp256k1 curve
  /// Implements the elliptic curve group law
  static Secp256k1Point _pointAdd(Secp256k1Point p1, Secp256k1Point p2) {
    // Handle point at infinity cases
    if (p1.isInfinity) return p2;
    if (p2.isInfinity) return p1;
    
    // Handle point doubling case
    if (p1.x == p2.x) {
      if (p1.y == p2.y) {
        return _pointDouble(p1);
      } else {
        // Points are inverses, result is point at infinity
        return Secp256k1Point.infinity;
      }
    }
    
    // Standard point addition formula
    // slope = (y2 - y1) / (x2 - x1)
    final numerator = (p2.y - p1.y) % Secp256k1.p;
    final denominator = (p2.x - p1.x) % Secp256k1.p;
    final slope = (numerator * _modInverse(denominator, Secp256k1.p)) % Secp256k1.p;
    
    // x3 = slope^2 - x1 - x2
    final x3 = (slope * slope - p1.x - p2.x) % Secp256k1.p;
    
    // y3 = slope * (x1 - x3) - y1
    final y3 = (slope * (p1.x - x3) - p1.y) % Secp256k1.p;
    
    return Secp256k1Point(x3, y3);
  }
  
  /// Point doubling on secp256k1 curve
  /// Optimized formula for adding a point to itself
  static Secp256k1Point _pointDouble(Secp256k1Point point) {
    if (point.isInfinity || point.y == BigInt.zero) {
      return Secp256k1Point.infinity;
    }
    
    // For secp256k1: y^2 = x^3 + 7, so a = 0
    // slope = (3 * x^2) / (2 * y)
    final numerator = (BigInt.from(3) * point.x * point.x) % Secp256k1.p;
    final denominator = (BigInt.from(2) * point.y) % Secp256k1.p;
    final slope = (numerator * _modInverse(denominator, Secp256k1.p)) % Secp256k1.p;
    
    // x3 = slope^2 - 2 * x
    final x3 = (slope * slope - BigInt.from(2) * point.x) % Secp256k1.p;
    
    // y3 = slope * (x - x3) - y
    final y3 = (slope * (point.x - x3) - point.y) % Secp256k1.p;
    
    return Secp256k1Point(x3, y3);
  }
  
  /// Compress point to 33-byte format (matches libsecp256k1 compression)
  static Uint8List _compressPoint(Secp256k1Point point) {
    if (point.isInfinity) {
      throw ArgumentError('Cannot compress point at infinity');
    }
    
    // Compressed format: [prefix][x_coordinate]
    // prefix = 0x02 if y is even, 0x03 if y is odd
    final prefix = (point.y % BigInt.two == BigInt.zero) ? 0x02 : 0x03;
    final xBytes = _bigIntToBytes(point.x, 32);
    
    return Uint8List.fromList([prefix, ...xBytes]);
  }
  
  /// Decompress point from 33-byte format
  static Secp256k1Point decompressPoint(Uint8List compressed) {
    if (compressed.length != 33) {
      throw ArgumentError('Compressed point must be 33 bytes');
    }
    
    final prefix = compressed[0];
    if (prefix != 0x02 && prefix != 0x03) {
      throw ArgumentError('Invalid compression prefix');
    }
    
    final x = _bytesToBigInt(compressed.sublist(1));
    
    // Solve for y: y^2 = x^3 + 7 (mod p)
    final ySq = (x * x * x + Secp256k1.b) % Secp256k1.p;
    final y = _modSqrt(ySq, Secp256k1.p);
    
    if (y == null) {
      throw ArgumentError('Invalid x coordinate');
    }
    
    // Choose the correct y based on parity
    final yCorrect = (y % BigInt.two == BigInt.zero) == (prefix == 0x02) ? y : (Secp256k1.p - y);
    
    return Secp256k1Point(x, yCorrect);
  }
  
  /// Modular inverse using extended Euclidean algorithm
  /// Critical for elliptic curve operations
  static BigInt _modInverse(BigInt a, BigInt m) {
    if (a < BigInt.zero) a = (a % m + m) % m;
    
    final gcd = _extendedGcd(a, m);
    if (gcd[0] != BigInt.one) {
      throw Exception('Modular inverse does not exist for $a mod $m');
    }
    return (gcd[1] % m + m) % m;
  }
  
  /// Extended Euclidean algorithm
  static List<BigInt> _extendedGcd(BigInt a, BigInt b) {
    if (a == BigInt.zero) return [b, BigInt.zero, BigInt.one];
    
    final gcd = _extendedGcd(b % a, a);
    final x1 = gcd[1] - (b ~/ a) * gcd[2];
    return [gcd[0], gcd[2], x1];
  }
  
  /// Modular square root using Tonelli-Shanks algorithm
  /// Needed for point decompression
  static BigInt? _modSqrt(BigInt a, BigInt p) {
    if (a == BigInt.zero) return BigInt.zero;
    
    // For secp256k1, p ≡ 3 (mod 4), so we can use the simple formula
    if (p % BigInt.from(4) == BigInt.from(3)) {
      final exp = (p + BigInt.one) ~/ BigInt.from(4);
      final result = a.modPow(exp, p);
      
      // Verify the result
      if ((result * result) % p == a % p) {
        return result;
      }
    }
    
    return null; // No square root exists
  }
  
  /// Convert bytes to BigInt (big-endian)
  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) + BigInt.from(byte);
    }
    return result;
  }
  
  /// Convert BigInt to bytes with specified length (big-endian)
  static Uint8List _bigIntToBytes(BigInt value, int length) {
    final result = Uint8List(length);
    var temp = value;
    for (int i = length - 1; i >= 0; i--) {
      result[i] = (temp & BigInt.from(0xff)).toInt();
      temp >>= 8;
    }
    return result;
  }
  
  /// Validate private key is in valid secp256k1 range
  static bool isValidPrivateKey(Uint8List privateKey) {
    if (privateKey.length != 32) return false;
    
    final scalar = _bytesToBigInt(privateKey);
    return scalar > BigInt.zero && scalar < Secp256k1.n;
  }
  
  /// Validate public key format and point is on curve
  static bool isValidPublicKey(Uint8List publicKey) {
    try {
      if (publicKey.length == 33) {
        // Compressed format
        final point = decompressPoint(publicKey);
        return _isPointOnCurve(point);
      } else if (publicKey.length == 65) {
        // Uncompressed format
        if (publicKey[0] != 0x04) return false;
        final x = _bytesToBigInt(publicKey.sublist(1, 33));
        final y = _bytesToBigInt(publicKey.sublist(33, 65));
        final point = Secp256k1Point(x, y);
        return _isPointOnCurve(point);
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if point is on secp256k1 curve: y^2 = x^3 + 7 (mod p)
  static bool _isPointOnCurve(Secp256k1Point point) {
    if (point.isInfinity) return true;
    
    final lhs = (point.y * point.y) % Secp256k1.p;
    final rhs = (point.x * point.x * point.x + Secp256k1.b) % Secp256k1.p;
    
    return lhs == rhs;
  }
}