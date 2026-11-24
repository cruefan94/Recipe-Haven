import 'dart:convert';

/// Closed vocabulary: never serialize exception messages, stack traces,
/// record contents, customer details, paths, identifiers or precise location.
enum DiagnosticApp { tradesmanPro, jobProof, rentalInspector, recipeHaven, blockChat }
enum DiagnosticArea {
  startup, navigation, estimates, invoices, jobs, customers, reports,
  storage, recipes, authentication, networking, unknown,
}
enum DiagnosticEventKind { testCrash, flutterError, asyncError, operationError }
enum DiagnosticExceptionKind {
  state, format, range, argument, type, other,
}

/// An intentionally sparse, privacy-reviewed candidate crash report.
///
/// No third-party SDK, HTTP service, or device identifier is wired here.
/// Any real receiver needs authentication, rate limits, TLS, retention and a
/// separate consent/privacy review before beta enrollment.
class DiagnosticReport {
  DiagnosticReport({
    required this.app,
    required this.area,
    required this.event,
    required this.exceptionKind,
    required this.appVersion,
    required this.isTest,
    required DateTime occurredAt,
  }) : occurredAt = occurredAt.toUtc() {
    if (!RegExp(r'^\\d{1,4}\\.\\d{1,4}\\.\\d{1,4}(?:\\+\\d{1,8})?\$')
        .hasMatch(appVersion)) {
      throw const FormatException('Invalid app version');
    }
  }

  final DiagnosticApp app;
  final DiagnosticArea area;
  final DiagnosticEventKind event;
  final DiagnosticExceptionKind exceptionKind;
  final String appVersion;
  final bool isTest;
  final DateTime occurredAt;

  static DiagnosticExceptionKind classify(Object exception) {
    if (exception is StateError) return DiagnosticExceptionKind.state;
    if (exception is FormatException) return DiagnosticExceptionKind.format;
    if (exception is RangeError) return DiagnosticExceptionKind.range;
    if (exception is ArgumentError) return DiagnosticExceptionKind.argument;
    if (exception is TypeError) return DiagnosticExceptionKind.type;
    return DiagnosticExceptionKind.other;
  }

  factory DiagnosticReport.fromException({
    required DiagnosticApp app,
    required DiagnosticArea area,
    required DiagnosticEventKind event,
    required String appVersion,
    required Object exception,
    required bool isTest,
    DateTime? occurredAt,
  }) => DiagnosticReport(
    app: app, area: area, event: event,
    exceptionKind: classify(exception), appVersion: appVersion,
    isTest: isTest, occurredAt: occurredAt ?? DateTime.now().toUtc(),
  );

  /// This is the entire allowed wire format; no arbitrary metadata map.
  Map<String, Object> toJson() => {
    'schema': 1,
    'app': app.name,
    'area': area.name,
    'event': event.name,
    'error_class': exceptionKind.name,
    'app_version': appVersion,
    'test_event': isTest,
    'occurred_at_utc': occurredAt.toIso8601String(),
  };

  String encode() => jsonEncode(toJson());
}

/// A replaceable receiver. In tests use an in-memory sink; production network
/// transport must not be added until privacy, consent and security gates pass.
abstract class DiagnosticSink {
  Future<void> send(String jsonPayload);
}

class DiagnosticReporter {
  const DiagnosticReporter({
    required this.sink,
    this.collectionEnabled = false,
    this.userHasConsented = false,
  });

  final DiagnosticSink sink;
  final bool collectionEnabled;
  final bool userHasConsented;

  /// Default deny: sends nothing unless both explicit gates are enabled.
  Future<bool> submit(DiagnosticReport report) async {
    if (!collectionEnabled || !userHasConsented) return false;
    await sink.send(report.encode());
    return true;
  }
}
