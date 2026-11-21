import 'package:android_app_foundation/android_app_foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_inspector/property_report.dart';

void main() {
  final records = [
    WorkRecord(id: 'a', kind: 'room_checklist',
      data: {'property': 'Apt A', 'room': 'Kitchen',
        'draft': true, 'summary': {'issues': 2}},
      updatedAt: DateTime.utc(2026)),
    WorkRecord(id: 'b', kind: 'room_checklist',
      data: {'property': 'Apt A', 'room': 'Living',
        'draft': false, 'summary': {'issues': 0}},
      updatedAt: DateTime.utc(2026)),
    WorkRecord(id: 'c', kind: 'room_checklist',
      data: {'property': 'Apt B', 'room': 'Hallway',
        'draft': false, 'summary': {'issues': 1}},
      updatedAt: DateTime.utc(2026)),
  ];
  test('separates properties and sums issues correctly', () {
    expect(PropertySummary.names(records), ['Apt A', 'Apt B']);
    final selected = PropertySummary.select(records, 'Apt A');
    expect(selected.length, 2);
    expect(PropertySummary.issues(selected), 2);
    expect(PropertySummary.incomplete(selected), 1);
  });
}
