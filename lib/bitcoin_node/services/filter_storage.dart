import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/block_header.dart';
import '../models/compact_filter.dart';

// Storage service for compact filters and headers
class FilterStorage {
  static final FilterStorage _instance = FilterStorage._internal();
  factory FilterStorage() => _instance;
  FilterStorage._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'gotham_spv.db');

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

    // Compact filter headers table
    await db.execute('''
      CREATE TABLE filter_headers (
        block_hash TEXT PRIMARY KEY,
        filter_hash TEXT NOT NULL,
        previous_filter_header TEXT NOT NULL,
        block_height INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Compact filters table
    await db.execute('''
      CREATE TABLE compact_filters (
        block_hash TEXT PRIMARY KEY,
        block_height INTEGER NOT NULL,
        filter_type INTEGER NOT NULL,
        filter_data BLOB NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Wallet addresses table
    await db.execute('''
      CREATE TABLE watch_addresses (
        address TEXT PRIMARY KEY,
        script_pubkey TEXT,
        added_at INTEGER NOT NULL,
        last_checked INTEGER DEFAULT 0
      )
    ''');

    // Transaction cache table
    await db.execute('''
      CREATE TABLE transactions (
        txid TEXT PRIMARY KEY,
        block_hash TEXT,
        block_height INTEGER,
        tx_data TEXT NOT NULL,
        confirmations INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // UTXO tracking table
    await db.execute('''
      CREATE TABLE utxos (
        txid TEXT NOT NULL,
        vout INTEGER NOT NULL,
        address TEXT NOT NULL,
        amount INTEGER NOT NULL,
        script_pubkey TEXT NOT NULL,
        block_height INTEGER,
        spent INTEGER DEFAULT 0,
        PRIMARY KEY (txid, vout)
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_block_headers_height ON block_headers(height)');
    await db.execute('CREATE INDEX idx_filter_headers_height ON filter_headers(block_height)');
    await db.execute('CREATE INDEX idx_compact_filters_height ON compact_filters(block_height)');
    await db.execute('CREATE INDEX idx_transactions_height ON transactions(block_height)');
    await db.execute('CREATE INDEX idx_utxos_address ON utxos(address)');
    await db.execute('CREATE INDEX idx_utxos_spent ON utxos(spent)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades
    if (oldVersion < newVersion) {
      // Add migration logic if needed
    }
  }

  Future<void> initialize() async {
    await database; // Ensure database is initialized
    print('Filter storage initialized');
  }

  // Header operations
  Future<void> storeHeader(BlockHeader header) async {
    final db = await database;
    await db.insert(
      'block_headers',
      header.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> storeHeaders(List<BlockHeader> headers) async {
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

  Future<BlockHeader?> getHeader(String hash) async {
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

  Future<BlockHeader?> getHeaderByHeight(int height) async {
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

  Future<BlockHeader?> getLatestHeader() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'block_headers',
      orderBy: 'height DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return BlockHeader.fromDbMap(maps.first);
    }
    return null;
  }

  Future<List<BlockHeader>> getHeaders({int? limit, int? offset}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'block_headers',
      orderBy: 'height DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => BlockHeader.fromDbMap(map)).toList();
  }

  // Filter header operations
  Future<void> storeFilterHeader(CompactFilterHeader filterHeader) async {
    final db = await database;
    await db.insert(
      'filter_headers',
      filterHeader.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> storeFilterHeaders(List<CompactFilterHeader> filterHeaders) async {
    final db = await database;
    final batch = db.batch();
    
    for (final filterHeader in filterHeaders) {
      batch.insert(
        'filter_headers',
        filterHeader.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  Future<CompactFilterHeader?> getFilterHeader(String blockHash) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'filter_headers',
      where: 'block_hash = ?',
      whereArgs: [blockHash],
    );

    if (maps.isNotEmpty) {
      return CompactFilterHeader.fromDbMap(maps.first);
    }
    return null;
  }

  Future<List<CompactFilterHeader>> getFilterHeaders({int? limit, int? fromHeight}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    
    if (fromHeight != null) {
      where = 'block_height >= ?';
      whereArgs = [fromHeight];
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'filter_headers',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'block_height ASC',
      limit: limit,
    );

    return maps.map((map) => CompactFilterHeader.fromDbMap(map)).toList();
  }

  // Compact filter operations
  Future<void> storeFilter(CompactFilter filter) async {
    final db = await database;
    await db.insert(
      'compact_filters',
      filter.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> storeFilters(List<CompactFilter> filters) async {
    final db = await database;
    final batch = db.batch();
    
    for (final filter in filters) {
      batch.insert(
        'compact_filters',
        filter.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  Future<CompactFilter?> getFilter(String blockHash) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'compact_filters',
      where: 'block_hash = ?',
      whereArgs: [blockHash],
    );

    if (maps.isNotEmpty) {
      return CompactFilter.fromDbMap(maps.first);
    }
    return null;
  }

  Future<List<CompactFilter>> getFilters({int? limit, int? fromHeight}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    
    if (fromHeight != null) {
      where = 'block_height >= ?';
      whereArgs = [fromHeight];
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'compact_filters',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'block_height DESC',
      limit: limit,
    );

    return maps.map((map) => CompactFilter.fromDbMap(map)).toList();
  }

  Future<List<CompactFilter>> getRecentFilters(int count) async {
    return await getFilters(limit: count);
  }

  // Watch address operations
  Future<void> addWatchAddress(String address, {String? scriptPubKey}) async {
    final db = await database;
    await db.insert(
      'watch_addresses',
      {
        'address': address,
        'script_pubkey': scriptPubKey ?? '',
        'added_at': DateTime.now().millisecondsSinceEpoch,
        'last_checked': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> addWatchAddresses(List<String> addresses) async {
    final db = await database;
    final batch = db.batch();
    
    for (final address in addresses) {
      batch.insert(
        'watch_addresses',
        {
          'address': address,
          'script_pubkey': '',
          'added_at': DateTime.now().millisecondsSinceEpoch,
          'last_checked': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  Future<List<String>> getWatchAddresses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('watch_addresses');
    return maps.map((map) => map['address'] as String).toList();
  }

  Future<void> updateAddressLastChecked(String address) async {
    final db = await database;
    await db.update(
      'watch_addresses',
      {'last_checked': DateTime.now().millisecondsSinceEpoch},
      where: 'address = ?',
      whereArgs: [address],
    );
  }

  // Transaction operations
  Future<void> storeTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    await db.insert(
      'transactions',
      {
        'txid': transaction['txid'],
        'block_hash': transaction['block_hash'],
        'block_height': transaction['block_height'],
        'tx_data': transaction.toString(),
        'confirmations': transaction['confirmations'] ?? 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getTransactions({int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps;
  }

  // UTXO operations
  Future<void> addUTXO({
    required String txid,
    required int vout,
    required String address,
    required int amount,
    required String scriptPubKey,
    int? blockHeight,
  }) async {
    final db = await database;
    await db.insert(
      'utxos',
      {
        'txid': txid,
        'vout': vout,
        'address': address,
        'amount': amount,
        'script_pubkey': scriptPubKey,
        'block_height': blockHeight,
        'spent': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markUTXOSpent(String txid, int vout) async {
    final db = await database;
    await db.update(
      'utxos',
      {'spent': 1},
      where: 'txid = ? AND vout = ?',
      whereArgs: [txid, vout],
    );
  }

  Future<List<Map<String, dynamic>>> getUnspentUTXOs({String? address}) async {
    final db = await database;
    String where = 'spent = 0';
    List<dynamic> whereArgs = [];
    
    if (address != null) {
      where += ' AND address = ?';
      whereArgs.add(address);
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'utxos',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'amount DESC',
    );
    
    return maps;
  }

  Future<int> getBalance({String? address}) async {
    final utxos = await getUnspentUTXOs(address: address);
    return utxos.fold<int>(0, (sum, utxo) => sum + (utxo['amount'] as int));
  }

  // Cleanup operations
  Future<int> cleanupOldData({int keepDays = 30}) async {
    final db = await database;
    final cutoffTime = DateTime.now().subtract(Duration(days: keepDays));
    final cutoffTimestamp = cutoffTime.millisecondsSinceEpoch;

    int deletedCount = 0;
    
    // Clean up old transactions
    deletedCount += await db.delete(
      'transactions',
      where: 'created_at < ? AND confirmations > 6',
      whereArgs: [cutoffTimestamp],
    );
    
    // Clean up old filters (keep recent ones)
    final latestHeight = await _getLatestHeight();
    if (latestHeight > 1000) {
      deletedCount += await db.delete(
        'compact_filters',
        where: 'block_height < ?',
        whereArgs: [latestHeight - 1000],
      );
      
      deletedCount += await db.delete(
        'filter_headers',
        where: 'block_height < ?',
        whereArgs: [latestHeight - 1000],
      );
    }

    print('Cleaned up $deletedCount old records');
    return deletedCount;
  }

  Future<int> _getLatestHeight() async {
    final db = await database;
    final result = await db.rawQuery('SELECT MAX(height) as max_height FROM block_headers');
    return (result.first['max_height'] as int?) ?? 0;
  }

  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  // Statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    final db = await database;
    
    final headerCount = await db.rawQuery('SELECT COUNT(*) as count FROM block_headers');
    final filterHeaderCount = await db.rawQuery('SELECT COUNT(*) as count FROM filter_headers');
    final filterCount = await db.rawQuery('SELECT COUNT(*) as count FROM compact_filters');
    final addressCount = await db.rawQuery('SELECT COUNT(*) as count FROM watch_addresses');
    final txCount = await db.rawQuery('SELECT COUNT(*) as count FROM transactions');
    final utxoCount = await db.rawQuery('SELECT COUNT(*) as count FROM utxos WHERE spent = 0');
    
    return {
      'headers': headerCount.first['count'],
      'filter_headers': filterHeaderCount.first['count'],
      'filters': filterCount.first['count'],
      'watch_addresses': addressCount.first['count'],
      'transactions': txCount.first['count'],
      'unspent_utxos': utxoCount.first['count'],
    };
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