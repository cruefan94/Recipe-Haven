import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import '../models/recipe.dart';
import 'cookbook_store.dart';
import 'shopping_list_store.dart';

/// Versioned portable JSON backup for recipes AND the shopping list.
class KitchenBackupData {
  const KitchenBackupData({
    required this.recipes,
    required this.shoppingItems,
    required this.isLegacyCookbook,
  });
  final List<Recipe> recipes;
  final List<ShoppingItem> shoppingItems;
  final bool isLegacyCookbook;
}

class KitchenImportResult {
  const KitchenImportResult({
    required this.recipesAdded,
    required this.shoppingItemsAdded,
    required this.legacyCookbook,
  });
  final int recipesAdded;
  final int shoppingItemsAdded;
  final bool legacyCookbook;
}

/// Some recipes can be committed even if shopping-list persistence fails.
/// Reimporting the same backup is safe: existing IDs are retained unchanged.
class PartialKitchenImportException implements Exception {
  const PartialKitchenImportException(this.recipesAdded);
  final int recipesAdded;
}

class KitchenBackupCodec {
  static const int maxBytes = 8 * 1024 * 1024;
  static const String format = 'recipe-haven-kitchen';
  static const int version = 1;

  static String encode({
    required List<Recipe> recipes,
    required List<ShoppingItem> shoppingItems,
  }) {
    if (recipes.length > 5000 ||
        shoppingItems.length > ShoppingListStore.maxItems) {
      throw const FormatException('Too many entries in the backup.');
    }
    final text = const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'recipes': recipes.map((recipe) => recipe.toJson()).toList(),
      'shoppingItems': shoppingItems.map((item) => item.toJson()).toList(),
    });
    if (utf8.encode(text).length > maxBytes) {
      throw const FormatException('Backup exceeds 8 MB.');
    }
    return text;
  }

  /// Accept both the new full backup and older cookbook-only JSON backups.
  /// Validate everything before modifying either saved collection.
  static KitchenBackupData decode(String text) {
    if (utf8.encode(text).length > maxBytes) {
      throw const FormatException('Backup exceeds 8 MB.');
    }
    dynamic parsed;
    try {
      parsed = jsonDecode(text);
    } catch (_) {
      throw const FormatException('Not valid Recipe Haven backup JSON.');
    }
    if (parsed is! Map) {
      throw const FormatException('Invalid Recipe Haven backup.');
    }
    final isFull = parsed['format'] == format &&
        parsed['version'] == version;
    final isLegacy = parsed['format'] == 'recipe-haven-cookbook' &&
        parsed['version'] == 1;
    if (!isFull && !isLegacy) {
      throw const FormatException('Unsupported Recipe Haven backup version.');
    }
    final rawRecipes = parsed['recipes'];
    final rawItems = isFull ? parsed['shoppingItems'] : <dynamic>[];
    if (rawRecipes is! List || rawItems is! List ||
        rawRecipes.length > 5000 ||
        rawItems.length > ShoppingListStore.maxItems) {
      throw const FormatException('Invalid or oversized backup entries.');
    }
    final recipes = <Recipe>[];
    final shopping = <ShoppingItem>[];
    try {
      for (final value in rawRecipes) {
        if (value is! Map) {
          throw const FormatException('Invalid recipe in backup.');
        }
        final recipe = Recipe.fromJson(Map<String, dynamic>.from(value));
        if (recipe.id.trim().isEmpty || recipe.id.length > 500 ||
            recipe.title.trim().isEmpty || recipe.title.length > 500 ||
            recipe.ingredients.length > 400 || recipe.steps.length > 400) {
          throw const FormatException('Recipe has invalid backup fields.');
        }
        recipes.add(recipe);
      }
      for (final value in rawItems) {
        if (value is! Map || value['id'] is! String ||
            value['text'] is! String || value['checked'] is! bool) {
          throw const FormatException('Invalid shopping item in backup.');
        }
        final item = ShoppingItem.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (item.id.trim().isEmpty || item.id.length > 500 ||
            item.text.trim().isEmpty || item.text.length > 600 ||
            item.sourceId.length > 500 || item.sourceRecipe.length > 300) {
          throw const FormatException('Shopping item has invalid fields.');
        }
        shopping.add(item);
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Malformed recipe or shopping backup data.');
    }
    return KitchenBackupData(
      recipes: recipes,
      shoppingItems: shopping,
      isLegacyCookbook: isLegacy,
    );
  }
}

class KitchenBackupService {
  static String exportData(CookbookStore cookbook, ShoppingListStore shopping) {
    if (cookbook.readFailure || shopping.readFailure) {
      throw StateError('Saved data could not be read; full backup is blocked.');
    }
    return KitchenBackupCodec.encode(
      recipes: cookbook.saved, shoppingItems: shopping.items,
    );
  }

  static Future<KitchenImportResult> importData(
    String text, CookbookStore cookbook, ShoppingListStore shopping) async {
    final parsed = KitchenBackupCodec.decode(text);
    if (cookbook.readFailure ||
        (!parsed.isLegacyCookbook && shopping.readFailure)) {
      throw StateError('Saved data could not be read; import is blocked.');
    }
    // Keep the cookbook's existing duplicate-safe persistence behavior.
    final cookbookJson = jsonEncode({
      'format': 'recipe-haven-cookbook',
      'version': 1,
      'recipes': parsed.recipes.map((recipe) => recipe.toJson()).toList(),
    });
    final recipesAdded = await cookbook.mergeBackup(cookbookJson);
    if (parsed.isLegacyCookbook) {
      return KitchenImportResult(
        recipesAdded: recipesAdded,
        shoppingItemsAdded: 0,
        legacyCookbook: true,
      );
    }
    try {
      final shoppingAdded =
          await shopping.mergeBackupItems(parsed.shoppingItems);
      return KitchenImportResult(
        recipesAdded: recipesAdded,
        shoppingItemsAdded: shoppingAdded,
        legacyCookbook: false,
      );
    } catch (_) {
      throw PartialKitchenImportException(recipesAdded);
    }
  }

  static Future<bool> saveFile(
    CookbookStore cookbook, ShoppingListStore shopping) async {
    final bytes = Uint8List.fromList(
      utf8.encode(exportData(cookbook, shopping)),
    );
    final now = DateTime.now();
    final date = [
      now.year.toString().padLeft(4, '0'),
      now.month.toString().padLeft(2, '0'),
      now.day.toString().padLeft(2, '0'),
    ].join('-');
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save Recipe Haven kitchen backup',
      fileName: 'Recipe-Haven-Kitchen-Backup-' + date + '.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      mimeType: 'application/json',
      bytes: bytes,
    );
    return path != null;
  }

  /// Null if picker canceled; otherwise the number of entries merged.
  static Future<KitchenImportResult?> restoreFile(
    CookbookStore cookbook, ShoppingListStore shopping) async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Select Recipe Haven kitchen backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    final length = file.lengthSync() ?? await file.length();
    if (length != null && length > KitchenBackupCodec.maxBytes) {
      throw const FormatException('Backup file exceeds 8 MB.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > KitchenBackupCodec.maxBytes) {
      throw const FormatException('Backup file exceeds 8 MB.');
    }
    return importData(
      utf8.decode(bytes, allowMalformed: false),
      cookbook, shopping,
    );
  }
}
