import '../gotham_node/consensus/amount.dart';

/// Gotham Network Types
enum GothamNetwork {
  mainnet,
  testnet,
  regtest,
}

/// Extension for network names
extension GothamNetworkExtension on GothamNetwork {
  String get name {
    switch (this) {
      case GothamNetwork.mainnet:
        return 'main';
      case GothamNetwork.testnet:
        return 'test';
      case GothamNetwork.regtest:
        return 'regtest';
    }
  }
  
  static GothamNetwork parseNetwork(String networkString) {
    switch (networkString.toLowerCase()) {
      case 'main':
      case 'mainnet':
        return GothamNetwork.mainnet;
      case 'test':
      case 'testnet':
        return GothamNetwork.testnet;
      case 'regtest':
        return GothamNetwork.regtest;
      default:
        return GothamNetwork.mainnet; // Default to mainnet
    }
  }
}

/// Gotham Wallet Model - Based on Gotham Core wallet structure
/// 
/// This represents a wallet container that can manage multiple addresses,
/// similar to how Gotham Core handles wallets.
class GothamWallet {
  final String name;
  final String? description;
  final bool isEncrypted;
  final bool isWatchOnly;
  final bool isHD; // Hierarchical Deterministic
  final String? seedPhrase; // Only for HD wallets
  final DateTime createdAt;
  final DateTime? lastUsed;
  final GothamNetwork network;
  final int version;
  final Map<String, dynamic>? metadata;

  // Wallet-level balance (sum of all addresses) - in satoshis for consensus compatibility
  final GAmount totalBalance;
  final GAmount confirmedBalance;
  final GAmount unconfirmedBalance;
  final GAmount immatureBalance;

  // Address management
  final int addressCount;
  final int usedAddressCount;
  final int changeAddressCount;

  // Transaction statistics
  final int transactionCount;
  final DateTime? lastTransactionTime;

  GothamWallet({
    required this.name,
    this.description,
    this.isEncrypted = false,
    this.isWatchOnly = false,
    this.isHD = true,
    this.seedPhrase,
    required this.createdAt,
    this.lastUsed,
    this.network = GothamNetwork.mainnet,
    this.version = 1,
    this.metadata,
    this.totalBalance = 0,
    this.confirmedBalance = 0,
    this.unconfirmedBalance = 0,
    this.immatureBalance = 0,
    this.addressCount = 0,
    this.usedAddressCount = 0,
    this.changeAddressCount = 0,
    this.transactionCount = 0,
    this.lastTransactionTime,
  });

  GothamWallet copyWith({
    String? name,
    String? description,
    bool? isEncrypted,
    bool? isWatchOnly,
    bool? isHD,
    String? seedPhrase,
    DateTime? createdAt,
    DateTime? lastUsed,
    GothamNetwork? network,
    int? version,
    Map<String, dynamic>? metadata,
    GAmount? totalBalance,
    GAmount? confirmedBalance,
    GAmount? unconfirmedBalance,
    GAmount? immatureBalance,
    int? addressCount,
    int? usedAddressCount,
    int? changeAddressCount,
    int? transactionCount,
    DateTime? lastTransactionTime,
  }) {
    return GothamWallet(
      name: name ?? this.name,
      description: description ?? this.description,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      isWatchOnly: isWatchOnly ?? this.isWatchOnly,
      isHD: isHD ?? this.isHD,
      seedPhrase: seedPhrase ?? this.seedPhrase,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      network: network ?? this.network,
      version: version ?? this.version,
      metadata: metadata ?? this.metadata,
      totalBalance: totalBalance ?? this.totalBalance,
      confirmedBalance: confirmedBalance ?? this.confirmedBalance,
      unconfirmedBalance: unconfirmedBalance ?? this.unconfirmedBalance,
      immatureBalance: immatureBalance ?? this.immatureBalance,
      addressCount: addressCount ?? this.addressCount,
      usedAddressCount: usedAddressCount ?? this.usedAddressCount,
      changeAddressCount: changeAddressCount ?? this.changeAddressCount,
      transactionCount: transactionCount ?? this.transactionCount,
      lastTransactionTime: lastTransactionTime ?? this.lastTransactionTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'isEncrypted': isEncrypted,
      'isWatchOnly': isWatchOnly,
      'isHD': isHD,
      'seedPhrase': seedPhrase,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastUsed': lastUsed?.millisecondsSinceEpoch,
      'network': network.name,
      'version': version,
      'metadata': metadata,
      'totalBalance': totalBalance,
      'confirmedBalance': confirmedBalance,
      'unconfirmedBalance': unconfirmedBalance,
      'immatureBalance': immatureBalance,
      'addressCount': addressCount,
      'usedAddressCount': usedAddressCount,
      'changeAddressCount': changeAddressCount,
      'transactionCount': transactionCount,
      'lastTransactionTime': lastTransactionTime?.millisecondsSinceEpoch,
    };
  }

  factory GothamWallet.fromJson(Map<String, dynamic> json) {
    return GothamWallet(
      name: json['name'] ?? '',
      description: json['description'],
      isEncrypted: json['isEncrypted'] ?? false,
      isWatchOnly: json['isWatchOnly'] ?? false,
      isHD: json['isHD'] ?? true,
      seedPhrase: json['seedPhrase'],
      createdAt: json['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : DateTime.now(),
      lastUsed: json['lastUsed'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastUsed'])
          : null,
      network: GothamNetworkExtension.parseNetwork(json['network'] ?? 'main'),
      version: json['version'] ?? 1,
      metadata: json['metadata'],
      totalBalance: (json['totalBalance'] ?? 0).toInt(),
      confirmedBalance: (json['confirmedBalance'] ?? 0).toInt(),
      unconfirmedBalance: (json['unconfirmedBalance'] ?? 0).toInt(),
      immatureBalance: (json['immatureBalance'] ?? 0).toInt(),
      addressCount: json['addressCount'] ?? 0,
      usedAddressCount: json['usedAddressCount'] ?? 0,
      changeAddressCount: json['changeAddressCount'] ?? 0,
      transactionCount: json['transactionCount'] ?? 0,
      lastTransactionTime: json['lastTransactionTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastTransactionTime'])
          : null,
    );
  }

  // Getters for wallet status
  bool get hasBalance => totalBalance > 0;
  bool get hasTransactions => transactionCount > 0;
  bool get isActive => hasBalance || hasTransactions;
  bool get needsBackup => isHD && seedPhrase != null && !isWatchOnly;
  
  String get displayName => description?.isNotEmpty == true ? description! : name;
  
  String get balanceFormatted => totalBalance.formatted;
  String get confirmedBalanceFormatted => confirmedBalance.formatted;
  
  String get statusDescription {
    if (isWatchOnly) return 'Watch-Only Wallet';
    if (isEncrypted) return 'Encrypted Wallet';
    if (isHD) return 'HD Wallet';
    return 'Standard Wallet';
  }

  @override
  String toString() {
    return 'GothamWallet(name: $name, balance: ${totalBalance.formattedAuto}, addresses: $addressCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GothamWallet && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}