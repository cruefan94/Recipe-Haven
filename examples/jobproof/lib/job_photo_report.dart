import 'dart:io';
import 'package:android_app_foundation/android_app_foundation.dart';
import 'package:path/path.dart' as p;
import 'photo_index.dart';

/// User-initiated export; no server upload or claim of tamper-proof evidence.
class JobPhotoReport {
  static List<ReportSection> sections(String job, List<WorkRecord> records) => [
    ReportSection('Job', ['Project: ' + job, 'Photos: ' + records.length.toString()]),
    ReportSection('Recorded photographs', [
      for (final row in records)
        (row.data['stage']?.toString() ?? 'Photo') + ' - ' +
        row.updatedAt.toLocal().toString().split('.').first +
        ' - ' + (row.data['note']?.toString() ?? ''),
    ]),
  ];

  static Future<void> share(String job, List<WorkRecord> records, Directory docs) async {
    final photos = <ReportPicture>[];
    for (final row in records.take(24)) {
      final filename = row.data['filename'];
      if (filename is! String || !PhotoIndex.safeFilename(filename)) continue;
      final extension = p.extension(filename).toLowerCase();
      // PDF embedded images support JPEG and PNG. Retain other metadata in text.
      if (!['.jpg', '.jpeg', '.png'].contains(extension)) continue;
      final file = File(p.join(docs.path, 'evidence', filename));
      if (!await file.exists()) continue;
      if (await file.length() > 6 * 1024 * 1024) continue;
      photos.add(ReportPicture(
        (row.data['stage']?.toString() ?? 'Photo') + ': ' +
        (row.data['note']?.toString() ?? ''),
        await file.readAsBytes(),
      ));
    }
    await BusinessPdf.share(
      filename: 'JobProof-Photo-Report.pdf',
      title: 'JOB PHOTO REPORT',
      subtitle: job + ' - ' + DateTime.now().toLocal().toString().split('.').first,
      sections: sections(job, records),
      pictures: photos,
    );
  }
}
