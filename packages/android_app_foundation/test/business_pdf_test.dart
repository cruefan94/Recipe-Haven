import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_app_foundation/business_pdf.dart';

void main() {
  test('creates a portable PDF from real record fields', () async {
    final bytes = await BusinessPdf.render(
      title: 'Job Summary',
      subtitle: 'Saved offline',
      sections: [const ReportSection('Cost', ['Total: 42.00 CAD'])],
    );
    expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(100));
  });
  test('rejects malformed empty report', () async {
    await expectLater(() => BusinessPdf.render(
      title: '', subtitle: '', sections: const []), throwsFormatException);
  });
}
