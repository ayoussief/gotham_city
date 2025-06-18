import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../services/wallet_service.dart';
import '../bitcoin_node/services/wallet_storage.dart';
import '../theme/app_theme.dart';

class WalletSettingsScreen extends StatefulWidget {
  final WalletService walletService;
  
  const WalletSettingsScreen({
    super.key,
    required this.walletService,
  });

  @override
  State<WalletSettingsScreen> createState() => _WalletSettingsScreenState();
}

class _WalletSettingsScreenState extends State<WalletSettingsScreen> {
  final WalletStorage _walletStorage = WalletStorage();
  bool _isLoading = false;
  String? _walletPath;
  Map<String, dynamic>? _walletInfo;

  @override
  void initState() {
    super.initState();
    _loadWalletInfo();
  }

  Future<void> _loadWalletInfo() async {
    try {
      _walletPath = await _walletStorage.walletFilePath;
      _walletInfo = _walletStorage.getWalletInfo();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading wallet info: $e');
    }
  }

  Future<void> _backupWallet() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Let user choose backup location
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectory != null) {
        final backupFileName = 'wallet_backup_${DateTime.now().millisecondsSinceEpoch}.dat';
        final backupPath = '$selectedDirectory/$backupFileName';
        
        await _walletStorage.backupWallet(backupPath);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Wallet backed up to: $backupPath'),
              backgroundColor: AppTheme.successGreen,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
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

  Future<void> _showWalletPath() async {
    if (_walletPath != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Wallet File Location'),
          content: SelectableText(
            _walletPath!,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _walletPath!));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Path copied to clipboard'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              },
              child: const Text('Copy Path'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _exportPrivateKeys() async {
    // Show warning dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Security Warning'),
          ],
        ),
        content: const Text(
          'Exporting private keys can be dangerous. Anyone with access to your private keys can steal your funds. Only proceed if you understand the risks.\n\nDo you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final addresses = _walletStorage.getAddresses();
        final privateKeys = <String, String>{};
        
        for (final entry in addresses.entries) {
          final address = entry.key;
          final privateKey = _walletStorage.getPrivateKey(address);
          if (privateKey != null) {
            privateKeys[address] = privateKey;
          }
        }

        if (privateKeys.isNotEmpty) {
          String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
          
          if (selectedDirectory != null) {
            final exportFileName = 'private_keys_${DateTime.now().millisecondsSinceEpoch}.txt';
            final exportPath = '$selectedDirectory/$exportFileName';
            
            final exportContent = privateKeys.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n');
            
            await File(exportPath).writeAsString(exportContent);
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Private keys exported to: $exportPath'),
                  backgroundColor: AppTheme.successGreen,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _unloadWallet() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.orange),
            SizedBox(width: 8),
            Text('Unload Wallet'),
          ],
        ),
        content: const Text(
          'Are you sure you want to unload the current wallet?\n\n'
          'This will sign you out and return to the wallet selection screen. '
          'Your wallet data will remain safe and you can load it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Unload Wallet'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() {
          _isLoading = true;
        });

        final prefs = await SharedPreferences.getInstance();
        
        // Clear current wallet data
        await prefs.remove('gotham_wallet');
        await prefs.remove('gotham_selected_wallet_id');
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wallet unloaded successfully'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          
          // Navigate back to wallet selector
          Navigator.of(context).pushReplacementNamed('/wallet-selector');
        }
        
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to unload wallet: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildWalletInfoCard(),
                const SizedBox(height: 16),
                _buildBackupSection(),
                const SizedBox(height: 16),
                _buildSecuritySection(),
              ],
            ),
    );
  }

  Widget _buildWalletInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info, color: AppTheme.accentGold),
                const SizedBox(width: 8),
                Text(
                  'Wallet Information',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_walletInfo != null) ...[
              _buildInfoRow('Wallet Version', _walletInfo!['wallet_version'].toString()),
              _buildInfoRow('Format', _walletInfo!['format']),
              _buildInfoRow('Balance', '${(_walletInfo!['balance'] / 100000000).toStringAsFixed(8)} GTC'),
              _buildInfoRow('Transactions', _walletInfo!['tx_count'].toString()),
              _buildInfoRow('Addresses', _walletInfo!['key_pool_size'].toString()),
              _buildInfoRow('HD Seed ID', _walletInfo!['hd_seed_id']?.toString().substring(0, 16) ?? 'N/A'),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showWalletPath,
                icon: const Icon(Icons.folder_open),
                label: const Text('Show Wallet File Location'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.backup, color: AppTheme.accentGold),
                const SizedBox(width: 8),
                Text(
                  'Backup & Recovery',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Regular backups are essential for wallet security. Your wallet.dat file contains all your private keys and addresses.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _backupWallet,
                icon: const Icon(Icons.save),
                label: const Text('Backup Wallet'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _exportPrivateKeys,
                icon: const Icon(Icons.key),
                label: const Text('Export Private Keys'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/wallet-selector');
                },
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Switch Wallet'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _unloadWallet,
                icon: const Icon(Icons.logout),
                label: const Text('Unload Wallet (Sign Out)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security, color: AppTheme.accentGold),
                const SizedBox(width: 8),
                Text(
                  'Security Tips',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '• Store your seed phrase offline in a secure location\n'
              '• Make regular backups of your wallet.dat file\n'
              '• Never share your private keys or seed phrase\n'
              '• Keep your wallet software updated\n'
              '• Consider using hardware wallets for large amounts',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}