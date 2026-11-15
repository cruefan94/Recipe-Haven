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
  const NearbyStoreResults({
    required this.stores, required this.provider,
    this.requestedRadiusKm = 30, this.searchedRadiusKm = 30,
  });
  final List<NearbyStore> stores;
  final String provider;
  final double requestedRadiusKm;
  final double searchedRadiusKm;
  bool get isPartial => searchedRadiusKm < requestedRadiusKm;
}

class StoreLocator {
  StoreLocator({http.Client? client, List<Uri>? overpassEndpoints})
      : _client = client ?? http.Client(),
        _overpassEndpoints = overpassEndpoints ?? [
          Uri.parse('https://overpass.private.coffee/api/interpreter'),
          Uri.parse('https://overpass-api.de/api/interpreter'),
          Uri.parse('https://lz4.overpass-api.de/api/interpreter'),
        ];
  final http.Client _client;
  final List<Uri> _overpassEndpoints;
  static const double radiusKm = 30;
  static const double minRadiusKm = 1;
  static const double maxRadiusKm = 50;
  static const String _workerUrl = String.fromEnvironment('STORE_LOOKUP_URL');

  /// Only called after the user presses Find Nearby Stores and grants location.
  Future<NearbyStoreResults> nearby(double latitude, double longitude, {
    String ingredient = '', double searchRadiusKm = radiusKm,
  }) async {
    if (!latitude.isFinite || !longitude.isFinite || latitude.abs() > 90 || longitude.abs() > 180) {
      throw const FormatException('Invalid device coordinates');
    }
    if (!searchRadiusKm.isFinite || searchRadiusKm < minRadiusKm ||
        searchRadiusKm > maxRadiusKm) {
      throw const FormatException('Choose a radius between 1 and 50 km.');
    }
    if (_workerUrl.isNotEmpty) {
      try {
        return await _googleWorker(latitude, longitude,
            ingredient.trim(), searchRadiusKm);
      } catch (_) {
        // A provider outage should not prevent a basic community-map search.
      }
    }
    try {
      final osm = await _openStreetMap(
          latitude, longitude, searchRadiusKm);
      if (osm.stores.isNotEmpty) return osm;
      try {
        final backup = await _photon(
            latitude, longitude, searchRadiusKm);
        return backup.stores.isNotEmpty ? backup : osm;
      } catch (_) {
        return osm;
      }
    } catch (_) {
      try {
        return await _photon(latitude, longitude, searchRadiusKm);
      } catch (_) {
        throw StateError('Both store directories are temporarily unavailable. '
          'Try a smaller search radius or Google Maps.');
      }
    }
  }

  Future<NearbyStoreResults> _googleWorker(
      double lat, double lon, String ingredient, double searchRadiusKm) async {
    final origin = Uri.tryParse(_workerUrl);
    if (origin == null || origin.scheme != 'https' || origin.host.isEmpty) {
      throw const FormatException('STORE_LOOKUP_URL must be an HTTPS endpoint');
    }
    final uri = origin.replace(queryParameters: {
      ...origin.queryParameters,
      'lat': '$lat', 'lon': '$lon',
      'radius': (searchRadiusKm * 1000).round().toString(),
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
      if (distance > searchRadiusKm) continue;
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
    return NearbyStoreResults(
      stores: stores, provider: 'Google Places',
      requestedRadiusKm: searchRadiusKm, searchedRadiusKm: searchRadiusKm);
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
  Future<NearbyStoreResults> _openStreetMap(
      double lat, double lon, double requestedKm) async {
    try {
      return await _queryOverpass(lat, lon, requestedKm, requestedKm);
    } catch (_) {
      if (requestedKm <= 10) rethrow;
      // A smaller query is less likely to overload public community servers.
      // Results must be explicitly labelled as a PARTIAL area search.
      return _queryOverpass(lat, lon, 10, requestedKm);
    }
  }

  Future<NearbyStoreResults> _queryOverpass(
      double lat, double lon, double searchedKm, double requestedKm) async {
    final around = '${(searchedKm * 1000).round()},${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}';
    const shopTypes =
        'supermarket|grocery|convenience|greengrocer|general|organic|deli|farm';
    final query = '[out:json][timeout:14];'
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
).timeout(const Duration(seconds: 16));
        if (response.statusCode != 200) {
          throw StateError('Store directory HTTP ${response.statusCode}');
        }
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map || decoded['elements'] is! List) {
          throw const FormatException('Invalid store directory response.');
        }
        if (decoded['remark'] is String &&
            (decoded['remark'] as String).isNotEmpty) {
          throw StateError('Store directory timed out.');
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
              !pointLon.isFinite) {
            continue;
          }
          final distance = distanceKm(lat, lon, pointLat, pointLon);
          if (distance > searchedKm) continue;
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
          stores: stores, provider: 'OpenStreetMap (${endpoint.host})',
          requestedRadiusKm: requestedKm, searchedRadiusKm: searchedKm);
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

  /// Independent read-only OSM geocoder fallback. Photon accepts a category
  /// filter without a free-text query. Results are validated and strictly
  /// distance-filtered rather than treating search bias as a radius bound.
  /// Only one request is issued after a user-initiated Overpass miss/outage.
  Future<NearbyStoreResults> _photon(
      double lat, double lon, double searchedKm) async {
    final uri = Uri.https('photon.komoot.io', '/api', {
      'lat': '$lat',
      'lon': '$lon',
      'limit': '50',
      'include': 'osm.shop.supermarket,osm.shop.grocery,'
          'osm.shop.convenience,osm.shop.general,osm.shop.greengrocer,'
          'osm.shop.organic,osm.shop.deli,osm.shop.farm',
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 9));
    if (response.statusCode != 200) {
      throw StateError('Photon directory HTTP ${response.statusCode}');
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map || json['features'] is! List) {
      throw const FormatException('Invalid backup directory response.');
    }
    const categories = {
      'supermarket', 'grocery', 'convenience', 'general',
      'greengrocer', 'organic', 'deli', 'farm',
    };
    final stores = <NearbyStore>[];
    final seen = <String>{};
    for (final raw in json['features'] as List) {
      if (raw is! Map) continue;
      final props = raw['properties'];
      final geometry = raw['geometry'];
      if (props is! Map || geometry is! Map) continue;
      final name = (props['name'] as String? ?? '').trim();
      if (name.isEmpty || props['osm_key'] != 'shop' ||
          !categories.contains(props['osm_value'])) {
        continue;
      }
      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.length < 2 ||
          coordinates[0] is! num || coordinates[1] is! num) {
        continue;
      }
      final storeLon = (coordinates[0] as num).toDouble();
      final storeLat = (coordinates[1] as num).toDouble();
      if (!storeLon.isFinite || !storeLat.isFinite ||
          storeLat.abs() > 90 || storeLon.abs() > 180) {
        continue;
      }
      final distance = distanceKm(lat, lon, storeLat, storeLon);
      if (distance > searchedKm) continue;
      final id = 'osm:${props['osm_type']}:${props['osm_id']}';
      if (!seen.add(id)) continue;
      final address = [
        props['housenumber'], props['street'],
        props['city'], props['state'],
      ].whereType<String>().where((v) => v.isNotEmpty).join(' ');
      stores.add(NearbyStore(
        id: id,
        name: name,
        latitude: storeLat,
        longitude: storeLon,
        distanceKm: distance,
        address: address,
        category: (props['osm_value'] as String).replaceAll('_', ' '),
      ));
    }
    stores.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return NearbyStoreResults(
      stores: stores, provider: 'OpenStreetMap search (Photon)',
      requestedRadiusKm: searchedKm, searchedRadiusKm: searchedKm,
    );
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
