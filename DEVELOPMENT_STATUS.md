# Recipe Haven — Android development status

**Updated:** 2026-11-15  
**Project coordination:** Cooking Haven main development hub  
**Repository:** `cruefan94/Recipe-Haven`  
**Development branch:** `feature/ingredient-products-and-cookbook-backup`  
**Open integration:** [Draft PR #1](https://github.com/cruefan94/Recipe-Haven/pull/1)

## Approved product scope

Recipe Haven is one cooking platform with two separate Android editions:

- **Professional** — Android launcher label **Recipe Haven**, package
  `com.cruefan94.recipe_haven`. Includes the everyday cooking features.
  No visible references, controls, backup messaging, or access points for the
  optional private cookbook.
- **Full** — launcher label **Recipe Haven Full**, package
  `com.cruefan94.recipe_haven.full`. Includes the Professional features,
  plus a separate password-protected cookbook and shopping list.

Do not restore earlier personalized edition branding. The editions have
independent Android application identities and private local app storage.
An iPhone version remains on the roadmap **after Android validation**.

## Features in the development source

- Online and 18 original offline recipes; recipe detail and saving.
- My Cookbook; manual recipe creation, URL import, and Android sharing.
- Pantry/ingredient cooking suggestions; ingredient substitutions.
- Grocery shopping list.
- All-in-one Kitchen Tools tab: cooking converter for US/metric volume, masses, oven temperatures, and a manual oven timer offering user-selected phone alarms, periodic progress reminders and overdue repeat notices. Timer state is stored across app restarts. Android may defer/mute alerts depending on notification permissions, exact alarm settings, and battery restrictions; direct oven control is not included.
- Find Ingredient: selectable **2, 5, 10, 20, 30, 50 km** radius;
  store directory results shown **inside the app** when available;
  fallback retailer searches and Maps links.
- JSON backup and restore with Professional import isolation.
- Separate Full-only private collection gated behind a user-made password.
- Material 3 Android layout with dedicated navigation and Options.

**Provider limitations:** Store directories and map links do not certify
retailer inventory, product pricing, or completeness. Public directories
can time out, have missing locations, or supply partial-radius results.

## Build verification

User-approved November 15 directive: produce **both Android editions** in every
new automatic test build, incorporating the latest ingredient-finder improvements.
The workflow now builds and separately uploads a Professional and a Full APK
from the same source, using the existing protected signing key and independent
package IDs. Both APK package names and signing certificates are validated by CI.

- `Recipe-Haven-Professional-Android-TEST` contains `Recipe-Haven-Professional-Android-TEST.apk`.
- `Recipe-Haven-Full-Android-TEST` contains `Recipe-Haven-Full-Android-TEST.apk`.

The most recently verified successful **Professional-only** build before this
workflow change was [run #71](https://github.com/cruefan94/Recipe-Haven/actions/runs/43767391150).
The first **two-edition** build must pass GitHub Actions before either newly
produced installer is described as available. Full requires phone validation
of the Options password flow and separate app data; Professional must have
no access to that collection. The ingredient-finder fix requires real-device
testing against public store providers. Neither build success nor mock tests
guarantee live store listings.

## Immediate Android acceptance checks

1. Install the latest signed Professional APK on the phone.
2. Confirm correct launcher name and no Full-only controls or labels anywhere.
3. Test recipe search, 18 offline recipes, saved recipes and manual/link import.
4. Test ingredient finder at 2 km, 10 km and 50 km with permission accepted;
   verify that in-app store rows appear if the directory has data, and that
   empty, partial and provider-outage states are understandable.
5. Test grocery checkoffs and export/import JSON, including invalid import.
6. Look for keyboard flicker, scrolling problems, clipping and Android back
   navigation. Retest after fixes.

## Future idea — dietary and preference filters (NOT IMPLEMENTED)

**Status:** Idea only, parked for later evaluation at the owner's request on 2026-11-23. Do **not** treat as a committed feature, a release promise, or authorization to implement.

Consider an optional **Filters** control beside the Find Recipes search field. For example, after entering "tacos," a person could select gluten-free, lactose-free, dairy-free, nut-free, vegetarian, vegan, no meat, other ingredient exclusions, and optional nutrition preferences (e.g. lower sodium). Tapping **Apply Filters** would narrow or prioritize the recipe results; a person could use filters once or save defaults. Show active filters clearly without adding UI clutter. Investigate reusing the same preferences in **Cook With What I Have**, shared by the Professional and Full editions.

Accessibility intent: easy for older and less technical cooks, no AI prompt required; a simple expandable options menu rather than a complex page.

Safety and feasibility before any implementation: ingredient/source metadata may be incomplete; lactose-free is not the same as dairy-free; do not imply that a recipe is guaranteed allergen-safe or cross-contact-free. Distinguish verified tags from estimated matches and missing data. Confirm whether recipe providers offer sufficient metadata, then test filter accuracy and usability.

## Next implementation priorities

- Verify the Kitchen Tools tab, conversion accuracy and Android timer notifications on physical devices (screen locked/background, permission denied, exact alarm denied, pause/resume and stop).
- Follow up on actual phone test observations, especially store availability
  and grocery-list UX.
- Preserve permanent Android signing key; do not regenerate or expose secrets.
- Keep Professional source and release output free of Full-only navigation.
- Continue professional UI refinement after functional validation.
- Build both signed APKs on the same development commit and phone-test each edition separately.
- Prepare iOS builds and TestFlight after the Android release is stable.

Older personalized-era documents in `docs/` are historical development
references, **not** the active product policy. This file and the README
supersede their prior edition names and release assumptions.
