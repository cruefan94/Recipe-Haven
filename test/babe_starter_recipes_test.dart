import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recipe_haven/data/babe_starter_recipes.dart';
import 'package:recipe_haven/services/recipe_search_service.dart';

void main() {
  test('18 offline recipes all have ingredient lists and instructions', () {
    expect(babeStarterRecipes, hasLength(18));
    expect(babeStarterRecipes.map((recipe) => recipe.id).toSet().length, 18);
    for (final recipe in babeStarterRecipes) {
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.steps, isNotEmpty);
      expect(recipe.source, 'Recipe Haven Originals');
    }
  });

  test('Chicken Parmesan is available for a reversed dish search offline', () {
    final found = RecipeSearchService.offlineSuggestions('parmesan chicken');
    expect(found.map((recipe) => recipe.title), contains('Chicken Parmesan'));
    expect(found.map((recipe) => recipe.title), isNot(contains('Banana Bread')));
  });

  test('offline recipes remain returned when all online sources fail', () async {
    final client = MockClient((request) async =>
        http.Response('Service unavailable', 503));
    final service = RecipeSearchService(client: client);
    final result = await service.search('Chicken Parmesan');
    expect(result.recipes.map((recipe) => recipe.title),
        contains('Chicken Parmesan'));
    expect(result.failedSources, isNotEmpty);
    service.dispose();
  });
}
