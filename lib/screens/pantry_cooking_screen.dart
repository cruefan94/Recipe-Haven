import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../data/babe_starter_recipes.dart';
import '../services/cookbook_store.dart';
import '../services/shopping_list_store.dart';
import '../services/recipe_search_service.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

/// "Cook with what I have": saved-cookbook suggestions work offline.
/// Online results are a limited TheMealDB sample, not an exhaustive pantry
/// filter or a guarantee that every required ingredient is available.
class PantryCookingScreen extends StatefulWidget {
  const PantryCookingScreen({super.key, required this.cookbook, required this.shopping});

  final CookbookStore cookbook;
  final ShoppingListStore shopping;

  @override
  State<PantryCookingScreen> createState() => _PantryCookingScreenState();
}

class _PantryCookingScreenState extends State<PantryCookingScreen> {
  final _input = TextEditingController();
  final _api = RecipeSearchService();
  List<String> _terms = const [];
  List<PantryRecipeMatch> _savedMatches = const [];
  List<PantryRecipeMatch> _onlineMatches = const [];
  List<String> _unavailableFilters = const [];
  bool _busy = false;
  bool _offlineOnly = false;
  String? _error;
  String _note = '';
  int _searchId = 0;

  @override
  void initState() {
    super.initState();
    widget.cookbook.addListener(_refreshSaved);
  }

  @override
  void dispose() {
    _searchId++;
    widget.cookbook.removeListener(_refreshSaved);
    _input.dispose();
    _api.dispose();
    super.dispose();
  }

  void _refreshSaved() {
    if (!mounted) return;
    setState(() => _savedMatches = _rankSaved(_terms));
  }

  List<PantryRecipeMatch> _rankSaved(List<String> pantry) {
    if (pantry.isEmpty) return const [];
    final candidates = <String, Recipe>{
      for (final recipe in babeStarterRecipes) recipe.id: recipe,
      for (final recipe in widget.cookbook.saved)
        if (recipe.collection == RecipeCollection.general &&
            recipe.ingredients.isNotEmpty)
          recipe.id: recipe,
    };
    final matches = candidates.values
        .map((recipe) => RecipeSearchService.scorePantry(recipe, pantry))
        .where((result) => result.matched > 0)
        .toList();
    matches.sort((a, b) {
      final rank = b.matched.compareTo(a.matched);
      return rank == 0
          ? a.recipe.title.toLowerCase().compareTo(b.recipe.title.toLowerCase())
          : rank;
    });
    return matches;
  }

  Future<void> _search() async {
    List<String> terms;
    try {
      terms = RecipeSearchService.pantryIngredients(_input.text);
      if (terms.isEmpty) {
        throw const FormatException('Type at least one ingredient.');
      }
    } on FormatException catch (error) {
      setState(() => _error = error.message.toString());
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final request = ++_searchId;
    setState(() {
      _terms = terms;
      _savedMatches = _rankSaved(terms);
      _onlineMatches = const [];
      _unavailableFilters = const [];
      _note = '';
      _busy = true;
      _error = null;
    });
    if (_offlineOnly) {
      setState(() {
        _busy = false;
        _note = 'Offline-only mode: showing matches from saved recipes.';
      });
      return;
    }
    try {
      final result = await _api.searchPantry(terms.join(', '));
      if (!mounted || request != _searchId) return;
      setState(() {
        _onlineMatches = result.matches;
        _unavailableFilters = result.failedSources;
        _note = result.note;
      });
    } catch (_) {
      if (mounted && request == _searchId) {
        setState(() => _error = 'Online suggestions are unavailable. '
            'Your saved cookbook suggestions can still be used offline.');
      }
    } finally {
      if (mounted && request == _searchId) {
        setState(() => _busy = false);
      }
    }
  }

  void _open(Recipe recipe) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => RecipeDetailScreen(
        recipe: recipe,
        cookbook: widget.cookbook,
        shopping: widget.shopping,
      ),
    ),
  );

  Future<void> _toggleSave(Recipe recipe) async {
    try {
      if (widget.cookbook.contains(recipe.id)) {
        await widget.cookbook.remove(recipe.id);
      } else {
        await widget.cookbook.save(recipe);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not update your cookbook.'),
        ));
      }
    }
  }

  Widget _recipeMatch(PantryRecipeMatch result) {
    final recipe = result.recipe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 8),
          child: Text(
            'Matched ' + result.matched.toString() + ' of ' +
                result.total.toString() + ': ' +
                result.matchedNames.join(', '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        RecipeCard(
          key: ValueKey(recipe.id),
          recipe: recipe,
          isSaved: widget.cookbook.contains(recipe.id),
          onOpen: () => _open(recipe),
          onToggleSave: () => _toggleSave(recipe),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedIds = widget.cookbook.saved.map((recipe) => recipe.id).toSet();
    final online = _onlineMatches
        .where((result) => !savedIds.contains(result.recipe.id)).toList();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        Text('Cook with what you have',
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('List up to three ingredients already in your kitchen. '
            'Find ideas in your saved cookbook first, plus an online recipe sample.'),
        const SizedBox(height: 14),
        TextField(
          controller: _input,
          maxLines: 2,
          minLines: 1,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: const InputDecoration(
            labelText: 'Ingredients you have',
            hintText: 'Chicken, rice, garlic',
            prefixIcon: Icon(Icons.kitchen_outlined),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Offline-only search'),
          subtitle: const Text('Search saved recipes without using internet'),
          value: _offlineOnly,
          onChanged: _busy ? null : (value) => setState(() => _offlineOnly = value),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _search,
          icon: const Icon(Icons.restaurant_menu_rounded),
          label: Text(_busy ? 'Finding meal ideas…' : 'Find recipe ideas'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: const ['Chicken', 'Egg', 'Potato', 'Rice']
              .map((name) => ActionChip(
                    label: Text(name),
                    onPressed: () {
                      _input.text = name;
                      _search();
                    },
                  ))
              .toList(),
        ),
        const SizedBox(height: 10),
        Text('Matching an ingredient does not mean a recipe requires only those '
            'ingredients. Open the recipe to check the full shopping list.',
            style: theme.textTheme.bodySmall),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        if (_terms.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Cookbook + built-in recipes (available offline)',
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (_savedMatches.isEmpty)
            const Text('No matching saved or built-in recipes found for these ingredients.'),
          ..._savedMatches.map(_recipeMatch),
          const SizedBox(height: 18),
          Text(_offlineOnly ? 'Offline search' : 'Discover more recipes online',
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (_busy) const Padding(
            padding: EdgeInsets.all(22),
            child: Center(child: CircularProgressIndicator()),
          ) else if (_offlineOnly)
            const Text('Only previously saved recipes were searched. '
                'Turn off Offline-only search to request more recipes.')
          else if (online.isEmpty)
            const Text('No new online recipes returned for this search. '
                'Try a more general ingredient such as chicken or potato.'),
          if (_unavailableFilters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Some ingredient searches were unavailable: ' +
                _unavailableFilters.join(', '),
                style: TextStyle(color: theme.colorScheme.error)),
          ],
          ...online.map(_recipeMatch),
          const SizedBox(height: 10),
          if (_note.isNotEmpty)
            Text(_note, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
