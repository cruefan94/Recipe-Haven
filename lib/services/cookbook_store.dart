import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';

/// Locally stored cookbook. Offline text survives normal app updates, but a
/// device uninstall removes it; future versions should offer export/backup.
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
