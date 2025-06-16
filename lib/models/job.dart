enum JobStatus {
  pending,
  confirmed,
  completed,
  failed,
  refunded,
}

enum JobType {
  computation,
  storage,
  network,
  custom,
}

class Job {
  final String id;
  final String title;
  final String description;
  final double reward;
  final JobType type;
  final JobStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? txHash;
  final int confirmations;

  Job({
    required this.id,
    required this.title,
    required this.description,
    required this.reward,
    required this.type,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.txHash,
    this.confirmations = 0,
  });

  Job copyWith({
    String? id,
    String? title,
    String? description,
    double? reward,
    JobType? type,
    JobStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? txHash,
    int? confirmations,
  }) {
    return Job(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      reward: reward ?? this.reward,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      txHash: txHash ?? this.txHash,
      confirmations: confirmations ?? this.confirmations,
    );
  }

  String get statusText {
    switch (status) {
      case JobStatus.pending:
        return 'Pending';
      case JobStatus.confirmed:
        return 'Confirmed';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.failed:
        return 'Failed';
      case JobStatus.refunded:
        return 'Refunded';
    }
  }

  String get typeText {
    switch (type) {
      case JobType.computation:
        return 'Computation';
      case JobType.storage:
        return 'Storage';
      case JobType.network:
        return 'Network';
      case JobType.custom:
        return 'Custom';
    }
  }
}