import 'dart:async';
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

  // Close database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}