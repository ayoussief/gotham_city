import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Database helper for cross-platform database initialization
class DatabaseHelper {
  static bool _initialized = false;

  /// Initialize database factory for desktop platforms
  static void initializeDatabaseFactory() {
    if (_initialized) return;

    // Initialize sqflite for desktop platforms
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // Initialize FFI
      sqfliteFfiInit();
      // Change the default factory
      databaseFactory = databaseFactoryFfi;
    }

    _initialized = true;
  }

  /// Check if running on desktop platform
  static bool get isDesktop {
    return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  }

  /// Check if running on mobile platform
  static bool get isMobile {
    return Platform.isAndroid || Platform.isIOS;
  }
}