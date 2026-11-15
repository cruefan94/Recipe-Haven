import 'package:flutter/material.dart';
import '../data/babe_starter_recipes.dart';
import '../models/recipe.dart';
import '../services/cookbook_store.dart';
import '../services/shopping_list_store.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

/// Browse complete, original recipes packaged with Babe, without any network.
class BabeStarterRecipesScreen extends StatefulWidget {
  const BabeStarterRecipesScreen({
    super.key,
    required this.cookbook,
    required this.shopping,
  });
  final CookbookStore cookbook;
  final ShoppingListStore shopping;

  @override
  State<BabeStarterRecipesScreen> createState() =>
      _BabeStarterRecipesScreenState();
}

class _BabeStarterRecipesScreenState extends State<BabeStarterRecipesScreen> {
  final _filter = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.cookbook.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.cookbook.removeListener(_refresh);
    _filter.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _open(Recipe recipe) {
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => RecipeDetailScreen(
        recipe: recipe,
        cookbook: widget.cookbook,
        shopping: widget.shopping,
      ),
    ));
  }

  Future<void> _save(Recipe recipe) async {
    try {
      if (widget.cookbook.contains(recipe.id)) {
        await widget.cookbook.remove(recipe.id);
      } else {
        await widget.cookbook.save(recipe);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not update your cookbook.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _filter.text.trim().toLowerCase();
    final results = babeStarterRecipes.where((recipe) =>
        q.isEmpty || recipe.title.toLowerCase().contains(q) ||
        recipe.category.toLowerCase().contains(q) ||
        recipe.ingredients.any((item) => item.toLowerCase().contains(q)))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Text('Babe Quick Recipes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('18 original, complete recipes included in Babe. '
          'Open and save them even when your phone is offline.'),
        const SizedBox(height: 14),
        TextField(
          controller: _filter,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Find a dish or ingredient...',
            suffixIcon: q.isEmpty ? null : IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _filter.clear()),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(results.length.toString() + ' recipes',
          style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (results.isEmpty) const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No built-in recipe matches that search. '
            'Try another ingredient or open Find Recipes for more sources.'),
        ),
        ...results.map((recipe) => RecipeCard(
          key: ValueKey(recipe.id),
          recipe: recipe,
          isSaved: widget.cookbook.contains(recipe.id),
          onOpen: () => _open(recipe),
          onToggleSave: () => _save(recipe),
        )),
        const SizedBox(height: 16),
        Text('Cooking times are estimates. Always follow safe food-handling '
            'practices, check allergens and verify cooking temperatures.',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
