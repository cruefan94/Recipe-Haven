import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recipe_haven/services/store_locator.dart';

void main() {
  test('30 km lookup uses second current Overpass server after first fails', () async {
    final visited = <String>[];
    final client = MockClient((request) async {
      visited.add(request.url.host);
      expect(request.bodyFields['data'], contains('30000'));
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
    final result = await finder.nearby(45.5, -73.57, ingredient: 'Parmesan cheese');
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

  test('30 km directory outage returns clearly labelled 10 km fallback list', () async {
    final calls = <String>[];
    final locator = StoreLocator(client: MockClient((request) async {
      final query = request.bodyFields['data']!;
      calls.add(query);
      if (query.contains('around:30000,')) {
        return http.Response('Busy', 503);
      }
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
    expect(calls.where((q) => q.contains('around:30000,')), hasLength(3));
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

}
