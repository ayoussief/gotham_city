import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final Wallet wallet;
  final WalletService walletService;

  const TransactionHistoryScreen({
    super.key,
    required this.wallet,
    required this.walletService,
  });

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _isLoading = false;
  String _filterType = 'all'; // all, sent, received
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get transaction history from wallet service
      final transactions = await widget.walletService.getTransactionHistory();
      setState(() {
        _transactions = transactions;
        _applyFilters();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load transactions: $e'),
            backgroundColor: Colors.red,
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

  void _applyFilters() {
    var filtered = _transactions.where((tx) {
      // Filter by type
      if (_filterType != 'all') {
        final txType = tx['type'] as String? ?? '';
        if (txType != _filterType) return false;
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final txid = (tx['txid'] as String? ?? '').toLowerCase();
        final amount = tx['balance_change']?.toString() ?? '';
        
        if (!txid.contains(query) && !amount.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort by timestamp (newest first)
    filtered.sort((a, b) {
      final aTime = a['timestamp'] as int? ?? 0;
      final bTime = b['timestamp'] as int? ?? 0;
      return bTime.compareTo(aTime);
    });

    setState(() {
      _filteredTransactions = filtered;
    });
  }

  Map<String, dynamic> _getTransactionStats() {
    final totalTxs = _transactions.length;
    final sentTxs = _transactions.where((tx) => tx['type'] == 'sent').length;
    final receivedTxs = _transactions.where((tx) => tx['type'] == 'received').length;
    
    final totalSent = _transactions
        .where((tx) => tx['type'] == 'sent')
        .fold<double>(0.0, (sum, tx) => sum + ((tx['balance_change'] as double?)?.abs() ?? 0.0));
    
    final totalReceived = _transactions
        .where((tx) => tx['type'] == 'received')
        .fold<double>(0.0, (sum, tx) => sum + ((tx['balance_change'] as double?) ?? 0.0));

    return {
      'total': totalTxs,
      'sent': sentTxs,
      'received': receivedTxs,
      'totalSent': totalSent,
      'totalReceived': totalReceived,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getTransactionStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportTransactions();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Export CSV'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats card
          if (!_isLoading) _buildStatsCard(stats),
          
          // Search and filter bar
          _buildSearchAndFilterBar(),
          
          // Transaction list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadTransactions,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final tx = _filteredTransactions[index];
                            return _buildTransactionCard(tx);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(Map<String, dynamic> stats) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Total',
                  '${stats['total']}',
                  Icons.swap_horiz,
                  Colors.blue,
                ),
                _buildStatItem(
                  'Sent',
                  '${stats['sent']}',
                  Icons.call_made,
                  Colors.red,
                ),
                _buildStatItem(
                  'Received',
                  '${stats['received']}',
                  Icons.call_received,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Total Sent',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${(stats['totalSent'] as double).toStringAsFixed(8)} GTC',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'Total Received',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${(stats['totalReceived'] as double).toStringAsFixed(8)} GTC',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search transactions...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _applyFilters();
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilters();
              });
            },
          ),
          const SizedBox(height: 8),
          // Filter chips
          Row(
            children: [
              Text(
                'Filter: ',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Sent', 'sent'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Received', 'received'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = value;
          _applyFilters();
        });
      },
      selectedColor: AppTheme.accentGold.withOpacity(0.3),
      checkmarkColor: Colors.black,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _filterType != 'all'
                ? 'No transactions match your criteria'
                : 'No transactions found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _filterType != 'all'
                ? 'Try adjusting your search or filter'
                : 'Your transaction history will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final isIncoming = tx['type'] == 'received';
    final balanceChange = tx['balance_change'] as double? ?? 0.0;
    final amount = balanceChange.abs();
    final txid = tx['txid'] as String? ?? '';
    final confirmations = tx['confirmations'] as int? ?? 0;
    final timestamp = tx['timestamp'] as int?;
    final blockHeight = tx['block_height'] as int?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showTransactionDetails(tx),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isIncoming ? Colors.green : Colors.red).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isIncoming ? Icons.call_received : Icons.call_made,
                      color: isIncoming ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIncoming ? 'Received' : 'Sent',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isIncoming ? Colors.green : Colors.red,
                          ),
                        ),
                        Text(
                          'TX: ${_truncateHash(txid)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isIncoming ? '+' : '-'}${amount.toStringAsFixed(8)} GTC',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isIncoming ? Colors.green : Colors.red,
                        ),
                      ),
                      if (timestamp != null)
                        Text(
                          _formatDateTime(DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    confirmations > 0 ? Icons.check_circle : Icons.schedule,
                    size: 16,
                    color: confirmations > 0 ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    confirmations > 0 
                        ? '$confirmations confirmations'
                        : 'Unconfirmed',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (blockHeight != null) ...[
                    const SizedBox(width: 16),
                    Icon(
                      Icons.layers,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Block $blockHeight',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> tx) {
    showDialog(
      context: context,
      builder: (context) => _TransactionDetailsDialog(transaction: tx),
    );
  }

  String _truncateHash(String hash) {
    if (hash.length <= 16) return hash;
    return '${hash.substring(0, 8)}...${hash.substring(hash.length - 8)}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportTransactions() async {
    if (_filteredTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transactions to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final csvData = _generateCSV();
      await Clipboard.setData(ClipboardData(text: csvData));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction history exported to clipboard as CSV'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export transactions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateCSV() {
    final buffer = StringBuffer();
    buffer.writeln('Date,Type,Amount,Transaction ID,Confirmations,Block Height');
    
    for (final tx in _filteredTransactions) {
      final timestamp = tx['timestamp'] as int?;
      final date = timestamp != null 
          ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toIso8601String()
          : '';
      
      buffer.writeln([
        date,
        tx['type'],
        (tx['balance_change'] as double? ?? 0.0).toStringAsFixed(8),
        tx['txid'],
        tx['confirmations'] ?? 0,
        tx['block_height'] ?? '',
      ].join(','));
    }
    
    return buffer.toString();
  }
}

class _TransactionDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const _TransactionDetailsDialog({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isIncoming = transaction['type'] == 'received';
    final balanceChange = transaction['balance_change'] as double? ?? 0.0;
    final amount = balanceChange.abs();
    final txid = transaction['txid'] as String? ?? '';
    final confirmations = transaction['confirmations'] as int? ?? 0;
    final timestamp = transaction['timestamp'] as int?;
    final blockHeight = transaction['block_height'] as int?;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isIncoming ? Icons.call_received : Icons.call_made,
            color: isIncoming ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(isIncoming ? 'Received' : 'Sent'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Amount', '${isIncoming ? '+' : '-'}${amount.toStringAsFixed(8)} GTC'),
            const SizedBox(height: 12),
            _buildDetailRow('Transaction ID', txid, copyable: true),
            const SizedBox(height: 12),
            _buildDetailRow('Confirmations', '$confirmations'),
            if (blockHeight != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow('Block Height', '$blockHeight'),
            ],
            if (timestamp != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                'Date',
                _formatDateTime(DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)),
              ),
            ],
            const SizedBox(height: 12),
            _buildDetailRow(
              'Status',
              confirmations > 0 ? 'Confirmed' : 'Unconfirmed',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: txid));
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transaction ID copied!')),
            );
          },
          child: const Text('Copy TX ID'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool copyable = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              fontFamily: value.length > 30 ? 'monospace' : null,
              fontSize: value.length > 30 ? 12 : null,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}