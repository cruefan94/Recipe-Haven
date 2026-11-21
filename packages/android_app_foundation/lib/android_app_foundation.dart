export 'business_pdf.dart';
library android_app_foundation;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Product identity and visual tokens. Each app supplies its own brand.
class AppBrand {
  const AppBrand({
    required this.name,
    required this.subtitle,
    required this.primary,
    required this.background,
    required this.icon,
    this.brightness = Brightness.light,
  });
  final String name;
  final String subtitle;
  final Color primary;
  final Color background;
  final IconData icon;
  final Brightness brightness;
}

/// User-facing screens, not unfinished placeholder buttons.
class AppFeature {
  const AppFeature({required this.title, required this.icon, required this.builder});
  final String title;
  final IconData icon;
  final WidgetBuilder builder;
}

/// Recipe Haven's Material 3 styling and full-screen feature navigation,
/// generalized for distinct business apps without reusing kitchen content.
class FieldApp extends StatelessWidget {
  const FieldApp({super.key, required this.brand, required this.features});
  final AppBrand brand;
  final List<AppFeature> features;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(seedColor: brand.primary, brightness: brand.brightness)
        .copyWith(surface: brand.background);
    return MaterialApp(
      title: brand.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: brand.background,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: _FieldDashboard(brand: brand, features: features),
    );
  }
}

class _FieldDashboard extends StatelessWidget {
  const _FieldDashboard({required this.brand, required this.features});
  final AppBrand brand;
  final List<AppFeature> features;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(brand.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Row(children: [
              Icon(brand.icon, size: 38, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(brand.subtitle,
                style: Theme.of(context).textTheme.titleMedium)),
            ]),
            const SizedBox(height: 22),
            for (final feature in features)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: Icon(feature.icon),
                    title: Text(feature.title),
                    trailing: const Icon(Icons.chevron_right),
                    minVerticalPadding: 14,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: feature.builder),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A portable business record, not a Recipe or a kitchen-specific model.
class WorkRecord {
  const WorkRecord({
    required this.id,
    required this.kind,
    required this.data,
    required this.updatedAt,
  });
  final String id;
  final String kind;
  final Map<String, dynamic> data;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'data': data,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory WorkRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'], kind = json['kind'], data = json['data'];
    final updated = json['updatedAt'];
    if (id is! String || id.isEmpty || id.length > 120 ||
        kind is! String || kind.isEmpty || kind.length > 80 ||
        data is! Map || updated is! String ||
        DateTime.tryParse(updated) == null) {
      throw const FormatException('Invalid business record');
    }
    return WorkRecord(
      id: id,
      kind: kind,
      data: Map<String, dynamic>.from(data),
      updatedAt: DateTime.parse(updated).toUtc(),
    );
  }
}

/// Offline-first SQLite is more appropriate than the Recipe Haven
/// SharedPreferences cookbook store for growing customer/job datasets.
/// SQLite is NOT encrypted by default: production privacy review is required.
class OfflineRecordStore {
  OfflineRecordStore({required this.databaseName});
  final String databaseName;
  Database? _database;

  Future<Database> _open() async {
    if (_database != null) return _database!;
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(databaseName)) {
      throw ArgumentError('Invalid database name');
    }
    final db = await openDatabase(
      p.join(await getDatabasesPath(), '$databaseName.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE work_records (id TEXT PRIMARY KEY, kind TEXT NOT NULL, data TEXT NOT NULL, updated_at TEXT NOT NULL)',
        );
        await db.execute('CREATE INDEX work_kind ON work_records(kind)');
      },
    );
    _database = db;
    return db;
  }

  Future<void> save(WorkRecord record) async {
    final checked = WorkRecord.fromJson(record.toJson());
    final db = await _open();
    await db.insert('work_records', {
      'id': checked.id,
      'kind': checked.kind,
      'data': jsonEncode(checked.data),
      'updated_at': checked.updatedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<WorkRecord>> list(String kind) async {
    final db = await _open();
    final rows = await db.query('work_records', where: 'kind = ?', whereArgs: [kind],
      orderBy: 'updated_at DESC');
    return rows.map((row) => WorkRecord.fromJson({
      'id': row['id'],
      'kind': row['kind'],
      'data': jsonDecode(row['data'] as String),
      'updatedAt': row['updated_at'],
    })).toList();
  }

  Future<void> remove(String id) async {
    final db = await _open();
    await db.delete('work_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}

/// Versioned, bounded JSON codec inspired by Recipe Haven backup validation.
/// Backups are plaintext and must not be treated as private/secure exports.
class RecordBackupCodec {
  static const format = 'android-business-records';
  static const version = 1;
  static const maxBytes = 8 * 1024 * 1024;

  static String encode(List<WorkRecord> records) {
    if (records.length > 5000) throw const FormatException('Too many records');
    final text = jsonEncode({
      'format': format,
      'version': version,
      'records': records.map((record) => record.toJson()).toList(),
    });
    if (utf8.encode(text).length > maxBytes) {
      throw const FormatException('Backup too large');
    }
    return text;
  }

  static List<WorkRecord> decode(String text) {
    if (utf8.encode(text).length > maxBytes) {
      throw const FormatException('Backup too large');
    }
    final Object? value = jsonDecode(text);
    if (value is! Map || value['format'] != format ||
        value['version'] != version || value['records'] is! List) {
      throw const FormatException('Unsupported business backup');
    }
    final records = value['records'] as List;
    if (records.length > 5000) throw const FormatException('Too many records');
    final ids = <String>{};
    return records.map((row) {
      if (row is! Map) throw const FormatException('Invalid record in backup');
      final record = WorkRecord.fromJson(Map<String, dynamic>.from(row));
      if (!ids.add(record.id)) throw const FormatException('Duplicate record ID');
      return record;
    }).toList(growable: false);
  }
}
