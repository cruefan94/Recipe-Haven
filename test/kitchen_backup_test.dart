import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_haven/models/recipe.dart';
import 'package:recipe_haven/services/shopping_list_store.dart';
import 'package:recipe_haven/services/kitchen_backup_service.dart';

void main() {
  const meal = Recipe(
    id: 'family:lasagna', title: 'Family Lasagna',
    source: 'My Cookbook',
    ingredients: ['2 cups mozzarella', '1 cup tomato sauce'],
    steps: ['Bake until hot.'],
  );
  const adult = Recipe(
    id: 'personal:separate', title: 'Separate Collection',
    source: 'My Cookbook', collection: RecipeCollection.marijuana,
    ingredients: ['1 cup flour'],
  );
  const groceries = <ShoppingItem>[
    ShoppingItem(
      id: 'manual:100', text: '1 L milk',
      sourceRecipe: 'Added manually', checked: false),
    ShoppingItem(
      id: 'recipe:lasagna:1', text: '2 cups mozzarella',
      sourceRecipe: 'Family Lasagna', sourceId: 'family:lasagna',
      checked: true),
  ];

  test('full kitchen backup includes recipes and checked shopping items', () {
    final encoded = KitchenBackupCodec.encode(
      recipes: [meal, adult], shoppingItems: groceries);
    final parsed = KitchenBackupCodec.decode(encoded);
    expect(parsed.isLegacyCookbook, isFalse);
    expect(parsed.recipes.map((recipe) => recipe.id),
      containsAll(['family:lasagna', 'personal:separate']));
    expect(parsed.recipes[1].collection, RecipeCollection.marijuana);
    expect(parsed.shoppingItems.length, 2);
    expect(parsed.shoppingItems[0].text, '1 L milk');
    expect(parsed.shoppingItems[1].checked, isTrue);
  });

  test('older cookbook-only JSON still restores recipe text', () {
    final old = jsonEncode({
      'format': 'recipe-haven-cookbook', 'version': 1,
      'recipes': [meal.toJson()],
    });
    final parsed = KitchenBackupCodec.decode(old);
    expect(parsed.isLegacyCookbook, isTrue);
    expect(parsed.recipes.single.steps, ['Bake until hot.']);
    expect(parsed.shoppingItems, isEmpty);
  });

  test('malformed shopping backup is rejected before any import', () {
    final broken = jsonEncode({
      'format': KitchenBackupCodec.format,
      'version': KitchenBackupCodec.version,
      'recipes': [meal.toJson()],
      'shoppingItems': [
        {'id': 'bad', 'text': 'milk', 'checked': 'true'},
      ],
    });
    expect(() => KitchenBackupCodec.decode(broken), throwsFormatException);
  });

  test('unsupported backup format is rejected', () {
    expect(
      () => KitchenBackupCodec.decode('{"format":"unknown","version":1,"recipes":[]}'),
      throwsFormatException,
    );
  });

  test('missing shoppingItems field is rejected for new backups', () {
    final missing = jsonEncode({
      'format': KitchenBackupCodec.format, 'version': 1,
      'recipes': [meal.toJson()],
    });
    expect(() => KitchenBackupCodec.decode(missing), throwsFormatException);
  });
}
