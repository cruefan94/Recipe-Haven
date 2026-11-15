import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recipe_haven/models/recipe.dart';
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
  test('Parmesan chicken search removes unrelated meals, regardless of word order', () async {
    final api = RecipeSearchService(client: MockClient((request) async {
      if (request.url.host == 'www.themealdb.com') {
        final term = request.url.queryParameters['s']?.toLowerCase() ?? '';
        if (term == 'chicken parmigiana') {
          return http.Response(jsonEncode({'meals': [
            {
              'idMeal': '101',
              'strMeal': 'Chicken Parmigiana',
              'strIngredient1': 'chicken breast',
              'strIngredient2': 'Parmesan',
              'strInstructions': 'Cook chicken.',
            },
          ]}), 200);
        }
        return http.Response(jsonEncode({'meals': [
          {'idMeal': '102', 'strMeal': 'Unrelated Lentil Soup'},
        ]}), 200);
      }
      if (request.url.host == 'dummyjson.com') {
        return http.Response(jsonEncode({'recipes': [
          {'id': 20, 'name': 'Parmesan Roasted Broccoli'},
          {'id': 21, 'name': 'Chicken Rice Bowl'},
        ]}), 200);
      }
      return http.Response('[]', 200);
    }));
    final result = await api.search('parmesan checking');
    expect(result.recipes, hasLength(2));
    expect(result.recipes.map((recipe) => recipe.title),
        containsAll(['Chicken Parmigiana', 'Chicken Parmesan']));
    expect(result.recipes.map((recipe) => recipe.title),
        isNot(contains('Unrelated Lentil Soup')));
    expect(result.failedSources, isEmpty);
    api.dispose();
  });

  test('relevance requires the entire dish, not one overlapping word', () {
    const good = Recipe(
      id: 'good', title: 'Chicken Parmesan with Pasta', source: 'Test');
    const swapped = Recipe(
      id: 'swapped', title: 'Parmesan Crusted Chicken', source: 'Test');
    const unrelated = Recipe(
      id: 'bad', title: 'Chicken Noodle Soup', source: 'Test');
    expect(RecipeSearchService.recipeRelevance(good, 'Parmesan chicken'),
        greaterThan(0));
    expect(RecipeSearchService.recipeRelevance(swapped, 'Parmesan chicken'),
        greaterThan(0));
    expect(RecipeSearchService.recipeRelevance(unrelated, 'Parmesan chicken'), 0);
  });

}
