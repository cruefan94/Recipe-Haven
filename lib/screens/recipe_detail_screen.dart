import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/recipe.dart';
import '../services/cookbook_store.dart';

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
  const RecipeDetailScreen({super.key, required this.recipe, required this.cookbook});
  final Recipe recipe;
  final CookbookStore cookbook;
  @override State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final Set<int> _checked = {};
  @override void initState() { super.initState(); widget.cookbook.addListener(_update); }
  @override void dispose() { widget.cookbook.removeListener(_update); super.dispose(); }
  void _update() { if (mounted) setState(() {}); }

  Future<void> _save() async {
    final saved = widget.cookbook.contains(widget.recipe.id);
    try {
      if (saved) { await widget.cookbook.remove(widget.recipe.id); }
      else { await widget.cookbook.save(widget.recipe); }
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

  @override Widget build(BuildContext context) {
    final recipe = widget.recipe;
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
          OutlinedButton.icon(onPressed: () => openExternalUrl(recipe.sourceUrl, context),
            icon: const Icon(Icons.open_in_new), label: const Text('Open original recipe')),
        ],
        if (recipe.ingredients.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Ingredients', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const Text('Tick off items as you cook'),
          const SizedBox(height: 8),
          ...recipe.ingredients.asMap().entries.map((item) => CheckboxListTile(
            value: _checked.contains(item.key), controlAffinity: ListTileControlAffinity.leading,
            title: Text(item.value), contentPadding: EdgeInsets.zero,
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
