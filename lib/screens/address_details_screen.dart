import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/address_info.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';

class AddressDetailsScreen extends StatefulWidget {
  final AddressInfo addressInfo;
  final WalletService walletService;

  const AddressDetailsScreen({
    super.key,
    required this.addressInfo,
    required this.walletService,
  });

  @override
  State<AddressDetailsScreen> createState() => _AddressDetailsScreenState();
}

class _AddressDetailsScreenState extends State<AddressDetailsScreen> {
  late AddressInfo _addressInfo;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = false;
  final TextEditingController _labelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _addressInfo = widget.addressInfo;
    _labelController.text = _addressInfo.label ?? '';
    _loadTransactions();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final transactions = await widget.walletService.getAddressTransactions(_addressInfo.address);
      setState(() {
        _transactions = transactions;
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

  Future<void> _updateLabel() async {
    final newLabel = _labelController.text.trim();
    if (newLabel == _addressInfo.label) return;

    try {
      await widget.walletService.updateAddressLabel(
        _addressInfo.address,
        newLabel.isEmpty ? null : newLabel,
      );
      
      setState(() {
        _addressInfo = _addressInfo.copyWith(label: newLabel.isEmpty ? null : newLabel);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Label updated successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update label: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_addressInfo.label ?? 'Address Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'copy_address':
                  _copyToClipboard(_addressInfo.address, 'Address');
                  break;
                case 'copy_public_key':
                  if (_addressInfo.publicKey != null) {
                    _copyToClipboard(_addressInfo.publicKey!, 'Public key');
                  }
                  break;
                case 'export_transactions':
                  _exportTransactions();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy_address',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('Copy Address'),
                  ],
                ),
              ),
              if (_addressInfo.publicKey != null)
                const PopupMenuItem(
                  value: 'copy_public_key',
                  child: Row(
                    children: [
                      Icon(Icons.key),
                      SizedBox(width: 8),
                      Text('Copy Public Key'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'export_transactions',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Export Transactions'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAddressCard(),
            const SizedBox(height: 16),
            _buildLabelCard(),
            const SizedBox(height: 16),
            _buildStatsCard(),
            const SizedBox(height: 16),
            _buildTransactionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getAddressTypeIcon(),
                  color: AppTheme.accentGold,
                ),
                const SizedBox(width: 8),
                Text(
                  'Address Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Address', _addressInfo.address, copyable: true),
            const SizedBox(height: 12),
            _buildInfoRow('Type', _addressInfo.typeDescription),
            const SizedBox(height: 12),
            _buildInfoRow('Balance', _addressInfo.balanceFormatted),
            if (_addressInfo.publicKey != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Public Key', _addressInfo.publicKey!, copyable: true),
            ],
            if (_addressInfo.derivationIndex > 0) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Derivation Index', _addressInfo.derivationIndex.toString()),
            ],
            if (_addressInfo.createdAt != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Created', _formatDateTime(_addressInfo.createdAt!)),
            ],
            if (_addressInfo.lastUsed != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Last Used', _formatDateTime(_addressInfo.lastUsed!)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLabelCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Label',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _labelController,
                    decoration: const InputDecoration(
                      hintText: 'Enter a label for this address...',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 50,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _updateLabel,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Balance',
                  _addressInfo.balanceFormatted,
                  Icons.account_balance_wallet,
                  AppTheme.accentGold,
                ),
                _buildStatItem(
                  'Transactions',
                  _addressInfo.transactionCount.toString(),
                  Icons.swap_horiz,
                  Colors.blue,
                ),
                _buildStatItem(
                  'Status',
                  _addressInfo.isUsed ? 'Used' : 'Unused',
                  _addressInfo.isUsed ? Icons.check_circle : Icons.radio_button_unchecked,
                  _addressInfo.isUsed ? Colors.green : Colors.grey,
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

  Widget _buildTransactionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: AppTheme.accentGold),
                const SizedBox(width: 8),
                Text(
                  'Transaction History',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_transactions.isNotEmpty)
                  Text(
                    '${_transactions.length} transactions',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_transactions.isEmpty)
              _buildEmptyTransactions()
            else
              _buildTransactionsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This address hasn\'t been used yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    return Column(
      children: _transactions.map((tx) => _buildTransactionItem(tx)).toList(),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final isIncoming = tx['type'] == 'received';
    final amount = (tx['amount'] as double).abs();
    final txid = tx['txid'] as String;
    final confirmations = tx['confirmations'] as int? ?? 0;
    final timestamp = tx['timestamp'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIncoming ? Icons.call_received : Icons.call_made,
                color: isIncoming ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isIncoming ? 'Received' : 'Sent',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isIncoming ? Colors.green : Colors.red,
                  ),
                ),
              ),
              Text(
                '${isIncoming ? '+' : '-'}${amount.toStringAsFixed(8)} GTC',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isIncoming ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'TX: ${_truncateHash(txid)}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () => _copyToClipboard(txid, 'Transaction ID'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                confirmations > 0 ? Icons.check_circle : Icons.schedule,
                size: 14,
                color: confirmations > 0 ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                confirmations > 0 
                    ? '$confirmations confirmations'
                    : 'Unconfirmed',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (timestamp != null)
                Text(
                  _formatDateTime(DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool copyable = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
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
        if (copyable) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () => _copyToClipboard(value, label),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ],
    );
  }

  IconData _getAddressTypeIcon() {
    if (_addressInfo.address.startsWith('gt1')) return Icons.security;
    if (_addressInfo.address.startsWith('3')) return Icons.shield;
    if (_addressInfo.address.startsWith('1')) return Icons.account_balance_wallet;
    return Icons.help_outline;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _truncateHash(String hash) {
    if (hash.length <= 16) return hash;
    return '${hash.substring(0, 8)}...${hash.substring(hash.length - 8)}';
  }

  Future<void> _exportTransactions() async {
    if (_transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transactions to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final csvData = _generateTransactionCSV();
      await Clipboard.setData(ClipboardData(text: csvData));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transactions exported to clipboard as CSV'),
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

  String _generateTransactionCSV() {
    final buffer = StringBuffer();
    buffer.writeln('Date,Type,Amount,Transaction ID,Confirmations');
    
    for (final tx in _transactions) {
      final timestamp = tx['timestamp'] as int?;
      final date = timestamp != null 
          ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toIso8601String()
          : '';
      
      buffer.writeln([
        date,
        tx['type'],
        (tx['amount'] as double).toStringAsFixed(8),
        tx['txid'],
        tx['confirmations'] ?? 0,
      ].join(','));
    }
    
    return buffer.toString();
  }
}