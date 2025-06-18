class AddressBookEntry {
  final String id;
  final String name;
  final String address;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  AddressBookEntry({
    required this.id,
    required this.name,
    required this.address,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  AddressBookEntry copyWith({
    String? id,
    String? name,
    String? address,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AddressBookEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'description': description,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory AddressBookEntry.fromJson(Map<String, dynamic> json) {
    return AddressBookEntry(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      description: json['description'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] ?? 0),
    );
  }

  String get displayAddress {
    if (address.length > 20) {
      return '${address.substring(0, 10)}...${address.substring(address.length - 10)}';
    }
    return address;
  }

  String get addressType {
    if (address.startsWith('gt1')) return 'Bech32';
    if (address.startsWith('3')) return 'P2SH';
    if (address.startsWith('1')) return 'P2PKH';
    return 'Unknown';
  }

  @override
  String toString() {
    return 'AddressBookEntry(id: $id, name: $name, address: $address)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AddressBookEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}