import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../models/recipe.dart';

class SearchResults {
  const SearchResults(this.recipes, this.failedSources);
  final List<Recipe> recipes;
  final List<String> failedSources;
}

/// An ingredient overlap score, not a nutrition or allergen guarantee.
/// These recipes may require additional ingredients beyond those entered.
class PantryRecipeMatch {
  const PantryRecipeMatch({
    required this.recipe,
    required this.matched,
    required this.total,
    required this.matchedNames,
  });
  final Recipe recipe;
  final int matched;
  final int total;
  final List<String> matchedNames;
}

class PantrySearchResults {
  const PantrySearchResults({
    required this.matches,
    required this.ingredients,
    required this.failedSources,
    required this.note,
  });
  final List<PantryRecipeMatch> matches;
  final List<String> ingredients;
  final List<String> failedSources;
  final String note;
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

  /// Parse a short comma-separated pantry list. The public TheMealDB V1
  /// ingredient filter accepts only one ingredient per call, so at most three
  /// are queried independently and ranked using detailed recipe ingredients.
  static List<String> pantryIngredients(String input) {
    final seen = <String>{};
    final ingredients = <String>[];
    for (final part in input.split(RegExp(r'[,;\n]'))) {
      final word = part.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (word.isEmpty) continue;
      if (word.length > 45 || !RegExp(r'^[a-zA-Z0-9 ()-]+
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

  Recipe _decodeMeal(Map<String, dynamic> m) {
    final ingredients = <String>[];
    for (var i = 1; i <= 20; i++) {
      final name = (m['strIngredient$i'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        final measure = (m['strMeasure$i'] ?? '').toString().trim();
        ingredients.add([measure, name].where((s) => s.isNotEmpty).join(' '));
      }
    }
    final directions = (m['strInstructions'] ?? '').toString().trim();
    final source = (m['strSource'] ?? '').toString().trim();
    return Recipe(
      id: 'mealdb:' + (m['idMeal'] ?? '').toString(),
      title: (m['strMeal'] ?? 'Untitled').toString(),
      source: 'TheMealDB',
      imageUrl: (m['strMealThumb'] ?? '').toString(),
      sourceUrl: source,
      category: (m['strCategory'] ?? '').toString(),
      cuisine: (m['strArea'] ?? '').toString(),
      ingredients: ingredients,
      steps: directions.isEmpty ? [] : directions.split(RegExp(r'\r?\n+'))
          .map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
    );
  }

  Future<List<Recipe>> _mealDb(String query) async {
    final data = await _json(Uri.https(
      'www.themealdb.com', '/api/json/v1/$_mealKey/search.php',
      {'s': query},
    )) as Map<String, dynamic>;
    final meals = data['meals'] as List? ?? const [];
    return meals.whereType<Map>()
        .map((row) => _decodeMeal(Map<String, dynamic>.from(row)))
        .toList();
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
        category: m['mealType'] is List ? (m['mealType'] as List).join(', ') : '',
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
).hasMatch(word)) {
        throw const FormatException(
          'Use simple ingredient names separated by commas (for example chicken, rice, garlic).',
        );
      }
      final key = word.toLowerCase();
      if (seen.add(key)) ingredients.add(word);
      if (ingredients.length > 3) {
        throw const FormatException(
          'Enter up to three ingredients. Multiple ingredients are ranked as suggestions.',
        );
      }
    }
    return ingredients;
  }

  static String _normalizedIngredient(String input) =>
      input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  /// Whole-word ingredient overlap avoids matching "rice" within "licorice".
  /// This is approximate: synonyms and recipe wording may differ.
  static PantryRecipeMatch scorePantry(Recipe recipe, List<String> pantry) {
    final matched = <String>[];
    for (final ingredient in pantry) {
      final needle = _normalizedIngredient(ingredient);
      if (needle.isEmpty) continue;
      final target = ' ' + needle + ' ';
      final hasIngredient = recipe.ingredients.any((line) {
        final value = ' ' + _normalizedIngredient(line) + ' ';
        return value.contains(target);
      });
      if (hasIngredient) matched.add(ingredient);
    }
    return PantryRecipeMatch(
      recipe: recipe, matched: matched.length,
      total: pantry.length, matchedNames: matched,
    );
  }

  /// Free-API pantry discovery. The primary TheMealDB V1 filter is single-
  /// ingredient only; this unions candidate IDs across 1–3 filters then looks
  /// up detailed meals for a short, capped shortlist. We do not claim that
  /// every ingredient is present or that these are all possible meals.
  Future<PantrySearchResults> searchPantry(String input) async {
    final terms = pantryIngredients(input);
    if (terms.isEmpty) {
      return const PantrySearchResults(
        matches: [], ingredients: [], failedSources: [],
        note: 'Enter at least one ingredient.',
      );
    }
    final ids = <String, int>{};
    final failed = <String>[];
    for (final ingredient in terms) {
      try {
        final apiTerm = ingredient.toLowerCase().replaceAll(' ', '_');
        final data = await _json(Uri.https(
          'www.themealdb.com', '/api/json/v1/$_mealKey/filter.php',
          {'i': apiTerm},
        )) as Map<String, dynamic>;
        final meals = data['meals'] as List? ?? const [];
        for (final row in meals.take(45)) {
          if (row is! Map) continue;
          final id = (row['idMeal'] ?? '').toString().trim();
          if (!RegExp(r'^\d+
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
        category: m['mealType'] is List ? (m['mealType'] as List).join(', ') : '',
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
).hasMatch(id)) continue;
          ids[id] = (ids[id] ?? 0) + 1;
        }
      } catch (_) {
        failed.add(ingredient);
      }
    }
    final rankedIds = ids.keys.toList()..sort((a, b) {
      final result = (ids[b] ?? 0).compareTo(ids[a] ?? 0);
      return result != 0 ? result : a.compareTo(b);
    });
    final detailed = <Recipe>[];
    final maxLookup = rankedIds.length < 12 ? rankedIds.length : 12;
    // Small batches avoid a burst of simultaneous requests against a public API.
    for (var start = 0; start < maxLookup; start += 3) {
      final group = rankedIds.skip(start).take(3);
      final lookedUp = await Future.wait(group.map((id) async {
        try {
          final data = await _json(Uri.https(
            'www.themealdb.com', '/api/json/v1/$_mealKey/lookup.php',
            {'i': id},
          )) as Map<String, dynamic>;
          final meals = data['meals'] as List? ?? const [];
          if (meals.isEmpty || meals.first is! Map) return null;
          return _decodeMeal(Map<String, dynamic>.from(meals.first as Map));
        } catch (_) {
          return null;
        }
      }));
      detailed.addAll(lookedUp.whereType<Recipe>());
    }

    final matches = detailed.map((recipe) => scorePantry(recipe, terms))
        .where((candidate) => candidate.matched > 0).toList();
    matches.sort((a, b) {
      final coverage = b.matched.compareTo(a.matched);
      return coverage == 0
          ? a.recipe.title.toLowerCase().compareTo(b.recipe.title.toLowerCase())
          : coverage;
    });
    return PantrySearchResults(
      matches: matches, ingredients: terms, failedSources: failed,
      note: 'Suggestions from a limited TheMealDB sample. Recipes may need other '
          'ingredients. Search uses individual ingredient filters; scores are approximate.',
    );
  }

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
        category: m['mealType'] is List ? (m['mealType'] as List).join(', ') : '',
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
