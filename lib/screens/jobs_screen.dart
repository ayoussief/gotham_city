import 'package:flutter/material.dart';
import '../models/job.dart';
import '../theme/app_theme.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  List<Job> _jobs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  void _loadJobs() {
    setState(() {
      _isLoading = true;
    });

    // Mock job data - will be replaced with actual backend
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _jobs = [
          Job(
            id: '1',
            title: 'Data Processing Task',
            description: 'Process large dataset for machine learning model training',
            reward: 0.001,
            type: JobType.computation,
            status: JobStatus.completed,
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
            completedAt: DateTime.now().subtract(const Duration(minutes: 30)),
            txHash: 'abc123def456',
            confirmations: 6,
          ),
          Job(
            id: '2',
            title: 'File Storage Service',
            description: 'Store encrypted files for 30 days',
            reward: 0.0005,
            type: JobType.storage,
            status: JobStatus.confirmed,
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
            txHash: 'def456ghi789',
            confirmations: 3,
          ),
          Job(
            id: '3',
            title: 'Network Relay Node',
            description: 'Provide network relay services for distributed system',
            reward: 0.002,
            type: JobType.network,
            status: JobStatus.pending,
            createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
            confirmations: 0,
          ),
          Job(
            id: '4',
            title: 'Custom Algorithm Execution',
            description: 'Execute custom cryptographic algorithm',
            reward: 0.0015,
            type: JobType.custom,
            status: JobStatus.failed,
            createdAt: DateTime.now().subtract(const Duration(hours: 3)),
            txHash: 'ghi789jkl012',
            confirmations: 1,
          ),
        ];
        _isLoading = false;
      });
    });
  }

  Color _getStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.pending:
        return AppTheme.warningOrange;
      case JobStatus.confirmed:
        return AppTheme.accentBlue;
      case JobStatus.completed:
        return AppTheme.successGreen;
      case JobStatus.failed:
        return AppTheme.dangerRed;
      case JobStatus.refunded:
        return AppTheme.mediumGray;
    }
  }

  IconData _getTypeIcon(JobType type) {
    switch (type) {
      case JobType.computation:
        return Icons.memory;
      case JobType.storage:
        return Icons.storage;
      case JobType.network:
        return Icons.network_check;
      case JobType.custom:
        return Icons.code;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJobs,
            tooltip: 'Refresh Jobs',
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingView() : _buildJobsList(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppTheme.accentGold,
      ),
    );
  }

  Widget _buildJobsList() {
    if (_jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.work_off,
              size: 64,
              color: AppTheme.mediumGray,
            ),
            const SizedBox(height: 16),
            Text(
              'No jobs found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Jobs you accept will appear here',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _loadJobs();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _jobs.length,
        itemBuilder: (context, index) {
          final job = _jobs[index];
          return _buildJobCard(job);
        },
      ),
    );
  }

  Widget _buildJobCard(Job job) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showJobDetails(job),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getTypeIcon(job.type),
                    color: AppTheme.accentGold,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      job.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(job.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(job.status).withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      job.statusText,
                      style: TextStyle(
                        color: _getStatusColor(job.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                job.description,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.monetization_on,
                    color: AppTheme.accentGold,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${job.reward.toStringAsFixed(8)} BTC',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.accentGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    job.typeText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (job.confirmations > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.successGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${job.confirmations} confirmations',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showJobDetails(Job job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.darkGray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.mediumGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: _buildJobDetailsContent(job),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobDetailsContent(Job job) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getTypeIcon(job.type),
              color: AppTheme.accentGold,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                job.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(job.status).withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getStatusColor(job.status).withOpacity(0.5),
            ),
          ),
          child: Text(
            job.statusText,
            style: TextStyle(
              color: _getStatusColor(job.status),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildDetailRow('Description', job.description),
        const SizedBox(height: 16),
        _buildDetailRow('Reward', '${job.reward.toStringAsFixed(8)} BTC'),
        const SizedBox(height: 16),
        _buildDetailRow('Type', job.typeText),
        const SizedBox(height: 16),
        _buildDetailRow('Created', _formatDateTime(job.createdAt)),
        if (job.completedAt != null) ...[
          const SizedBox(height: 16),
          _buildDetailRow('Completed', _formatDateTime(job.completedAt!)),
        ],
        if (job.txHash != null) ...[
          const SizedBox(height: 16),
          _buildDetailRow('Transaction', job.txHash!),
        ],
        const SizedBox(height: 16),
        _buildDetailRow('Confirmations', job.confirmations.toString()),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.accentGold,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}