import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../crypto/gotham_wallet.dart';

/// Gotham Core compatible wallet manager
/// Handles wallet directory structure and wallet.dat files exactly like Gotham Core
class GothamWalletManager {
  static final GothamWalletManager _instance = GothamWalletManager._internal();
  factory GothamWalletManager() => _instance;
  GothamWalletManager._internal();

  String? _walletDir;
  final Map<String, GothamWallet> _loadedWallets = {};

  /// Initialize wallet manager with proper directory structure
  Future<void> initialize({String? customWalletDir}) async {
    if (customWalletDir != null) {
      _walletDir = customWalletDir;
    } else {
      // Default to ~/.gotham/wallets (matches Gotham Core)
      final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
      _walletDir = path.join(homeDir, '.gotham', 'wallets');
    }
    
    // Ensure wallet directory exists
    final dir = Directory(_walletDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    print('GothamWalletManager: Initialized with wallet directory: $_walletDir');
  }

  /// Create new wallet (matches createwallet RPC)
  Future<CreateWalletResult> createWallet({
    required String walletName,
    bool disablePrivateKeys = false,
    bool blank = false,
    String? passphrase,
    bool avoidReuse = false,
    bool descriptors = true, // Always true, no legacy support
    bool? loadOnStartup,
    bool externalSigner = false,
  }) async {
    if (_walletDir == null) {
      throw StateError('Wallet manager not initialized');
    }

    // Validate parameters (matches Gotham Core validation)
    if (!descriptors) {
      throw ArgumentError('Legacy wallets can no longer be created. descriptors must be true.');
    }

    if (externalSigner && !disablePrivateKeys) {
      throw ArgumentError('Private keys must be disabled when using an external signer');
    }

    if (passphrase != null && passphrase.isNotEmpty && disablePrivateKeys) {
      throw ArgumentError('Passphrase provided but private keys are disabled');
    }

    // Create wallet directory structure: wallets/wallet_name/
    final walletPath = path.join(_walletDir!, walletName);
    final walletDir = Directory(walletPath);
    
    if (await walletDir.exists()) {
      throw ArgumentError('Wallet already exists: $walletName');
    }

    await walletDir.create(recursive: true);
    print('GothamWalletManager: Created wallet directory: $walletPath');

    // Create wallet flags (matches Gotham Core flags)
    int flags = walletFlagDescriptors;
    if (disablePrivateKeys) flags |= walletFlagDisablePrivateKeys;
    if (blank) flags |= walletFlagBlankWallet;
    if (avoidReuse) flags |= walletFlagAvoidReuse;
    if (externalSigner) flags |= walletFlagExternalSigner;

    GothamWallet wallet;
    List<String> warnings = [];

    if (blank) {
      // Create blank wallet (no keys)
      wallet = GothamWallet.createBlank(flags, walletName: walletName);
    } else if (disablePrivateKeys) {
      // Create watch-only wallet
      wallet = GothamWallet.createWatchOnly(flags, walletName: walletName);
    } else {
      // Create normal descriptor wallet with private keys
      wallet = GothamWallet.create(flags, walletName: walletName);
    }

    // Handle encryption
    if (passphrase != null && passphrase.isNotEmpty && !disablePrivateKeys) {
      if (!wallet.encryptWallet(passphrase)) {
        // Clean up on encryption failure
        await walletDir.delete(recursive: true);
        throw Exception('Wallet created but failed to encrypt');
      }
      
      if (!blank) {
        // Unlock to set up generation, then relock
        if (!wallet.unlock(passphrase)) {
          await walletDir.delete(recursive: true);
          throw Exception('Wallet was encrypted but could not be unlocked');
        }
        
        wallet.setupGeneration();
        wallet.lock();
      }
    } else if (!blank && !disablePrivateKeys) {
      // Set up key generation for unencrypted wallets
      wallet.setupGeneration();
    }

    // Save wallet.dat file
    final walletFile = File(path.join(walletPath, 'wallet.dat'));
    await _saveWalletFile(walletFile, wallet);

    // Load wallet into memory
    _loadedWallets[walletName] = wallet;

    // Handle load_on_startup setting
    if (loadOnStartup != null) {
      await _updateStartupWallets(walletName, loadOnStartup);
    }

    // Add legacy wallet warning if somehow created (shouldn't happen)
    if (!wallet.isWalletFlagSet(walletFlagDescriptors)) {
      warnings.add('Wallet created successfully. The legacy wallet type is being deprecated.');
    }

    print('GothamWalletManager: Successfully created wallet: $walletName');
    
    return CreateWalletResult(
      name: walletName,
      warnings: warnings,
    );
  }

  /// Load existing wallet (matches loadwallet RPC) 
  Future<LoadWalletResult> loadWallet({
    required String walletName,
    bool? loadOnStartup,
  }) async {
    if (_walletDir == null) {
      throw StateError('Wallet manager not initialized');
    }

    if (_loadedWallets.containsKey(walletName)) {
      throw ArgumentError('Wallet is already loaded: $walletName');
    }

    final walletPath = path.join(_walletDir!, walletName);
    final walletFile = File(path.join(walletPath, 'wallet.dat'));

    if (!await walletFile.exists()) {
      throw ArgumentError('Wallet file not found: $walletName');
    }

    // Load wallet from file
    final wallet = await _loadWalletFile(walletFile);
    _loadedWallets[walletName] = wallet;

    // Handle load_on_startup setting
    List<String> warnings = [];
    if (loadOnStartup != null) {
      await _updateStartupWallets(walletName, loadOnStartup);
    }

    print('GothamWalletManager: Successfully loaded wallet: $walletName');
    
    return LoadWalletResult(
      name: walletName,
      warnings: warnings,
    );
  }

  /// Unload wallet (matches unloadwallet RPC)
  Future<UnloadWalletResult> unloadWallet({
    required String walletName,
    bool? loadOnStartup,
  }) async {
    if (!_loadedWallets.containsKey(walletName)) {
      throw ArgumentError('Wallet not loaded: $walletName');
    }

    final wallet = _loadedWallets[walletName]!;
    
    // Save wallet before unloading
    final walletPath = path.join(_walletDir!, walletName);
    final walletFile = File(path.join(walletPath, 'wallet.dat'));
    await _saveWalletFile(walletFile, wallet);

    // Remove from memory
    _loadedWallets.remove(walletName);

    // Handle load_on_startup setting
    List<String> warnings = [];
    if (loadOnStartup != null) {
      await _updateStartupWallets(walletName, loadOnStartup);
    }

    print('GothamWalletManager: Successfully unloaded wallet: $walletName');
    
    return UnloadWalletResult(warnings: warnings);
  }

  /// List wallet directory (matches listwalletdir RPC)
  Future<List<WalletDirEntry>> listWalletDir() async {
    if (_walletDir == null) {
      throw StateError('Wallet manager not initialized');
    }

    final entries = <WalletDirEntry>[];
    final walletDir = Directory(_walletDir!);

    if (await walletDir.exists()) {
      await for (final entity in walletDir.list()) {
        if (entity is Directory) {
          final walletFile = File(path.join(entity.path, 'wallet.dat'));
          if (await walletFile.exists()) {
            final stat = await walletFile.stat();
            entries.add(WalletDirEntry(
              name: path.basename(entity.path),
              type: 'sqlite', // All new wallets are SQLite-based descriptors
            ));
          }
        }
      }
    }

    return entries;
  }

  /// List loaded wallets (matches listwallets RPC)
  List<String> listWallets() {
    return _loadedWallets.keys.toList();
  }

  /// Get wallet by name
  GothamWallet? getWallet(String walletName) {
    return _loadedWallets[walletName];
  }

  /// Get wallet directory path
  String get walletDirectory => _walletDir ?? '';

  // Private helper methods

  Future<void> _saveWalletFile(File walletFile, GothamWallet wallet) async {
    final walletData = wallet.serialize();
    final jsonString = jsonEncode(walletData);
    
    // Create backup first
    final backupFile = File('${walletFile.path}.bak');
    if (await walletFile.exists()) {
      await walletFile.copy(backupFile.path);
    }
    
    try {
      await walletFile.writeAsString(jsonString);
      print('GothamWalletManager: Saved wallet.dat: ${walletFile.path}');
    } catch (e) {
      // Restore backup on failure
      if (await backupFile.exists()) {
        await backupFile.copy(walletFile.path);
      }
      throw Exception('Failed to save wallet file: $e');
    }
  }

  Future<GothamWallet> _loadWalletFile(File walletFile) async {
    try {
      final jsonString = await walletFile.readAsString();
      final walletData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Reconstruct wallet from serialized data
      return GothamWallet.deserialize(walletData);
    } catch (e) {
      throw Exception('Failed to load wallet file: $e');
    }
  }

  Future<void> _updateStartupWallets(String walletName, bool loadOnStartup) async {
    // TODO: Implement startup wallet persistence (similar to Bitcoin Core settings)
    print('GothamWalletManager: Updated startup setting for $walletName: $loadOnStartup');
  }
}

// Result classes matching Gotham Core RPC responses

class CreateWalletResult {
  final String name;
  final List<String> warnings;

  CreateWalletResult({required this.name, required this.warnings});

  Map<String, dynamic> toJson() => {
    'name': name,
    if (warnings.isNotEmpty) 'warnings': warnings,
  };
}

class LoadWalletResult {
  final String name;
  final List<String> warnings;

  LoadWalletResult({required this.name, required this.warnings});

  Map<String, dynamic> toJson() => {
    'name': name,
    if (warnings.isNotEmpty) 'warnings': warnings,
  };
}

class UnloadWalletResult {
  final List<String> warnings;

  UnloadWalletResult({required this.warnings});

  Map<String, dynamic> toJson() => {
    if (warnings.isNotEmpty) 'warnings': warnings,
  };
}

class WalletDirEntry {
  final String name;
  final String type;

  WalletDirEntry({required this.name, required this.type});

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
  };
}

// Wallet flags (matching Gotham Core)
const int walletFlagAvoidReuse = 1 << 0;
const int walletFlagDescriptors = 1 << 4;
const int walletFlagDisablePrivateKeys = 1 << 5;
const int walletFlagBlankWallet = 1 << 6;
const int walletFlagExternalSigner = 1 << 7;