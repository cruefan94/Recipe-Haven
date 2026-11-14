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
  });

  final String initialIngredient;
  final ValueChanged<String>? onFindAlternatives;
  @override
  State<IngredientFinderScreen> createState() => _IngredientFinderScreenState();
}

class _IngredientFinderScreenState extends State<IngredientFinderScreen> {
  late final TextEditingController _ingredient;

  @override
  void initState() {
    super.initState();
    _ingredient = TextEditingController(text: widget.initialIngredient);
  }
  final _locator = StoreLocator();
  NearbyStoreResults? _found;
  Position? _position;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ingredient.dispose();
    _locator.dispose();
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
      throw StateError('Location access is needed to filter stores within 30 km.');
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
      final position = await _getPosition();
      final results = await _locator.nearby(position.latitude, position.longitude,
        ingredient: _ingredient.text.trim());
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

  Future<void> _maps() async {
    Position? position = _position;
    // A Maps search still works without our having permission; Maps can ask
    // directly for location on its own terms.
    if (position == null) {
      try { position = await _getPosition(); } catch (_) { /* Open Maps near me. */ }
    }
    if (!mounted) return;
    await openExternalUrl(googleMapsSearch(
      _ingredient.text.trim().isEmpty ? 'grocery stores' : _ingredient.text.trim(),
      latitude: position?.latitude, longitude: position?.longitude,
    ).toString(), context);
  }

  @override
  Widget build(BuildContext context) {
    final data = _found;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      Text('Find Ingredient', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Search for an ingredient, then find grocery stores within 30 km of your current location.'),
      const SizedBox(height: 14),
      TextField(
        controller: _ingredient,
        onSubmitted: (_) => _find(),
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          labelText: 'What ingredient do you need?',
          hintText: 'e.g. mozzarella, vanilla, flour',
          prefixIcon: Icon(Icons.shopping_basket_outlined),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _busy ? null : _find,
        icon: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.location_on_outlined),
        label: Text(_busy ? 'Finding nearby stores…' : 'Find stores within 30 km'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _maps,
        icon: const Icon(Icons.map_outlined),
        label: const Text('Search nearby on Google Maps'),
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
      Text('Google Maps locates stores, not products. Sizes, prices and stock appear only if a connected retailer feed supplies them. Check the store before visiting.',
        style: Theme.of(context).textTheme.bodySmall),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
      if (data != null) ...[
        const SizedBox(height: 20),
        Text('${data.stores.length} stores within 30 km',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text('Store directory: ${data.provider}. Distances are straight-line, not driving distance.',
          style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        if (data.stores.isEmpty) const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No stores returned by this directory. Try Google Maps to find more businesses.'),
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
