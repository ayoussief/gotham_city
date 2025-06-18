import 'package:flutter/material.dart';
import 'dart:async';
import '../services/spv_client.dart';
import '../services/wallet_backend.dart';
import '../services/filter_storage.dart';
import '../config/gotham_chain_params.dart';
import '../../lib/theme/app_theme.dart';

class SPVStatusScreen extends StatefulWidget {
  const SPVStatusScreen({super.key});

  @override
  State<SPVStatusScreen> createState() => _SPVStatusScreenState();
}

class _SPVStatusScreenState extends State<SPVStatusScreen> {
  final SPVClient _spvClient = SPVClient();
  final WalletBackend _walletBackend = WalletBackend();
  final FilterStorage _filterStorage = FilterStorage();
  
  SPVSyncStatus? _syncStatus;
  double _balance = 0.0;
  List<Map<String, dynamic>> _recentTransactions = [];
  Map<String, dynamic> _storageStats = {};
  bool _isLoading = true;
  
  StreamSubscription? _syncStatusSub;
  StreamSubscription? _newTransactionsSub;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeSPV();
    _setupStreams();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _syncStatusSub?.cancel();
    _newTransactionsSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _initializeSPV() async {
    try {
      await _spvClient.initialize();
      await _loadData();
    } catch (e) {
      print('Failed to initialize SPV client: $e');
    }
  }

  void _setupStreams() {
    _syncStatusSub = _spvClient.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _syncStatus = status;
        });
      }
    });

    _newTransactionsSub = _spvClient.newTransactionsStream.listen((txids) {
      if (mounted) {
        _loadTransactions();
        _loadBalance();
      }
    });
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadBalance(),
        _loadTransactions(),
        _loadStorageStats(),
      ]);
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await _walletBackend.getBalance();
      if (mounted) {
        setState(() {
          _balance = balance;
        });
      }
    } catch (e) {
      print('Error loading balance: $e');
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final transactions = await _walletBackend.getTransactionHistory();
      if (mounted) {
        setState(() {
          _recentTransactions = transactions.take(5).toList();
        });
      }
    } catch (e) {
      print('Error loading transactions: $e');
    }
  }

  Future<void> _loadStorageStats() async {
    try {
      final stats = await _filterStorage.getStorageStats();
      if (mounted) {
        setState(() {
          _storageStats = stats;
        });
      }
    } catch (e) {
      print('Error loading storage stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gotham SPV Node'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(_spvClient.isSyncing ? Icons.pause : Icons.play_arrow),
            onPressed: _toggleSync,
            tooltip: _spvClient.isSyncing ? 'Stop Sync' : 'Start Sync',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingView() : _buildContent(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppTheme.accentGold,
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSyncStatus(),
            const SizedBox(height: 16),
            _buildWalletInfo(),
            const SizedBox(height: 16),
            _buildNetworkInfo(),
            const SizedBox(height: 16),
            _buildStorageInfo(),
            const SizedBox(height: 16),
            _buildRecentTransactions(),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatus() {
    final status = _syncStatus;
    final isConnected = status?.isConnected ?? false;
    final isSyncing = status?.isSyncing ?? false;
    final progress = status?.syncProgress ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: isConnected ? AppTheme.successGreen : AppTheme.dangerRed,
                ),
                const SizedBox(width: 8),
                Text(
                  'SPV Sync Status',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentGold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isConnected ? AppTheme.successGreen : AppTheme.dangerRed).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      color: isConnected ? AppTheme.successGreen : AppTheme.dangerRed,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (status != null) ...[
              _buildInfoRow('Current Height', status.currentHeight.toString()),
              _buildInfoRow('Target Height', status.targetHeight.toString()),
              _buildInfoRow('Filters Downloaded', status.filtersDownloaded.toString()),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentGold),
              ),
              const SizedBox(height: 4),
              Text(
                'Sync Progress: ${(progress * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (isSyncing) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accentGold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Syncing with Gotham network...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.accentGold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWalletInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wallet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Balance',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${_balance.toStringAsFixed(8)} GTC',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentGold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showReceiveDialog,
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Receive'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGold,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showSendDialog,
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Network',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Network', GothamChainParams.networkName.toUpperCase()),
            _buildInfoRow('Protocol Version', GothamChainParams.protocolVersion.toString()),
            _buildInfoRow('Default Port', GothamChainParams.defaultPort.toString()),
            _buildInfoRow('Address Prefix', GothamChainParams.addressPrefix),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Local Storage',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Headers', _storageStats['headers']?.toString() ?? '0'),
            _buildInfoRow('Filters', _storageStats['filters']?.toString() ?? '0'),
            _buildInfoRow('Watch Addresses', _storageStats['watch_addresses']?.toString() ?? '0'),
            _buildInfoRow('Transactions', _storageStats['transactions']?.toString() ?? '0'),
            _buildInfoRow('UTXOs', _storageStats['unspent_utxos']?.toString() ?? '0'),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentGold,
                  ),
                ),
                TextButton(
                  onPressed: _showAllTransactions,
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_recentTransactions.isEmpty)
              Text(
                'No transactions yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              )
            else
              ..._recentTransactions.map((tx) => _buildTransactionItem(tx)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final txid = tx['txid'] as String? ?? '';
    final balanceChange = tx['balance_change'] as double? ?? 0.0;
    final type = tx['type'] as String? ?? 'unknown';
    final confirmations = tx['confirmations'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            type == 'received' ? Icons.arrow_downward : Icons.arrow_upward,
            color: type == 'received' ? AppTheme.successGreen : AppTheme.dangerRed,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txid.length > 16 ? '${txid.substring(0, 16)}...' : txid,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  '$confirmations confirmations',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${balanceChange > 0 ? '+' : ''}${balanceChange.toStringAsFixed(8)} GTC',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: balanceChange > 0 ? AppTheme.successGreen : AppTheme.dangerRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSync() async {
    try {
      if (_spvClient.isSyncing) {
        await _spvClient.stop();
      } else {
        await _spvClient.startSync();
      }
    } catch (e) {
      _showErrorDialog('Sync Error', e.toString());
    }
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => _SettingsDialog(),
    );
  }

  void _showReceiveDialog() {
    showDialog(
      context: context,
      builder: (context) => _ReceiveDialog(),
    );
  }

  void _showSendDialog() {
    showDialog(
      context: context,
      builder: (context) => _SendDialog(),
    );
  }

  void _showAllTransactions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TransactionHistoryScreen(),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Settings Dialog
class _SettingsDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('SPV Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.network_check),
            title: const Text('Network'),
            subtitle: Text(GothamChainParams.networkName.toUpperCase()),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Clear Cache'),
            subtitle: const Text('Remove stored filters and headers'),
            onTap: () {
              // Implement cache clearing
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// Receive Dialog
class _ReceiveDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Receive Gotham Coins'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Your receiving address:'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'gc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
              style: TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            // Copy address to clipboard
          },
          child: const Text('Copy'),
        ),
      ],
    );
  }
}

// Send Dialog
class _SendDialog extends StatelessWidget {
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Gotham Coins'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Recipient Address',
              hintText: 'gc1...',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Amount (GTC)',
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Implement send transaction
            Navigator.pop(context);
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}

// Transaction History Screen
class _TransactionHistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
      ),
      body: const Center(
        child: Text('Transaction history will be displayed here'),
      ),
    );
  }
}