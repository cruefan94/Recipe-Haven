/// Build-time feature gate for Recipe Haven Android.
///
/// Professional is the safe default. Full has an additional separate,
/// password-protected personal collection. Both share the cooking tools.
class AppEdition {
  static const String name = String.fromEnvironment(
    'RECIPE_HAVEN_EDITION', defaultValue: 'professional',
  );

  static const bool includesPrivateCollection = name == 'full';
  static const bool isProfessional = !includesPrivateCollection;
}
