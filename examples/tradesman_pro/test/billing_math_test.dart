import 'package:flutter_test/flutter_test.dart';
import 'package:tradesman_pro/billing_page.dart';

void main() {
  test('tax basis points and CAD cent rounding', () {
    expect(BillingMath.taxBasisPoints('13.00'), 1300);
    expect(BillingMath.taxAmount(10000, 1300), 1300);
    expect(BillingMath.taxAmount(101, 500), 5);
    expect(() => BillingMath.taxBasisPoints('101'), throwsFormatException);
    expect(() => BillingMath.taxBasisPoints('-3'), throwsFormatException);
  });
}
