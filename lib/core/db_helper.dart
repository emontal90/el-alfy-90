import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;
  DBHelper._init();

  Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDB('furniture_erp.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    void onOpen(Database db) async {
      try {
        await db.execute('ALTER TABLE upholsterer_batches ADD COLUMN pieces_json TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE upholsterer_batches ADD COLUMN received_date TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE upholsterer_batches ADD COLUMN sets_sent INTEGER DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE upholsterer_batches ADD COLUMN sets_received INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN sets_count INTEGER DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE archived_orders ADD COLUMN sets_count INTEGER DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS archived_orders (
            id INTEGER PRIMARY KEY,
            customer_id INTEGER NOT NULL,
            customer_name TEXT NOT NULL,
            category_id INTEGER NOT NULL,
            category_name TEXT NOT NULL,
            selected_components_json TEXT NOT NULL,
            specs TEXT,
            delivery_date TEXT NOT NULL,
            order_type TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            archived_at TEXT NOT NULL
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS stock_movements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category_id INTEGER NOT NULL,
            category_name TEXT NOT NULL,
            movement_type TEXT NOT NULL,
            qty_change INTEGER NOT NULL,
            stock_after INTEGER NOT NULL,
            notes TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      } catch (_) {}

      try {
        // تسوية وتصفير قطع أي صنف رصيد أطقمه صفر
        final zeroCats = await db.query('categories', where: 'stock_qty = 0 OR stock_qty IS NULL');
        for (final z in zeroCats) {
          final String raw = (z['components_json'] ?? '[]').toString();
          try {
            final List comps = jsonDecode(raw);
            bool changed = false;
            for (final c in comps) {
              if ((c['qty'] ?? 0) != 0) {
                c['qty'] = 0;
                changed = true;
              }
            }
            if (changed) {
              await db.update(
                'categories',
                {'components_json': jsonEncode(comps)},
                where: 'id = ?',
                whereArgs: [z['id']],
              );
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    if (kIsWeb) {
      return await openDatabase(filePath, version: 1, onCreate: _createDB, onOpen: onOpen);
    }
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB, onOpen: onOpen);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        components_json TEXT NOT NULL,
        stock_qty INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE upholsterer_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        upholsterer_name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        category_name TEXT NOT NULL,
        piece_name TEXT,
        total_sent INTEGER NOT NULL DEFAULT 0,
        received_qty INTEGER NOT NULL DEFAULT 0,
        sent_date TEXT NOT NULL,
        received_date TEXT,
        sets_sent INTEGER DEFAULT 1,
        sets_received INTEGER DEFAULT 0,
        pieces_json TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        customer_name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        category_name TEXT NOT NULL,
        selected_components_json TEXT NOT NULL,
        specs TEXT,
        delivery_date TEXT NOT NULL,
        order_type TEXT NOT NULL,
        sets_count INTEGER DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'waiting',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS archived_orders (
        id INTEGER PRIMARY KEY,
        customer_id INTEGER NOT NULL,
        customer_name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        category_name TEXT NOT NULL,
        selected_components_json TEXT NOT NULL,
        specs TEXT,
        delivery_date TEXT NOT NULL,
        order_type TEXT NOT NULL,
        sets_count INTEGER DEFAULT 1,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        archived_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        category_name TEXT NOT NULL,
        movement_type TEXT NOT NULL,
        qty_change INTEGER NOT NULL,
        stock_after INTEGER NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }
}
