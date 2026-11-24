import 'package:flutter_test/flutter_test.dart';
import 'package:android_app_foundation/android_app_foundation.dart';
import 'package:tradesman_pro/billing_page.dart';

void main() {
  test('duplicate invoice guard matches only invoices for the same estimate', () {
    WorkRecord record(String id, String quoteId, {String kind = 'invoice'}) =>
      WorkRecord(
        id: id, kind: kind, updatedAt: DateTime.utc(2026, 11, 24),
        data: {'quoteId': quoteId},
      );
    final invoices = [
      record('invoice_a', 'estimate_a'),
      record('other_type', 'estimate_b', kind: 'estimate'),
    ];
    expect(BillingMath.alreadyInvoiced(<WorkRecord>[], 'estimate_a'), isFalse);
    expect(BillingMath.alreadyInvoiced(invoices, 'estimate_a'), isTrue);
    expect(BillingMath.alreadyInvoiced(invoices, 'estimate_b'), isFalse);
    expect(BillingMath.alreadyInvoiced(invoices, 'estimate_c'), isFalse);
  });

  test('tax basis points and CAD cent rounding', () {
    expect(BillingMath.taxBasisPoints('13.00'), 1300);
    expect(BillingMath.taxAmount(10000, 1300), 1300);
    expect(BillingMath.taxAmount(101, 500), 5);
    expect(() => BillingMath.taxBasisPoints('101'), throwsFormatException);
    expect(() => BillingMath.taxBasisPoints('-3'), throwsFormatException);
  });
}
