import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../models/recipe.dart';

class SearchResults {
  const SearchResults(this.recipes, this.failedSources);
  final List<Recipe> recipes;
  final List<String> failedSources;
}


/// Ingredient overlap only; not a full pantry or allergy verification.
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

  /// Free API accepts one ingredient per request. Query at most three,
  /// deduplicate shortlists, then rank recipes by ingredient overlap.
  static List<String> pantryIngredients(String input) {
    final found = <String>[];
    final seen = <String>{};
    for (final candidate in input.split(RegExp(r'[,;\n]'))) {
      final value = candidate.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (value.isEmpty) continue;
      if (value.length > 45 ||
          !RegExp(r'^[a-zA-Z0-9 ()-]+$').hasMatch(value)) {
        throw const FormatException(
          'Enter simple ingredient names separated by commas.',
        );
      }
      if (seen.add(value.toLowerCase())) found.add(value);
      if (found.length > 3) {
        throw const FormatException('Enter up to three ingredients.');
      }
    }
    return found;
  }

  static String _normalized(String value) => value.toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  /// Count whole-phrase matches in the full list of ingredients.
  static PantryRecipeMatch scorePantry(Recipe recipe, List<String> pantry) {
    final matched = <String>[];
    for (final name in pantry) {
      final term = _normalized(name);
      if (term.isEmpty) continue;
      final needle = ' ' + term + ' ';
      if (recipe.ingredients.any((line) =>
          (' ' + _normalized(line) + ' ').contains(needle))) {
        matched.add(name);
      }
    }
    return PantryRecipeMatch(
      recipe: recipe, matched: matched.length,
      total: pantry.length, matchedNames: matched,
    );
  }

  Future<PantrySearchResults> searchPantry(String input) async {
    final terms = pantryIngredients(input);
    if (terms.isEmpty) {
      return const PantrySearchResults(
        matches: [], ingredients: [], failedSources: [],
        note: 'Enter at least one ingredient.',
      );
    }

    final counts = <String, int>{};
    final failures = <String>[];
    for (final term in terms) {
      try {
        final response = await _json(Uri.https(
          'www.themealdb.com', '/api/json/v1/$_mealKey/filter.php',
          {'i': term.toLowerCase().replaceAll(' ', '_')},
        )) as Map<String, dynamic>;
        final meals = response['meals'] as List? ?? const [];
        for (final raw in meals.take(45)) {
          if (raw is! Map) continue;
          final id = (raw['idMeal'] ?? '').toString().trim();
          if (!RegExp(r'^\d+$').hasMatch(id)) continue;
          counts[id] = (counts[id] ?? 0) + 1;
        }
      } catch (_) {
        failures.add(term);
      }
    }
    final ids = counts.keys.toList()..sort((a, b) {
      final c = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
      return c != 0 ? c : a.compareTo(b);
    });
    final limited = ids.take(12).toList();
    final candidates = <Recipe>[];
    for (var start = 0; start < limited.length; start += 3) {
      final chunk = limited.skip(start).take(3).toList();
      final batch = await Future.wait(chunk.map((id) async {
        try {
          final result = await _json(Uri.https(
            'www.themealdb.com', '/api/json/v1/$_mealKey/lookup.php', {'i': id},
          )) as Map<String, dynamic>;
          final list = result['meals'] as List? ?? const [];
          if (list.isEmpty || list.first is! Map) return null;
          return _fromMeal(Map<String, dynamic>.from(list.first as Map));
        } catch (_) {
          return null;
        }
      }));
      candidates.addAll(batch.whereType<Recipe>());
    }
    final matches = candidates
        .map((r) => scorePantry(r, terms))
        .where((m) => m.matched > 0).toList();
    matches.sort((a, b) {
      final score = b.matched.compareTo(a.matched);
      return score != 0 ? score :
          a.recipe.title.toLowerCase().compareTo(b.recipe.title.toLowerCase());
    });
    return PantrySearchResults(
      matches: matches, ingredients: terms, failedSources: failures,
      note: 'Limited online recipe suggestions. Check every full ingredient '
          'list before cooking; other groceries may be needed.',
    );
  }

  /// Normalize common dish aliases and small user typos for comparison.
  /// Keep multi-word queries conjunctive: all important dish words must
  /// appear in a title, not just one of them.
  static String _recipeWord(String word) {
    return switch (word) {
      'parm' || 'parmigiana' || 'parmigiano' => 'parmesan',
      'checking' || 'chickens' => 'chicken',
      'alfredo' => 'alfredo',
      _ => word,
    };
  }

  static List<String> _recipeTerms(String query) {
    const ignored = {'recipe', 'recipes', 'a', 'an', 'the', 'of',
      'with', 'how', 'to', 'make', 'easy', 'best', 'for'};
    final terms = <String>[];
    for (final raw in query.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
      if (raw.isEmpty || ignored.contains(raw)) continue;
      final term = _recipeWord(raw);
      if (!terms.contains(term)) terms.add(term);
    }
    return terms;
  }

  /// Public for unit tests and use in future recipe-result components.
  /// Unknown/broad WordPress matches never get a positive score unless
  /// their visible recipe title actually contains the requested dish words.
  static int recipeRelevance(Recipe recipe, String query) {
    final terms = _recipeTerms(query);
    if (terms.isEmpty) return 0;
    final titleWords = recipe.title.toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.isNotEmpty)
        .map(_recipeWord).toSet();
    final matches = terms.where(titleWords.contains).length;
    if (matches != terms.length) return 0;
    final original = query.toLowerCase().trim();
    final title = recipe.title.toLowerCase().trim();
    if (title == original) return 100;
    if (title.startsWith(original)) return 90;
    // "Chicken Parmesan" is a better result for "Parmesan chicken"
    // than e.g. "Dinner with Parmesan Chicken, Rice and Soup".
    return 65 + (terms.length * 3) -
        (titleWords.length - terms.length).clamp(0, 20).toInt();
  }

  List<String> _mealSearchVariants(String query) {
    final variants = <String>[query];
    final terms = _recipeTerms(query);
    if (terms.length == 2) {
      final reordered = terms.reversed.join(' ');
      if (reordered.toLowerCase() != query.toLowerCase()) {
        variants.add(reordered);
      }
      if (terms.contains('chicken') && terms.contains('parmesan')) {
        variants.add('Chicken Parmigiana');
        variants.add('Chicken Parmesan');
      }
    }
    return variants.map((s) => s.trim()).where((s) => s.isNotEmpty)
        .toSet().take(4).toList();
  }

  Future<List<Recipe>> _mealDbForDish(String query) async {
    final found = <String, Recipe>{};
    var succeeded = false;
    for (final variant in _mealSearchVariants(query)) {
      try {
        final results = await _mealDb(variant);
        succeeded = true;
        for (final recipe in results) {
          found.putIfAbsent(recipe.id, () => recipe);
        }
      } catch (_) {
        // A single unavailable variant must not hide other valid matches.
      }
    }
    if (!succeeded) {
      throw StateError('TheMealDB could not answer this search.');
    }
    return found.values.toList();
  }

  Future<SearchResults> search(String input) async {
    final query = input.trim();
    if (_recipeTerms(query).isEmpty) return const SearchResults([], []);
    final futures = <Future<List<Recipe>>>[
      _mealDbForDish(query),
      _dummyJson(query),
      ..._sites.entries.map((site) => _wordpress(site.key, site.value, query)),
    ];
    final sourceNames = ['TheMealDB', 'DummyJSON (sample recipes)', ..._sites.keys];
    final results = await Future.wait(futures.map((f) async {
      try { return (await f, false); } catch (_) { return (<Recipe>[], true); }
    }));
    final failed = <String>[];
    final unique = <String, Recipe>{};
    for (var i = 0; i < results.length; i++) {
      if (results[i].$2) failed.add(sourceNames[i]);
      for (final recipe in results[i].$1) {
        if (recipeRelevance(recipe, query) > 0) {
          unique.putIfAbsent(recipe.id, () => recipe);
        }
      }
    }
    final sorted = unique.values.toList()..sort((a, b) {
      final rank = recipeRelevance(b, query).compareTo(recipeRelevance(a, query));
      return rank != 0 ? rank :
          a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return SearchResults(sorted, failed);
  }

  Future<dynamic> _json(Uri uri) async {
    final response = await _client.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Recipe _fromMeal(Map<String, dynamic> meal) {
    final ingredients = <String>[];
    for (var i = 1; i <= 20; i++) {
      final name = (meal['strIngredient$i'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final amount = (meal['strMeasure$i'] ?? '').toString().trim();
      ingredients.add([amount, name].where((v) => v.isNotEmpty).join(' '));
    }
    final directions = (meal['strInstructions'] ?? '').toString().trim();
    return Recipe(
      id: 'mealdb:' + (meal['idMeal'] ?? '').toString(),
      title: (meal['strMeal'] ?? 'Untitled').toString(),
      source: 'TheMealDB',
      imageUrl: (meal['strMealThumb'] ?? '').toString(),
      sourceUrl: (meal['strSource'] ?? '').toString(),
      category: (meal['strCategory'] ?? '').toString(),
      cuisine: (meal['strArea'] ?? '').toString(),
      ingredients: ingredients,
      steps: directions.isEmpty ? [] : directions
          .split(RegExp(r'\r?\n+')).map((v) => v.trim())
          .where((v) => v.isNotEmpty).toList(),
    );
  }

  Future<List<Recipe>> _mealDb(String query) async {
    final data = await _json(Uri.https(
      'www.themealdb.com', '/api/json/v1/$_mealKey/search.php',
      {'s': query},
    )) as Map<String, dynamic>;
    final meals = data['meals'] as List? ?? const [];
    return meals.whereType<Map>()
        .map((raw) => _fromMeal(Map<String, dynamic>.from(raw)))
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
