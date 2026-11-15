# Recipe Haven

**One cooking app with two editions: Professional and Full.** Android is the active development platform. An iPhone version is planned for a later milestone.

| Edition | Purpose | Features | Android identity |
| --- | --- | --- | --- |
| **Recipe Haven Professional** | Everyday cooking, home kitchens, professional and workplace settings | Recipe search, offline recipes, personal cookbook, recipe import, pantry cooking, grocery list, ingredient finder, substitutions, JSON backup/restore | `com.cruefan94.recipe_haven` |
| **Recipe Haven Full** | All cooking tools plus an additional password-protected personal collection | Everything in Professional, with the optional separate cookbook and shopping list | `com.cruefan94.recipe_haven.full` |

The **Professional** app does **not show, unlock, navigate to, import, or export** Full-only collection entries. It makes no reference to that extra collection in its interface or everyday screens.

## Android build priority

**Next APK:** a fresh-install, permanently signed **Recipe Haven Professional Android test APK**. Full remains in shared source but is not the next downloadable APK.

Source and current Android build workflow live on the [Android development branch](https://github.com/cruefan94/Recipe-Haven/tree/feature/ingredient-products-and-cookbook-backup). The [Professional APK workflow](https://github.com/cruefan94/Recipe-Haven/actions) runs static analysis, tests, release-signs the Professional variant with the existing owner-managed signing key, verifies its package name and certificate, and uploads the installation artifact.

The two variants are separate Android package identities. They can coexist without sharing private storage. Preserve the existing permanent key and private backup. Device testing is required before describing a build as production-ready.

## What the app does

Recipe Haven supports finding recipes, 18 original offline recipes, adding or importing recipes, saving a cookbook, ingredient substitutions, cooking from pantry ingredients, offline shopping lists, adjustable-radius nearby store searches (2–50 km), and validated JSON backups. Retailer stock and prices are not verified without authorized live catalogues.

Professional will have no extra private-collection menu entry or prompts. Full retains a separate optional password-protected collection.

## Future iPhone support

Future iPhone builds will use the **same Recipe Haven branding** and two-edition model. The Flutter architecture and iOS preparation scripts remain in the development branch, but actual iPhone device testing, Apple signing, TestFlight, App Store review, and a signed IPA have not been completed.

The iPhone simulator workflow is **manual-only** and cannot produce an iPhone-installable IPA without Apple signing.

## Development status

Android Professional signing/build and user testing come first, followed by Full-edition distribution and later iPhone development. The default branch provides project coordination and manual workflows; the active source changes remain in a draft pull request until reviewed and tested.

**Current draft:** [Recipe Haven development PR #1](https://github.com/cruefan94/Recipe-Haven/pull/1).

Do not share keystore material or GitHub secret values. Recipe backups can contain personal information; keep them private.
