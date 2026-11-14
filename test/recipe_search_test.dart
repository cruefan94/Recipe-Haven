import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recipe_haven/services/recipe_search_service.dart';

void main() {
  test('same-named recipes from different sources appear separately', () async {
    final api = RecipeSearchService(client: MockClient((request) async {
      if (request.url.host == 'www.themealdb.com') {
        return http.Response(jsonEncode({'meals': [
          {'idMeal': '7', 'strMeal': 'Chicken Soup', 'strInstructions': 'Simmer for 20 minutes.',
           'strIngredient1': 'Chicken', 'strMeasure1': '1 cup'},
        ]}), 200);
      }
      if (request.url.host == 'dummyjson.com') {
        return http.Response(jsonEncode({'recipes': [
          {'id': 12, 'name': 'Chicken Soup', 'ingredients': ['1 cup chicken'],
           'instructions': ['Bring to a boil.']},
        ]}), 200);
      }
      return http.Response('[]', 200);
    }));
    final result = await api.search('Chicken Soup');
    expect(result.recipes, hasLength(2));
    expect(result.recipes.map((r) => r.id).toSet(), hasLength(2));
    expect(result.failedSources, isEmpty);
    api.dispose();
  });
}
