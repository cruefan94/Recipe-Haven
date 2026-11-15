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

The latest confirmed successful signed Professional APK at this checkpoint is
GitHub Actions [run #66](https://github.com/cruefan94/Recipe-Haven/actions/runs/43764869438)
(2026-11-15). Flutter analysis, automated tests, release compilation,
package-ID verification, signing-certificate verification and artifact upload
all **passed**.

Artifact: `Recipe-Haven-Professional-Android-TEST` containing
`Recipe-Haven-Professional-Android-TEST.apk`.
This is a new-install Professional APK; subsequent same-package, same-key
versions can upgrade in place. **No phone install or hardware test is yet
claimed.** Full has not been released as the next APK.

A further automated widget regression test is being added for the radius
selector and visible nearby-store list. Newer workflow runs must be
independently checked before describing them as successful.

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

## Next implementation priorities

- Follow up on actual phone test observations, especially store availability
  and grocery-list UX.
- Preserve permanent Android signing key; do not regenerate or expose secrets.
- Keep Professional source and release output free of Full-only navigation.
- Continue professional UI refinement after functional validation.
- Release the separate Full APK only once Professional is validated.
- Prepare iOS builds and TestFlight after the Android release is stable.

Older personalized-era documents in `docs/` are historical development
references, **not** the active product policy. This file and the README
supersede their prior edition names and release assumptions.
