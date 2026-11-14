import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/recipe.dart';
import '../services/cookbook_store.dart';
import '../services/shopping_list_store.dart';
import '../services/recipe_import_service.dart';
import 'ingredient_alternatives_screen.dart';

Future<void> openExternalUrl(String raw, BuildContext context) async {
  final uri = Uri.tryParse(raw);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No original recipe link is available.')));
    return;
  }
  try {
    final worked = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!worked && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open your browser.')));
    }
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open that link.')));
  }
}

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipe, required this.cookbook, required this.shopping});
  final Recipe recipe;
  final CookbookStore cookbook;
  final ShoppingListStore shopping;
  @override State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final Set<int> _checked = {};
  late Recipe _displayRecipe;
  bool _importBusy = false;

  @override void initState() {
    super.initState();
    _displayRecipe = widget.recipe;
    widget.cookbook.addListener(_update);
  }
  @override void dispose() { widget.cookbook.removeListener(_update); super.dispose(); }
  void _update() { if (mounted) setState(() {}); }

  Future<void> _save() async {
    final saved = widget.cookbook.contains(_displayRecipe.id);
    try {
      if (saved) { await widget.cookbook.remove(_displayRecipe.id); }
      else { await widget.cookbook.save(_displayRecipe); }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(saved ? 'Removed from cookbook' : 'Saved to your cookbook')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update cookbook.')));
      }
    }
  }

  Future<void> _addIngredientsToShopping() async {
    final recipe = _displayRecipe;
    if (recipe.ingredients.isEmpty) return;
    try {
      final count = await widget.shopping.addRecipeIngredients(recipe);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(count == 0
            ? 'These ingredients are already on your shopping list.'
            : 'Added ' + count.toString() + ' ingredients to your shopping list.'),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not add shopping ingredients. Please try again.'),
        ));
      }
    }
  }

  Future<void> _importFromSource() async {
    final current = _displayRecipe;
    if (_importBusy || current.sourceUrl.isEmpty) return;
    setState(() => _importBusy = true);
    try {
      final parsed = await RecipeImportService().importUrl(current.sourceUrl);
      if (!mounted) return;
      if (!parsed.hasInstructions) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This website did not expose recipe instructions. Use Open original recipe.'),
        ));
        return;
      }
      final enriched = parsed.copyWith(
        id: current.id,
        collection: current.collection,
      );
      // Replace the same saved recipe only when the user already saved it.
      // Otherwise let the user review the imported ingredients before saving.
      if (widget.cookbook.contains(current.id)) {
        await widget.cookbook.save(enriched);
      }
      if (!mounted) return;
      setState(() {
        _displayRecipe = enriched;
        _checked.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.cookbook.contains(current.id)
          ? 'Ingredients and instructions updated in your cookbook.'
          : 'Recipe loaded! Tap Save to keep it offline.'),
      ));
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message.toString())));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not import the recipe. The original website link is still available.'),
      ));
    } finally {
      if (mounted) setState(() => _importBusy = false);
    }
  }

  @override Widget build(BuildContext context) {
    final recipe = _displayRecipe;
    final saved = widget.cookbook.contains(recipe.id);
    final theme = Theme.of(context);
    final cookbookName = recipe.collection == RecipeCollection.marijuana ? 'Marijuana Cookbook' : 'My Cookbook';
    return Scaffold(
      appBar: AppBar(title: const Text('Recipe details'), actions: [IconButton(
        onPressed: _save, tooltip: saved ? 'Remove from cookbook' : 'Save to cookbook',
        icon: Icon(saved ? Icons.bookmark : Icons.bookmark_outline))]),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 32), children: [
        if (recipe.imageUrl.isNotEmpty) ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.network(recipe.imageUrl, height: 230, fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox(height: 60, child: Icon(Icons.restaurant, size: 45))),
        ),
        const SizedBox(height: 16),
        Text(recipe.title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('From ${recipe.source}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
        if (recipe.category.isNotEmpty || recipe.cuisine.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text([recipe.cuisine, recipe.category].where((s) => s.isNotEmpty).join('  •  ')),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: _save,
          icon: Icon(saved ? Icons.bookmark_added : Icons.bookmark_add_outlined),
          label: Text(saved ? 'Saved to $cookbookName' : 'Save to $cookbookName')),
        if (recipe.sourceUrl.isNotEmpty) ...[
          const SizedBox(height: 8),
          if (recipe.linkOnly || !recipe.hasInstructions) ...[
            FilledButton.tonalIcon(
              onPressed: _importBusy ? null : _importFromSource,
              icon: _importBusy
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_rounded),
              label: Text(_importBusy ? 'Importing recipe…' : 'Import ingredients & steps'),
            ),
            const SizedBox(height: 8),
            const Text('Import works when the website publishes structured recipe data. '
              'Some sites provide a link only.'),
          ],
          OutlinedButton.icon(onPressed: () => openExternalUrl(recipe.sourceUrl, context),
            icon: const Icon(Icons.open_in_new), label: const Text('Open original recipe')),
        ],
        if (recipe.ingredients.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Ingredients', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const Text('Tick off items as you cook'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _addIngredientsToShopping,
            icon: const Icon(Icons.add_shopping_cart_outlined),
            label: const Text('Add ingredients to shopping list'),
          ),
          const SizedBox(height: 8),
          ...recipe.ingredients.asMap().entries.map((item) => CheckboxListTile(
            value: _checked.contains(item.key), controlAffinity: ListTileControlAffinity.leading,
            title: Text(item.value), contentPadding: EdgeInsets.zero,
            secondary: IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Find alternative to ingredient',
              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Ingredient Alternatives')),
                  body: SafeArea(child: IngredientAlternativesScreen(
                    initialIngredient: item.value,
                  )),
                ),
              )),
            ),
            onChanged: (isChecked) => setState(() { if (isChecked == true) { _checked.add(item.key); } else { _checked.remove(item.key); } }),
          )),
        ],
        if (recipe.steps.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('Instructions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...recipe.steps.asMap().entries.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 16, child: Text('${item.key + 1}', style: const TextStyle(fontSize: 13))),
              const SizedBox(width: 12),
              Expanded(child: Padding(padding: const EdgeInsets.only(top: 5), child: Text(item.value, style: theme.textTheme.bodyLarge))),
            ]),
          )),
        ],
        if (!recipe.hasInstructions) ...[
          const SizedBox(height: 26),
          const Icon(Icons.link, size: 44),
          const SizedBox(height: 8),
          const Text('This recipe is saved as a link. Tap “Open original recipe” to read its instructions.',
            textAlign: TextAlign.center),
        ],
      ]),
    );
  }
}
