import '../gotham_node/consensus/amount.dart';

/// Address Information Model - Based on Gotham Core address management
/// 
/// Represents a single address within a wallet, similar to how Gotham Core
/// manages individual addresses within a wallet container.
class AddressInfo {
  final String address;
  final GAmount balance;
  final GAmount confirmedBalance;
  final GAmount unconfirmedBalance;
  final String? label;
  final bool isChange; // Internal/change address vs receiving address
  final bool isInternal; // Same as isChange, for compatibility
  final int transactionCount;
  final DateTime? createdAt;
  final DateTime? lastUsed;
  final String? publicKey;
  final String? privateKey; // Only available if wallet is unlocked
  final int derivationIndex;
  final String derivationPath; // HD wallet derivation path
  final String addressType; // 'bech32', 'p2sh', 'p2pkh', etc.
  final String walletName; // Which wallet this address belongs to
  final bool isWatchOnly;
  final Map<String, dynamic>? metadata;

  AddressInfo({
    required this.address,
    required this.balance,
    this.confirmedBalance = 0,
    this.unconfirmedBalance = 0,
    this.label,
    this.isChange = false,
    bool? isInternal,
    this.transactionCount = 0,
    this.createdAt,
    this.lastUsed,
    this.publicKey,
    this.privateKey,
    this.derivationIndex = 0,
    this.derivationPath = '',
    required this.addressType,
    required this.walletName,
    this.isWatchOnly = false,
    this.metadata,
  }) : isInternal = isInternal ?? isChange;

  AddressInfo copyWith({
    String? address,
    GAmount? balance,
    GAmount? confirmedBalance,
    GAmount? unconfirmedBalance,
    String? label,
    bool? isChange,
    bool? isInternal,
    int? transactionCount,
    DateTime? createdAt,
    DateTime? lastUsed,
    String? publicKey,
    String? privateKey,
    int? derivationIndex,
    String? derivationPath,
    String? addressType,
    String? walletName,
    bool? isWatchOnly,
    Map<String, dynamic>? metadata,
  }) {
    return AddressInfo(
      address: address ?? this.address,
      balance: balance ?? this.balance,
      confirmedBalance: confirmedBalance ?? this.confirmedBalance,
      unconfirmedBalance: unconfirmedBalance ?? this.unconfirmedBalance,
      label: label ?? this.label,
      isChange: isChange ?? this.isChange,
      isInternal: isInternal ?? this.isInternal,
      transactionCount: transactionCount ?? this.transactionCount,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      publicKey: publicKey ?? this.publicKey,
      privateKey: privateKey ?? this.privateKey,
      derivationIndex: derivationIndex ?? this.derivationIndex,
      derivationPath: derivationPath ?? this.derivationPath,
      addressType: addressType ?? this.addressType,
      walletName: walletName ?? this.walletName,
      isWatchOnly: isWatchOnly ?? this.isWatchOnly,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'balance': balance,
      'confirmedBalance': confirmedBalance,
      'unconfirmedBalance': unconfirmedBalance,
      'label': label,
      'isChange': isChange,
      'isInternal': isInternal,
      'transactionCount': transactionCount,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'lastUsed': lastUsed?.millisecondsSinceEpoch,
      'publicKey': publicKey,
      'privateKey': privateKey, // Note: Be careful with private key storage
      'derivationIndex': derivationIndex,
      'derivationPath': derivationPath,
      'addressType': addressType,
      'walletName': walletName,
      'isWatchOnly': isWatchOnly,
      'metadata': metadata,
    };
  }

  factory AddressInfo.fromJson(Map<String, dynamic> json) {
    return AddressInfo(
      address: json['address'] ?? '',
      balance: (json['balance'] ?? 0).toInt(),
      confirmedBalance: (json['confirmedBalance'] ?? 0).toInt(),
      unconfirmedBalance: (json['unconfirmedBalance'] ?? 0).toInt(),
      label: json['label'],
      isChange: json['isChange'] ?? false,
      isInternal: json['isInternal'] ?? json['isChange'] ?? false,
      transactionCount: json['transactionCount'] ?? 0,
      createdAt: json['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : null,
      lastUsed: json['lastUsed'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastUsed'])
          : null,
      publicKey: json['publicKey'],
      privateKey: json['privateKey'],
      derivationIndex: json['derivationIndex'] ?? 0,
      derivationPath: json['derivationPath'] ?? '',
      addressType: json['addressType'] ?? 'unknown',
      walletName: json['walletName'] ?? '',
      isWatchOnly: json['isWatchOnly'] ?? false,
      metadata: json['metadata'],
    );
  }

  bool get hasBalance => balance > 0;
  bool get hasConfirmedBalance => confirmedBalance > 0;
  bool get hasUnconfirmedBalance => unconfirmedBalance > 0;
  bool get hasTransactions => transactionCount > 0;
  bool get isUsed => hasTransactions || hasBalance;
  bool get isReceivingAddress => !isChange && !isInternal;
  bool get isChangeAddress => isChange || isInternal;
  
  String get displayAddress {
    if (address.length > 20) {
      return '${address.substring(0, 10)}...${address.substring(address.length - 10)}';
    }
    return address;
  }

  String get balanceFormatted => balance.formatted;
  String get confirmedBalanceFormatted => confirmedBalance.formatted;
  String get unconfirmedBalanceFormatted => unconfirmedBalance.formatted;
  
  String get typeDescription {
    switch (addressType.toLowerCase()) {
      case 'bech32':
        return 'Native SegWit (Bech32)';
      case 'bech32m':
        return 'Taproot (Bech32m)';
      case 'p2sh':
        return 'SegWit (P2SH)';
      case 'p2pkh':
        return 'Legacy (P2PKH)';
      default:
        return 'Unknown';
    }
  }

  String get purposeDescription {
    if (isWatchOnly) return 'Watch-Only';
    if (isChangeAddress) return 'Change Address';
    if (isReceivingAddress) return 'Receiving Address';
    return 'Unknown Purpose';
  }

  String get displayLabel {
    if (label?.isNotEmpty == true) return label!;
    if (isChangeAddress) return 'Change Address #$derivationIndex';
    return 'Address #$derivationIndex';
  }

  @override
  String toString() {
    return 'AddressInfo(address: $address, balance: ${balance.formattedAuto}, wallet: $walletName, label: $label)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AddressInfo && 
           other.address == address && 
           other.walletName == walletName;
  }

  @override
  int get hashCode => Object.hash(address, walletName);
}