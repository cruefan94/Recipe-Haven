import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';

/// Shopping quantities stay exactly as written by the original recipe.
/// We do not combine different measures or pretend to know their equivalents.
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.text,
    required this.sourceRecipe,
    this.sourceId = '',
    this.collection = RecipeCollection.general,
    this.checked = false,
  });

  final String id;
  final String text;
  final String sourceRecipe;
  final String sourceId;
  final String collection;
  final bool checked;

  ShoppingItem copyWith({bool? checked}) => ShoppingItem(
    id: id, text: text, sourceRecipe: sourceRecipe, sourceId: sourceId,
    collection: collection, checked: checked ?? this.checked,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'text': text, 'sourceRecipe': sourceRecipe,
    'sourceId': sourceId, 'collection': collection, 'checked': checked,
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
    id: (json['id'] ?? '').toString(),
    text: (json['text'] ?? '').toString(),
    sourceRecipe: (json['sourceRecipe'] ?? '').toString(),
    sourceId: (json['sourceId'] ?? '').toString(),
    collection: json['collection'] == RecipeCollection.marijuana
        ? RecipeCollection.marijuana : RecipeCollection.general,
    checked: json['checked'] == true,
  );
}

/// Shared across app screens, local to each installed edition.
/// Every write is serialized and a failure restores the previous list.
class ShoppingListStore extends ChangeNotifier {
  ShoppingListStore(this._prefs);

  static const _key = 'recipe_haven_shopping_v1';
  static const maxItems = 1000;
  final SharedPreferencesAsync _prefs;
  final List<ShoppingItem> _items = [];
  Future<void> _pendingWrite = Future<void>.value();
  bool _readFailure = false;
  int _manualSerial = 0;

  bool get readFailure => _readFailure;
  List<ShoppingItem> get items => List.unmodifiable(_items);
  int get toBuyCount => _items.where((item) => item.collection == RecipeCollection.general && !item.checked).length;
  int get checkedCount => _items.where((item) => item.collection == RecipeCollection.general && item.checked).length;
  int checkedCountFor(String collection) => _items.where((item) => item.collection == collection && item.checked).length;

  static Future<ShoppingListStore> load() async {
    final result = ShoppingListStore(SharedPreferencesAsync());
    try {
      final data = await result._prefs.getString(_key);
      if (data != null) {
        final value = jsonDecode(data);
        if (value is! List) throw const FormatException('Invalid shopping list');
        if (value.length > maxItems) throw const FormatException('Shopping list too long');
        for (final item in value) {
          if (item is! Map) throw const FormatException('Invalid shopping item');
          final parsed = ShoppingItem.fromJson(Map<String, dynamic>.from(item));
          if (parsed.id.isEmpty || parsed.text.trim().isEmpty) {
            throw const FormatException('Missing shopping item name or ID');
          }
          result._items.add(parsed);
        }
      }
    } catch (error) {
      debugPrint('Shopping list is unreadable: $error');
      result._items.clear();
      // Do not overwrite an unreadable original.
      result._readFailure = true;
    }
    return result;
  }

  Future<T> _mutate<T>(Future<T> Function() body) {
    final operation = _pendingWrite.then((_) => body());
    _pendingWrite = operation.then<void>(
      (_) {}, onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  Future<T> _transaction<T>(T Function() change) async {
    if (_readFailure) {
      throw StateError('Shopping list could not be read. Existing data is protected.');
    }
    final previous = List<ShoppingItem>.from(_items);
    try {
      final outcome = change();
      await _prefs.setString(_key, jsonEncode(
        _items.map((item) => item.toJson()).toList(),
      ));
      notifyListeners();
      return outcome;
    } catch (_) {
      _items..clear()..addAll(previous);
      notifyListeners();
      rethrow;
    }
  }

  /// Stable recipe ID + ingredient line index prevents accidental duplicates.
  Future<int> addRecipeIngredients(Recipe recipe) => _mutate(() =>
    _transaction<int>(() {
      if (recipe.ingredients.isEmpty) return 0;
      final known = _items.map((item) => item.id).toSet();
      var count = 0;
      for (var i = 0; i < recipe.ingredients.length; i++) {
        final line = recipe.ingredients[i].trim();
        if (line.isEmpty) continue;
        final id = 'recipe:' + Uri.encodeComponent(recipe.id) + ':' + i.toString();
        if (!known.add(id)) continue;
        if (_items.length >= maxItems) {
          throw StateError('Shopping list has reached its 1000-item limit.');
        }
        _items.add(ShoppingItem(
          id: id, text: line, sourceRecipe: recipe.title,
          sourceId: recipe.id, collection: recipe.collection,
        ));
        count++;
      }
      return count;
    }),
  );

  Future<void> addManual(String text, {String collection = RecipeCollection.general}) async {
    await _mutate(() => _transaction<int>(() {
      final line = text.trim();
      if (line.isEmpty || line.length > 220) {
        throw const FormatException('Enter 1 to 220 characters for an item.');
      }
      if (_items.length >= maxItems) {
        throw StateError('Shopping list has reached its 1000-item limit.');
      }
      final id = 'manual:' +
          DateTime.now().microsecondsSinceEpoch.toString() + ':' +
          (_manualSerial++).toString();
      _items.add(ShoppingItem(
        id: id, text: line, sourceRecipe: 'Added manually',
        collection: collection,
      ));
      return 0;
    }));
  }

  Future<void> setChecked(String id, bool checked) async {
    await _mutate(() => _transaction<int>(() {
      final index = _items.indexWhere((item) => item.id == id);
      if (index >= 0) {
        _items[index] = _items[index].copyWith(checked: checked);
      }
      return 0;
    }));
  }

  Future<void> remove(String id) async {
    await _mutate(() => _transaction<int>(() {
      _items.removeWhere((item) => item.id == id);
      return 0;
    }));
  }

  Future<int> clearChecked({String collection = RecipeCollection.general}) => _mutate(() =>
    _transaction<int>(() {
      final before = _items.length;
      _items.removeWhere((item) => item.collection == collection && item.checked);
      return before - _items.length;
    }),
  );

  /// Merge imported groceries by stable ID without removing local entries.
  /// Serialized persistence rolls back the entire batch if saving fails.
  Future<int> mergeBackupItems(List<ShoppingItem> incoming) => _mutate(() =>
    _transaction<int>(() {
      if (incoming.length > maxItems) {
        throw const FormatException('Backup has too many shopping items.');
      }
      final known = _items.map((item) => item.id).toSet();
      var added = 0;
      for (final item in incoming) {
        if (item.id.trim().isEmpty || item.id.length > 500 ||
            item.text.trim().isEmpty || item.text.length > 600 ||
            item.sourceRecipe.length > 300 || item.sourceId.length > 500) {
          throw const FormatException('Backup has an invalid shopping item.');
        }
        if (!known.add(item.id)) continue;
        if (_items.length >= maxItems) {
          throw const FormatException('Shopping list is full; no items imported.');
        }
        _items.add(item);
        added++;
      }
      return added;
    }),
  );

  String copyText({bool includeChecked = false, String collection = RecipeCollection.general}) => _items
      .where((item) => item.collection == collection && (includeChecked || !item.checked))
      .map((item) => '- ' + item.text)
      .join('\n');
}
