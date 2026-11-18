import 'package:android_app_foundation/android_app_foundation.dart';

/// Indexes existing local photo records without uploading private job data.
class PhotoIndex {
  static List<String> jobs(List<WorkRecord> records) {
    final names = records.map((r) => r.data['job'])
      .whereType<String>().where((name) => name.trim().isNotEmpty).toSet().toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  static List<WorkRecord> forJob(List<WorkRecord> records, String job) {
    return records.where((record) => record.kind == 'photo' &&
      record.data['job'] == job).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static WorkRecord? latestStage(List<WorkRecord> records, String stage) {
    for (final record in records) {
      if (record.data['stage'] == stage) return record;
    }
    return null;
  }

  static bool safeFilename(String filename) =>
    RegExp(r'^photo_[0-9]+\.(jpg|jpeg|png|webp)$').hasMatch(filename);
}
