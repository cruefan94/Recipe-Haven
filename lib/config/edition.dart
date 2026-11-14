import 'package:flutter/foundation.dart';

/// Build-time edition selection. We intentionally ship only Mom & Dad on iOS.
enum RecipeHavenEdition { babe, momdad }

class EditionConfig {
  const EditionConfig._(this.edition);

  final RecipeHavenEdition edition;

  static const String definedEdition = String.fromEnvironment(
    'EDITION', defaultValue: 'momdad',
  );

  static EditionConfig resolve({String? editionName, TargetPlatform? platform}) {
    final raw = editionName ?? definedEdition;
    final edition = switch (raw) {
      'babe' => RecipeHavenEdition.babe,
      'momdad' => RecipeHavenEdition.momdad,
      _ => throw ArgumentError.value(raw, 'EDITION', 'Expected babe or momdad'),
    };
    if (platform == TargetPlatform.iOS && edition == RecipeHavenEdition.babe) {
      throw UnsupportedError('The Babe edition is Android-only. Build the Mom & Dad edition for iOS.');
    }
    return EditionConfig._(edition);
  }

  bool get isBabe => edition == RecipeHavenEdition.babe;
  bool get supportsIos => !isBabe;
  bool get hasMarijuanaCookbook => true;
  bool get hasIngredientFinder => true;
  String get welcomeTitle => isBabe ? 'made just for you babe 💛' : 'for mom and dad';
  String get appTitle => isBabe ? 'Recipe Haven 💛' : 'Recipe Haven — For Mom and Dad';
  String get welcomeSubtitle => isBabe
      ? 'A little place for everything delicious.'
      : 'All your favourite recipes, together in one place.';
}
