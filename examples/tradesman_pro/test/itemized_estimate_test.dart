import 'package:flutter_test/flutter_test.dart';
import 'package:tradesman_pro/itemized_estimate.dart';

void main() {
  test('cent-exact line totals and overhead/markup', () {
    final line = EstimateLine('Foam', 12550, 175, 'board ft');
    expect(line.totalCents, 21963);
    expect(ItemizedEstimate.money(line.totalCents), '219.63');
    expect(ItemizedEstimate.total([line], 10, 20), 28991);
  });
  test('quantity and amount validation', () {
    expect(ItemizedEstimate.parseHundredths('1.25'), 125);
    expect(ItemizedEstimate.parseHundredths('0', allowZero: true), 0);
    expect(() => ItemizedEstimate.parseHundredths('0'), throwsFormatException);
    expect(() => ItemizedEstimate.parseHundredths('1.234'), throwsFormatException);
    expect(() => ItemizedEstimate.total([], 0, 0), throwsFormatException);
  });
}
