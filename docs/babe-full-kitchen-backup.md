# Babe Android — Full Kitchen Backup

## Milestone

Babe now supports a single portable **full kitchen JSON backup** covering:
- My Cookbook and the separate Marijuana Cookbook (including source links, ingredients and instructions).
- Shopping List item text, source recipe, and checked/purchased state.

**Backup & Restore → Save Full Kitchen Backup** writes a JSON file with a system file chooser. **Import Kitchen Backup File** merges entries, preserving those already on the phone. A clipboard fallback remains available for smaller collections.

## Legacy compatibility and safety

- Current full backup format: `recipe-haven-kitchen`, version 1.
- Older `recipe-haven-cookbook`, version 1 JSON files can still be imported; they contain no groceries.
- A full backup is validated completely before any import begins. Recipes merge by ID first, then groceries merge by ID, rather than overwriting the local collection.
- If the shopping-list write fails after recipe persistence, the app displays a **partial import** message. Retry the same backup to add the remaining items; existing recipe IDs will be skipped.
- If a store reports unreadable data, full export/import is blocked to avoid destroying or masking previous local data.
- Backups are limited to 8 MB, 5,000 recipes and 1,000 shopping items.
- The file can contain personally sensitive recipe notes and adult-use items. Keep it private.
- Backups do **not** continuously synchronize devices.

## Installing Babe Stable without removing the original app

The debug-signed Babe APK and future Babe Stable have different Android package IDs. Android stores their data separately, and different signing certificates prevent a direct APK update.

1. Leave your original Babe installation intact.
2. In the original app, export a Full Kitchen Backup (if supported). For an older app, export the previous cookbook-only backup and separately copy your shopping list as text.
3. Install Babe Stable alongside the old app, once a permanently signed Stable APK has been produced.
4. Import the JSON in the new app, verify recipes and groceries, and keep the original installation until satisfied.
5. Later Stable releases can update in place when signed with the same permanent key and a higher version code.

A permanently signed Stable APK **has not been produced** because repository signing secrets still need to be configured.

## Source and checks

Source: `lib/services/kitchen_backup_service.dart`, `lib/services/shopping_list_store.dart`, `lib/screens/home_screen.dart`.

Automated codec/regression tests: `test/kitchen_backup_test.dart`. These do not substitute for a full on-phone import and update test.
