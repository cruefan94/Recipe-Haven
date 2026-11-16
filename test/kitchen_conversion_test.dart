import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_haven/services/kitchen_conversion.dart';

void main() {
  test('one US cup equals 16 US tablespoons', () {
    expect(KitchenConversion.convert(1, 'usCup', 'usTbsp'), closeTo(16, 1e-10));
  });
  test('metric cup is 250 ml and is distinct from US cup', () {
    expect(KitchenConversion.convert(1, 'metricCup', 'ml'), 250);
    expect(KitchenConversion.convert(1, 'usCup', 'ml'), closeTo(236.588, 0.001));
  });
  test('one pound equals 16 ounces', () {
    expect(KitchenConversion.convert(1, 'lb', 'oz'), closeTo(16, 1e-10));
  });
  test('oven temperature conversions work', () {
    expect(KitchenConversion.convert(350, 'f', 'c'), closeTo(176.667, 0.001));
    expect(KitchenConversion.convert(180, 'c', 'f'), 356);
  });
  test('does not invent density for dry ingredients', () {
    expect(() => KitchenConversion.convert(1, 'usCup', 'g'),
        throwsArgumentError);
  });
}
