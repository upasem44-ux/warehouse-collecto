import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  // رفع الإصدار إلى 2 لتفعيل الترقية على الأجهزة الحالية
  static const int databaseVersion = 2;
  static const String databaseName = 'dawacom_collector.db';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final dbDirectory = await getDatabasesPath();
    final dbPath = p.join(dbDirectory, databaseName);

    return openDatabase(
      dbPath,
      version: databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA synchronous = FULL');
      },
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        area TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        balance_yer REAL NOT NULL DEFAULT 0,
        balance_sar REAL NOT NULL DEFAULT 0,
        balance_usd REAL NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number TEXT NOT NULL UNIQUE,
        distributor_code TEXT NOT NULL,
        customer_code TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        amount REAL NOT NULL CHECK(amount > 0),
        currency TEXT NOT NULL,
        method TEXT NOT NULL,
        network TEXT,
        transfer_ref TEXT,
        note TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        shift_date TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        synced_at TEXT,
        FOREIGN KEY(customer_code) REFERENCES customers(code)
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_sequences (
        distributor_code TEXT NOT NULL,
        shift_date TEXT NOT NULL,
        last_number INTEGER NOT NULL,
        PRIMARY KEY(distributor_code, shift_date)
      )
    ''');

    await db.execute('CREATE INDEX idx_receipts_customer ON receipts(customer_code)');
    await db.execute('CREATE INDEX idx_receipts_date ON receipts(shift_date)');
    await db.execute('CREATE INDEX idx_receipts_sync ON receipts(sync_status)');
    await db.execute('CREATE INDEX idx_receipts_status ON receipts(status)');

    // الفهرس الفريد لمنع تكرار الحوالات
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_transfer_ref 
      ON receipts(network, transfer_ref) 
      WHERE method = 'حوالة' AND transfer_ref IS NOT NULL AND status != 'draft'
    ''');

    debugPrint('Dawacom SQLite database initialized (v$version).');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_transfer_ref 
        ON receipts(network, transfer_ref) 
        WHERE method = 'حوالة' AND transfer_ref IS NOT NULL AND status != 'draft'
      ''');
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
