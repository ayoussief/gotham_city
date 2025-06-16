enum TransactionType {
  sent,
  received,
  jobPayment,
  jobReward,
  refund,
}

class Transaction {
  final String id;
  final String txHash;
  final double amount;
  final TransactionType type;
  final DateTime timestamp;
  final String? fromAddress;
  final String? toAddress;
  final int confirmations;
  final double fee;
  final String? jobId;
  final String? description;

  Transaction({
    required this.id,
    required this.txHash,
    required this.amount,
    required this.type,
    required this.timestamp,
    this.fromAddress,
    this.toAddress,
    this.confirmations = 0,
    this.fee = 0.0,
    this.jobId,
    this.description,
  });

  Transaction copyWith({
    String? id,
    String? txHash,
    double? amount,
    TransactionType? type,
    DateTime? timestamp,
    String? fromAddress,
    String? toAddress,
    int? confirmations,
    double? fee,
    String? jobId,
    String? description,
  }) {
    return Transaction(
      id: id ?? this.id,
      txHash: txHash ?? this.txHash,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      confirmations: confirmations ?? this.confirmations,
      fee: fee ?? this.fee,
      jobId: jobId ?? this.jobId,
      description: description ?? this.description,
    );
  }

  String get typeText {
    switch (type) {
      case TransactionType.sent:
        return 'Sent';
      case TransactionType.received:
        return 'Received';
      case TransactionType.jobPayment:
        return 'Job Payment';
      case TransactionType.jobReward:
        return 'Job Reward';
      case TransactionType.refund:
        return 'Refund';
    }
  }

  bool get isIncoming {
    return type == TransactionType.received || 
           type == TransactionType.jobReward || 
           type == TransactionType.refund;
  }
}

extension TransactionTypeExtension on TransactionType {
  bool get isIncoming {
    return this == TransactionType.received || 
           this == TransactionType.jobReward || 
           this == TransactionType.refund;
  }
}