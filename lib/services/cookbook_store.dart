import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';

/// Locally stored cookbook with portable versioned JSON backup/restore.
 /// Backups include personal recipe text and links and should be kept private.
class CookbookStore extends ChangeNotifier {
  CookbookStore(this._prefs);
  final SharedPreferencesAsync _prefs;
  static const _key = 'recipe_haven_cookbook_v1';
  final List<Recipe> _saved = [];

  List<Recipe> get saved => List.unmodifiable(_saved);
  bool contains(String id) => _saved.any((recipe) => recipe.id == id);

  static Future<CookbookStore> load() async {
    final store = CookbookStore(SharedPreferencesAsync());
    try {
      final raw = await store._prefs.getString(_key);
      if (raw != null) {
        final rows = jsonDecode(raw) as List<dynamic>;
        store._saved.addAll(rows.map((e) => Recipe.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (e) {
      // Preserve any unreadable raw value rather than silently overwriting it.
      debugPrint('Cookbook could not be decoded: $e');
      store._readFailure = true;
    }
    return store;
  }

  bool _readFailure = false;
  bool get readFailure => _readFailure;

  /// A portable text backup of both collections, including saved offline text.
  String exportBackup() => const JsonEncoder.withIndent('  ').convert({
    'format': 'recipe-haven-cookbook',
    'version': 1,
    'recipes': _saved.map((recipe) => recipe.toJson()).toList(),
  });

  /// Add recipes from a backup without removing existing entries.
  /// Input is validated before the first change; persistence failures roll back.
  Future<int> mergeBackup(String text) async {
    if (_readFailure) throw StateError('Cookbook is unreadable; import disabled.');
    if (text.length > 8 * 1024 * 1024) {
      throw const FormatException('Backup is too large for clipboard restore.');
    }
    dynamic data;
    try {
      data = jsonDecode(text);
    } catch (_) {
      throw const FormatException('Clipboard does not contain valid JSON.');
    }
    if (data is! Map ||
        data['format'] != 'recipe-haven-cookbook' ||
        data['version'] != 1 ||
        data['recipes'] is! List) {
      throw const FormatException('Not a supported Recipe Haven backup.');
    }
    final rows = data['recipes'] as List;
    if (rows.length > 5000) {
      throw const FormatException('Backup contains too many recipes.');
    }
    final incoming = <Recipe>[];
    for (final row in rows) {
      if (row is! Map) throw const FormatException('Backup has an invalid recipe.');
      final recipe = Recipe.fromJson(Map<String, dynamic>.from(row));
      if (recipe.id.trim().isEmpty || recipe.title.trim().isEmpty) {
        throw const FormatException('Backup has an invalid recipe ID or title.');
      }
      incoming.add(recipe);
    }
    final ids = _saved.map((recipe) => recipe.id).toSet();
    final unique = incoming.where((recipe) => ids.add(recipe.id)).toList();
    if (unique.isEmpty) return 0;
    final previous = List<Recipe>.from(_saved);
    _saved.addAll(unique);
    try {
      await _persist();
    } catch (_) {
      _saved..clear()..addAll(previous);
      rethrow;
    }
    notifyListeners();
    return unique.length;
  }

  Future<void> save(Recipe recipe) async {
    if (_readFailure) throw StateError('Saved cookbook could not be loaded. Please back up the app data before editing.');
    final before = List<Recipe>.from(_saved);
    _saved.removeWhere((r) => r.id == recipe.id);
    _saved.insert(0, recipe);
    notifyListeners();
    try { await _persist(); } catch (_) {
      _saved..clear()..addAll(before);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> remove(String id) async {
    if (_readFailure) throw StateError('Saved cookbook could not be loaded.');
    final before = List<Recipe>.from(_saved);
    _saved.removeWhere((r) => r.id == id);
    notifyListeners();
    try { await _persist(); } catch (_) {
      _saved..clear()..addAll(before);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _persist() async => _prefs.setString(_key, jsonEncode(_saved.map((e) => e.toJson()).toList()));
}
