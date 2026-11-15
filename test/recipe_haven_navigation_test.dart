import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_haven/screens/home_screen.dart';
import 'package:recipe_haven/services/cookbook_store.dart';
import 'package:recipe_haven/services/shopping_list_store.dart';
import 'package:recipe_haven/services/private_cookbook_password.dart';

class _Prefs extends Fake implements SharedPreferencesAsync {
  final values = <String, String>{};
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  testWidgets('Recipe Haven launches with one brand and direct kitchen tabs',
      (tester) async {
    final prefs = _Prefs();
    final cookbook = CookbookStore(prefs);
    final shopping = ShoppingListStore(prefs);
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        cookbook: cookbook,
        shopping: shopping,
        privatePassword: PrivateCookbookPassword(preferences: prefs),
      ),
    ));
    expect(find.text('Recipe Haven'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Find'), findsOneWidget);
    expect(find.text('Cookbook'), findsOneWidget);
    expect(find.text('Shopping'), findsOneWidget);
    expect(find.textContaining('Babe'), findsNothing);
    await tester.tap(find.text('Cookbook'));
    await tester.pumpAndSettle();
    expect(find.text('My Cookbook'), findsWidgets);
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    expect(find.text('Your Shopping List'), findsOneWidget);
  });
}
