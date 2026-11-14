import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../models/recipe.dart';

class SearchResults {
  const SearchResults(this.recipes, this.failedSources);
  final List<Recipe> recipes;
  final List<String> failedSources;
}

class RecipeSearchService {
  RecipeSearchService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const _mealKey = String.fromEnvironment('MEALDB_KEY', defaultValue: '1');
  static const _sites = <String, String>{
    'Budget Bytes': 'https://www.budgetbytes.com',
    'Love and Lemons': 'https://www.loveandlemons.com',
    'RecipeTin Eats': 'https://www.recipetineats.com',
  };

  Future<SearchResults> search(String input) async {
    final query = input.trim();
    if (query.isEmpty) return const SearchResults([], []);
    final futures = <Future<List<Recipe>>>[
      _mealDb(query),
      _dummyJson(query),
      ..._sites.entries.map((site) => _wordpress(site.key, site.value, query)),
    ];
    final sourceNames = ['TheMealDB', 'DummyJSON (sample recipes)', ..._sites.keys];
    final results = await Future.wait(futures.map((f) async {
      try { return (await f, false); } catch (_) { return (<Recipe>[], true); }
    }));
    final failed = <String>[];
    final found = <Recipe>[];
    for (var i = 0; i < results.length; i++) {
      found.addAll(results[i].$1);
      if (results[i].$2) failed.add(sourceNames[i]);
    }
    final unique = <String, Recipe>{};
    for (final r in found) {
      unique.putIfAbsent(r.id, () => r);
    }
    final sorted = unique.values.toList()..sort((a, b) {
      final aStarts = a.title.toLowerCase().startsWith(query.toLowerCase());
      final bStarts = b.title.toLowerCase().startsWith(query.toLowerCase());
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return SearchResults(sorted, failed);
  }

  Future<dynamic> _json(Uri uri) async {
    final response = await _client.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<List<Recipe>> _mealDb(String query) async {
    final json = await _json(Uri.https('www.themealdb.com', '/api/json/v1/$_mealKey/search.php', {'s': query})) as Map<String, dynamic>;
    final meals = json['meals'] as List? ?? const [];
    return meals.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final ingredients = <String>[];
      for (var i = 1; i <= 20; i++) {
        final name = '${m['strIngredient$i'] ?? ''}'.trim();
        if (name.isNotEmpty) {
          final measure = '${m['strMeasure$i'] ?? ''}'.trim();
          ingredients.add([measure, name].where((s) => s.isNotEmpty).join(' '));
        }
      }
      final directions = '${m['strInstructions'] ?? ''}'.trim();
      return Recipe(
        id: 'mealdb:${m['idMeal']}', title: '${m['strMeal'] ?? 'Untitled'}',
        source: 'TheMealDB', imageUrl: '${m['strMealThumb'] ?? ''}',
        sourceUrl: '${m['strSource'] ?? ''}',
        category: '${m['strCategory'] ?? ''}', cuisine: '${m['strArea'] ?? ''}',
        ingredients: ingredients,
        steps: directions.isEmpty ? [] : directions.split(RegExp(r'\r?\n+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      );
    }).toList();
  }

  /// DummyJSON is a public sample dataset, not a comprehensive recipe service.
  /// It is useful for extra recipe variations while the source adapters grow.
  Future<List<Recipe>> _dummyJson(String query) async {
    final json = await _json(Uri.https('dummyjson.com', '/recipes/search', {'q': query, 'limit': '100'})) as Map<String, dynamic>;
    final rows = json['recipes'] as List? ?? const [];
    return rows.map((row) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = '${m['id'] ?? ''}';
      return Recipe(
        id: 'dummyjson:$id', title: '${m['name'] ?? 'Untitled'}',
        source: 'Sample recipe collection', imageUrl: '${m['image'] ?? ''}',
        category: '${m['mealType'] is List ? (m['mealType'] as List).join(', ') : ''}',
        cuisine: '${m['cuisine'] ?? ''}',
        timeMinutes: ((m['prepTimeMinutes'] as num?)?.toInt() ?? 0) + ((m['cookTimeMinutes'] as num?)?.toInt() ?? 0),
        ingredients: ((m['ingredients'] as List?) ?? []).map((e) => '$e').toList(),
        steps: ((m['instructions'] as List?) ?? []).map((e) => '$e').toList(),
      );
    }).toList();
  }

  Future<List<Recipe>> _wordpress(String source, String host, String query) async {
    final base = Uri.parse(host);
    final data = await _json(base.replace(path: '/wp-json/wp/v2/search', queryParameters: {
      'search': query, 'per_page': '12', 'type': 'post',
    }));
    if (data is! List) return [];
    return data.whereType<Map>().map((row) {
      final m = Map<String, dynamic>.from(row);
      final url = '${m['url'] ?? ''}';
      final title = html_parser.parseFragment('${m['title'] ?? ''}').text?.trim() ?? '';
      return Recipe(
        id: 'web:$url', title: title, source: source,
        sourceUrl: url, linkOnly: true,
      );
    }).where((r) => r.title.isNotEmpty && Uri.tryParse(r.sourceUrl)?.hasScheme == true).toList();
  }

  void dispose() => _client.close();
}
