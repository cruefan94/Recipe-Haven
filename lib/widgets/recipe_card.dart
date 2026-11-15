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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 88, height: 88,
                child: recipe.imageUrl.isNotEmpty
                    ? Image.network(recipe.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, trace) =>
                            _placeholder(colors))
                    : _placeholder(colors),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.title, maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700, height: 1.2)),
                const SizedBox(height: 6),
                Text(recipe.source, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall),
                if (recipe.category.isNotEmpty ||
                    recipe.cuisine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text([recipe.cuisine, recipe.category]
                      .where((value) => value.isNotEmpty).join(' · '),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall),
                ],
                if (recipe.linkOnly) ...[
                  const SizedBox(height: 4),
                  Text('Read on original website',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.primary)),
                ],
              ],
            )),
            IconButton(
              tooltip: isSaved ? 'Remove from cookbook' : 'Save to cookbook',
              onPressed: onToggleSave,
              icon: Icon(isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded),
              color: isSaved ? colors.primary : colors.onSurfaceVariant,
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
