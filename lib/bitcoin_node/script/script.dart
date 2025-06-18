import 'dart:typed_data';

/// Bitcoin Script implementation matching Gotham Core's CScript
class CScript {
  List<int> _data = [];
  
  CScript([List<int>? data]) {
    if (data != null) {
      _data = List.from(data);
    }
  }
  
  /// Create from hex string
  CScript.fromHex(String hex) {
    if (hex.length % 2 != 0) {
      throw ArgumentError('Invalid hex string length');
    }
    
    _data = [];
    for (int i = 0; i < hex.length; i += 2) {
      final byte = int.parse(hex.substring(i, i + 2), radix: 16);
      _data.add(byte);
    }
  }
  
  /// Create from Uint8List bytes
  CScript.fromBytes(Uint8List bytes) : _data = bytes.toList();
  
  /// Get script data as List<int>
  List<int> get data => List.unmodifiable(_data);
  
  /// Get script data as Uint8List
  Uint8List get bytes => Uint8List.fromList(_data);
  
  /// Get script size
  int get size => _data.length;
  
  /// Check if script is empty
  bool get isEmpty => _data.isEmpty;
  
  /// Clear script
  void clear() => _data.clear();
  
  /// Add single byte/opcode
  void add(int byte) {
    _data.add(byte & 0xff);
  }
  
  /// Add multiple bytes
  void addAll(List<int> bytes) {
    _data.addAll(bytes);
  }
  
  /// Add data with push opcode
  void addData(List<int> data) {
    if (data.isEmpty) {
      add(OP_0);
      return;
    }
    
    if (data.length <= 75) {
      // Direct push
      add(data.length);
      addAll(data);
    } else if (data.length <= 0xff) {
      // OP_PUSHDATA1
      add(OP_PUSHDATA1);
      add(data.length);
      addAll(data);
    } else if (data.length <= 0xffff) {
      // OP_PUSHDATA2
      add(OP_PUSHDATA2);
      add(data.length & 0xff);
      add((data.length >> 8) & 0xff);
      addAll(data);
    } else {
      // OP_PUSHDATA4
      add(OP_PUSHDATA4);
      add(data.length & 0xff);
      add((data.length >> 8) & 0xff);
      add((data.length >> 16) & 0xff);
      add((data.length >> 24) & 0xff);
      addAll(data);
    }
  }
  
  /// Convert to hex string
  String toHex() {
    return _data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
  
  /// Serialize for transmission
  Uint8List serialize() {
    final buffer = BytesBuilder();
    buffer.add(_serializeVarInt(_data.length));
    buffer.add(_data);
    return buffer.toBytes();
  }
  
  @override
  bool operator ==(Object other) {
    if (other is! CScript) return false;
    if (_data.length != other._data.length) return false;
    for (int i = 0; i < _data.length; i++) {
      if (_data[i] != other._data[i]) return false;
    }
    return true;
  }
  
  @override
  int get hashCode => Object.hashAll(_data);
  
  @override
  String toString() {
    if (_data.isEmpty) return 'CScript()';
    return 'CScript(${toHex()})';
  }
  
  /// Check if script is Pay-to-Public-Key-Hash
  bool isPayToPubKeyHash() {
    return _data.length == 25 &&
           _data[0] == OP_DUP &&
           _data[1] == OP_HASH160 &&
           _data[2] == 20 &&
           _data[23] == OP_EQUALVERIFY &&
           _data[24] == OP_CHECKSIG;
  }
  
  /// Check if script is Pay-to-Script-Hash
  bool isPayToScriptHash() {
    return _data.length == 23 &&
           _data[0] == OP_HASH160 &&
           _data[1] == 20 &&
           _data[22] == OP_EQUAL;
  }
  
  /// Check if script is Pay-to-Witness-Public-Key-Hash
  bool isPayToWitnessPubKeyHash() {
    return _data.length == 22 &&
           _data[0] == OP_0 &&
           _data[1] == 20;
  }
  
  /// Check if script is Pay-to-Witness-Script-Hash
  bool isPayToWitnessScriptHash() {
    return _data.length == 34 &&
           _data[0] == OP_0 &&
           _data[1] == 32;
  }
  
  /// Get the script type
  ScriptType getType() {
    if (isPayToPubKeyHash()) return ScriptType.payToPubKeyHash;
    if (isPayToScriptHash()) return ScriptType.payToScriptHash;
    if (isPayToWitnessPubKeyHash()) return ScriptType.payToWitnessPubKeyHash;
    if (isPayToWitnessScriptHash()) return ScriptType.payToWitnessScriptHash;
    return ScriptType.nonStandard;
  }
}

/// Script types
enum ScriptType {
  nonStandard,
  payToPubKey,
  payToPubKeyHash,
  payToScriptHash,
  payToWitnessPubKeyHash,
  payToWitnessScriptHash,
  multiSig,
  nullData,
}

// Bitcoin Script opcodes (subset of most commonly used)
const int OP_0 = 0x00;
const int OP_1 = 0x51;
const int OP_16 = 0x60;

const int OP_DUP = 0x76;
const int OP_HASH160 = 0xa9;
const int OP_EQUAL = 0x87;
const int OP_EQUALVERIFY = 0x88;
const int OP_CHECKSIG = 0xac;
const int OP_CHECKMULTISIG = 0xae;

const int OP_PUSHDATA1 = 0x4c;
const int OP_PUSHDATA2 = 0x4d;
const int OP_PUSHDATA4 = 0x4e;

const int OP_RETURN = 0x6a;

// Utility function for variable length integer serialization
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