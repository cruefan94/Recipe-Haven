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
}
