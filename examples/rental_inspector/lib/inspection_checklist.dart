/// A structured room-by-room condition checklist, not a legal certification.
class RoomChecklist {
  static const areas = [
    'Walls and paint', 'Floors', 'Doors and windows',
    'Fixtures', 'Electrical outlets', 'Plumbing', 'Cleanliness',
  ];

  static const ratings = [
    'Not checked', 'Good', 'Fair', 'Needs attention', 'Not applicable',
  ];

  static Map<String, String> empty() => {
    for (final area in areas) area: 'Not checked',
  };

  static RoomSummary summarize(Map<String, String> responses) {
    if (responses.keys.toSet().difference(areas.toSet()).isNotEmpty ||
        responses.values.any((v) => !ratings.contains(v))) {
      throw const FormatException('Unrecognized checklist item or rating');
    }
    final missing = areas.where((area) =>
      !responses.containsKey(area) || responses[area] == 'Not checked').length;
    final issues = areas.where((area) =>
      responses[area] == 'Needs attention').length;
    final fair = areas.where((area) => responses[area] == 'Fair').length;
    final good = areas.where((area) => responses[area] == 'Good').length;
    final na = areas.where((area) => responses[area] == 'Not applicable').length;
    return RoomSummary(
      completed: areas.length - missing, pending: missing,
      issues: issues, fair: fair, good: good, notApplicable: na,
    );
  }
}

class RoomSummary {
  const RoomSummary({
    required this.completed, required this.pending, required this.issues,
    required this.fair, required this.good, required this.notApplicable,
  });
  final int completed, pending, issues, fair, good, notApplicable;
  bool get complete => pending == 0;
  Map<String, int> toJson() => {
    'completed': completed, 'pending': pending, 'issues': issues,
    'fair': fair, 'good': good, 'notApplicable': notApplicable,
  };
}
