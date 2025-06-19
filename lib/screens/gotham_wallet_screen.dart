import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/gotham_wallet.dart';
import '../models/address_info.dart';
import '../services/gotham_wallet_manager.dart';
import '../theme/app_theme.dart';
import 'address_list_screen.dart';
import 'transaction_history_screen.dart';

/// Gotham Wallet Screen - Proper wallet/address separation
/// 
/// This screen shows wallet information (container) and allows management
/// of multiple addresses within the wallet, following Gotham Core's architecture.
class GothamWalletScreen extends StatefulWidget {
  const GothamWalletScreen({super.key});

  @override
  State<GothamWalletScreen> createState() => _GothamWalletScreenState();
}

class _GothamWalletScreenState extends State<GothamWalletScreen> {
  final GothamWalletManager _walletManager = GothamWalletManager();
  GothamWallet? _currentWallet;
  List<AddressInfo> _addresses = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  
  // Stream subscriptions for proper disposal
  StreamSubscription? _walletStreamSub;
  StreamSubscription? _addressesStreamSub;
  StreamSubscription? _syncStatusStreamSub;

  @override
  void initState() {
    super.initState();
    _initializeWalletManager();
  }

  Future<void> _initializeWalletManager() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('GothamWalletScreen: Starting wallet manager initialization...');
      
      await _walletManager.initialize()
          .timeout(const Duration(seconds: 30));
      
      print('GothamWalletScreen: Wallet manager initialized');
      
      // Listen to wallet updates
      _walletStreamSub = _walletManager.walletStream.listen((wallet) {
        if (mounted && _currentWallet != wallet) {
          print('GothamWalletScreen: Wallet update received: ${wallet?.name ?? 'null'}');
          setState(() {
            _currentWallet = wallet;
          });
        }
      });

      // Listen to address updates
      _addressesStreamSub = _walletManager.addressesStream.listen((addresses) {
        if (mounted) {
          print('GothamWalletScreen: Addresses update received: ${addresses.length} addresses');
          setState(() {
            _addresses = addresses;
          });
        }
      });

      // Listen to sync status
      _syncStatusStreamSub = _walletManager.syncStatusStream.listen((syncing) {
        if (mounted && _isSyncing != syncing) {
          print('GothamWalletScreen: Sync status update: $syncing');
          setState(() {
            _isSyncing = syncing;
          });
        }
      });

      // Set initial state
      setState(() {
        _currentWallet = _walletManager.currentWallet;
        _addresses = _walletManager.currentAddresses;
      });
      
      print('GothamWalletScreen: Initialization completed');
    } catch (e) {
      print('GothamWalletScreen: Initialization failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize wallet manager: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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

  Future<void> _createNewWallet() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _buildCreateWalletDialog(),
    );

    if (result != null && mounted) {
      setState(() {
        _isLoading = true;
      });

      try {
        print('Creating new wallet: ${result['name']}');
        
        final wallet = await _walletManager.createWallet(
          name: result['name']!,
          description: result['description'],
        );
        
        print('Wallet created successfully: ${wallet.name}');
        
        // Show seed phrase to user
        if (mounted && wallet.seedPhrase != null) {
          await _showSeedPhraseDialog(wallet.seedPhrase!);
        }
      } catch (e) {
        print('Error creating wallet: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create wallet: $e'),
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
  }

  Future<void> _importWallet() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _buildImportWalletDialog(),
    );

    if (result != null && mounted) {
      setState(() {
        _isLoading = true;
      });

      try {
        print('Importing wallet: ${result['name']}');
        
        final wallet = await _walletManager.importWallet(
          name: result['name']!,
          seedPhrase: result['seedPhrase']!,
          description: result['description'],
        );
        
        print('Wallet imported successfully: ${wallet.name}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Wallet imported successfully: ${wallet.name}'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } catch (e) {
        print('Error importing wallet: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to import wallet: $e'),
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
  }

  Future<void> _generateNewAddress() async {
    if (_currentWallet == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final addressInfo = await _walletManager.getNewAddress(
        label: 'Address #${_addresses.where((a) => !a.isChange).length + 1}',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New address generated: ${addressInfo.displayAddress}'),
            backgroundColor: AppTheme.successGreen,
            action: SnackBarAction(
              label: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: addressInfo.address));
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate address: $e'),
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

  Future<void> _refreshWallet() async {
    if (_currentWallet == null) return;

    try {
      await _walletManager.refreshWallet();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wallet refreshed successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh wallet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCreateWalletDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    return AlertDialog(
      title: const Text('Create New Wallet'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Wallet Name',
              hintText: 'Enter wallet name',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Enter wallet description',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'A new HD wallet will be created with a secure seed phrase.',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (nameController.text.trim().isNotEmpty) {
              Navigator.of(context).pop({
                'name': nameController.text.trim(),
                'description': descriptionController.text.trim(),
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }

  Widget _buildImportWalletDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final seedPhraseController = TextEditingController();

    return AlertDialog(
      title: const Text('Import Wallet'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Wallet Name',
              hintText: 'Enter wallet name',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Enter wallet description',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: seedPhraseController,
            decoration: const InputDecoration(
              labelText: 'Seed Phrase',
              hintText: 'Enter 12 or 24 word seed phrase',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          const Text(
            'Import an existing HD wallet using its seed phrase.',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (nameController.text.trim().isNotEmpty && 
                seedPhraseController.text.trim().isNotEmpty) {
              Navigator.of(context).pop({
                'name': nameController.text.trim(),
                'description': descriptionController.text.trim(),
                'seedPhrase': seedPhraseController.text.trim(),
              });
            }
          },
          child: const Text('Import'),
        ),
      ],
    );
  }

  Future<void> _showSeedPhraseDialog(String seedPhrase) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Backup Your Seed Phrase'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'IMPORTANT: Write down this seed phrase and store it safely. This is the only way to recover your wallet.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[100],
              ),
              child: SelectableText(
                seedPhrase,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '• Never share this seed phrase with anyone\n'
              '• Store it in a secure location\n'
              '• Anyone with this phrase can access your funds',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: seedPhrase));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Seed phrase copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I\'ve Saved It'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _walletStreamSub?.cancel();
    _addressesStreamSub?.cancel();
    _syncStatusStreamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentWallet?.displayName ?? 'Gotham Wallet'),
        actions: [
          if (_currentWallet != null) ...[
            IconButton(
              icon: _isSyncing 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: _isSyncing ? null : _refreshWallet,
              tooltip: 'Refresh Wallet',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'addresses':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddressListScreen(
                          wallet: _currentWallet!,
                          walletService: null, // We'll need to adapt this
                        ),
                      ),
                    );
                    break;
                  case 'transactions':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TransactionHistoryScreen(
                          wallet: _currentWallet!,
                        ),
                      ),
                    );
                    break;
                  case 'backup':
                    if (_currentWallet?.seedPhrase != null) {
                      _showSeedPhraseDialog(_currentWallet!.seedPhrase!);
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'addresses',
                  child: Row(
                    children: [
                      Icon(Icons.list),
                      SizedBox(width: 8),
                      Text('View All Addresses'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'transactions',
                  child: Row(
                    children: [
                      Icon(Icons.history),
                      SizedBox(width: 8),
                      Text('Transaction History'),
                    ],
                  ),
                ),
                if (_currentWallet?.needsBackup == true)
                  const PopupMenuItem(
                    value: 'backup',
                    child: Row(
                      children: [
                        Icon(Icons.backup),
                        SizedBox(width: 8),
                        Text('Backup Seed Phrase'),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentWallet == null
              ? _buildNoWalletState()
              : _buildWalletContent(),
      floatingActionButton: _currentWallet != null
          ? FloatingActionButton.extended(
              onPressed: _isLoading ? null : _generateNewAddress,
              icon: const Icon(Icons.add),
              label: const Text('New Address'),
              backgroundColor: AppTheme.accentGold,
              foregroundColor: Colors.black,
            )
          : null,
    );
  }

  Widget _buildNoWalletState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.account_balance_wallet,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Wallet Found',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a new wallet or import an existing one to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _createNewWallet,
                icon: const Icon(Icons.add),
                label: const Text('Create Wallet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _importWallet,
                icon: const Icon(Icons.download),
                label: const Text('Import Wallet'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletContent() {
    final receivingAddresses = _addresses.where((a) => !a.isChange).toList();
    final changeAddresses = _addresses.where((a) => a.isChange).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wallet Overview Card
          _buildWalletOverviewCard(),
          const SizedBox(height: 16),
          
          // Quick Actions
          _buildQuickActionsCard(),
          const SizedBox(height: 16),
          
          // Address Summary
          _buildAddressSummaryCard(receivingAddresses, changeAddresses),
          const SizedBox(height: 16),
          
          // Recent Addresses
          if (receivingAddresses.isNotEmpty) ...[
            _buildRecentAddressesCard(receivingAddresses),
            const SizedBox(height: 16),
          ],
          
          // Wallet Statistics
          _buildWalletStatsCard(),
        ],
      ),
    );
  }

  Widget _buildWalletOverviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _currentWallet!.isHD ? Icons.account_tree : Icons.account_balance_wallet,
                  color: AppTheme.accentGold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentWallet!.displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _currentWallet!.statusDescription,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildBalanceItem(
                    'Total Balance',
                    _currentWallet!.balanceFormatted,
                    Icons.account_balance_wallet,
                    AppTheme.accentGold,
                  ),
                ),
                Expanded(
                  child: _buildBalanceItem(
                    'Confirmed',
                    _currentWallet!.confirmedBalanceFormatted,
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceItem(String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generateNewAddress,
                    icon: const Icon(Icons.add),
                    label: const Text('New Address'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGold,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Navigate to send screen
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSummaryCard(List<AddressInfo> receiving, List<AddressInfo> change) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Address Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Receiving',
                    '${receiving.length}',
                    Icons.call_received,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Change',
                    '${change.length}',
                    Icons.swap_horiz,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Used',
                    '${_addresses.where((a) => a.isUsed).length}',
                    Icons.history,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRecentAddressesCard(List<AddressInfo> addresses) {
    final recentAddresses = addresses.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Addresses',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to full address list
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...recentAddresses.map((address) => _buildAddressListItem(address)),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressListItem(AddressInfo address) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: address.hasBalance ? AppTheme.accentGold : Colors.grey[300],
        child: Icon(
          address.isChangeAddress ? Icons.swap_horiz : Icons.call_received,
          color: address.hasBalance ? Colors.black : Colors.grey[600],
        ),
      ),
      title: Text(
        address.displayLabel,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        address.displayAddress,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            address.balanceFormatted,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: address.hasBalance ? AppTheme.accentGold : Colors.grey,
            ),
          ),
          if (address.transactionCount > 0)
            Text(
              '${address.transactionCount} txs',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      onTap: () {
        Clipboard.setData(ClipboardData(text: address.address));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address copied to clipboard')),
        );
      },
    );
  }

  Widget _buildWalletStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wallet Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatRow('Created', _formatDate(_currentWallet!.createdAt)),
            if (_currentWallet!.lastUsed != null)
              _buildStatRow('Last Used', _formatDate(_currentWallet!.lastUsed!)),
            _buildStatRow('Network', _currentWallet!.network.toUpperCase()),
            _buildStatRow('Type', _currentWallet!.statusDescription),
            if (_currentWallet!.transactionCount > 0)
              _buildStatRow('Transactions', '${_currentWallet!.transactionCount}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}