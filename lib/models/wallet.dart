import '../gotham_node/consensus/amount.dart';

class Wallet {
  final String address;
  final GAmount balance;
  final String privateKey;
  final bool isImported;
  final String? seedPhrase;
  final DateTime? createdAt;
  final String network;

  Wallet({
    required this.address,
    required this.balance,
    required this.privateKey,
    this.isImported = false,
    this.seedPhrase,
    this.createdAt,
    this.network = 'gotham',
  });

  Wallet copyWith({
    String? address,
    GAmount? balance,
    String? privateKey,
    bool? isImported,
    String? seedPhrase,
    DateTime? createdAt,
    String? network,
  }) {
    return Wallet(
      address: address ?? this.address,
      balance: balance ?? this.balance,
      privateKey: privateKey ?? this.privateKey,
      isImported: isImported ?? this.isImported,
      seedPhrase: seedPhrase ?? this.seedPhrase,
      createdAt: createdAt ?? this.createdAt,
      network: network ?? this.network,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'balance': balance,
      'privateKey': privateKey,
      'isImported': isImported,
      'seedPhrase': seedPhrase,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'network': network,
    };
  }

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      address: json['address'] ?? '',
      balance: (json['balance'] ?? 0.0).toDouble(),
      privateKey: json['privateKey'] ?? '',
      isImported: json['isImported'] ?? false,
      seedPhrase: json['seedPhrase'],
      createdAt: json['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : null,
      network: json['network'] ?? 'gotham',
    );
  }

  bool get isHDWallet => seedPhrase != null;
  bool get isLegacyAddress => address.startsWith('1') || address.startsWith('3');
  bool get isBech32Address => address.startsWith('gt1');
  
  String get displayAddress {
    if (address.length > 20) {
      return '${address.substring(0, 10)}...${address.substring(address.length - 10)}';
    }
    return address;
  }

  String get balanceFormatted => '${balance.toStringAsFixed(8)} GTC';
}