class RecipeCollection {
  static const general = 'general';
  static const marijuana = 'marijuana';
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.source,
    this.imageUrl = '',
    this.sourceUrl = '',
    this.category = '',
    this.cuisine = '',
    this.timeMinutes,
    this.ingredients = const [],
    this.steps = const [],
    this.linkOnly = false,
    this.collection = RecipeCollection.general,
  });

  final String id;
  final String title;
  final String source;
  final String imageUrl;
  final String sourceUrl;
  final String category;
  final String cuisine;
  final int? timeMinutes;
  final List<String> ingredients;
  final List<String> steps;
  final bool linkOnly;
  /// Which separately displayed cookbook this recipe belongs to.
  final String collection;

  bool get hasInstructions => ingredients.isNotEmpty || steps.isNotEmpty;

  Recipe copyWith({
    String? id,
    String? title,
    String? source,
    String? imageUrl,
    String? sourceUrl,
    String? category,
    String? cuisine,
    int? timeMinutes,
    List<String>? ingredients,
    List<String>? steps,
    bool? linkOnly,
    String? collection,
  }) => Recipe(
    id: id ?? this.id,
    title: title ?? this.title,
    source: source ?? this.source,
    imageUrl: imageUrl ?? this.imageUrl,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    category: category ?? this.category,
    cuisine: cuisine ?? this.cuisine,
    timeMinutes: timeMinutes ?? this.timeMinutes,
    ingredients: ingredients ?? this.ingredients,
    steps: steps ?? this.steps,
    linkOnly: linkOnly ?? this.linkOnly,
    collection: collection ?? this.collection,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'source': source,
    'imageUrl': imageUrl, 'sourceUrl': sourceUrl,
    'category': category, 'cuisine': cuisine, 'timeMinutes': timeMinutes,
    'ingredients': ingredients, 'steps': steps, 'linkOnly': linkOnly,
    'collection': collection,
  };

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
    id: '${j['id'] ?? ''}', title: '${j['title'] ?? ''}',
    source: '${j['source'] ?? ''}', imageUrl: '${j['imageUrl'] ?? ''}',
    sourceUrl: '${j['sourceUrl'] ?? ''}', category: '${j['category'] ?? ''}',
    cuisine: '${j['cuisine'] ?? ''}', timeMinutes: (j['timeMinutes'] as num?)?.toInt(),
    ingredients: ((j['ingredients'] as List?) ?? []).map((e) => '$e').toList(),
    steps: ((j['steps'] as List?) ?? []).map((e) => '$e').toList(),
    linkOnly: j['linkOnly'] == true,
    // Existing saved recipes predate collections and stay in the everyday cookbook.
    collection: j['collection'] == RecipeCollection.marijuana
        ? RecipeCollection.marijuana : RecipeCollection.general,
  );
}
