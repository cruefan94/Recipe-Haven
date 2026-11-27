import 'package:flutter_test/flutter_test.dart';
import 'package:tradesman_pro_starter/estimate_math.dart';
void main() {
  test('exact CAD cents conversion', () {
    expect(EstimateMath.parseCents('12.30'), 1230);
    expect(EstimateMath.parseCents('12'), 1200);
    expect(() => EstimateMath.parseCents('1.234'), throwsFormatException);
  });
  test('overhead and markup calculation', () {
    expect(EstimateMath.totalCents(materialCents: 10000, labourCents: 10000,
      overheadPercent: 10, marginPercent: 20), 26400);
  });
}
