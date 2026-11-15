# Cook With What I Have — ingredient-based recipe discovery

This feature is available in **both Recipe Haven editions**. From Kitchen Home, open **Cook With What I Have**, enter up to three ingredients separated by commas (example: `chicken, rice, garlic`), and choose **Find meals I can make**.

## How results are assembled

1. The app first scans saved **My Cookbook** recipe ingredients locally. These results work offline and do not require location access. Link-only recipes without ingredient lists are not ranked.
2. It queries TheMealDB's *free V1 single-ingredient filter* separately for each term (the free API does **not** support combined ingredient filtering).
3. IDs from those results are ranked by frequency across the individual searches. The app requests full recipe details for at most **12** shortlisted meals in batches of three.
4. Recipes with ingredient overlap are sorted by the number of typed ingredients found in the full list. The result displays a **matched X of Y** label and the matching ingredient names, but does not claim the meal can be prepared without more ingredients.

Sources are capped to avoid unrestricted public-API requests. Search may miss recipes, miss synonyms, or fail when providers are unavailable. Results are suggestions—not complete nutritional, dietary, allergy, or pantry verification.

## Limitations and future production requirements

- TheMealDB documentation: https://www.themealdb.com/docs_api_guide.php
- TheMealDB terms: https://www.themealdb.com/terms_of_use.php
- Developer test key `1` is for development and personal testing. **TheMealDB requires a supporter/commercial subscription to publish an app using its API to an app store.** Before publication obtain and configure a permitted production key, display required attribution, and review image/content rights and any applicable rate limits.
- Premium TheMealDB V2 offers multi-ingredient filters, but this implementation intentionally uses separate V1 calls and local overlap ranking; it does not pretend to use premium functionality.
- Offline suggestions use saved cookbook recipes with full ingredient lists. Saving a link alone does not enable offline ingredient matching.
- Input is limited to three short ingredient names; full shopping-list support may be added separately.
- Ingredient wording is not a reliable allergy or dietary verification mechanism.

## Engineering status

Source files: `lib/services/recipe_search_service.dart`, `lib/screens/pantry_cooking_screen.dart`, and `lib/screens/home_screen.dart`. The development branch remains **uncompiled and untested by user request**, and previous APK artifacts from `main` do not include this feature. Nothing is represented as production-ready.
