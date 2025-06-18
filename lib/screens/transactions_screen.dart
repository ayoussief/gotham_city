import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/transaction.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final WalletService _walletService = WalletService();
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  DateTime? _lastRefresh;
  StreamSubscription? _transactionStreamSub;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadTransactions();
  }

  Future<void> _initializeAndLoadTransactions() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      if (!_isInitialized) {
        await _walletService.initialize();
        
        // Listen to transaction updates (store subscription for disposal)
        _transactionStreamSub = _walletService.transactionsStream.listen((transactions) {
          if (mounted && !_transactionsEqual(_transactions, transactions)) {
            setState(() {
              _transactions = transactions;
            });
          }
        });
        
        _isInitialized = true;
      }

      // Load initial transactions
      await _loadTransactions();
    } catch (e) {
      print('Error initializing transactions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load transactions: $e'),
            backgroundColor: AppTheme.dangerRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final transactions = await _walletService.getTransactionHistory();
      if (mounted && !_transactionsEqual(_transactions, transactions)) {
        setState(() {
          _transactions = transactions;
        });
      }
    } catch (e) {
      // If no wallet or error, show mock data for demo
      final mockTransactions = [
          Transaction(
            txid: 'abc123def456ghi789jkl012mno345pqr678stu901vwx234yz',
            amount: 0.001,
            type: TransactionType.jobReward,
            status: TransactionStatus.confirmed,
            timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
            fromAddress: '',
            toAddress: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
            confirmations: 6,
            fee: 0.00001,
            jobId: '1',
            description: 'Reward for Data Processing Task',
          ),
          Transaction(
            txid: 'def456ghi789jkl012mno345pqr678stu901vwx234yz567abc',
            amount: 0.0005,
            type: TransactionType.jobPayment,
            status: TransactionStatus.confirmed,
            timestamp: DateTime.now().subtract(const Duration(hours: 1)),
            fromAddress: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
            toAddress: '',
            confirmations: 3,
            fee: 0.00001,
            jobId: '2',
            description: 'Payment for File Storage Service',
          ),
          Transaction(
            txid: 'ghi789jkl012mno345pqr678stu901vwx234yz567abc123def',
            amount: 0.01,
            type: TransactionType.received,
            status: TransactionStatus.confirmed,
            timestamp: DateTime.now().subtract(const Duration(hours: 2)),
            fromAddress: 'bc1qsender123456789abcdefghijklmnopqrstuvwxyz',
            toAddress: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
            confirmations: 12,
            fee: 0.00002,
            description: 'Received Bitcoin',
          ),
          Transaction(
            txid: 'jkl012mno345pqr678stu901vwx234yz567abc123def456ghi',
            amount: 0.005,
            type: TransactionType.sent,
            status: TransactionStatus.confirmed,
            timestamp: DateTime.now().subtract(const Duration(hours: 4)),
            fromAddress: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
            toAddress: 'bc1qrecipient987654321zyxwvutsrqponmlkjihgfed',
            confirmations: 24,
            fee: 0.00003,
            description: 'Sent Bitcoin',
          ),
        ];
      
      if (mounted && !_transactionsEqual(_transactions, mockTransactions)) {
        setState(() {
          _transactions = mockTransactions;
        });
      }
    }
    
    _lastRefresh = DateTime.now();
  }
  
  bool _transactionsEqual(List<Transaction> list1, List<Transaction> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].txid != list2[i].txid || 
          list1[i].status != list2[i].status ||
          list1[i].confirmations != list2[i].confirmations) {
        return false;
      }
    }
    return true;
  }

  Future<void> _refreshTransactions() async {
    await _loadTransactions();
  }

  Color _getTransactionColor(TransactionType type) {
    switch (type) {
      case TransactionType.received:
      case TransactionType.jobReward:
      case TransactionType.refund:
        return AppTheme.successGreen;
      case TransactionType.sent:
      case TransactionType.jobPayment:
        return AppTheme.dangerRed;
    }
  }

  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.received:
        return Icons.call_received;
      case TransactionType.sent:
        return Icons.call_made;
      case TransactionType.jobPayment:
        return Icons.work;
      case TransactionType.jobReward:
        return Icons.monetization_on;
      case TransactionType.refund:
        return Icons.undo;
    }
  }

  String _getTransactionPrefix(TransactionType type) {
    return type.isIncoming ? '+' : '-';
  }

  @override
  void dispose() {
    _transactionStreamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
            tooltip: 'Refresh Transactions',
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingView() : _buildTransactionsList(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppTheme.accentGold,
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long,
              size: 64,
              color: AppTheme.mediumGray,
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Your transaction history will appear here',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _loadTransactions();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final transaction = _transactions[index];
          return _buildTransactionCard(transaction);
        },
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final color = _getTransactionColor(transaction.type);
    final icon = _getTransactionIcon(transaction.type);
    final prefix = _getTransactionPrefix(transaction.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showTransactionDetails(transaction),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.typeText,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (transaction.description != null)
                      Text(
                        transaction.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(transaction.timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$prefix${transaction.amount.toStringAsFixed(8)} BTC',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        transaction.confirmations >= 6
                            ? Icons.check_circle
                            : Icons.hourglass_empty,
                        color: transaction.confirmations >= 6
                            ? AppTheme.successGreen
                            : AppTheme.warningOrange,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${transaction.confirmations}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: transaction.confirmations >= 6
                              ? AppTheme.successGreen
                              : AppTheme.warningOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionDetails(Transaction transaction) {
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
                  child: _buildTransactionDetailsContent(transaction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionDetailsContent(Transaction transaction) {
    final color = _getTransactionColor(transaction.type);
    final icon = _getTransactionIcon(transaction.type);
    final prefix = _getTransactionPrefix(transaction.type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.typeText,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$prefix${transaction.amount.toStringAsFixed(8)} BTC',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (transaction.description != null) ...[
          _buildDetailRow('Description', transaction.description!),
          const SizedBox(height: 16),
        ],
        _buildDetailRow('Transaction Hash', transaction.txHash, copyable: true),
        const SizedBox(height: 16),
        _buildDetailRow('Amount', '${transaction.amount.toStringAsFixed(8)} BTC'),
        const SizedBox(height: 16),
        _buildDetailRow('Fee', '${transaction.fee.toStringAsFixed(8)} BTC'),
        const SizedBox(height: 16),
        _buildDetailRow('Confirmations', transaction.confirmations.toString()),
        const SizedBox(height: 16),
        _buildDetailRow('Timestamp', _formatFullDateTime(transaction.timestamp)),
        if (transaction.fromAddress != null) ...[
          const SizedBox(height: 16),
          _buildDetailRow('From', transaction.fromAddress!, copyable: true),
        ],
        if (transaction.toAddress != null) ...[
          const SizedBox(height: 16),
          _buildDetailRow('To', transaction.toAddress!, copyable: true),
        ],
        if (transaction.jobId != null) ...[
          const SizedBox(height: 16),
          _buildDetailRow('Job ID', transaction.jobId!),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool copyable = false}) {
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
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: copyable ? 'monospace' : null,
                ),
              ),
            ),
            if (copyable)
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => _copyToClipboard(value),
                tooltip: 'Copy',
              ),
          ],
        ),
      ],
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        backgroundColor: AppTheme.successGreen,
      ),
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

  String _formatFullDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}