import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recipe_haven/services/store_locator.dart';

void main() {
  test('5 km lookup uses second current Overpass server after first fails', () async {
    final visited = <String>[];
    final client = MockClient((request) async {
      visited.add(request.url.host);
      expect(request.bodyFields['data'], contains('5000'));
      if (request.url.host == 'overpass.private.coffee') {
        return http.Response('Temporary error', 503);
      }
      return http.Response(jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 100,
            'lat': 45.501,
            'lon': -73.571,
            'tags': {'name': 'Test Grocery', 'shop': 'supermarket'}
          },
          {
            'type': 'node',
            'id': 101,
            'lat': 46.2,
            'lon': -73.571,
            'tags': {'name': 'Too Far Away', 'shop': 'supermarket'}
          },
        ]
      }), 200);
    });
    final finder = StoreLocator(client: client);
    final result = await finder.nearby(45.5, -73.57,
        ingredient: 'Parmesan cheese', searchRadiusKm: 5);
    expect(visited, ['overpass.private.coffee', 'overpass-api.de']);
    expect(result.stores, hasLength(1));
    expect(result.stores.single.name, 'Test Grocery');
    expect(result.provider, contains('overpass-api.de'));
    finder.dispose();
  });

  test('temporary directory outages report an error instead of no stores', () async {
    final finder = StoreLocator(client: MockClient((request) async {
      return http.Response('Unavailable', 503);
    }));
    expect(
      () => finder.nearby(45.5, -73.57),
      throwsA(isA<StateError>()),
    );
    finder.dispose();
  });
  test('selected 5 km radius changes API query and in-app store distances', () async {
    final locator = StoreLocator(client: MockClient((request) async {
      expect(request.bodyFields['data'], contains('around:5000,'));
      return http.Response(jsonEncode({
        'elements': [
          {'type': 'node', 'id': 1, 'lat': 45.501, 'lon': -73.57,
            'tags': {'name': 'Nearby Grocery', 'shop': 'supermarket'}},
          {'type': 'node', 'id': 2, 'lat': 45.7, 'lon': -73.57,
            'tags': {'name': 'Distant Grocery', 'shop': 'supermarket'}},
        ],
      }), 200);
    }));
    final result = await locator.nearby(45.5, -73.57, searchRadiusKm: 5);
    expect(result.stores.map((store) => store.name), ['Nearby Grocery']);
    expect(result.requestedRadiusKm, 5);
    expect(result.searchedRadiusKm, 5);
    expect(result.isPartial, isFalse);
    locator.dispose();
  });

  test('30 km search returns quick and labelled local-area list', () async {
    final calls = <String>[];
    final locator = StoreLocator(client: MockClient((request) async {
      if (request.url.host == 'photon.komoot.io') {
        return http.Response('Public location lookup unavailable', 503);
      }
      final query = request.bodyFields['data']!;
      calls.add(query);
      return http.Response(jsonEncode({
        'elements': [
          {'type': 'node', 'id': 3, 'lat': 45.501, 'lon': -73.57,
            'tags': {'name': 'Local Grocery', 'shop': 'grocery'}},
        ],
      }), 200);
    }));
    final result = await locator.nearby(45.5, -73.57, searchRadiusKm: 30);
    expect(result.stores.single.name, 'Local Grocery');
    expect(result.requestedRadiusKm, 30);
    expect(result.searchedRadiusKm, 10);
    expect(result.isPartial, isTrue);
    expect(calls.where((q) => q.contains('around:30000,')), isEmpty);
    expect(calls.where((q) => q.contains('around:10000,')), hasLength(1));
    locator.dispose();
  });

  test('bad search radius is rejected without any directory request', () async {
    final locator = StoreLocator(client: MockClient((_) async {
      fail('No network request should occur for an invalid radius.');
    }));
    expect(() => locator.nearby(45.5, -73.57, searchRadiusKm: 100),
        throwsFormatException);
    locator.dispose();
  });

  test('Photon backup produces real in-app store rows when Overpass fails',
      () async {
    final hosts = <String>[];
    final locator = StoreLocator(client: MockClient((request) async {
      hosts.add(request.url.host);
      if (request.url.host != 'photon.komoot.io') {
        return http.Response('Server overloaded', 503);
      }
      expect(request.url.path, '/reverse');
      expect(request.url.queryParameters['radius'], '5');
      expect(request.url.queryParameters['include'],
          contains('osm.shop.supermarket'));
      return http.Response(jsonEncode({
        'features': [
          {
            'properties': {
              'osm_type': 'N', 'osm_id': 123,
              'osm_key': 'shop', 'osm_value': 'supermarket',
              'name': 'Local Grocery', 'street': 'Market Road',
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [-73.571, 45.501],
            },
          },
          {
            'properties': {
              'osm_type': 'N', 'osm_id': 124,
              'osm_key': 'shop', 'osm_value': 'supermarket',
              'name': 'Too Far Away',
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [-73.571, 46.2],
            },
          },
        ],
      }), 200);
    }));
    final result = await locator.nearby(
        45.5, -73.57, searchRadiusKm: 5);
    expect(hosts.last, 'photon.komoot.io');
    expect(result.provider, contains('Photon'));
    expect(result.stores.map((store) => store.name), ['Local Grocery']);
    expect(result.stores.single.address, contains('Market Road'));
    locator.dispose();
  });

  test('a 50 km request keeps its label when local stores are returned', () async {
    final queries = <String>[];
    final locator = StoreLocator(client: MockClient((request) async {
      if (request.url.host == 'photon.komoot.io') {
        return http.Response('Public map service busy', 503);
      }
      final query = request.bodyFields['data']!;
      queries.add(query);
      return http.Response(jsonEncode({
        'elements': [
          {'type': 'node', 'id': 50, 'lat': 45.501, 'lon': -73.57,
            'tags': {'name': 'Nearby Grocer', 'shop': 'supermarket'}},
        ],
      }), 200);
    }));
    final result = await locator.nearby(
        45.5, -73.57, ingredient: 'feta', searchRadiusKm: 50);
    expect(queries.where((q) => q.contains('around:50000,')), isEmpty);
    expect(result.stores.single.name, 'Nearby Grocer');
    expect(result.requestedRadiusKm, 50);
    expect(result.searchedRadiusKm, 10);
    expect(result.isPartial, isTrue);
    locator.dispose();
  });

  test('30 km Photon reverse search can return the full requested area', () async {
    final hosts = <String>[];
    final locator = StoreLocator(client: MockClient((request) async {
      hosts.add(request.url.host);
      expect(request.url.path, '/reverse');
      expect(request.url.queryParameters['radius'], '30');
      return http.Response(jsonEncode({
        'features': [
          {
            'properties': {
              'osm_type': 'N', 'osm_id': 777,
              'osm_key': 'shop', 'osm_value': 'supermarket',
              'name': 'City Food Market',
            },
            'geometry': {
              'type': 'Point', 'coordinates': [-73.57, 45.6],
            },
          },
        ],
      }), 200);
    }));
    final result = await locator.nearby(45.5, -73.57, searchRadiusKm: 30);
    expect(result.stores.single.name, 'City Food Market');
    expect(result.isPartial, isFalse);
    expect(hosts, ['photon.komoot.io']);
    locator.dispose();
  });

  test('a stalled public directory exits with a clear timeout', () async {
    final pendingResponse = Completer<http.Response>();
    final locator = StoreLocator(
      lookupTimeout: const Duration(milliseconds: 40),
      providerTimeout: const Duration(seconds: 3),
      overpassEndpoints: [Uri.parse('https://overpass.example/api/interpreter')],
      client: MockClient((_) => pendingResponse.future),
    );
    await expectLater(
      locator.nearby(45.5, -73.57, searchRadiusKm: 50),
      throwsA(isA<StateError>().having(
        (e) => e.message.toString(), 'error', contains('timed out'))),
    );
    locator.dispose();
  });
}
