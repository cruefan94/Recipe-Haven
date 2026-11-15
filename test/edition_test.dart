import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_haven/config/edition.dart';

void main() {
  test('Android legacy build selector presents unified Recipe Haven', () {
    final babe = EditionConfig.resolve(
      editionName: 'babe', platform: TargetPlatform.android,
    );
    expect(babe.isBabe, isTrue);
    expect(babe.welcomeTitle, 'Recipe Haven');
    expect(babe.appTitle, 'Recipe Haven');
    expect(babe.supportsIos, isFalse);
    expect(babe.hasMarijuanaCookbook, isTrue);
    expect(babe.hasIngredientFinder, isTrue);
    expect(() => EditionConfig.resolve(
      editionName: 'babe', platform: TargetPlatform.iOS,
    ), throwsUnsupportedError);
  });

  test('Mom and Dad supports iOS and Android and matches Babe features', () {
    final ios = EditionConfig.resolve(
      editionName: 'momdad', platform: TargetPlatform.iOS,
    );
    final android = EditionConfig.resolve(
      editionName: 'momdad', platform: TargetPlatform.android,
    );
    expect(ios.welcomeTitle, 'for mom and dad');
    expect(ios.supportsIos, isTrue);
    expect(android.supportsIos, isTrue);
    expect(ios.hasMarijuanaCookbook, isTrue);
    expect(ios.hasIngredientFinder, isTrue);
  });

  test('unknown edition must not silently become another edition', () {
    expect(() => EditionConfig.resolve(
      editionName: 'other', platform: TargetPlatform.android,
    ), throwsArgumentError);
  });
}
