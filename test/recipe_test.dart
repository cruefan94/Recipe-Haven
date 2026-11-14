import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_haven/models/recipe.dart';

void main() {
  test('recipe round trip preserves ingredients, steps, source identity', () {
    const original = Recipe(
      id: 'web:https://example.org/soup', title: 'Tomato soup', source: 'Example',
      sourceUrl: 'https://example.org/soup', category: 'Soup', cuisine: 'Italian',
      ingredients: ['2 tomatoes', '1 cup water'], steps: ['Boil.', 'Blend.'],
    );
    final restored = Recipe.fromJson(original.toJson());
    expect(restored.title, original.title);
    expect(restored.id, original.id);
    expect(restored.ingredients, original.ingredients);
    expect(restored.steps, original.steps);
    expect(restored.hasInstructions, isTrue);
  });
  test('marijuana cookbook collection survives JSON save and restore', () {
    const recipe = Recipe(id: 'adult:1', title: 'Private recipe', source: 'Personal',
      collection: RecipeCollection.marijuana);
    final restored = Recipe.fromJson(recipe.toJson());
    expect(restored.collection, RecipeCollection.marijuana);
  });
  test('older recipes and unrecognized collections use everyday cookbook', () {
    const old = {'id': 'legacy:1', 'title': 'Bread', 'source': 'Family'};
    expect(Recipe.fromJson(old).collection, RecipeCollection.general);
    expect(Recipe.fromJson({...old, 'collection': 'unknown'}).collection, RecipeCollection.general);
  });
  test('recipe can be assigned to a different cookbook', () {
    const recipe = Recipe(id: 'x', title: 'Snack', source: 'Family');
    expect(recipe.copyWith(collection: RecipeCollection.marijuana).collection,
      RecipeCollection.marijuana);
  });
  test('link-only recipes retain original URL', () {
    const recipe = Recipe(id: 'web:test', title: 'A', source: 'B',
        sourceUrl: 'https://example.org', linkOnly: true);
    expect(Recipe.fromJson(recipe.toJson()).linkOnly, isTrue);
  });
}
