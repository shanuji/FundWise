import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

class MarketDataCache {
  static final MarketDataCache instance = MarketDataCache._();
  MarketDataCache._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = '${await getDatabasesPath()}/fundwise_market.db';
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE nifty_history (
            date TEXT PRIMARY KEY,
            close REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE scheme_cache (
            isin TEXT PRIMARY KEY,
            scheme_code TEXT,
            scheme_name TEXT,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE nav_history (
            isin TEXT NOT NULL,
            date TEXT NOT NULL,
            nav REAL NOT NULL,
            PRIMARY KEY (isin, date)
          )
        ''');
      },
    );
    return _db!;
  }

  Future<double?> niftyClose(DateTime date) async {
    final db = await database;
    final rows = await db.query(
      'nifty_history',
      where: 'date = ?',
      whereArgs: [_dayKey(date)],
      limit: 1,
    );
    return rows.isEmpty ? null : (rows.first['close'] as num).toDouble();
  }

  Future<Map<String, double>> niftyRange(DateTime start, DateTime end) async {
    await ensureNiftyRange(start, end);
    final db = await database;
    final rows = await db.query(
      'nifty_history',
      where: 'date >= ? AND date <= ?',
      whereArgs: [_dayKey(start), _dayKey(end)],
      orderBy: 'date ASC',
    );
    return {
      for (final row in rows)
        row['date'].toString(): (row['close'] as num).toDouble(),
    };
  }

  Future<void> ensureNiftyRange(DateTime start, DateTime end) async {
    if (end.isBefore(start)) return;
    final db = await database;
    final minRows = await db.rawQuery('SELECT MIN(date) AS d FROM nifty_history');
    final maxRows = await db.rawQuery('SELECT MAX(date) AS d FROM nifty_history');
    final minDate = _parseKey(minRows.first['d']?.toString());
    final maxDate = _parseKey(maxRows.first['d']?.toString());

    if (minDate == null || maxDate == null) {
      await _fetchNifty(start, end);
      return;
    }

    if (start.isBefore(minDate)) {
      await _fetchNifty(start, minDate.subtract(const Duration(days: 1)));
    }
    if (end.isAfter(maxDate)) {
      await _fetchNifty(maxDate.add(const Duration(days: 1)), end);
    }
  }

  Future<void> _fetchNifty(DateTime start, DateTime end) async {
    if (end.isBefore(start)) return;
    final period1 = DateTime(start.year, start.month, start.day)
            .millisecondsSinceEpoch ~/
        1000;
    final period2 = DateTime(end.year, end.month, end.day)
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch ~/
        1000;
    final uri = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/%5ENSEI'
      '?period1=$period1&period2=$period2&interval=1d&events=history',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Unable to update Nifty 50 history (HTTP ${response.statusCode}).');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final result = ((json['chart'] as Map?)?['result'] as List?)?.firstOrNull;
    if (result is! Map) throw Exception('Nifty 50 API returned no history.');
    final timestamps = (result['timestamp'] as List?) ?? const [];
    final closes = (((result['indicators'] as Map?)?['quote'] as List?)?.firstOrNull as Map?)?['close'] as List? ?? const [];
    final db = await database;
    final batch = db.batch();
    for (var i = 0; i < timestamps.length && i < closes.length; i++) {
      final ts = (timestamps[i] as num).toInt();
      final close = closes[i];
      if (close == null) continue;
      final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true).toLocal();
      if (date.isBefore(start) || date.isAfter(end)) continue;
      batch.insert(
        'nifty_history',
        {'date': _dayKey(date), 'close': (close as num).toDouble()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<String?> cachedSchemeCode(String isin) async {
    final db = await database;
    final rows = await db.query(
      'scheme_cache',
      columns: ['scheme_code'],
      where: 'isin = ?',
      whereArgs: [isin],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['scheme_code']?.toString();
  }

  Future<void> cacheSchemeCode(String isin, String code, String name) async {
    final db = await database;
    await db.insert(
      'scheme_cache',
      {
        'isin': isin,
        'scheme_code': code,
        'scheme_name': name,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<double?> cachedNav(String isin, DateTime date) async {
    final db = await database;
    final rows = await db.query(
      'nav_history',
      columns: ['nav'],
      where: 'isin = ? AND date = ?',
      whereArgs: [isin, _dayKey(date)],
      limit: 1,
    );
    return rows.isEmpty ? null : (rows.first['nav'] as num).toDouble();
  }

  Future<void> cacheNav(String isin, DateTime date, double nav) async {
    final db = await database;
    await db.insert(
      'nav_history',
      {'isin': isin, 'date': _dayKey(date), 'nav': nav},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseKey(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
