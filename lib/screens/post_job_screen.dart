import 'package:flutter/material.dart';
import '../models/job.dart';
import '../theme/app_theme.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rewardController = TextEditingController();
  
  JobType _selectedType = JobType.computation;
  bool _isPosting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  Future<void> _postJob() async {
    if (!_formKey.currentState!.validate() || _isPosting) return;

    setState(() {
      _isPosting = true;
    });

    try {
      // Mock job posting - will be replaced with actual backend
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job posted successfully!'),
            backgroundColor: AppTheme.successGreen,
            duration: Duration(seconds: 3),
          ),
        );

        // Clear form only after successful post
        _clearForm();
      }
    } catch (e) {
      print('Error posting job: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post job: $e'),
            backgroundColor: AppTheme.dangerRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }
  
  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _rewardController.clear();
    setState(() {
      _selectedType = JobType.computation;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post New Job'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a new job',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Fill in the details below to post your job to the network',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _buildJobTypeSelector(),
              const SizedBox(height: 24),
              _buildTitleField(),
              const SizedBox(height: 16),
              _buildDescriptionField(),
              const SizedBox(height: 16),
              _buildRewardField(),
              const SizedBox(height: 24),
              _buildJobTypeInfo(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPosting ? null : _postJob,
                  child: _isPosting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryBlack,
                          ),
                        )
                      : const Text('Post Job'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Job Type',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.mediumGray,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.lightGray),
          ),
          child: Column(
            children: JobType.values.map((type) {
              return RadioListTile<JobType>(
                title: Text(_getJobTypeTitle(type)),
                subtitle: Text(_getJobTypeDescription(type)),
                value: type,
                groupValue: _selectedType,
                onChanged: (JobType? value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                    });
                  }
                },
                activeColor: AppTheme.accentGold,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: 'Job Title',
        hintText: 'Enter a descriptive title for your job',
        prefixIcon: Icon(Icons.title),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a job title';
        }
        if (value.length < 5) {
          return 'Title must be at least 5 characters long';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Job Description',
        hintText: 'Provide detailed information about the job requirements',
        prefixIcon: Icon(Icons.description),
      ),
      maxLines: 4,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a job description';
        }
        if (value.length < 20) {
          return 'Description must be at least 20 characters long';
        }
        return null;
      },
    );
  }

  Widget _buildRewardField() {
    return TextFormField(
      controller: _rewardController,
      decoration: const InputDecoration(
        labelText: 'Reward (BTC)',
        hintText: '0.001',
        prefixIcon: Icon(Icons.monetization_on),
        suffixText: 'BTC',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a reward amount';
        }
        final reward = double.tryParse(value);
        if (reward == null) {
          return 'Please enter a valid number';
        }
        if (reward <= 0) {
          return 'Reward must be greater than 0';
        }
        if (reward < 0.00001) {
          return 'Minimum reward is 0.00001 BTC';
        }
        return null;
      },
    );
  }

  Widget _buildJobTypeInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getJobTypeIcon(_selectedType),
                color: AppTheme.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _getJobTypeTitle(_selectedType),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.accentBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getJobTypeDetailedDescription(_selectedType),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.accentBlue,
            ),
          ),
        ],
      ),
    );
  }

  String _getJobTypeTitle(JobType type) {
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

  String _getJobTypeDescription(JobType type) {
    switch (type) {
      case JobType.computation:
        return 'CPU/GPU intensive tasks';
      case JobType.storage:
        return 'File storage and retrieval';
      case JobType.network:
        return 'Network relay and routing';
      case JobType.custom:
        return 'Custom algorithms and scripts';
    }
  }

  String _getJobTypeDetailedDescription(JobType type) {
    switch (type) {
      case JobType.computation:
        return 'Computation jobs involve CPU or GPU intensive tasks such as data processing, machine learning model training, mathematical calculations, or cryptographic operations. Workers will execute your computational tasks and return the results.';
      case JobType.storage:
        return 'Storage jobs involve storing files or data for a specified period. This includes file hosting, backup services, distributed storage, and data archival. Workers will store your data securely and make it available when needed.';
      case JobType.network:
        return 'Network jobs involve providing network services such as relay nodes, proxy services, VPN endpoints, or routing services. Workers will contribute their network resources to support distributed network operations.';
      case JobType.custom:
        return 'Custom jobs allow you to define specific algorithms, scripts, or unique tasks that don\'t fit into standard categories. Workers will execute your custom code or perform specialized tasks according to your requirements.';
    }
  }

  IconData _getJobTypeIcon(JobType type) {
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
}