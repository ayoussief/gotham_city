import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../services/wallet_service.dart';
import '../models/wallet.dart';
import '../theme/app_theme.dart';
import 'import_wallet_screen.dart';

class WalletSelectorScreen extends StatefulWidget {
  const WalletSelectorScreen({super.key});

  @override
  State<WalletSelectorScreen> createState() => _WalletSelectorScreenState();
}

class _WalletSelectorScreenState extends State<WalletSelectorScreen> {
  final WalletService _walletService = WalletService();
  List<WalletInfo> _availableWallets = [];
  bool _isLoading = false;
  String? _selectedWalletId;
  bool _dialogOpen = false;
  bool _operationCancelRequested = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableWallets();
  }

  void _cancelOperation() {
    setState(() {
      _operationCancelRequested = true;
      _isLoading = false;
    });
  }

  Future<void> _unloadCurrentWallet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear current wallet data
      await prefs.remove('gotham_wallet');
      await prefs.remove('gotham_selected_wallet_id');
      
      // Reset state
      setState(() {
        _selectedWalletId = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wallet unloaded successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
      
      // Reload wallets list
      await _loadAvailableWallets();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unload wallet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAvailableWallets() async {
    if (_dialogOpen) return; // Don't update state while dialog is open
    
    setState(() {
      _isLoading = true;
      _operationCancelRequested = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if operation was cancelled
      if (_operationCancelRequested) {
        return;
      }
      
      final walletListJson = prefs.getString('gotham_wallet_list') ?? '[]';
      final List<dynamic> walletList = jsonDecode(walletListJson);
      
      _availableWallets = walletList
          .map((json) => WalletInfo.fromJson(json))
          .toList();
      
      // Get currently selected wallet
      _selectedWalletId = prefs.getString('gotham_selected_wallet_id');
      
    } catch (e) {
      print('Error loading wallet list: $e');
    } finally {
      if (mounted && !_dialogOpen && !_operationCancelRequested) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectWallet(String walletId) async {
    setState(() {
      _isLoading = true;
      _operationCancelRequested = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if operation was cancelled
      if (_operationCancelRequested) {
        return;
      }
      
      // Find the wallet data
      final walletKey = 'gotham_wallet_$walletId';
      final walletDataJson = prefs.getString(walletKey);
      
      if (walletDataJson != null && !_operationCancelRequested) {
        // Set as current wallet
        await prefs.setString('gotham_wallet', walletDataJson);
        await prefs.setString('gotham_selected_wallet_id', walletId);
        
        // Navigate back to main screen
        if (mounted && !_operationCancelRequested) {
          Navigator.of(context).pushReplacementNamed('/main');
        }
      }
    } catch (e) {
      if (mounted && !_operationCancelRequested) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load wallet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted && !_dialogOpen && !_operationCancelRequested) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createNewWallet() async {
    // First, ask user for wallet name
    final walletName = await _askForWalletName();
    if (walletName == null || walletName.trim().isEmpty) {
      return; // User cancelled or entered empty name
    }

    setState(() {
      _isLoading = true;
      _operationCancelRequested = false;
    });

    try {
      // Initialize wallet service if needed
      if (!_walletService.isInitialized && !_operationCancelRequested) {
        await _walletService.initialize();
      }
      
      if (_operationCancelRequested) {
        return;
      }
      
      final wallet = await _walletService.createNewWallet();
      
      if (_operationCancelRequested) {
        return;
      }
      
      // Add to wallet list with chosen name
      await _addWalletToList(wallet, walletName.trim());
      
      // Stop loading before showing dialog
      setState(() {
        _isLoading = false;
      });
      
      // Show seed phrase dialog (this blocks until user closes it)
      if (mounted && wallet.seedPhrase != null && !_operationCancelRequested) {
        await _showSeedPhraseDialog(wallet.seedPhrase!);
      }
      
      // Reload wallets after dialog is closed
      if (!_operationCancelRequested) {
        await _loadAvailableWallets();
      }
      
    } catch (e) {
      if (!_operationCancelRequested) {
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create wallet: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<String?> _askForWalletName() async {
    final TextEditingController controller = TextEditingController();
    
    _dialogOpen = true;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit, color: AppTheme.accentGold),
              SizedBox(width: 8),
              Text('Name Your Wallet'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a name for your new wallet. This will help you identify it later.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Wallet Name',
                  hintText: 'e.g., My Main Wallet',
                  border: OutlineInputBorder(),
                ),
                maxLength: 50,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(context).pop(name);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    _dialogOpen = false;
    return result;
  }

  Future<void> _addWalletToList(Wallet wallet, String walletName) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Create wallet info with user-chosen name
    final walletInfo = WalletInfo(
      id: wallet.address, // Use address as ID
      name: walletName,
      address: wallet.address,
      createdAt: DateTime.now(),
      lastUsed: DateTime.now(),
    );
    
    // Add to wallet list
    final walletListJson = prefs.getString('gotham_wallet_list') ?? '[]';
    final List<dynamic> walletList = jsonDecode(walletListJson);
    walletList.add(walletInfo.toJson());
    
    await prefs.setString('gotham_wallet_list', jsonEncode(walletList));
    
    // Save wallet data separately
    final walletKey = 'gotham_wallet_${walletInfo.id}';
    await prefs.setString(walletKey, jsonEncode(wallet.toJson()));
    
    // Create a wallet file with the chosen name
    await _createWalletFile(walletName, wallet);
  }
  
  Future<void> _createWalletFile(String walletName, Wallet wallet) async {
    try {
      // Get the wallet directory (same as WalletService uses)
      final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
      final walletDir = '$homeDir/.gotham';
      
      // Create directory if it doesn't exist
      final dir = Directory(walletDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // Create wallet file with chosen name
      final walletFileName = _sanitizeFileName(walletName);
      final walletFile = File('$walletDir/$walletFileName.dat');
      
      // Create wallet data content (similar to wallet.dat format)
      final walletData = {
        'name': walletName,
        'address': wallet.address,
        'private_key': wallet.privateKey,
        'seed_phrase': wallet.seedPhrase,
        'balance': wallet.balance,
        'network': wallet.network,
        'is_imported': wallet.isImported,
        'created_at': DateTime.now().toIso8601String(),
        'wallet_version': '1.0',
      };
      
      await walletFile.writeAsString(jsonEncode(walletData));
      
      print('Created wallet file: ${walletFile.path}');
      
    } catch (e) {
      print('Error creating wallet file: $e');
      // Don't fail the whole process if file creation fails
    }
  }
  
  String _sanitizeFileName(String fileName) {
    // Remove invalid characters for file names
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  Future<void> _importWallet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImportWalletScreen(walletService: _walletService),
      ),
    );

    if (result != null && result is Wallet) {
      // Ask for wallet name for imported wallet too
      final walletName = await _askForWalletName();
      if (walletName != null && walletName.trim().isNotEmpty) {
        await _addWalletToList(result, walletName.trim());
        await _loadAvailableWallets();
      }
    }
  }

  Future<void> _showSeedPhraseDialog(String seedPhrase) async {
    _dialogOpen = true;
    final result = await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false, // Prevent back button
          child: AlertDialog(
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
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('I\'ve Saved It'),
              ),
            ],
          ),
        );
      },
    );
    _dialogOpen = false;
    return result;
  }

  Future<void> _deleteWallet(WalletInfo walletInfo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Wallet'),
        content: Text(
          'Are you sure you want to delete "${walletInfo.name}"?\n\n'
          'Make sure you have backed up your seed phrase!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        
        // Remove from wallet list
        final walletListJson = prefs.getString('gotham_wallet_list') ?? '[]';
        final List<dynamic> walletList = jsonDecode(walletListJson);
        walletList.removeWhere((w) => w['id'] == walletInfo.id);
        await prefs.setString('gotham_wallet_list', jsonEncode(walletList));
        
        // Remove wallet data
        await prefs.remove('gotham_wallet_${walletInfo.id}');
        
        // If this was the selected wallet, clear selection
        if (_selectedWalletId == walletInfo.id) {
          await prefs.remove('gotham_selected_wallet_id');
          await prefs.remove('gotham_wallet');
        }
        
        await _loadAvailableWallets();
        
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete wallet: $e'),
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
        title: const Text('Select Wallet'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? _buildLoadingView()
          : Column(
              children: [
                if (_availableWallets.isEmpty)
                  Expanded(
                    child: _buildEmptyState(),
                  )
                else
                  Expanded(
                    child: _buildWalletList(),
                  ),
                _buildBottomActions(),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 80,
              color: AppTheme.accentGold,
            ),
            const SizedBox(height: 24),
            Text(
              'No Wallets Found',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Create a new wallet or import an existing one to get started',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _availableWallets.length,
      itemBuilder: (context, index) {
        final wallet = _availableWallets[index];
        final isSelected = wallet.id == _selectedWalletId;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected ? AppTheme.accentGold : AppTheme.mediumGray,
              child: Icon(
                Icons.account_balance_wallet,
                color: isSelected ? Colors.black : Colors.white,
              ),
            ),
            title: Text(wallet.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${wallet.address.substring(0, 10)}...${wallet.address.substring(wallet.address.length - 10)}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                Text(
                  'Created: ${wallet.createdAt.day}/${wallet.createdAt.month}/${wallet.createdAt.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.accentGold,
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteWallet(wallet),
                ),
              ],
            ),
            onTap: isSelected ? null : () => _selectWallet(wallet.id),
          ),
        );
      },
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.lightGray.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _createNewWallet,
              icon: const Icon(Icons.add),
              label: const Text('Create New Wallet'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _importWallet,
              icon: const Icon(Icons.file_download),
              label: const Text('Import Wallet'),
            ),
          ),
          if (_selectedWalletId != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/main');
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue with Selected Wallet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _unloadCurrentWallet,
                icon: const Icon(Icons.logout),
                label: const Text('Unload Current Wallet'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppTheme.accentGold,
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            'Loading...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Please wait while we process your request',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _cancelOperation,
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class WalletInfo {
  final String id;
  final String name;
  final String address;
  final DateTime createdAt;
  final DateTime lastUsed;

  WalletInfo({
    required this.id,
    required this.name,
    required this.address,
    required this.createdAt,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'created_at': createdAt.millisecondsSinceEpoch,
      'last_used': lastUsed.millisecondsSinceEpoch,
    };
  }

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at']),
      lastUsed: DateTime.fromMillisecondsSinceEpoch(json['last_used']),
    );
  }
}