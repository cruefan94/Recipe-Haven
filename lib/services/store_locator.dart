import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// Product information must come from a retailer-authorized catalogue,
/// never inferred from a Google Maps or OpenStreetMap business listing.
class IngredientProduct {
  const IngredientProduct({
    required this.name, this.size = '', this.price = '',
    this.currency = '', this.availability = '', this.productUrl,
    this.updatedAt = '',
  });
  final String name;
  final String size;
  final String price;
  final String currency;
  final String availability;
  final Uri? productUrl;
  final String updatedAt;
  String get priceLabel => price.isEmpty ? 'Price not available'
      : currency.isEmpty ? price : '$currency $price';
}

class NearbyStore {
  const NearbyStore({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.address = '',
    this.website,
    this.googleMapsUrl,
    this.category = 'Food store',
    this.products = const [],
  });
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String address;
  final Uri? website;
  final String? googleMapsUrl;
  final String category;
  final List<IngredientProduct> products;
}

class NearbyStoreResults {
  const NearbyStoreResults({required this.stores, required this.provider});
  final List<NearbyStore> stores;
  final String provider;
}

class StoreLocator {
  StoreLocator({http.Client? client, List<Uri>? overpassEndpoints})
      : _client = client ?? http.Client(),
        _overpassEndpoints = overpassEndpoints ?? [
          Uri.parse('https://overpass.private.coffee/api/interpreter'),
          Uri.parse('https://overpass-api.de/api/interpreter'),
        ];
  final http.Client _client;
  final List<Uri> _overpassEndpoints;
  static const double radiusKm = 30;
  static const String _workerUrl = String.fromEnvironment('STORE_LOOKUP_URL');

  /// Only called after the user presses Find Nearby Stores and grants location.
  Future<NearbyStoreResults> nearby(double latitude, double longitude, {String ingredient = ''}) async {
    if (!latitude.isFinite || !longitude.isFinite || latitude.abs() > 90 || longitude.abs() > 180) {
      throw const FormatException('Invalid device coordinates');
    }
    if (_workerUrl.isNotEmpty) {
      try {
        return await _googleWorker(latitude, longitude, ingredient.trim());
      } catch (_) {
        // A provider outage should not prevent a basic community-map search.
      }
    }
    return _openStreetMap(latitude, longitude);
  }

  Future<NearbyStoreResults> _googleWorker(double lat, double lon, String ingredient) async {
    final origin = Uri.tryParse(_workerUrl);
    if (origin == null || origin.scheme != 'https' || origin.host.isEmpty) {
      throw const FormatException('STORE_LOOKUP_URL must be an HTTPS endpoint');
    }
    final uri = origin.replace(queryParameters: {
      ...origin.queryParameters,
      'lat': '$lat', 'lon': '$lon', 'radius': '30000',
      'ingredient': ingredient.length > 120 ? ingredient.substring(0, 120) : ingredient,
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 16));
    if (response.statusCode != 200) throw StateError('Store service unavailable');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final stores = <NearbyStore>[];
    for (final raw in (data['stores'] as List<dynamic>? ?? [])) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final pointLat = (item['latitude'] as num?)?.toDouble();
      final pointLon = (item['longitude'] as num?)?.toDouble();
      if (pointLat == null || pointLon == null) continue;
      final name = (item['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final distance = distanceKm(lat, lon, pointLat, pointLon);
      if (distance > radiusKm) continue;
      stores.add(NearbyStore(
        id: 'google:${item['id'] ?? name}', name: name,
        latitude: pointLat, longitude: pointLon, distanceKm: distance,
        address: (item['address'] as String? ?? '').trim(),
        website: safeWebsite(item['website'] as String?),
        googleMapsUrl: item['mapsUrl'] as String?,
        category: 'Store',
        products: _productsFromCatalog(item['products']),
      ));
    }
    stores.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return NearbyStoreResults(stores: stores, provider: 'Google Places');
  }

  /// Optional worker product fields; missing price or stock stays unknown.
  List<IngredientProduct> _productsFromCatalog(dynamic input) {
    if (input is! List) return const [];
    final output = <IngredientProduct>[];
    for (final raw in input.take(15)) {
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);
      String field(String key, [int maxLength = 160]) {
        final rawValue = data[key];
        final value = rawValue is String ? rawValue.trim() : '';
        return value.length > maxLength ? value.substring(0, maxLength) : value;
      }
      final name = field('name');
      if (name.isEmpty) continue;
      final listed = data['price'];
      final price = listed is num ? listed.toStringAsFixed(2) : field('price', 32);
      final status = switch (field('availability', 30).toLowerCase()) {
        'in_stock' => 'In stock according to retailer',
        'out_of_stock' => 'Out of stock according to retailer',
        'limited' => 'Limited stock according to retailer',
        _ => '',
      };
      output.add(IngredientProduct(
        name: name, size: field('size', 80), price: price,
        currency: field('currency', 8).toUpperCase(),
        availability: status,
        productUrl: safeWebsite(field('productUrl', 1000)),
        updatedAt: field('updatedAt', 40),
      ));
    }
    return output;
  }

  /// Do not silently equate an HTTP error with a lack of grocery stores.
  Future<NearbyStoreResults> _openStreetMap(double lat, double lon) async {
    final around = '30000,${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}';
    const shopTypes =
        'supermarket|grocery|convenience|greengrocer|general|organic|deli|farm';
    final query = '[out:json][timeout:18];'
        '(nwr["shop"~"^($shopTypes)\$"](around:$around););'
        'out center 600;';
    Object? lastFailure;
    NearbyStoreResults? emptyResult;
    for (final endpoint in _overpassEndpoints) {
      try {
        final response = await _client.post(
          endpoint,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
            'Accept': 'application/json',
            'User-Agent': 'RecipeHaven/0.2 (https://github.com/cruefan94/Recipe-Haven)',
          },
          body: {'data': query},
        ).timeout(const Duration(seconds: 21));
        if (response.statusCode != 200) {
          throw StateError('Store directory HTTP ${response.statusCode}');
        }
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map || decoded['elements'] is! List) {
          throw const FormatException('Invalid store directory response.');
        }
        final stores = <NearbyStore>[];
        final seen = <String>{};
        for (final raw in (decoded['elements'] as List)) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);
          final tags = (item['tags'] as Map?)?.cast<String, dynamic>() ?? {};
          final name = (tags['name'] as String? ?? '').trim();
          if (name.isEmpty) continue;
          final center = (item['center'] as Map?)?.cast<String, dynamic>() ?? item;
          final pointLat = (center['lat'] as num?)?.toDouble();
          final pointLon = (center['lon'] as num?)?.toDouble();
          if (pointLat == null || pointLon == null || !pointLat.isFinite ||
              !pointLon.isFinite) continue;
          final distance = distanceKm(lat, lon, pointLat, pointLon);
          if (distance > radiusKm) continue;
          final id = 'osm:${item['type']}:${item['id']}';
          if (!seen.add(id)) continue;
          final streetAddress = [
            tags['addr:housenumber'], tags['addr:street'], tags['addr:city'],
          ].whereType<String>().where((v) => v.isNotEmpty).join(' ');
          stores.add(NearbyStore(
            id: id, name: name, latitude: pointLat, longitude: pointLon,
            distanceKm: distance, address: streetAddress,
            website: safeWebsite((tags['website'] ?? tags['contact:website'])?.toString()),
            category: (tags['shop'] as String? ?? 'Food store').replaceAll('_', ' '),
          ));
        }
        stores.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        final result = NearbyStoreResults(
          stores: stores, provider: 'OpenStreetMap (${endpoint.host})');
        if (stores.isNotEmpty) return result;
        emptyResult ??= result;
      } catch (error) {
        lastFailure = error;
      }
    }
    if (emptyResult != null) {
      return emptyResult;
    }
    throw StateError('Store directory temporarily unavailable. '
        'Nearby grocery stores may still exist. Use the direct Maps search. '
        '${lastFailure is FormatException ? 'Directory response invalid.' : ''}');
  }

  void dispose() => _client.close();
}

/// Only direct HTTPS/HTTP store websites are opened. Prevent unsafe schemes.
Uri? safeWebsite(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final trimmed = value.trim();
  final parsed = Uri.tryParse(trimmed.contains('://') ? trimmed : 'https://$trimmed');
  if (parsed == null || !{'http', 'https'}.contains(parsed.scheme) ||
      parsed.host.isEmpty || !parsed.host.contains('.') || parsed.userInfo.isNotEmpty) {
    return null;
  }
  return parsed;
}

double distanceKm(double latA, double lonA, double latB, double lonB) {
  const earthKm = 6371.0088;
  final dLat = (latB - latA) * math.pi / 180;
  final dLon = (lonB - lonA) * math.pi / 180;
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(latA * math.pi / 180) * math.cos(latB * math.pi / 180) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthKm * math.asin(math.min(1, math.sqrt(a)));
}

Uri googleMapsSearch(String ingredient, {double? latitude, double? longitude}) {
  final near = latitude != null && longitude != null
      ? ' near ${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}'
      : ' near me';
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1', 'query': '$ingredient grocery store$near',
  });
}

Uri googleMapsStore(NearbyStore store) {
  final directlyProvided = Uri.tryParse(store.googleMapsUrl ?? '');
  if (directlyProvided != null && directlyProvided.scheme == 'https' &&
      {'google.com', 'www.google.com', 'maps.google.com'}.contains(directlyProvided.host)) {
    return directlyProvided;
  }
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1', 'query': '${store.name}, ${store.address.isEmpty ? '${store.latitude},${store.longitude}' : store.address}',
  });
}

Uri googleMapsDirections(NearbyStore store) => Uri.https('www.google.com', '/maps/dir/', {
  'api': '1', 'destination': '${store.latitude},${store.longitude}',
});

Uri storeIngredientWebSearch(NearbyStore store, String ingredient) {
  final site = store.website?.host;
  final search = site == null
      ? '"${store.name}" "$ingredient" grocery price size'
      : 'site:$site "$ingredient" price size';
  return Uri.https('www.google.com', '/search', {'q': search});
}
