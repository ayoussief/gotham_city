import 'package:flutter/material.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';

class ImportWalletScreen extends StatefulWidget {
  final WalletService walletService;
  
  const ImportWalletScreen({
    super.key,
    required this.walletService,
  });

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _privateKeyController = TextEditingController();
  final _mnemonicController = TextEditingController();
  bool _isLoading = false;
  int _selectedTab = 0;

  @override
  void dispose() {
    _privateKeyController.dispose();
    _mnemonicController.dispose();
    super.dispose();
  }

  Future<void> _importWallet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Wallet wallet;
      
      if (_selectedTab == 0) {
        // Import from private key
        wallet = await widget.walletService.importWalletFromPrivateKey(
          _privateKeyController.text.trim(),
        );
      } else {
        // Import from seed phrase
        wallet = await widget.walletService.importWalletFromSeed(
          _mnemonicController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context, wallet);
      }
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Wallet'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Import your existing wallet',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your preferred import method below',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _buildTabSelector(),
              const SizedBox(height: 24),
              Expanded(
                child: _selectedTab == 0 ? _buildPrivateKeyTab() : _buildMnemonicTab(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _importWallet,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryBlack,
                          ),
                        )
                      : const Text('Import Wallet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.mediumGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? AppTheme.accentGold : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Private Key',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedTab == 0 ? AppTheme.primaryBlack : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? AppTheme.accentGold : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Seed Phrase',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedTab == 1 ? AppTheme.primaryBlack : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateKeyTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Private Key',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your wallet\'s private key (WIF format)',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _privateKeyController,
          decoration: const InputDecoration(
            labelText: 'Private Key',
            hintText: 'Enter your private key...',
            prefixIcon: Icon(Icons.key),
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your private key';
            }
            if (value.length < 50) {
              return 'Private key seems too short';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warningOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.warningOrange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning,
                color: AppTheme.warningOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Never share your private key with anyone. Keep it secure!',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.warningOrange,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMnemonicTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seed Phrase',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your 12 or 24 word seed phrase',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _mnemonicController,
          decoration: const InputDecoration(
            labelText: 'Seed Phrase',
            hintText: 'word1 word2 word3 ...',
            prefixIcon: Icon(Icons.list_alt),
          ),
          maxLines: 4,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your seed phrase';
            }
            final words = value.trim().split(' ');
            if (words.length != 12 && words.length != 24) {
              return 'Seed phrase must be 12 or 24 words';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.accentBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.accentBlue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info,
                color: AppTheme.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Separate each word with a space. Make sure the words are in the correct order.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.accentBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}