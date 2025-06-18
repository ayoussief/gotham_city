class AddressInfo {
  final String address;
  final double balance;
  final String? label;
  final bool isChange;
  final int transactionCount;
  final DateTime? createdAt;
  final DateTime? lastUsed;
  final String? publicKey;
  final int derivationIndex;
  final String addressType;

  AddressInfo({
    required this.address,
    required this.balance,
    this.label,
    this.isChange = false,
    this.transactionCount = 0,
    this.createdAt,
    this.lastUsed,
    this.publicKey,
    this.derivationIndex = 0,
    required this.addressType,
  });

  AddressInfo copyWith({
    String? address,
    double? balance,
    String? label,
    bool? isChange,
    int? transactionCount,
    DateTime? createdAt,
    DateTime? lastUsed,
    String? publicKey,
    int? derivationIndex,
    String? addressType,
  }) {
    return AddressInfo(
      address: address ?? this.address,
      balance: balance ?? this.balance,
      label: label ?? this.label,
      isChange: isChange ?? this.isChange,
      transactionCount: transactionCount ?? this.transactionCount,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      publicKey: publicKey ?? this.publicKey,
      derivationIndex: derivationIndex ?? this.derivationIndex,
      addressType: addressType ?? this.addressType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'balance': balance,
      'label': label,
      'isChange': isChange,
      'transactionCount': transactionCount,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'lastUsed': lastUsed?.millisecondsSinceEpoch,
      'publicKey': publicKey,
      'derivationIndex': derivationIndex,
      'addressType': addressType,
    };
  }

  factory AddressInfo.fromJson(Map<String, dynamic> json) {
    return AddressInfo(
      address: json['address'] ?? '',
      balance: (json['balance'] ?? 0.0).toDouble(),
      label: json['label'],
      isChange: json['isChange'] ?? false,
      transactionCount: json['transactionCount'] ?? 0,
      createdAt: json['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : null,
      lastUsed: json['lastUsed'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastUsed'])
          : null,
      publicKey: json['publicKey'],
      derivationIndex: json['derivationIndex'] ?? 0,
      addressType: json['addressType'] ?? 'unknown',
    );
  }

  bool get hasBalance => balance > 0;
  bool get hasTransactions => transactionCount > 0;
  bool get isUsed => hasTransactions || hasBalance;
  
  String get displayAddress {
    if (address.length > 20) {
      return '${address.substring(0, 10)}...${address.substring(address.length - 10)}';
    }
    return address;
  }

  String get balanceFormatted => '${balance.toStringAsFixed(8)} GTC';
  
  String get typeDescription {
    switch (addressType.toLowerCase()) {
      case 'bech32':
        return 'Native SegWit (Bech32)';
      case 'p2sh':
        return 'SegWit (P2SH)';
      case 'p2pkh':
        return 'Legacy (P2PKH)';
      default:
        return 'Unknown';
    }
  }

  @override
  String toString() {
    return 'AddressInfo(address: $address, balance: $balance, label: $label)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AddressInfo && other.address == address;
  }

  @override
  int get hashCode => address.hashCode;
}