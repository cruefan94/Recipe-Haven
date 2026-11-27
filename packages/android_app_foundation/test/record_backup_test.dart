import 'package:flutter_test/flutter_test.dart';
import 'package:android_app_foundation/android_app_foundation.dart';

void main() {
  test('record backup round trips', () {
    final input = WorkRecord(
      id: 'job-1',
      kind: 'estimate',
      data: {'customer': 'Sample', 'totalCents': 123456},
      updatedAt: DateTime.utc(2026, 11, 18),
    );
    final restored = RecordBackupCodec.decode(RecordBackupCodec.encode([input]));
    expect(restored.single.data['totalCents'], 123456);
  });
  test('reject unrelated and malformed backups', () {
    expect(() => RecordBackupCodec.decode('{"format":"recipe-haven-kitchen","version":1,"records":[]}'),
      throwsFormatException);
    expect(() => RecordBackupCodec.decode('{"format":"android-business-records","version":1,"records":[{"id":""}]}'),
      throwsFormatException);
  });
  test('reject duplicate record identities', () {
    final r = WorkRecord(id: 'same', kind: 'inspection', data: {},
      updatedAt: DateTime.utc(2026));
    final raw = RecordBackupCodec.encode([r, r]);
    expect(() => RecordBackupCodec.decode(raw), throwsFormatException);
  });
}
