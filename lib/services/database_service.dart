import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/block_header.dart';
import '../bitcoin_node/services/database_helper.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize database factory for desktop platforms
    DatabaseHelper.initializeDatabaseFactory();
    
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'gotham_node.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Block headers table
    await db.execute('''
      CREATE TABLE block_headers (
        hash TEXT PRIMARY KEY,
        version INTEGER NOT NULL,
        previous_block_hash TEXT NOT NULL,
        merkle_root TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        bits INTEGER NOT NULL,
        nonce INTEGER NOT NULL,
        height INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create index on height for faster queries
    await db.execute('''
      CREATE INDEX idx_block_headers_height ON block_headers(height)
    ''');

    // Create index on timestamp for cache cleanup
    await db.execute('''
      CREATE INDEX idx_block_headers_timestamp ON block_headers(timestamp)
    ''');

    // Create index on created_at for cache management
    await db.execute('''
      CREATE INDEX idx_block_headers_created_at ON block_headers(created_at)
    ''');

    // Wallets table - Based on Gotham Core wallet structure
    await db.execute('''
      CREATE TABLE wallets (
        name TEXT PRIMARY KEY,
        description TEXT,
        is_encrypted INTEGER DEFAULT 0,
        is_watch_only INTEGER DEFAULT 0,
        is_hd INTEGER DEFAULT 1,
        seed_phrase TEXT,
        created_at INTEGER NOT NULL,
        last_used INTEGER,
        network TEXT DEFAULT 'main',
        version INTEGER DEFAULT 1,
        metadata TEXT,
        total_balance INTEGER DEFAULT 0,
        confirmed_balance INTEGER DEFAULT 0,
        unconfirmed_balance INTEGER DEFAULT 0,
        immature_balance INTEGER DEFAULT 0,
        address_count INTEGER DEFAULT 0,
        used_address_count INTEGER DEFAULT 0,
        change_address_count INTEGER DEFAULT 0,
        transaction_count INTEGER DEFAULT 0,
        last_transaction_time INTEGER
      )
    ''');

    // Addresses table - Individual addresses within wallets
    await db.execute('''
      CREATE TABLE addresses (
        address TEXT PRIMARY KEY,
        wallet_name TEXT NOT NULL,
        balance INTEGER DEFAULT 0,
        confirmed_balance INTEGER DEFAULT 0,
        unconfirmed_balance INTEGER DEFAULT 0,
        label TEXT,
        is_change INTEGER DEFAULT 0,
        is_internal INTEGER DEFAULT 0,
        transaction_count INTEGER DEFAULT 0,
        created_at INTEGER,
        last_used INTEGER,
        public_key TEXT,
        private_key TEXT,
        derivation_index INTEGER DEFAULT 0,
        derivation_path TEXT DEFAULT '',
        address_type TEXT NOT NULL,
        is_watch_only INTEGER DEFAULT 0,
        metadata TEXT,
        FOREIGN KEY (wallet_name) REFERENCES wallets (name) ON DELETE CASCADE
      )
    ''');

    // Transactions table - Transaction records for wallets
    await db.execute('''
      CREATE TABLE transactions (
        txid TEXT PRIMARY KEY,
        wallet_name TEXT NOT NULL,
        block_hash TEXT,
        block_height INTEGER,
        timestamp INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        fee INTEGER DEFAULT 0,
        confirmations INTEGER DEFAULT 0,
        is_coinbase INTEGER DEFAULT 0,
        category TEXT NOT NULL,
        address TEXT,
        label TEXT,
        raw_transaction TEXT,
        metadata TEXT,
        FOREIGN KEY (wallet_name) REFERENCES wallets (name) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_addresses_wallet ON addresses(wallet_name)');
    await db.execute('CREATE INDEX idx_addresses_balance ON addresses(balance)');
    await db.execute('CREATE INDEX idx_addresses_is_change ON addresses(is_change)');
    await db.execute('CREATE INDEX idx_addresses_derivation_index ON addresses(derivation_index)');
    
    await db.execute('CREATE INDEX idx_transactions_wallet ON transactions(wallet_name)');
    await db.execute('CREATE INDEX idx_transactions_timestamp ON transactions(timestamp)');
    await db.execute('CREATE INDEX idx_transactions_block_height ON transactions(block_height)');
    await db.execute('CREATE INDEX idx_transactions_address ON transactions(address)');

    // Node settings table
    await db.execute('''
      CREATE TABLE node_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Peers table (for caching peer information)
    await db.execute('''
      CREATE TABLE peers (
        address TEXT PRIMARY KEY,
        port INTEGER NOT NULL,
        user_agent TEXT,
        version INTEGER,
        services INTEGER,
        last_seen INTEGER NOT NULL,
        connection_count INTEGER DEFAULT 0,
        is_banned INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < newVersion) {
      // Add migration logic if needed
    }
  }

  // Block header operations
  Future<void> insertBlockHeader(BlockHeader header) async {
    final db = await database;
    await db.insert(
      'block_headers',
      header.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertBlockHeaders(List<BlockHeader> headers) async {
    final db = await database;
    final batch = db.batch();
    
    for (final header in headers) {
      batch.insert(
        'block_headers',
        header.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  Future<BlockHeader?> getBlockHeader(String hash) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'block_headers',
      where: 'hash = ?',
      whereArgs: [hash],
    );

    if (maps.isNotEmpty) {
      return BlockHeader.fromDbMap(maps.first);
    }
    return null;
  }

  Future<BlockHeader?> getBlockHeaderByHeight(int height) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'block_headers',
      where: 'height = ?',
      whereArgs: [height],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return BlockHeader.fromDbMap(maps.first);
    }
    return null;
  }

  Future<List<BlockHeader>> getBlockHeaders({
    int? limit,
    int? offset,
    String? orderBy,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'block_headers',
      orderBy: orderBy ?? 'height DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => BlockHeader.fromDbMap(map)).toList();
  }

  Future<List<BlockHeader>> getRecentBlockHeaders(int count) async {
    return await getBlockHeaders(
      limit: count,
      orderBy: 'height DESC',
    );
  }

  Future<BlockHeader?> getLatestBlockHeader() async {
    final headers = await getRecentBlockHeaders(1);
    return headers.isNotEmpty ? headers.first : null;
  }

  Future<int> getBlockHeadersCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM block_headers');
    return result.first['count'] as int;
  }

  Future<int> getLatestBlockHeight() async {
    final db = await database;
    final result = await db.rawQuery('SELECT MAX(height) as max_height FROM block_headers');
    return (result.first['max_height'] as int?) ?? 0;
  }

  // Cache management - delete blocks older than 24 hours
  Future<int> cleanupOldBlocks() async {
    final db = await database;
    final cutoffTime = DateTime.now().subtract(const Duration(hours: 24));
    final cutoffTimestamp = cutoffTime.millisecondsSinceEpoch ~/ 1000;

    final deletedCount = await db.delete(
      'block_headers',
      where: 'timestamp < ?',
      whereArgs: [cutoffTimestamp],
    );

    print('Cleaned up $deletedCount old block headers');
    return deletedCount;
  }

  // Alternative cleanup - keep only last 144 blocks (approximately 24 hours)
  Future<int> cleanupKeepLatestBlocks(int keepCount) async {
    final db = await database;
    
    // Get the height threshold
    final result = await db.rawQuery('''
      SELECT height FROM block_headers 
      ORDER BY height DESC 
      LIMIT 1 OFFSET ?
    ''', [keepCount - 1]);

    if (result.isEmpty) return 0;

    final thresholdHeight = result.first['height'] as int;
    
    final deletedCount = await db.delete(
      'block_headers',
      where: 'height < ?',
      whereArgs: [thresholdHeight],
    );

    print('Cleaned up $deletedCount old block headers, keeping latest $keepCount blocks');
    return deletedCount;
  }

  // Node settings operations
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'node_settings',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'node_settings',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
  }

  // Peer operations
  Future<void> updatePeerInfo(String address, int port, Map<String, dynamic> peerData) async {
    final db = await database;
    await db.insert(
      'peers',
      {
        'address': address,
        'port': port,
        'user_agent': peerData['user_agent'] ?? '',
        'version': peerData['version'] ?? 0,
        'services': peerData['services'] ?? 0,
        'last_seen': DateTime.now().millisecondsSinceEpoch,
        'connection_count': 1,
        'is_banned': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getKnownPeers() async {
    final db = await database;
    return await db.query(
      'peers',
      where: 'is_banned = 0',
      orderBy: 'last_seen DESC',
      limit: 50,
    );
  }

  // Database maintenance
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  Future<int> getDatabaseSize() async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA page_count');
    final pageCount = result.first['page_count'] as int;
    
    final pageSizeResult = await db.rawQuery('PRAGMA page_size');
    final pageSize = pageSizeResult.first['page_size'] as int;
    
    return pageCount * pageSize;
  }

  // Get database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await database;
    
    final blockHeadersCount = await getBlockHeadersCount();
    final latestHeight = await getLatestBlockHeight();
    final dbSize = await getDatabaseSize();
    
    final peersResult = await db.rawQuery('SELECT COUNT(*) as count FROM peers');
    final peersCount = peersResult.first['count'] as int;
    
    return {
      'block_headers_count': blockHeadersCount,
      'latest_height': latestHeight,
      'database_size_bytes': dbSize,
      'database_size_mb': (dbSize / (1024 * 1024)).toStringAsFixed(2),
      'peers_count': peersCount,
    };
  }

  // Wallet operations
  Future<void> saveWallet(Map<String, dynamic> walletData) async {
    final db = await database;
    
    // Convert boolean fields to integers for SQLite
    final data = Map<String, dynamic>.from(walletData);
    data['is_encrypted'] = (data['isEncrypted'] ?? false) ? 1 : 0;
    data['is_watch_only'] = (data['isWatchOnly'] ?? false) ? 1 : 0;
    data['is_hd'] = (data['isHD'] ?? true) ? 1 : 0;
    
    // Convert metadata to JSON string if it exists
    if (data['metadata'] != null) {
      data['metadata'] = jsonEncode(data['metadata']);
    }
    
    // Remove Flutter-style keys and use database column names
    data.remove('isEncrypted');
    data.remove('isWatchOnly');
    data.remove('isHD');
    
    await db.insert(
      'wallets',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getWallets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'wallets',
      orderBy: 'last_used DESC, created_at DESC',
    );

    // Convert database format back to Flutter format
    return maps.map((map) {
      final data = Map<String, dynamic>.from(map);
      data['isEncrypted'] = (data['is_encrypted'] ?? 0) == 1;
      data['isWatchOnly'] = (data['is_watch_only'] ?? 0) == 1;
      data['isHD'] = (data['is_hd'] ?? 1) == 1;
      
      // Parse metadata JSON if it exists
      if (data['metadata'] != null && data['metadata'] is String) {
        try {
          data['metadata'] = jsonDecode(data['metadata']);
        } catch (e) {
          data['metadata'] = null;
        }
      }
      
      // Remove database-style keys
      data.remove('is_encrypted');
      data.remove('is_watch_only');
      data.remove('is_hd');
      
      return data;
    }).toList();
  }

  Future<Map<String, dynamic>?> getWallet(String name) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'wallets',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (maps.isNotEmpty) {
      final data = Map<String, dynamic>.from(maps.first);
      data['isEncrypted'] = (data['is_encrypted'] ?? 0) == 1;
      data['isWatchOnly'] = (data['is_watch_only'] ?? 0) == 1;
      data['isHD'] = (data['is_hd'] ?? 1) == 1;
      
      if (data['metadata'] != null && data['metadata'] is String) {
        try {
          data['metadata'] = jsonDecode(data['metadata']);
        } catch (e) {
          data['metadata'] = null;
        }
      }
      
      data.remove('is_encrypted');
      data.remove('is_watch_only');
      data.remove('is_hd');
      
      return data;
    }
    return null;
  }

  Future<void> deleteWallet(String name) async {
    final db = await database;
    await db.delete(
      'wallets',
      where: 'name = ?',
      whereArgs: [name],
    );
    // Addresses and transactions will be deleted automatically due to CASCADE
  }

  // Address operations
  Future<void> saveAddress(Map<String, dynamic> addressData) async {
    final db = await database;
    
    // Convert boolean fields to integers for SQLite
    final data = Map<String, dynamic>.from(addressData);
    data['is_change'] = (data['isChange'] ?? false) ? 1 : 0;
    data['is_internal'] = (data['isInternal'] ?? false) ? 1 : 0;
    data['is_watch_only'] = (data['isWatchOnly'] ?? false) ? 1 : 0;
    
    // Convert metadata to JSON string if it exists
    if (data['metadata'] != null) {
      data['metadata'] = jsonEncode(data['metadata']);
    }
    
    // Remove Flutter-style keys
    data.remove('isChange');
    data.remove('isInternal');
    data.remove('isWatchOnly');
    
    await db.insert(
      'addresses',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAddressesForWallet(String walletName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'addresses',
      where: 'wallet_name = ?',
      whereArgs: [walletName],
      orderBy: 'is_change ASC, derivation_index ASC',
    );

    // Convert database format back to Flutter format
    return maps.map((map) {
      final data = Map<String, dynamic>.from(map);
      data['isChange'] = (data['is_change'] ?? 0) == 1;
      data['isInternal'] = (data['is_internal'] ?? 0) == 1;
      data['isWatchOnly'] = (data['is_watch_only'] ?? 0) == 1;
      
      // Parse metadata JSON if it exists
      if (data['metadata'] != null && data['metadata'] is String) {
        try {
          data['metadata'] = jsonDecode(data['metadata']);
        } catch (e) {
          data['metadata'] = null;
        }
      }
      
      // Remove database-style keys
      data.remove('is_change');
      data.remove('is_internal');
      data.remove('is_watch_only');
      
      return data;
    }).toList();
  }

  Future<Map<String, dynamic>?> getAddress(String address) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'addresses',
      where: 'address = ?',
      whereArgs: [address],
    );

    if (maps.isNotEmpty) {
      final data = Map<String, dynamic>.from(maps.first);
      data['isChange'] = (data['is_change'] ?? 0) == 1;
      data['isInternal'] = (data['is_internal'] ?? 0) == 1;
      data['isWatchOnly'] = (data['is_watch_only'] ?? 0) == 1;
      
      if (data['metadata'] != null && data['metadata'] is String) {
        try {
          data['metadata'] = jsonDecode(data['metadata']);
        } catch (e) {
          data['metadata'] = null;
        }
      }
      
      data.remove('is_change');
      data.remove('is_internal');
      data.remove('is_watch_only');
      
      return data;
    }
    return null;
  }

  // Transaction operations
  Future<void> saveTransaction(Map<String, dynamic> transactionData) async {
    final db = await database;
    
    // Convert boolean fields to integers for SQLite
    final data = Map<String, dynamic>.from(transactionData);
    data['is_coinbase'] = (data['isCoinbase'] ?? false) ? 1 : 0;
    
    // Convert metadata to JSON string if it exists
    if (data['metadata'] != null) {
      data['metadata'] = jsonEncode(data['metadata']);
    }
    
    // Remove Flutter-style keys
    data.remove('isCoinbase');
    
    await db.insert(
      'transactions',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getTransactionsForWallet(String walletName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'wallet_name = ?',
      whereArgs: [walletName],
      orderBy: 'timestamp DESC',
    );

    // Convert database format back to Flutter format
    return maps.map((map) {
      final data = Map<String, dynamic>.from(map);
      data['isCoinbase'] = (data['is_coinbase'] ?? 0) == 1;
      
      // Parse metadata JSON if it exists
      if (data['metadata'] != null && data['metadata'] is String) {
        try {
          data['metadata'] = jsonDecode(data['metadata']);
        } catch (e) {
          data['metadata'] = null;
        }
      }
      
      // Remove database-style keys
      data.remove('is_coinbase');
      
      return data;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getTransactionsForAddress(String address) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'address = ?',
      whereArgs: [address],
      orderBy: 'timestamp DESC',
    );

    return maps.map((map) {
      final data = Map<String, dynamic>.from(map);
      data['isCoinbase'] = (data['is_coinbase'] ?? 0) == 1;
      
      if (data['metadata'] != null && data['metadata'] is String) {
        try {
          data['metadata'] = jsonDecode(data['metadata']);
        } catch (e) {
          data['metadata'] = null;
        }
      }
      
      data.remove('is_coinbase');
      
      return data;
    }).toList();
  }

  // Initialize method to ensure database is ready
  Future<void> initialize() async {
    await database; // This will trigger database creation if needed
  }

  // Close database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}