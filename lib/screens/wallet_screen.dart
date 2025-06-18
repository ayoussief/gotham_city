import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import 'import_wallet_screen.dart';
import 'send_screen.dart';
import 'receive_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();
  Wallet? _wallet;
  bool _isLoading = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initializeWallet();
  }

  Future<void> _initializeWallet() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _walletService.initialize();
      
      // Listen to wallet updates
      _walletService.walletStream.listen((wallet) {
        if (mounted) {
          setState(() {
            _wallet = wallet;
          });
        }
      });

      // Listen to sync status
      _walletService.syncStatusStream.listen((syncing) {
        if (mounted) {
          setState(() {
            _isSyncing = syncing;
          });
        }
      });

      // Set initial wallet
      setState(() {
        _wallet = _walletService.currentWallet;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize wallet: $e'),
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

  Future<void> _loadWallet() async {
    if (_walletService.currentWallet != null) {
      try {
        await _walletService.refreshWallet();
        setState(() {
          _wallet = _walletService.currentWallet;
        });
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
  }

  Future<void> _createNewWallet() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final wallet = await _walletService.createNewWallet();
      
      // Show seed phrase to user
      if (mounted && wallet.seedPhrase != null) {
        await _showSeedPhraseDialog(wallet.seedPhrase!);
      }
    } catch (e) {
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

  Future<void> _importWallet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ImportWalletScreen(walletService: _walletService)),
    );

    // Wallet will be updated through the stream listener
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wallet imported successfully'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  void _copyAddress() {
    if (_wallet != null) {
      Clipboard.setData(ClipboardData(text: _wallet!.address));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address copied to clipboard'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gotham City Wallet'),
        actions: [
          if (_wallet != null)
            IconButton(
              icon: _isSyncing 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: _isSyncing ? null : _refreshWallet,
              tooltip: _isSyncing ? 'Syncing...' : 'Refresh Balance',
            ),
        ],
      ),
      body: _wallet == null ? _buildWalletSetup() : _buildWalletView(),
    );
  }

  Future<void> _refreshWallet() async {
    try {
      await _walletService.refreshWallet();
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

  Future<void> _showSeedPhraseDialog(String seedPhrase) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Backup Your Seed Phrase'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Write down these 12 words in order and keep them safe. This is the only way to recover your wallet.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.mediumGray,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.lightGray),
                  ),
                  child: SelectableText(
                    seedPhrase,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '⚠️ Never share your seed phrase with anyone!\n'
                  '⚠️ Store it offline in a secure location.\n'
                  '⚠️ Anyone with this phrase can access your funds.',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: seedPhrase));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Seed phrase copied to clipboard'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              },
              child: const Text('Copy'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('I\'ve Saved It'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWalletSetup() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: AppTheme.accentGold,
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to Gotham City',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Create a new wallet or import an existing one to get started',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const CircularProgressIndicator(
                color: AppTheme.accentGold,
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createNewWallet,
                  child: const Text('Create New Wallet'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _importWallet,
                  child: const Text('Import Existing Wallet'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWalletView() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadWallet();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(),
            const SizedBox(height: 16),
            _buildAddressCard(),
            const SizedBox(height: 16),
            _buildQuickActions(),
            const SizedBox(height: 16),
            _buildWalletInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  color: AppTheme.accentGold,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Balance',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _wallet!.balanceFormatted,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            if (_isSyncing)
              Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Syncing with Gotham network...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              )
            else
              Text(
                'Network: ${_wallet!.network.toUpperCase()}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.qr_code,
                  color: AppTheme.accentGold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Wallet Address',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.mediumGray,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.lightGray),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _wallet!.address,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: _copyAddress,
                    tooltip: 'Copy Address',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _wallet!.balance > 0 ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SendScreen(
                            wallet: _wallet!,
                            walletService: _walletService,
                          ),
                        ),
                      );
                    } : null,
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReceiveScreen(
                            wallet: _wallet!,
                            walletService: _walletService,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.call_received),
                    label: const Text('Receive'),
                  ),
                ),
              ],
            ),
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
              'Wallet Information',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Type', _wallet!.isHDWallet ? 'HD Wallet' : 'Single Key'),
            const SizedBox(height: 8),
            _buildInfoRow('Source', _wallet!.isImported ? 'Imported' : 'Generated'),
            const SizedBox(height: 8),
            _buildInfoRow('Network', _wallet!.network.toUpperCase()),
            const SizedBox(height: 8),
            _buildInfoRow('Address Type', _wallet!.isBech32Address ? 'Bech32 (gt1...)' : 'Legacy'),
            const SizedBox(height: 8),
            _buildInfoRow('Status', _isSyncing ? 'Syncing' : 'Active'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.accentGold,
          ),
        ),
      ],
    );
  }
}