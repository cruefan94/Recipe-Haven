import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'config/edition.dart';
import 'screens/home_screen.dart';
import 'services/cookbook_store.dart';
import 'services/shopping_list_store.dart';
import 'services/incoming_recipe_share.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final edition = EditionConfig.resolve(platform: defaultTargetPlatform);
  final cookbook = await CookbookStore.load();
  final shopping = await ShoppingListStore.load();
  // A shared browser link is queued until the user opens Add Recipe.
  // iOS ignores this Android-only bridge.
  await IncomingRecipeShare.instance.initialize();
  runApp(RecipeHavenApp(cookbook: cookbook, shopping: shopping, edition: edition));
}

class RecipeHavenApp extends StatelessWidget {
  const RecipeHavenApp({super.key, required this.cookbook, required this.shopping, required this.edition});
  final CookbookStore cookbook;
  final ShoppingListStore shopping;
  final EditionConfig edition;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: edition.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFA638), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF0B1018),
        cardTheme: const CardThemeData(elevation: 0, color: Color(0xFF18212D)),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF18212D),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: RecipeHavenWelcomeScreen(cookbook: cookbook, shopping: shopping, edition: edition),
    );
  }
}

/// Both versions have their own title screen but share every cooking feature.
class RecipeHavenWelcomeScreen extends StatelessWidget {
  const RecipeHavenWelcomeScreen({
    super.key, required this.cookbook, required this.shopping, required this.edition,
  });
  final CookbookStore cookbook;
  final ShoppingListStore shopping;
  final EditionConfig edition;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.menu_book_rounded, size: 90, color: Color(0xFFFFA638)),
              const SizedBox(height: 28),
              Text(edition.welcomeTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 18),
              Text(edition.welcomeSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute<void>(
                  builder: (_) => HomeScreen(cookbook: cookbook, shopping: shopping),
                )),
                icon: Icon(edition.isBabe ? Icons.favorite_outline : Icons.restaurant_menu),
                label: const Text('Start cooking'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
