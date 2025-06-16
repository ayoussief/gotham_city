class Wallet {
  final String address;
  final double balance;
  final String privateKey;
  final bool isImported;

  Wallet({
    required this.address,
    required this.balance,
    required this.privateKey,
    this.isImported = false,
  });

  Wallet copyWith({
    String? address,
    double? balance,
    String? privateKey,
    bool? isImported,
  }) {
    return Wallet(
      address: address ?? this.address,
      balance: balance ?? this.balance,
      privateKey: privateKey ?? this.privateKey,
      isImported: isImported ?? this.isImported,
    );
  }
}