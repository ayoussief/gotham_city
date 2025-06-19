import 'dart:typed_data';
import 'dart:math';

// BIP157/158 Compact Block Filter implementation
class CompactFilter {
  final int filterType;
  final Uint8List filterData;
  final String blockHash;
  final int blockHeight;
  
  CompactFilter({
    required this.filterType,
    required this.filterData,
    required this.blockHash,
    required this.blockHeight,
  });
  
  factory CompactFilter.fromBytes(Uint8List data, String blockHash, int blockHeight) {
    if (data.length < 1) {
      throw ArgumentError('Filter data too short');
    }
    
    int filterType = data[0];
    Uint8List filterData = data.sublist(1);
    
    return CompactFilter(
      filterType: filterType,
      filterData: filterData,
      blockHash: blockHash,
      blockHeight: blockHeight,
    );
  }
  
  // Check if the filter might contain any of the given elements
  bool matchAny(List<Uint8List> elements) {
    if (elements.isEmpty || filterData.isEmpty) {
      return false;
    }
    
    try {
      GolombFilter golomb = GolombFilter.fromBytes(filterData);
      return golomb.matchAny(elements);
    } catch (e) {
      print('Error matching filter: $e');
      return false;
    }
  }
  
  // Check if the filter might contain a specific element
  bool match(Uint8List element) {
    return matchAny([element]);
  }
  
  // Convert to database map
  Map<String, dynamic> toDbMap() {
    return {
      'block_hash': blockHash,
      'block_height': blockHeight,
      'filter_type': filterType,
      'filter_data': filterData,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }
  
  // Create from database map
  factory CompactFilter.fromDbMap(Map<String, dynamic> map) {
    return CompactFilter(
      filterType: map['filter_type'],
      filterData: map['filter_data'],
      blockHash: map['block_hash'],
      blockHeight: map['block_height'],
    );
  }
  
  @override
  String toString() {
    return 'CompactFilter(height: $blockHeight, hash: ${blockHash.substring(0, 8)}..., size: ${filterData.length})';
  }
}

// Compact Filter Header (BIP157)
class CompactFilterHeader {
  final String filterHash;
  final String previousFilterHeader;
  final String blockHash;
  final int blockHeight;
  
  CompactFilterHeader({
    required this.filterHash,
    required this.previousFilterHeader,
    required this.blockHash,
    required this.blockHeight,
  });
  
  factory CompactFilterHeader.fromJson(Map<String, dynamic> json) {
    return CompactFilterHeader(
      filterHash: json['filter_hash'] ?? '',
      previousFilterHeader: json['previous_filter_header'] ?? '',
      blockHash: json['block_hash'] ?? '',
      blockHeight: json['block_height'] ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'filter_hash': filterHash,
      'previous_filter_header': previousFilterHeader,
      'block_hash': blockHash,
      'block_height': blockHeight,
    };
  }
  
  Map<String, dynamic> toDbMap() {
    return {
      'filter_hash': filterHash,
      'previous_filter_header': previousFilterHeader,
      'block_hash': blockHash,
      'block_height': blockHeight,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }
  
  factory CompactFilterHeader.fromDbMap(Map<String, dynamic> map) {
    return CompactFilterHeader(
      filterHash: map['filter_hash'],
      previousFilterHeader: map['previous_filter_header'],
      blockHash: map['block_hash'],
      blockHeight: map['block_height'],
    );
  }
  
  @override
  String toString() {
    return 'CompactFilterHeader(height: $blockHeight, hash: ${blockHash.substring(0, 8)}...)';
  }
}

// Golomb-coded set filter implementation (simplified)
class GolombFilter {
  final Uint8List data;
  final int p; // False positive rate parameter
  final int m; // Hash function count parameter
  
  GolombFilter({
    required this.data,
    this.p = 19,
    this.m = 784931,
  });
  
  factory GolombFilter.fromBytes(Uint8List data) {
    return GolombFilter(data: data);
  }
  
  // Check if any of the elements might be in the set
  bool matchAny(List<Uint8List> elements) {
    if (data.isEmpty) return false;
    
    try {
      // Simplified implementation - in production, you'd want a proper
      // Golomb-coded set decoder here
      return _simpleMatch(elements);
    } catch (e) {
      print('Error in Golomb filter matching: $e');
      return false;
    }
  }
  
  // Simplified matching logic (replace with proper Golomb decoding)
  bool _simpleMatch(List<Uint8List> elements) {
    // This is a placeholder implementation
    // In a real implementation, you would:
    // 1. Decode the Golomb-coded set from the filter data
    // 2. Hash each element with SipHash using the block hash as key
    // 3. Check if the hash modulo the set size is in the decoded set
    
    // For now, we'll use a simple hash-based approach
    for (var element in elements) {
      int hash = _simpleHash(element);
      if (_checkHash(hash)) {
        return true;
      }
    }
    return false;
  }
  
  int _simpleHash(Uint8List element) {
    int hash = 0;
    for (int byte in element) {
      hash = ((hash * 31) + byte) & 0xFFFFFFFF;
    }
    return hash;
  }
  
  bool _checkHash(int hash) {
    // Simplified check - in reality, this would check against the decoded Golomb set
    int index = hash % data.length;
    return data[index] != 0;
  }
}

// Filter matching result
class FilterMatchResult {
  final bool matched;
  final List<String> matchedElements;
  final CompactFilter filter;
  
  FilterMatchResult({
    required this.matched,
    required this.matchedElements,
    required this.filter,
  });
  
  @override
  String toString() {
    return 'FilterMatchResult(matched: $matched, elements: ${matchedElements.length})';
  }
}