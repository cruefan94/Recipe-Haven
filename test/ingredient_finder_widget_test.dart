import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recipe_haven/screens/ingredient_finder_screen.dart';
import 'package:recipe_haven/services/store_locator.dart';

void main() {
  testWidgets('selected radius produces an in-app list of nearby stores',
      (tester) async {
    final requestedQueries = <String>[];
    final locator = StoreLocator(
      overpassEndpoints: [Uri.parse('https://overpass.example/api/interpreter')],
      client: MockClient((request) async {
        if (request.url.host == 'photon.komoot.io') {
          expect(request.url.path, '/reverse');
          expect(request.url.queryParameters['radius'], '20');
          return http.Response('Public directory busy', 503);
        }
        requestedQueries.add(request.bodyFields['data']!);
        return http.Response(jsonEncode({
          'elements': [
            {
              'type': 'node',
              'id': 42,
              'lat': 45.501,
              'lon': -73.571,
              'tags': {
                'name': 'Test Grocery',
                'shop': 'supermarket',
                'addr:street': 'Market Street',
              },
            },
          ],
        }), 200);
      }),
    );
    final position = Position(
      longitude: -73.57,
      latitude: 45.5,
      timestamp: DateTime(2026),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 10,
      heading: 0,
      headingAccuracy: 10,
      speed: 0,
      speedAccuracy: 10,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IngredientFinderScreen(
          initialIngredient: 'flour',
          storeLocator: locator,
          positionProvider: () async => position,
        ),
      ),
    ));

    expect(find.text('Find stores within 10 km'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ingredient-search-radius')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20 km').last);
    await tester.pumpAndSettle();
    expect(find.text('Find stores within 20 km'), findsOneWidget);

    await tester.tap(find.text('Find stores within 20 km'));
    await tester.pumpAndSettle();
    expect(requestedQueries, hasLength(1));
    expect(requestedQueries.single, contains('around:10000,'));

    await tester.scrollUntilVisible(
      find.text('Nearby stores (1)'), 180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Nearby stores (1)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Test Grocery'), 180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Test Grocery'), findsOneWidget);
    // Local directory coverage is deliberately marked as partial rather
    // than presented as a complete 20 km result.
    expect(find.textContaining('Searched 10 km ·'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    locator.dispose();
  });
}
