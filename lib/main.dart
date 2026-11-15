import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/cookbook_store.dart';
import 'services/shopping_list_store.dart';
import 'services/incoming_recipe_share.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cookbook = await CookbookStore.load();
  final shopping = await ShoppingListStore.load();
  // A shared browser link is queued until the user opens Add Recipe.
  // iOS ignores this Android-only bridge.
  await IncomingRecipeShare.instance.initialize();
  runApp(RecipeHavenApp(cookbook: cookbook, shopping: shopping));
}

class RecipeHavenApp extends StatelessWidget {
  const RecipeHavenApp({super.key, required this.cookbook, required this.shopping});
  final CookbookStore cookbook;
  final ShoppingListStore shopping;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recipe Haven',
      debugShowCheckedModeBanner: false,
      theme: _recipeHavenTheme(),
      // Open directly to the kitchen; no edition-selection or welcome gate.
      home: HomeScreen(cookbook: cookbook, shopping: shopping),
    );
  }
}


/// Consistent, accessible dark design shared across the Android screens.
ThemeData _recipeHavenTheme() {
  const background = Color(0xFF0F151D);
  const card = Color(0xFF192430);
  const input = Color(0xFF202D3B);
  const foreground = Color(0xFFF7F3EF);
  const quiet = Color(0xFFB9C3CD);
  const accent = Color(0xFFF1B97E);
  const outline = Color(0xFF344452);
  final colors = ColorScheme.fromSeed(
    seedColor: accent, brightness: Brightness.dark,
  ).copyWith(
    primary: accent,
    onPrimary: const Color(0xFF392512),
    surface: background,
    onSurface: foreground,
    onSurfaceVariant: quiet,
    surfaceContainer: card,
    surfaceContainerHigh: input,
    outline: outline,
    outlineVariant: outline,
  );
  final corners = BorderRadius.circular(15);
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: foreground,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: foreground, fontSize: 21,
        fontWeight: FontWeight.w700, letterSpacing: -0.35,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: outline, width: 0.7),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: input,
      border: OutlineInputBorder(
        borderRadius: corners,
        borderSide: const BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: corners,
        borderSide: const BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: corners,
        borderSide: const BorderSide(color: accent, width: 1.7),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: corners),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(
          borderRadius: corners,
          side: const BorderSide(color: outline),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: card,
      indicatorColor: accent.withAlpha(38),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: input,
      contentTextStyle: const TextStyle(color: foreground),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
