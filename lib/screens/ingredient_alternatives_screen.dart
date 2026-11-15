import 'package:flutter/material.dart';
import '../services/ingredient_substitutions.dart';

/// Self-contained lookup: no network or GPS required.
class IngredientAlternativesScreen extends StatefulWidget {
  const IngredientAlternativesScreen({
    super.key,
    this.initialIngredient = '',
    this.onFindNearby,
  });

  final String initialIngredient;
  final ValueChanged<String>? onFindNearby;

  @override
  State<IngredientAlternativesScreen> createState() =>
      _IngredientAlternativesScreenState();
}

class _IngredientAlternativesScreenState
    extends State<IngredientAlternativesScreen> {
  late final TextEditingController _input;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.initialIngredient);
  }

  @override
  void didUpdateWidget(covariant IngredientAlternativesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIngredient != widget.initialIngredient) {
      _input.text = widget.initialIngredient;
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _select(String ingredient) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _input.text = ingredient);
  }

  @override
  Widget build(BuildContext context) {
    final query = _input.text.trim();
    final guide = IngredientSubstitutions.lookup(query);
    final alternatives = IngredientSubstitutions.suggestions(query)
        .where((entry) => !identical(entry, guide))
        .take(10)
        .toList();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        Text('Missing an ingredient?',
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Type the ingredient you are out of and see possible '
            'replacements, how much to use, and which recipes they suit. '
            'Works offline.'),
        const SizedBox(height: 14),
        TextField(
          controller: _input,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: InputDecoration(
            labelText: 'Missing ingredient',
            hintText: 'Buttermilk, eggs, heavy cream...',
            prefixIcon: const Icon(Icons.swap_horiz_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear ingredient',
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => setState(() => _input.clear()),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        if (query.isEmpty) ...[
          Text('Popular replacements',
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              'Buttermilk', 'Egg', 'Heavy cream', 'Baking powder',
              'Butter', 'Cornstarch', 'Brown sugar', 'Sour cream',
            ].map((name) => ActionChip(
              label: Text(name),
              onPressed: () => _select(name),
            )).toList(),
          ),
        ] else if (guide == null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Icon(Icons.search_off_outlined, size: 40),
                  const SizedBox(height: 8),
                  Text('No reliable offline match found',
                    style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Try the ingredient name without quantities or '
                      'choose a related ingredient below.',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ] else ...[
          Text('Alternatives to ' + guide.name,
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('For: ' + guide.referenceAmount,
              style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('The amounts below are for the reference quantity, '
              'not automatically adjusted to the amount in your recipe.'),
          const SizedBox(height: 14),
          ...guide.options.map((option) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Use ' + option.amount,
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Best for: ' + option.bestFor),
                  const SizedBox(height: 5),
                  Text(option.note),
                ],
              ),
            ),
          )),
          if (guide.caution.isNotEmpty) ...[
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: const Text('Important note'),
              subtitle: Text(guide.caution),
            ),
          ],
        ],
        if (alternatives.isNotEmpty && query.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(guide == null ? 'Did you mean?' : 'Related ingredients',
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: alternatives.map((entry) => ActionChip(
              label: Text(entry.name),
              onPressed: () => _select(entry.name),
            )).toList(),
          ),
        ],
        if (widget.onFindNearby != null) ...[
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => widget.onFindNearby!(
                guide?.name ?? query),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Find the ingredient in nearby stores'),
          ),
        ],
        const SizedBox(height: 22),
        Text('Substitutes can change taste, texture, rise and allergens. '
            'Check ingredient labels. Do not change tested home-canning '
            'or preservation recipes, infant food, or medically prescribed '
            'diets based on this general guide.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall),
      ],
    );
  }
}
