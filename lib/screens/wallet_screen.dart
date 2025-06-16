import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/wallet.dart';
import '../theme/app_theme.dart';
import 'import_wallet_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Wallet? _wallet;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  void _loadWallet() {
    // Mock wallet data - will be replaced with actual backend
    setState(() {
      _wallet = Wallet(
        address: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
        balance: 0.00125847,
        privateKey: 'mock_private_key',
        isImported: true,
      );
    });
  }

  void _createNewWallet() {
    setState(() {
      _isLoading = true;
    });

    // Mock wallet creation - will be replaced with actual backend
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _wallet = Wallet(
          address: 'bc1q${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
          balance: 0.0,
          privateKey: 'generated_private_key',
          isImported: false,
        );
        _isLoading = false;
      });
    });
  }

  void _importWallet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ImportWalletScreen()),
    );

    if (result != null && result is Wallet) {
      setState(() {
        _wallet = result;
      });
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
              icon: const Icon(Icons.refresh),
              onPressed: _loadWallet,
              tooltip: 'Refresh Balance',
            ),
        ],
      ),
      body: _wallet == null ? _buildWalletSetup() : _buildWalletView(),
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
              '${_wallet!.balance.toStringAsFixed(8)} BTC',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '≈ \$${(_wallet!.balance * 45000).toStringAsFixed(2)} USD',
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
                    onPressed: () {
                      // TODO: Implement send functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Send feature coming soon')),
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Implement receive functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Receive feature coming soon')),
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
            _buildInfoRow('Type', _wallet!.isImported ? 'Imported' : 'Generated'),
            const SizedBox(height: 8),
            _buildInfoRow('Network', 'Bitcoin Mainnet'),
            const SizedBox(height: 8),
            _buildInfoRow('Status', 'Active'),
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