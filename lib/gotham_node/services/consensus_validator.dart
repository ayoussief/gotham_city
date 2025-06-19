import 'dart:typed_data';
import '../models/block_header.dart';
import '../primitives/transaction.dart';
import '../config/gotham_chain_params.dart';

/// Lightweight consensus validation for Gotham SPV node
/// Just enough validation to keep the boat floating! 🚢
class ConsensusValidator {
  static final ConsensusValidator _instance = ConsensusValidator._internal();
  factory ConsensusValidator() => _instance;
  ConsensusValidator._internal();

  // Validation cache for performance
  final Map<String, bool> _validationCache = {};
  
  /// Validate block header (essential for SPV security)
  bool validateBlockHeader(BlockHeader header, BlockHeader? previousHeader) {
    final cacheKey = 'header_${header.hash}';
    if (_validationCache.containsKey(cacheKey)) {
      return _validationCache[cacheKey]!;
    }
    
    bool isValid = true;
    
    try {
      // 1. Basic structure validation
      if (!_validateHeaderStructure(header)) {
        isValid = false;
      }
      
      // 2. Check proof of work (simplified)
      if (isValid && !_validateProofOfWork(header)) {
        isValid = false;
      }
      
      // 3. Check timestamp rules
      if (isValid && !_validateTimestamp(header, previousHeader)) {
        isValid = false;
      }
      
      // 4. Check against checkpoints
      if (isValid && !_validateCheckpoint(header)) {
        isValid = false;
      }
      
    } catch (e) {
      print('Header validation error: $e');
      isValid = false;
    }
    
    _validationCache[cacheKey] = isValid;
    return isValid;
  }
  
  /// Validate transaction (basic validation for SPV)
  bool validateTransaction(CTransaction transaction) {
    final cacheKey = 'tx_${transaction.txid}';
    if (_validationCache.containsKey(cacheKey)) {
      return _validationCache[cacheKey]!;
    }
    
    bool isValid = true;
    
    try {
      // 1. Basic structure validation
      if (!_validateTransactionStructure(transaction)) {
        isValid = false;
      }
      
      // 2. Input/Output validation
      if (isValid && !_validateTransactionInputsOutputs(transaction)) {
        isValid = false;
      }
      
    } catch (e) {
      print('Transaction validation error: $e');
      isValid = false;
    }
    
    _validationCache[cacheKey] = isValid;
    return isValid;
  }
  
  /// Validate proof of work (simplified for SPV)
  bool _validateProofOfWork(BlockHeader header) {
    try {
      // For SPV, we do basic PoW validation
      // Full validation would require more complex calculations
      
      // Check if hash starts with enough zeros based on difficulty
      final hashInt = BigInt.parse(header.hash, radix: 16);
      final target = _bitsToTarget(header.bits);
      
      return hashInt <= target;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Validate timestamp rules
  bool _validateTimestamp(BlockHeader header, BlockHeader? previousHeader) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // Block timestamp cannot be more than 2 hours in the future
    if (header.timestamp > now + 7200) {
      return false;
    }
    
    // Block timestamp must be greater than previous block
    if (previousHeader != null && header.timestamp <= previousHeader.timestamp) {
      return false;
    }
    
    return true;
  }
  
  /// Validate against checkpoints
  bool _validateCheckpoint(BlockHeader header) {
    final checkpoint = GothamChainParams.getCheckpoint(header.height);
    if (checkpoint != null) {
      return header.hash == checkpoint;
    }
    return true; // No checkpoint at this height
  }
  
  /// Validate header structure
  bool _validateHeaderStructure(BlockHeader header) {
    // Check required fields
    if (header.hash.isEmpty || header.hash.length != 64) return false;
    if (header.previousBlockHash.isEmpty || header.previousBlockHash.length != 64) return false;
    if (header.merkleRoot.isEmpty || header.merkleRoot.length != 64) return false;
    if (header.height < 0) return false;
    if (header.timestamp <= 0) return false;
    if (header.bits <= 0) return false;
    if (header.nonce < 0) return false;
    
    return true;
  }
  
  /// Validate transaction structure
  bool _validateTransactionStructure(CTransaction transaction) {
    // Check basic structure
    if (transaction.txid.isEmpty || transaction.txid.length != 64) return false;
    if (transaction.inputs.isEmpty) return false;
    if (transaction.outputs.isEmpty) return false;
    if (transaction.version < 1) return false;
    if (transaction.lockTime < 0) return false;
    
    return true;
  }
  
  /// Validate transaction inputs and outputs
  bool _validateTransactionInputsOutputs(CTransaction transaction) {
    // Basic input validation
    for (final input in transaction.inputs) {
      if (input.previousTxid.isEmpty || input.previousTxid.length != 64) return false;
      if (input.outputIndex < 0) return false;
    }
    
    // Basic output validation
    int totalOutput = 0;
    for (final output in transaction.outputs) {
      if (output.value < 0) return false;
      if (output.value > 21000000 * 100000000) return false; // Max 21M coins
      
      totalOutput += output.value;
      if (totalOutput > 21000000 * 100000000) return false;
      
      if (output.scriptPubKey.isEmpty) return false;
    }
    
    return true;
  }
  
  /// Convert bits to target (simplified)
  BigInt _bitsToTarget(int bits) {
    final exponent = bits >> 24;
    final mantissa = bits & 0x00ffffff;
    
    if (exponent <= 3) {
      return BigInt.from(mantissa >> (8 * (3 - exponent)));
    } else {
      return BigInt.from(mantissa) << (8 * (exponent - 3));
    }
  }
  
  /// Clear validation cache
  void clearCache() {
    _validationCache.clear();
  }
  
  /// Get validation statistics
  Map<String, int> getValidationStats() {
    return {
      'cache_size': _validationCache.length,
      'valid_items': _validationCache.values.where((v) => v).length,
      'invalid_items': _validationCache.values.where((v) => !v).length,
    };
  }
}