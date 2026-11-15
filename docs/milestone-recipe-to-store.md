# Milestone: Recipe → Shopping List → Find Ingredient / Substitute

**Milestone type:** integrated source development, not a release. Both Android editions and the For Mom and Dad iPhone edition share the Flutter screens and local persistence. Babe remains Android-only.

## Workflow

1. Browse or import a recipe in Find Recipes, Cook With What I Have, or My Cookbook.
2. Open Recipe Details. If ingredients are present, tap **Add ingredients to shopping list**. Each ingredient line is added separately with its original units, quantity, recipe title and collection. Repeating the same action for the same recipe does not duplicate the previously added lines.
3. Open **Shopping List** from Kitchen Home. Add manual groceries, check off purchased items, remove individual items, or clear checked items after confirmation. Count of remaining items is visible on the Home screen.
4. For a missing item, tap **Find nearby**. This preloads Find Ingredient, which requests the phone's location only when searching, then lists mapped grocery businesses within a 30 km straight-line radius; product prices are only shown if an authorized retailer feed supplies them.
5. Tap **Substitute** to open the offline Ingredient Alternatives reference. It displays contextual substitutes and reference quantities rather than inventing equivalence guarantees.
6. Tap **Copy to share** to copy unchecked shopping lines into another app, such as a private note or message.

## Data behavior

- Shopping items persist locally using SharedPreferencesAsync, under a separate key in each independently installed edition. They survive ordinary updates that retain the app data.
- Original recipe lines are not automatically aggregated: `1 cup milk` and `2 cups milk` remain distinct, because adding different units and servings without a conversion engine would be misleading.
- Ingredient rows have stable recipe ID + index identifiers to prevent repeated bulk imports from duplicating ingredients.
- Manual items have generated IDs; the shopping screen serializes writes and rolls back failed persistence.
- If stored shopping data is corrupt, source refuses to overwrite it and disables editing.
- The **existing Cookbook JSON backup still includes only recipes**. The shopping list is NOT in that file; use Copy to share before uninstalling, changing device, or transitioning from a debug-signed APK to a release-signed APK. A unified full-data backup remains future work.
- Checked shopping items stay on the list until manually removed or Clear checked is confirmed.
- No cloud sync or store catalog price verification is asserted.

## Source files

- lib/services/shopping_list_store.dart — persistent local shopping list, serialized writes and error protection.
- lib/screens/shopping_list_screen.dart — full shopping list UI with checkboxes, manual groceries, item shortcuts, and copy.
- lib/main.dart — loads shopping data at app startup.
- lib/screens/home_screen.dart — Shopping List card, remaining count, navigation and cross-screen callbacks.
- lib/screens/recipe_detail_screen.dart — bulk ingredient import from a recipe.
- lib/screens/pantry_cooking_screen.dart — shopping list remains available when opening recipes via pantry search.

## Known limits and next iteration

- No automatic inventory awareness, unit normalization or reliable product price/stock data without an authorized retailer integration.
- No file backup of shopping items, multi-device sync, grocery department sorting, collaborative editing or weekly meal planning yet.
- Source has **not** been compiled, analyzed, or tested in GitHub CI or on an Android/iPhone device since this change, following the user's instruction to skip testing.
- The last successful APKs on main remain unchanged and do not contain this source milestone. Do not merge or claim installability without a later verification milestone.
