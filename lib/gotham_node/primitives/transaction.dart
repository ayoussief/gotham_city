import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../script/script.dart';

/// Gotham Core transaction primitives in Dart
/// This matches the exact structure and behavior of Gotham Core's transaction classes

/// An outpoint - a combination of a transaction hash and an index n into its vout
/// Matches Gotham Core's COutPoint exactly
class COutPoint {
  Uint8List hash;
  int n;
  
  static const int nullIndex = 0xFFFFFFFF;
  
  COutPoint() : hash = Uint8List(32), n = nullIndex;
  
  COutPoint.withHash(this.hash, this.n);
  
  void setNull() {
    hash = Uint8List(32);
    n = nullIndex;
  }
  
  bool isNull() => hash.every((b) => b == 0) && n == nullIndex;
  
  @override
  bool operator ==(Object other) {
    if (other is! COutPoint) return false;
    return listEquals(hash, other.hash) && n == other.n;
  }
  
  @override
  int get hashCode => Object.hash(hash, n);
  
  @override
  String toString() {
    final hashHex = hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$hashHex:$n';
  }
  
  /// Serialize to bytes (matches Gotham Core SERIALIZE_METHODS)
  Uint8List serialize() {
    final buffer = BytesBuilder();
    buffer.add(hash);
    buffer.add(_serializeUint32(n));
    return buffer.toBytes();
  }
  
  /// Deserialize from bytes
  static COutPoint deserialize(Uint8List data) {
    if (data.length < 36) throw ArgumentError('Invalid COutPoint data');
    
    final hash = data.sublist(0, 32);
    final n = _deserializeUint32(data.sublist(32, 36));
    
    return COutPoint.withHash(hash, n);
  }
}

/// Script witness data (for SegWit transactions)
class CScriptWitness {
  List<Uint8List> stack = [];
  
  bool get isEmpty => stack.isEmpty;
  
  void clear() => stack.clear();
  
  @override
  String toString() {
    return 'CScriptWitness(${stack.length} items)';
  }
  
  /// Serialize witness stack
  Uint8List serialize() {
    final buffer = BytesBuilder();
    buffer.add(_serializeVarInt(stack.length));
    
    for (final item in stack) {
      buffer.add(_serializeVarInt(item.length));
      buffer.add(item);
    }
    
    return buffer.toBytes();
  }
}

/// An input of a transaction. Contains the location of the previous
/// transaction's output that it claims and a signature that matches the
/// output's public key. Matches Gotham Core's CTxIn exactly.
class CTxIn {
  COutPoint prevout;
  CScript scriptSig;
  int nSequence;
  CScriptWitness scriptWitness;
  
  // Sequence number constants (matching Gotham Core)
  static const int sequenceFinal = 0xffffffff;
  static const int maxSequenceNonfinal = sequenceFinal - 1;
  static const int sequenceLocktimeDisableFlag = 1 << 31;
  static const int sequenceLocktimeTypeFlag = 1 << 22;
  static const int sequenceLockTimeMask = 0x0000ffff;
  static const int sequenceLocktimeGranularity = 9;
  
  CTxIn({
    COutPoint? prevout,
    CScript? scriptSig,
    int? nSequence,
    CScriptWitness? scriptWitness,
  }) : prevout = prevout ?? COutPoint(),
       scriptSig = scriptSig ?? CScript(),
       nSequence = nSequence ?? sequenceFinal,
       scriptWitness = scriptWitness ?? CScriptWitness();
  
  /// Get previous transaction ID as hex string
  String get previousTxid => prevout.hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  
  /// Get output index
  int get outputIndex => prevout.n;
  
  @override
  bool operator ==(Object other) {
    if (other is! CTxIn) return false;
    return prevout == other.prevout &&
           scriptSig == other.scriptSig &&
           nSequence == other.nSequence;
  }
  
  @override
  int get hashCode => Object.hash(prevout, scriptSig, nSequence);
  
  @override
  String toString() {
    return 'CTxIn(prevout: $prevout, scriptSig: $scriptSig, nSequence: $nSequence)';
  }
  
  /// Serialize to bytes
  Uint8List serialize() {
    final buffer = BytesBuilder();
    buffer.add(prevout.serialize());
    buffer.add(scriptSig.serialize());
    buffer.add(_serializeUint32(nSequence));
    return buffer.toBytes();
  }
}

/// An output of a transaction. Contains the public key that the next input
/// must be able to sign with to claim it. Matches Gotham Core's CTxOut exactly.
class CTxOut {
  int nValue; // Amount in satoshis
  CScript scriptPubKey;
  
  CTxOut({this.nValue = -1, CScript? scriptPubKey}) 
    : scriptPubKey = scriptPubKey ?? CScript();
  
  void setNull() {
    nValue = -1;
    scriptPubKey.clear();
  }
  
  bool isNull() => nValue == -1;
  
  /// Get value (alias for nValue)
  int get value => nValue;
  
  @override
  bool operator ==(Object other) {
    if (other is! CTxOut) return false;
    return nValue == other.nValue && scriptPubKey == other.scriptPubKey;
  }
  
  @override
  int get hashCode => Object.hash(nValue, scriptPubKey);
  
  @override
  String toString() {
    return 'CTxOut(nValue: $nValue, scriptPubKey: $scriptPubKey)';
  }
  
  /// Serialize to bytes
  Uint8List serialize() {
    final buffer = BytesBuilder();
    buffer.add(_serializeUint64(nValue));
    buffer.add(scriptPubKey.serialize());
    return buffer.toBytes();
  }
}

/// Mutable transaction (for building transactions)
/// Matches Gotham Core's CMutableTransaction
class CMutableTransaction {
  List<CTxIn> vin = [];
  List<CTxOut> vout = [];
  int version;
  int nLockTime;
  
  static const int currentVersion = 2;
  
  CMutableTransaction({
    this.version = currentVersion,
    this.nLockTime = 0,
    List<CTxIn>? vin,
    List<CTxOut>? vout,
  }) {
    this.vin = vin ?? [];
    this.vout = vout ?? [];
  }
  
  bool get isNull => vin.isEmpty && vout.isEmpty;
  
  /// Check if transaction has witness data
  bool hasWitness() {
    return vin.any((input) => !input.scriptWitness.isEmpty);
  }
  
  /// Get total output value
  int getValueOut() {
    return vout.fold(0, (sum, output) => sum + output.nValue);
  }
  
  /// Get transaction size in bytes (without witness data)
  int getSerializeSize() {
    return _serializeSize(false);
  }
  
  /// Get transaction size in bytes including witness data
  int getTotalSize() {
    return _serializeSize(true);
  }
  
  /// Get transaction weight (BIP 141)
  int getWeight() {
    final baseSize = _serializeSize(false);
    final totalSize = _serializeSize(true);
    return baseSize * 3 + totalSize;
  }
  
  /// Get virtual size (weight / 4, rounded up)
  int getVirtualSize() {
    return (getWeight() + 3) ~/ 4;
  }
  
  int _serializeSize(bool includeWitness) {
    // Simplified size calculation
    int size = 4 + 4; // version + nLockTime
    size += _varIntSize(vin.length);
    size += _varIntSize(vout.length);
    
    for (final input in vin) {
      size += input.serialize().length;
      if (includeWitness && !input.scriptWitness.isEmpty) {
        size += input.scriptWitness.serialize().length;
      }
    }
    
    for (final output in vout) {
      size += output.serialize().length;
    }
    
    if (includeWitness && hasWitness()) {
      size += 2; // marker + flag
    }
    
    return size;
  }
  
  @override
  String toString() {
    return 'CMutableTransaction(version: $version, vin: ${vin.length}, vout: ${vout.length}, nLockTime: $nLockTime)';
  }
}

/// Immutable transaction (matches Gotham Core's CTransaction exactly)
class CTransaction {
  final List<CTxIn> vin;
  final List<CTxOut> vout;
  final int version;
  final int nLockTime;
  
  // Cached values (computed once)
  final bool _hasWitness;
  final Uint8List _hash;
  final Uint8List _witnessHash;
  
  static const int currentVersion = 2;
  
  CTransaction._(
    this.vin,
    this.vout,
    this.version,
    this.nLockTime,
    this._hasWitness,
    this._hash,
    this._witnessHash,
  );
  
  /// Create from mutable transaction
  factory CTransaction.fromMutable(CMutableTransaction tx) {
    final hasWitness = tx.hasWitness();
    final hash = _computeHash(tx, false);
    final witnessHash = _computeHash(tx, true);
    
    return CTransaction._(
      List.unmodifiable(tx.vin),
      List.unmodifiable(tx.vout),
      tx.version,
      tx.nLockTime,
      hasWitness,
      hash,
      witnessHash,
    );
  }
  
  bool get isNull => vin.isEmpty && vout.isEmpty;
  
  /// Get transaction hash (TXID)
  Uint8List get hash => _hash;
  
  /// Get witness hash (WTXID)
  Uint8List get witnessHash => _witnessHash;
  
  /// Get transaction hash as hex string
  String get hashHex => _hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  
  /// Get witness hash as hex string
  String get witnessHashHex => _witnessHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  
  /// Get transaction ID (alias for hashHex)
  String get txid => hashHex;
  
  /// Get inputs (alias for vin)
  List<CTxIn> get inputs => vin;
  
  /// Get outputs (alias for vout)
  List<CTxOut> get outputs => vout;
  
  /// Get lock time (alias for nLockTime)
  int get lockTime => nLockTime;
  
  /// Check if transaction has witness data
  bool hasWitness() => _hasWitness;
  
  /// Get total output value
  int getValueOut() {
    return vout.fold(0, (sum, output) => sum + output.nValue);
  }
  
  /// Serialize transaction to bytes
  Uint8List serialize({bool includeWitness = true}) {
    final buffer = BytesBuilder();
    
    // Version
    buffer.add(_serializeUint32(version));
    
    // Handle witness serialization
    if (includeWitness && hasWitness()) {
      // Extended format with witness
      buffer.add(_serializeVarInt(0)); // marker
      buffer.add([1]); // flag
    }
    
    // Inputs
    buffer.add(_serializeVarInt(vin.length));
    for (final input in vin) {
      buffer.add(input.serialize());
    }
    
    // Outputs
    buffer.add(_serializeVarInt(vout.length));
    for (final output in vout) {
      buffer.add(output.serialize());
    }
    
    // Witness data
    if (includeWitness && hasWitness()) {
      for (final input in vin) {
        buffer.add(input.scriptWitness.serialize());
      }
    }
    
    // Lock time
    buffer.add(_serializeUint32(nLockTime));
    
    return buffer.toBytes();
  }
  
  @override
  String toString() {
    return 'CTransaction(hash: $hashHex, version: $version, vin: ${vin.length}, vout: ${vout.length}, nLockTime: $nLockTime)';
  }
  
  /// Compute transaction hash (internal)
  static Uint8List _computeHash(CMutableTransaction tx, bool witness) {
    final serialized = witness ? 
      _serializeWithWitness(tx) : 
      _serializeWithoutWitness(tx);
    
    // Double SHA256 (Gotham's hash algorithm)
    final hash1 = sha256.convert(serialized);
    final hash2 = sha256.convert(hash1.bytes);
    
    return Uint8List.fromList(hash2.bytes.reversed.toList()); // Little endian
  }
  
  static Uint8List _serializeWithoutWitness(CMutableTransaction tx) {
    final buffer = BytesBuilder();
    buffer.add(_serializeUint32(tx.version));
    buffer.add(_serializeVarInt(tx.vin.length));
    for (final input in tx.vin) {
      buffer.add(input.serialize());
    }
    buffer.add(_serializeVarInt(tx.vout.length));
    for (final output in tx.vout) {
      buffer.add(output.serialize());
    }
    buffer.add(_serializeUint32(tx.nLockTime));
    return buffer.toBytes();
  }
  
  static Uint8List _serializeWithWitness(CMutableTransaction tx) {
    final buffer = BytesBuilder();
    buffer.add(_serializeUint32(tx.version));
    
    if (tx.hasWitness()) {
      buffer.add(_serializeVarInt(0)); // marker
      buffer.add([1]); // flag
    }
    
    buffer.add(_serializeVarInt(tx.vin.length));
    for (final input in tx.vin) {
      buffer.add(input.serialize());
    }
    
    buffer.add(_serializeVarInt(tx.vout.length));
    for (final output in tx.vout) {
      buffer.add(output.serialize());
    }
    
    if (tx.hasWitness()) {
      for (final input in tx.vin) {
        buffer.add(input.scriptWitness.serialize());
      }
    }
    
    buffer.add(_serializeUint32(tx.nLockTime));
    return buffer.toBytes();
  }
}

// Utility functions for serialization (matching Gotham's serialization format)

Uint8List _serializeUint32(int value) {
  final bytes = ByteData(4);
  bytes.setUint32(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}

Uint8List _serializeUint64(int value) {
  final bytes = ByteData(8);
  bytes.setUint64(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}

int _deserializeUint32(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return data.getUint32(0, Endian.little);
}

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

int _varIntSize(int value) {
  if (value < 0xfd) return 1;
  if (value <= 0xffff) return 3;
  if (value <= 0xffffffff) return 5;
  return 9;
}

bool listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Transaction output specification for wallet transaction building
class TransactionOutput {
  final String address;
  final int amount; // Amount in satoshis
  final String? label;
  
  TransactionOutput({
    required this.address,
    required this.amount,
    this.label,
  });
  
  @override
  String toString() {
    return 'TransactionOutput(address: $address, amount: $amount, label: $label)';
  }
}

/// UTXO (Unspent Transaction Output) for coin selection
class UTXO {
  final COutPoint outpoint;
  final CTxOut output;
  final int confirmations;
  final bool isCoinbase;
  final String? address;
  final String? label;
  
  UTXO({
    required this.outpoint,
    required this.output,
    this.confirmations = 0,
    this.isCoinbase = false,
    this.address,
    this.label,
  });
  
  /// Get the amount in satoshis
  int get amount => output.nValue;
  
  /// Check if UTXO is spendable
  bool get isSpendable => !output.isNull() && confirmations > 0;
  
  @override
  String toString() {
    return 'UTXO(outpoint: $outpoint, amount: $amount, confirmations: $confirmations)';
  }
}