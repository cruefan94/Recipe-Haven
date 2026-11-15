import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:recipe_haven/screens/home_screen.dart';
import 'package:recipe_haven/services/cookbook_store.dart';
import 'package:recipe_haven/services/shopping_list_store.dart';

void main() {
  testWidgets('private cookbook stays hidden until opened via Options', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cookbook = CookbookStore(SharedPreferencesAsync());
    final shopping = ShoppingListStore(SharedPreferencesAsync());

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(cookbook: cookbook, shopping: shopping),
    ));

    expect(find.text('Marijuana Cookbook'), findsNothing);
    expect(find.text('Marijuana'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Options'), 250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Options'));
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
