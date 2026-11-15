import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'recipe_detail_screen.dart';
import '../services/store_locator.dart';

/// Find local grocery businesses by location, then link to their own catalogs.
/// A business's presence on Maps is not evidence of item stock or price.
class IngredientFinderScreen extends StatefulWidget {
  const IngredientFinderScreen({
    super.key,
    this.initialIngredient = '',
    this.onFindAlternatives,
    this.storeLocator,
    this.positionProvider,
  });

  final String initialIngredient;
  final ValueChanged<String>? onFindAlternatives;
  /// Optional dependencies let tests exercise the actual in-app store list
  /// without requesting phone location or making live directory calls.
  final StoreLocator? storeLocator;
  final Future<Position> Function()? positionProvider;
  @override
  State<IngredientFinderScreen> createState() => _IngredientFinderScreenState();
}

class _IngredientFinderScreenState extends State<IngredientFinderScreen> {
  late final TextEditingController _ingredient;

  @override
  void initState() {
    super.initState();
    _ingredient = TextEditingController(text: widget.initialIngredient);
    _locator = widget.storeLocator ?? StoreLocator();
    _ownsLocator = widget.storeLocator == null;
  }
  late final StoreLocator _locator;
  late final bool _ownsLocator;
  NearbyStoreResults? _found;
  Position? _position;
  bool _busy = false;
  String? _error;
  int _radiusKm = 10;
  static const List<int> _radiusOptions = [2, 5, 10, 20, 30, 50];

  @override
  void dispose() {
    _ingredient.dispose();
    if (_ownsLocator) _locator.dispose();
    super.dispose();
  }

  Future<Position> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Turn on Location in your phone settings to search nearby stores.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError("Location permission is blocked. Enable it in your phone's app settings.");
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Location permission is needed to list nearby stores.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 18)),
    );
  }

  Future<void> _find() async {
    if (_ingredient.text.trim().isEmpty) {
      setState(() => _error = 'Type the ingredient you need first.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() { _busy = true; _error = null; _found = null; });
    try {
      final position = widget.positionProvider != null
          ? await widget.positionProvider!()
          : await _getPosition();
      final results = await _locator.nearby(position.latitude, position.longitude,
        ingredient: _ingredient.text.trim(),
        searchRadiusKm: _radiusKm.toDouble());
      if (!mounted) return;
      setState(() { _position = position; _found = results; });
    } catch (e) {
      if (!mounted) return;
      final message = e is StateError ? e.message :
          'The store directory or GPS is unavailable. Try again or open Google Maps.';
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Maps works immediately, even if the app's GPS permission was denied.
  /// Searching for supermarket businesses avoids confusing ingredient
  /// names with store names.
  Future<void> _maps() async {
    if (!mounted) return;
    await openExternalUrl(googleMapsSearch(
      'supermarkets',
      latitude: _position?.latitude, longitude: _position?.longitude,
    ).toString(), context);
  }

  /// A product web search is a useful fallback when public store directories
  /// time out. Prices or stock shown by external websites are not verified.
  Future<void> _searchProductWeb() async {
    final name = _ingredient.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter an ingredient first, such as Parmesan cheese.');
      return;
    }
    final uri = Uri.https('www.google.com', '/search', {
      'q': '$name grocery store buy near me',
    });
    await openExternalUrl(uri.toString(), context);
  }

  @override
  Widget build(BuildContext context) {
    final data = _found;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      const Text('Find grocery stores nearby, or search for an ingredient '
          'online. Store listings do not confirm product stock.'),
      const SizedBox(height: 14),
      TextField(
        controller: _ingredient,
        onSubmitted: (_) => _find(),
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          labelText: 'What ingredient do you need?',
          hintText: 'e.g. Parmesan cheese, vanilla, flour',
          prefixIcon: Icon(Icons.shopping_basket_outlined),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        const Expanded(child: Text('Search radius',
          style: TextStyle(fontWeight: FontWeight.w600))),
        const SizedBox(width: 12),
        DropdownButton<int>(
          key: const ValueKey('ingredient-search-radius'),
          value: _radiusKm,
          underline: const SizedBox.shrink(),
          items: _radiusOptions.map((km) => DropdownMenuItem<int>(
            value: km, child: Text('$km km'),
          )).toList(),
          onChanged: _busy ? null : (km) {
            if (km == null) return;
            setState(() {
              _radiusKm = km;
              _found = null;
              _error = null;
            });
          },
        ),
      ]),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _busy ? null : _find,
        icon: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.location_on_outlined),
        label: Text(_busy ? 'Finding nearby stores…'
          : 'Find stores within $_radiusKm km'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _maps,
        icon: const Icon(Icons.map_outlined),
        label: const Text('See grocery stores on Google Maps'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _searchProductWeb,
        icon: const Icon(Icons.manage_search_outlined),
        label: const Text('Look for this ingredient at retailers'),
      ),
      if (widget.onFindAlternatives != null) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => widget.onFindAlternatives!(_ingredient.text.trim()),
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Out of stock? Find an alternative'),
        ),
      ],
      const SizedBox(height: 12),
      Text('Location is requested only when you search. Your current coordinates are sent to a store-directory provider to locate nearby businesses. No background tracking.',
        style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      Text('If the store directory cannot load, the Google Maps and retailer '
          'search buttons above still work. Only an authorized retailer '
          'catalogue can confirm product sizes, prices or stock.',
        style: Theme.of(context).textTheme.bodySmall),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Card(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_error!, style: TextStyle(
              color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _find,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry store list'),
            ),
          ]),
        )),
      ],
      if (data != null) ...[
        const SizedBox(height: 20),
        Text('Nearby stores (${data.stores.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold)),
        if (data.isPartial) ...[
          const SizedBox(height: 6),
          Text('Partial results: ${data.requestedRadiusKm.toInt()} km search '
              'was unavailable. Showing stores within '
              '${data.searchedRadiusKm.toInt()} km instead.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.tertiary)),
        ],
        Text('Searched ${data.searchedRadiusKm.toInt()} km · '
            '${data.provider} · straight-line distance.',
          style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        if (data.stores.isEmpty) const Padding(
          padding: EdgeInsets.all(16),
          child: Text('This directory has no mapped stores to show right now. '
              'That does not mean local grocery stores are absent. '
              'Use the direct Maps or retailer search above.'),
        ),
        ...data.stores.map((store) => Card(
          key: ValueKey(store.id),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(store.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${store.distanceKm.toStringAsFixed(1)} km away · ${store.category}'),
              if (store.address.isNotEmpty) Text(store.address),
              const SizedBox(height: 7),
              if (store.products.isEmpty)
                const Text('Product size and price not available from this directory. Check the retailer.',
                  style: TextStyle(fontSize: 12))
              else ...[
                const Text('Retailer catalogue listings',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...store.products.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (item.size.isNotEmpty) Text('Size: ${item.size}'),
                    Text(item.priceLabel),
                    if (item.availability.isNotEmpty) Text(item.availability),
                    if (item.updatedAt.isNotEmpty) Text('Listing updated: ${item.updatedAt}'),
                    if (item.productUrl != null)
                      TextButton.icon(
                        onPressed: () => openExternalUrl(item.productUrl.toString(), context),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('View retailer product'),
                      ),
                  ]),
                )),
              ],
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 5, children: [
                OutlinedButton.icon(
                  onPressed: () => openExternalUrl(googleMapsStore(store).toString(), context),
                  icon: const Icon(Icons.place_outlined, size: 18), label: const Text('Maps'),
                ),
                OutlinedButton.icon(
                  onPressed: () => openExternalUrl(googleMapsDirections(store).toString(), context),
                  icon: const Icon(Icons.directions_outlined, size: 18), label: const Text('Directions'),
                ),
                if (store.website != null) OutlinedButton.icon(
                  onPressed: () => openExternalUrl(store.website.toString(), context),
                  icon: const Icon(Icons.storefront_outlined, size: 18), label: const Text('Store website'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => openExternalUrl(
                    storeIngredientWebSearch(store, _ingredient.text.trim()).toString(), context),
                  icon: const Icon(Icons.manage_search, size: 18), label: const Text('Look for item'),
                ),
              ]),
            ],
          )),
        )),
        const SizedBox(height: 8),
        const Text('Stores and product information may be incomplete, especially for smaller retailers. Verify with the store before visiting.'),
      ],
    ]);
  }
}
