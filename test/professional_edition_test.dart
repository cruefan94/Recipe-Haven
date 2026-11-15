import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_haven/screens/home_screen.dart';
import 'package:recipe_haven/services/cookbook_store.dart';
import 'package:recipe_haven/services/shopping_list_store.dart';
import 'package:recipe_haven/services/private_cookbook_password.dart';

class _MemoryPreferences extends Fake implements SharedPreferencesAsync {
  final values = <String, String>{};
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async { values[key] = value; }
}

void main() {
  testWidgets('Professional home and Options contain no restricted collection',
      (tester) async {
    final prefs = _MemoryPreferences();
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        cookbook: CookbookStore(prefs), shopping: ShoppingListStore(prefs),
        privatePassword: PrivateCookbookPassword(preferences: prefs),
        includePrivateCollection: false,
      ),
    ));

    expect(find.textContaining('Marijuana', skipOffstage: false), findsNothing);
    expect(find.text('Private Cookbook', skipOffstage: false), findsNothing);

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    expect(find.text('Backup & Restore'), findsWidgets);
    expect(find.text('Private Cookbook'), findsNothing);
    expect(find.textContaining('Marijuana', skipOffstage: false), findsNothing);

    await tester.tap(find.text('Backup & Restore').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('private password'), findsNothing);
    expect(find.textContaining('Marijuana', skipOffstage: false), findsNothing);
  });
}
