import 'package:android_app_foundation/android_app_foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobproof/photo_index.dart';

void main() {
  final records = [
    WorkRecord(id: '1', kind: 'photo', data: {'job': 'Cabin', 'stage': 'Before'},
      updatedAt: DateTime.utc(2026, 1, 1)),
    WorkRecord(id: '2', kind: 'photo', data: {'job': 'Cabin', 'stage': 'After'},
      updatedAt: DateTime.utc(2026, 1, 3)),
    WorkRecord(id: '3', kind: 'photo', data: {'job': 'Garage', 'stage': 'Before'},
      updatedAt: DateTime.utc(2026, 1, 2)),
  ];

  test('jobs stay independent and timeline is newest-first', () {
    expect(PhotoIndex.jobs(records), ['Cabin', 'Garage']);
    final cabin = PhotoIndex.forJob(records, 'Cabin');
    expect(cabin.map((e) => e.id).toList(), ['2', '1']);
    expect(PhotoIndex.latestStage(cabin, 'Before')?.id, '1');
    expect(PhotoIndex.latestStage(cabin, 'After')?.id, '2');
  });

  test('reject traversal or unrelated filenames', () {
    expect(PhotoIndex.safeFilename('photo_123.jpg'), true);
    expect(PhotoIndex.safeFilename('../photos/secret.jpg'), false);
    expect(PhotoIndex.safeFilename('unverified.jpg'), false);
  });
}
