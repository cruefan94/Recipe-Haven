import 'package:flutter_test/flutter_test.dart';
import 'package:rental_inspector_starter/inspection_checklist.dart';

void main() {
  test('unrated entries remain drafts', () {
    final summary = RoomChecklist.summarize(RoomChecklist.empty());
    expect(summary.complete, false);
    expect(summary.pending, RoomChecklist.areas.length);
  });
  test('condition issues and non-applicable values are counted correctly', () {
    final ratings = {for (final area in RoomChecklist.areas) area: 'Good'};
    ratings['Walls and paint'] = 'Needs attention';
    ratings['Plumbing'] = 'Not applicable';
    ratings['Floors'] = 'Fair';
    final summary = RoomChecklist.summarize(ratings);
    expect(summary.complete, true);
    expect(summary.issues, 1);
    expect(summary.fair, 1);
    expect(summary.notApplicable, 1);
    expect(summary.good, RoomChecklist.areas.length - 3);
  });
  test('unexpected rating is rejected', () {
    final ratings = RoomChecklist.empty();
    ratings['Floors'] = 'Excellent';
    expect(() => RoomChecklist.summarize(ratings), throwsFormatException);
  });
}
