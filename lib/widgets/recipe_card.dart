import 'package:flutter/material.dart';
import '../models/recipe.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.recipe, required this.isSaved, required this.onOpen, required this.onToggleSave});
  final Recipe recipe;
  final bool isSaved;
  final VoidCallback onOpen;
  final VoidCallback onToggleSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 90, height: 90,
                child: recipe.imageUrl.isNotEmpty
                    ? Image.network(recipe.imageUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _placeholder(scheme))
                    : _placeholder(scheme),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(recipe.source, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              if (recipe.category.isNotEmpty || recipe.cuisine.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text([recipe.cuisine, recipe.category].where((s) => s.isNotEmpty).join(' • '),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
              if (recipe.linkOnly) Padding(padding: const EdgeInsets.only(top: 5), child: Text('View source to read',
                style: TextStyle(color: scheme.primary, fontSize: 12))),
            ])),
            IconButton(
              tooltip: isSaved ? 'Remove from cookbook' : 'Save to cookbook',
              onPressed: onToggleSave,
              icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: isSaved ? scheme.primary : scheme.onSurfaceVariant),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => ColoredBox(
    color: scheme.secondaryContainer,
    child: Icon(Icons.restaurant_menu, size: 32, color: scheme.onSecondaryContainer),
  );
}
