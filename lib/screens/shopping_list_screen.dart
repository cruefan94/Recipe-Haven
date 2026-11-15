import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';
import '../services/ingredient_substitutions.dart';
import '../services/shopping_list_store.dart';

/// Offline shopping list, shared across Recipe Haven's cooking screens.
/// Item text remains intact so quantities from different recipes are not
/// incorrectly combined.
class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({
    super.key,
    required this.shopping,
    required this.onFindNearby,
    required this.onFindAlternative,
    this.privateCollectionOnly = false,
  });

  final ShoppingListStore shopping;
  final ValueChanged<String> onFindNearby;
  final ValueChanged<String> onFindAlternative;
  final bool privateCollectionOnly;

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  String get _collection => widget.privateCollectionOnly
      ? RecipeCollection.marijuana : RecipeCollection.general;
  final _newItem = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.shopping.addListener(_changed);
  }

  @override
  void dispose() {
    widget.shopping.removeListener(_changed);
    _newItem.dispose();
    super.dispose();
  }

  void _changed() { if (mounted) setState(() {}); }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _action(Future<void> Function() request) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await request();
    } on FormatException catch (e) {
      _message(e.message.toString());
    } catch (_) {
      _message('Could not update the shopping list. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final text = _newItem.text.trim();
    if (text.isEmpty) {
      _message('Type the ingredient or grocery item first.');
      return;
    }
    await _action(() async {
      await widget.shopping.addManual(text, collection: _collection);
      if (!mounted) return;
      _newItem.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      _message('Item added to shopping list.');
    });
  }

  Future<void> _clearBought() async {
    if (_busy || widget.shopping.readFailure || widget.shopping.checkedCountFor(_collection) == 0) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Clear checked items?'),
        content: const Text('This removes only items you marked as purchased. '
            'Other ingredients will stay on your shopping list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Remove checked'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _action(() async {
      final count = await widget.shopping.clearChecked(collection: _collection);
      _message('Removed ' + count.toString() + ' checked items.');
    });
  }

  Future<void> _copy() async {
    final text = widget.shopping.copyText(collection: _collection);
    if (text.isEmpty) {
      _message('You have no unchecked items to copy.');
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: 'Shopping List\n' + text));
      _message('Unchecked shopping items copied.');
    } catch (_) {
      _message('Could not copy shopping list.');
    }
  }

  /// A recognized ingredient name is a better store search term than the
  /// original quantity line. Otherwise Find Ingredient lets users edit text.
  String _searchTerm(ShoppingItem item) =>
      IngredientSubstitutions.lookup(item.text)?.name ?? item.text;

  Widget _itemCard(ShoppingItem item) {
    final theme = Theme.of(context);
    final source = item.sourceRecipe == 'Added manually'
        ? 'Added manually'
        : 'From ' + item.sourceRecipe;
    return Card(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Checkbox(
                value: item.checked,
                onChanged: _busy || widget.shopping.readFailure ? null : (checked) => _action(() =>
                    widget.shopping.setChecked(item.id, checked ?? false)),
              ),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.text, style: theme.textTheme.bodyLarge?.copyWith(
                    decoration: item.checked
                        ? TextDecoration.lineThrough : TextDecoration.none,
                  )),
                  const SizedBox(height: 3),
                  Text(source, style: theme.textTheme.bodySmall),
                  if (item.collection == RecipeCollection.marijuana)
                    Text('From separate adult-use cookbook',
                        style: theme.textTheme.bodySmall),
                ],
              )),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove shopping item',
                onPressed: _busy || widget.shopping.readFailure ? null : () => _action(() =>
                    widget.shopping.remove(item.id)),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.place_outlined, size: 17),
                    label: const Text('Find nearby'),
                    onPressed: () => widget.onFindNearby(_searchTerm(item)),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.swap_horiz, size: 17),
                    label: const Text('Substitute'),
                    onPressed: () => widget.onFindAlternative(item.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopping = widget.shopping;
    final all = shopping.items.where((item) => item.collection == _collection).toList();
    final pending = all.where((item) => !item.checked).toList();
    final checked = all.where((item) => item.checked).toList();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        if (widget.privateCollectionOnly)
          Text('Private Shopping List',
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800)),
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(children: [
              Icon(Icons.shopping_basket_outlined,
                color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 13),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pending.length.toString() + ' left to buy',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(checked.length.toString() +
                      ' completed · Available offline',
                    style: theme.textTheme.bodySmall),
                ],
              )),
            ]),
          ),
        ),
        TextField(
          controller: _newItem,
          maxLength: 220,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _add(),
          decoration: InputDecoration(
            labelText: 'Add a grocery item',
            hintText: 'e.g. 1 L milk',
            prefixIcon: const Icon(Icons.add_shopping_cart),
            suffixIcon: IconButton(
              tooltip: 'Add item',
              onPressed: _busy || shopping.readFailure ? null : _add,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _copy,
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Copy to share'),
          ),
          OutlinedButton.icon(
            onPressed: _busy || shopping.readFailure || checked.isEmpty ? null : _clearBought,
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('Clear checked'),
          ),
        ]),
        if (shopping.readFailure) ...[
          const SizedBox(height: 15),
          Text('Saved shopping data could not be read. Editing is disabled '
              'to protect the existing data.',
              style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 20),
        Text('To buy', style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (pending.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nothing to buy yet. Add an item or import ingredients '
                'from a recipe.'),
          ),
        ...pending.map(_itemCard),
        if (checked.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Checked off', style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...checked.map(_itemCard),
        ],
        const SizedBox(height: 15),
        Text('Recipe quantities are preserved as entered. '
            'Verify product prices and availability with the store.',
            style: theme.textTheme.bodySmall),
      ],
    );
  }
}
