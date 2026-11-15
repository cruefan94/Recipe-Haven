import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:recipe_haven/screens/home_screen.dart';
import 'package:recipe_haven/services/cookbook_store.dart';
import 'package:recipe_haven/services/shopping_list_store.dart';
import 'package:recipe_haven/services/private_cookbook_password.dart';

class _MemoryPreferences extends Fake implements SharedPreferencesAsync {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  testWidgets('private cookbook stays hidden until opened via Options', (tester) async {
    final prefs = _MemoryPreferences();
    final cookbook = CookbookStore(prefs);
    final shopping = ShoppingListStore(prefs);

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(cookbook: cookbook, shopping: shopping,
        privatePassword: PrivateCookbookPassword(preferences: prefs)),
    ));

    expect(find.text('Marijuana Cookbook'), findsNothing);
    expect(find.text('Marijuana'), findsNothing);

    // Options is available directly from the app bar, even when the
    // compact home-tool list is below the fold.
    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();

    expect(find.text('Private Cookbook'), findsOneWidget);
    expect(find.text('Marijuana Cookbook'), findsNothing);

    await tester.tap(find.text('Private Cookbook'));
    await tester.pumpAndSettle();
    expect(find.text('Set private cookbook password'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Marijuana Cookbook'), findsNothing);
  });
}
