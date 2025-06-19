import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';

class BlockHeader {
  final int version;
  final String previousBlockHash;
  final String merkleRoot;
  final int timestamp;
  final int bits;
  final int nonce;
  final int height;
  final String hash;

  BlockHeader({
    required this.version,
    required this.previousBlockHash,
    required this.merkleRoot,
    required this.timestamp,
    required this.bits,
    required this.nonce,
    required this.height,
    required this.hash,
  });

  factory BlockHeader.fromJson(Map<String, dynamic> json) {
    return BlockHeader(
      version: json['version'] ?? 0,
      previousBlockHash: json['previousblockhash'] ?? '',
      merkleRoot: json['merkleroot'] ?? '',
      timestamp: json['time'] ?? 0,
      bits: int.tryParse(json['bits']?.toString() ?? '0', radix: 16) ?? 0,
      nonce: json['nonce'] ?? 0,
      height: json['height'] ?? 0,
      hash: json['hash'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'previousblockhash': previousBlockHash,
      'merkleroot': merkleRoot,
      'time': timestamp,
      'bits': bits.toRadixString(16),
      'nonce': nonce,
      'height': height,
      'hash': hash,
    };
  }

  Map<String, dynamic> toDbMap() {
    return {
      'hash': hash,
      'version': version,
      'previous_block_hash': previousBlockHash,
      'merkle_root': merkleRoot,
      'timestamp': timestamp,
      'bits': bits,
      'nonce': nonce,
      'height': height,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory BlockHeader.fromDbMap(Map<String, dynamic> map) {
    return BlockHeader(
      version: map['version'],
      previousBlockHash: map['previous_block_hash'],
      merkleRoot: map['merkle_root'],
      timestamp: map['timestamp'],
      bits: map['bits'],
      nonce: map['nonce'],
      height: map['height'],
      hash: map['hash'],
    );
  }

  // Calculate difficulty from bits
  double get difficulty {
    if (bits == 0) return 0.0;
    
    final target = _bitsToTarget(bits);
    final maxTarget = BigInt.parse('00000000FFFF0000000000000000000000000000000000000000000000000000', radix: 16);
    
    return maxTarget / target;
  }

  BigInt _bitsToTarget(int bits) {
    final exponent = bits >> 24;
    final mantissa = bits & 0x00ffffff;
    
    if (exponent <= 3) {
      return BigInt.from(mantissa >> (8 * (3 - exponent)));
    } else {
      return BigInt.from(mantissa) << (8 * (exponent - 3));
    }
  }

  // Verify proof of work
  bool verifyProofOfWork() {
    final target = _bitsToTarget(bits);
    final hashBigInt = BigInt.parse(hash, radix: 16);
    return hashBigInt <= target;
  }

  // Get block age in hours
  int get ageInHours {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (now - timestamp) ~/ 3600;
  }

  // Check if block is older than 24 hours (144 blocks approximately)
  bool get isOlderThan24Hours {
    return ageInHours > 24;
  }

  @override
  String toString() {
    return 'BlockHeader(hash: ${hash.substring(0, 8)}..., height: $height, time: ${DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BlockHeader && other.hash == hash;
  }

  @override
  int get hashCode => hash.hashCode;
}

// Blockchain info model
class BlockchainInfo {
  final int blocks;
  final int headers;
  final String bestBlockHash;
  final double difficulty;
  final int medianTime;
  final double verificationProgress;
  final bool initialBlockDownload;
  final String chainWork;
  final int sizeOnDisk;
  final bool pruned;

  BlockchainInfo({
    required this.blocks,
    required this.headers,
    required this.bestBlockHash,
    required this.difficulty,
    required this.medianTime,
    required this.verificationProgress,
    required this.initialBlockDownload,
    required this.chainWork,
    required this.sizeOnDisk,
    required this.pruned,
  });

  factory BlockchainInfo.fromJson(Map<String, dynamic> json) {
    return BlockchainInfo(
      blocks: json['blocks'] ?? 0,
      headers: json['headers'] ?? 0,
      bestBlockHash: json['bestblockhash'] ?? '',
      difficulty: (json['difficulty'] ?? 0.0).toDouble(),
      medianTime: json['mediantime'] ?? 0,
      verificationProgress: (json['verificationprogress'] ?? 0.0).toDouble(),
      initialBlockDownload: json['initialblockdownload'] ?? false,
      chainWork: json['chainwork'] ?? '',
      sizeOnDisk: json['size_on_disk'] ?? 0,
      pruned: json['pruned'] ?? false,
    );
  }

  // Calculate sync percentage
  double get syncPercentage {
    if (headers == 0) return 0.0;
    return (blocks / headers) * 100;
  }

  // Check if node is synced (within 1 block)
  bool get isSynced {
    return (headers - blocks) <= 1;
  }
}