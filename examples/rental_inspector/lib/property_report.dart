import 'dart:io';
import 'package:android_app_foundation/android_app_foundation.dart';
import 'package:path/path.dart' as p;

class PropertySummary {
  static List<String> names(List<WorkRecord> records) {
    final names = records.map((r) => r.data['property'])
      .whereType<String>().where((x) => x.trim().isNotEmpty)
      .toSet().toList()..sort();
    return names;
  }
  static List<WorkRecord> select(
    List<WorkRecord> records, String property) =>
    records.where((r) => r.data['property'] == property).toList();
  static int issues(List<WorkRecord> inspections) =>
    inspections.fold<int>(0, (count, item) {
      final summary = item.data['summary'];
      if (summary is Map && summary['issues'] is int) {
        return count + (summary['issues'] as int);
      }
      return count;
    });
  static int incomplete(List<WorkRecord> inspections) =>
    inspections.where((row) => row.data['draft'] == true).length;
}

class PropertyPdf {
  static Future<void> share({
    required String property,
    required List<WorkRecord> inspections,
    required List<WorkRecord> photos,
    required Directory documents,
  }) async {
    final sections = <ReportSection>[
      ReportSection('Property', [
        'Location: ' + property,
        'Rooms inspected: ' + inspections.length.toString(),
        'Incomplete room records: ' + PropertySummary.incomplete(inspections).toString(),
        'Items needing attention: ' + PropertySummary.issues(inspections).toString(),
      ]),
    ];
    for (final record in inspections) {
      final data = record.data;
      final lines = <String>[
        'Inspection: ' + (data['inspectionType']?.toString() ?? ''),
        'Status: ' + (data['draft'] == true ? 'Draft' : 'Completed checklist'),
        'Recorded: ' + record.updatedAt.toLocal().toString().split('.').first,
      ];
      final ratings = data['ratings'];
      if (ratings is Map) {
        for (final rating in ratings.entries) {
          lines.add(rating.key.toString() + ': ' + rating.value.toString());
        }
      } else {
        lines.add('Condition: ' + (data['condition']?.toString() ?? ''));
      }
      final note = data['notes']?.toString() ?? '';
      if (note.isNotEmpty) lines.add('Notes: ' + note);
      sections.add(ReportSection(data['room']?.toString() ?? 'Area', lines));
    }
    final pictures = <ReportPicture>[];
    for (final item in photos.take(20)) {
      final filename = item.data['filename'];
      if (filename is! String ||
          !RegExp(r'^roomphoto_[0-9]+\.(jpg|jpeg|png)$').hasMatch(filename)) {
        continue;
      }
      final file = File(p.join(documents.path, 'property_photos', filename));
      if (!await file.exists() || await file.length() > 6 * 1024 * 1024) continue;
      pictures.add(ReportPicture(
        (item.data['room']?.toString() ?? '') + ' - ' +
        (item.data['caption']?.toString() ?? ''),
        await file.readAsBytes(),
      ));
    }
    await BusinessPdf.share(
      filename: 'Rental-Property-Report.pdf',
      title: 'PROPERTY CONDITION REPORT',
      subtitle: property + ' - ' + DateTime.now().toLocal().toString().split('.').first,
      sections: sections,
      pictures: pictures,
    );
  }
}
