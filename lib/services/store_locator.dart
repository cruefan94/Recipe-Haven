import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// No product inventory or price claim is made from a map listing.
/// Google Places can be enabled through a separate, server-side worker.
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
}

class NearbyStoreResults {
  const NearbyStoreResults({required this.stores, required this.provider});
  final List<NearbyStore> stores;
  final String provider;
}

class StoreLocator {
  StoreLocator({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const double radiusKm = 30;
  static const String _workerUrl = String.fromEnvironment('STORE_LOOKUP_URL');

  /// Only called after the user presses Find Nearby Stores and grants location.
  Future<NearbyStoreResults> nearby(double latitude, double longitude) async {
    if (!latitude.isFinite || !longitude.isFinite || latitude.abs() > 90 || longitude.abs() > 180) {
      throw const FormatException('Invalid device coordinates');
    }
    if (_workerUrl.isNotEmpty) {
      try {
        return await _googleWorker(latitude, longitude);
      } catch (_) {
        // A provider outage should not prevent a basic community-map search.
      }
    }
    return _openStreetMap(latitude, longitude);
  }

  Future<NearbyStoreResults> _googleWorker(double lat, double lon) async {
    final origin = Uri.tryParse(_workerUrl);
    if (origin == null || origin.scheme != 'https' || origin.host.isEmpty) {
      throw const FormatException('STORE_LOOKUP_URL must be an HTTPS endpoint');
    }
    final uri = origin.replace(queryParameters: {
      ...origin.queryParameters,
      'lat': '$lat', 'lon': '$lon', 'radius': '30000',
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
      ));
    }
    stores.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return NearbyStoreResults(stores: stores, provider: 'Google Places');
  }

  Future<NearbyStoreResults> _openStreetMap(double lat, double lon) async {
    // The public Overpass service may be slow or unavailable; this is a fallback,
    // not a guarantee of full or real-time store coverage.
    final around = '30000,${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}';
    const shopTypes = 'supermarket|grocery|convenience|greengrocer|butcher|bakery|deli|general|organic|spices|health_food|farm';
    final query = '''[out:json][timeout:22];
(
node["shop"~"^($shopTypes)\$"] (around:$around);
way["shop"~"^($shopTypes)\$"] (around:$around);
);
out center 550;''';
    final response = await _client.post(
      Uri.parse('https://overpass.kumi.systems/api/interpreter'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8'},
      body: {'data': query},
    ).timeout(const Duration(seconds: 28));
    if (response.statusCode != 200) throw StateError('Nearby stores could not be loaded');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final stores = <NearbyStore>[];
    for (final raw in (data['elements'] as List<dynamic>? ?? [])) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final tags = (item['tags'] as Map?)?.cast<String, dynamic>() ?? {};
      final name = (tags['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final center = (item['center'] as Map?)?.cast<String, dynamic>() ?? item;
      final pointLat = (center['lat'] as num?)?.toDouble();
      final pointLon = (center['lon'] as num?)?.toDouble();
      if (pointLat == null || pointLon == null) continue;
      final distance = distanceKm(lat, lon, pointLat, pointLon);
      if (distance > radiusKm) continue;
      final streetAddress = [
        tags['addr:housenumber'], tags['addr:street'], tags['addr:city'],
      ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
      stores.add(NearbyStore(
        id: 'osm:${item['type']}:${item['id']}', name: name,
        latitude: pointLat, longitude: pointLon, distanceKm: distance,
        address: streetAddress,
        website: safeWebsite((tags['website'] ?? tags['contact:website']) as String?),
        category: (tags['shop'] as String? ?? 'Food store').replaceAll('_', ' '),
      ));
    }
    stores.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return NearbyStoreResults(stores: stores, provider: 'OpenStreetMap');
  }

  void dispose() => _client.close();
}

/// Only direct HTTPS/HTTP store websites are opened. Prevent unsafe schemes.
Uri? safeWebsite(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final trimmed = value.trim();
  final parsed = Uri.tryParse(trimmed.contains('://') ? trimmed : 'https://$trimmed');
  if (parsed == null || !{'http', 'https'}.contains(parsed.scheme) ||
      parsed.host.isEmpty || !parsed.host.contains('.') || parsed.userInfo.isNotEmpty) return null;
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
