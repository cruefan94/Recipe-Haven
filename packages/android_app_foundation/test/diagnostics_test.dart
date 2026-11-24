import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_app_foundation/diagnostics.dart';

class RecordingDiagnosticSink implements DiagnosticSink {
  final payloads = <String>[];
  @override
  Future<void> send(String jsonPayload) async {
    payloads.add(jsonPayload);
  }
}

void main() {
  DiagnosticReport fakeCrash(Object error) => DiagnosticReport.fromException(
    app: DiagnosticApp.tradesmanPro,
    area: DiagnosticArea.invoices,
    event: DiagnosticEventKind.testCrash,
    exception: error,
    appVersion: '0.5.0+1',
    isTest: true,
    occurredAt: DateTime.utc(2026, 11, 24, 1, 0),
  );

  test('pre-beta crash test sends nothing when reporting is disabled', () async {
    final sink = RecordingDiagnosticSink();
    final report = fakeCrash(StateError('Private customer: Jane Smith'));
    final defaultReporter = DiagnosticReporter(sink: sink);
    expect(await defaultReporter.submit(report), isFalse);
    final noConsent = DiagnosticReporter(sink: sink, collectionEnabled: true);
    expect(await noConsent.submit(report), isFalse);
    expect(sink.payloads, isEmpty);
  });

  test('controlled exception arrives at test receiver with only approved fields', () async {
    final sink = RecordingDiagnosticSink();
    final reporter = DiagnosticReporter(
      sink: sink, collectionEnabled: true, userHasConsented: true,
    );

    // Intentionally throw as an automated test fixture, not a real customer crash.
    DiagnosticReport report;
    try {
      throw StateError('Customer Jane Smith, 123 Maple St, invoice INV-SECRET');
    } catch (error) {
      report = fakeCrash(error);
    }

    expect(await reporter.submit(report), isTrue);
    expect(sink.payloads, hasLength(1));
    final body = jsonDecode(sink.payloads.single) as Map<String, dynamic>;
    expect(body.keys.toSet(), {
      'schema', 'app', 'area', 'event', 'error_class',
      'app_version', 'test_event', 'occurred_at_utc',
    });
    expect(body['schema'], 1);
    expect(body['app'], 'tradesmanPro');
    expect(body['area'], 'invoices');
    expect(body['event'], 'testCrash');
    expect(body['error_class'], 'state');
    expect(body['app_version'], '0.5.0+1');
    expect(body['test_event'], isTrue);
    expect(body['occurred_at_utc'], '2026-11-24T01:00:00.000Z');
    for (final secret in ['Jane', 'Maple', 'INV-SECRET', 'Customer']) {
      expect(sink.payloads.single, isNot(contains(secret)));
    }
  });

  test('arbitrary version text cannot be smuggled into diagnostic payload', () {
    expect(
      () => DiagnosticReport(
        app: DiagnosticApp.tradesmanPro,
        area: DiagnosticArea.startup,
        event: DiagnosticEventKind.operationError,
        exceptionKind: DiagnosticExceptionKind.other,
        appVersion: '1.0.0 private notes: 123 Maple St',
        isTest: true,
        occurredAt: DateTime.utc(2026, 11, 24),
      ),
      throwsFormatException,
    );
  });

  test('known error categories do not transmit exception messages', () {
    expect(DiagnosticReport.classify(const FormatException('My private address')),
      DiagnosticExceptionKind.format);
    expect(DiagnosticReport.classify(RangeError(1234)),
      DiagnosticExceptionKind.range);
  });
}
