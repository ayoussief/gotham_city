import '../gotham_node/consensus/amount.dart';

enum TransactionType {
  sent,
  received,
  jobPayment,
  jobReward,
  refund,
}

enum TransactionStatus {
  pending,
  confirmed,
  failed,
}

class Transaction {
  final String txid;
  final GAmount amount;
  final GAmount fee;
  final int confirmations;
  final DateTime timestamp;
  final TransactionType type;
  final TransactionStatus status;
  final String fromAddress;
  final String toAddress;
  final String? jobId;
  final String? description;

  Transaction({
    required this.txid,
    required this.amount,
    required this.fee,
    required this.confirmations,
    required this.timestamp,
    required this.type,
    required this.status,
    required this.fromAddress,
    required this.toAddress,
    this.jobId,
    this.description,
  });

  // Legacy compatibility
  String get id => txid;
  String get txHash => txid;

  Transaction copyWith({
    String? txid,
    GAmount? amount,
    GAmount? fee,
    TransactionType? type,
    TransactionStatus? status,
    DateTime? timestamp,
    String? fromAddress,
    String? toAddress,
    int? confirmations,
    double? fee,
    String? jobId,
    String? description,
  }) {
    return Transaction(
      txid: txid ?? this.txid,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      status: status ?? this.status,
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