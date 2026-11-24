import 'dart:io';
import 'package:android_app_foundation/android_app_foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'photo_index.dart';
import 'job_photo_report.dart';

/// Job-filtered photo timeline and latest before/after comparison.
class PhotoReviewPage extends StatefulWidget {
  const PhotoReviewPage({super.key, required this.store});
  final OfflineRecordStore store;
  @override State<PhotoReviewPage> createState() => _PhotoReviewPageState();
}

class _PhotoReviewPageState extends State<PhotoReviewPage> {
  String? selectedJob;
  late Future<List<WorkRecord>> photos;
  late Future<Directory> documents;

  @override void initState() {
    super.initState();
    photos = widget.store.list('photo');
    documents = getApplicationDocumentsDirectory();
  }

  void reload() => setState(() { photos = widget.store.list('photo'); });

  Widget preview(WorkRecord? record, Directory dir, {double height = 180}) {
    if (record == null) return SizedBox(height: height,
      child: const Center(child: Text('No photo for this stage')));
    final filename = record.data['filename'];
    if (filename is! String || !PhotoIndex.safeFilename(filename)) {
      return SizedBox(height: height,
        child: const Center(child: Text('Photo unavailable')));
    }
    final file = File(p.join(dir.path, 'evidence', filename));
    return Image.file(file, width: double.infinity, height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) =>
        SizedBox(height: height,
          child: const Center(child: Text('Photo unavailable'))));
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Photo review'),
      actions: [IconButton(tooltip: 'Refresh photos',
        icon: const Icon(Icons.refresh), onPressed: reload)]),
    body: FutureBuilder<List<WorkRecord>>(
      future: photos,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Could not load photos.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final all = snapshot.data!;
        final jobs = PhotoIndex.jobs(all);
        if (jobs.isEmpty) return const Center(child: Text('Take your first job photo.'));
        final job = jobs.contains(selectedJob) ? selectedJob! : jobs.first;
        final records = PhotoIndex.forJob(all, job);
        return FutureBuilder<Directory>(
          future: documents,
          builder: (context, folders) {
            if (folders.hasError) return const Center(child: Text('Photo storage unavailable.'));
            if (!folders.hasData) return const Center(child: CircularProgressIndicator());
            final root = folders.data!;
            return ListView(padding: const EdgeInsets.all(16), children: [
              DropdownButtonFormField<String>(
                initialValue: job,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Select job'),
                items: jobs.map((name) => DropdownMenuItem(value: name,
                  child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (value) { if (value != null) setState(() => selectedJob = value); },
              ),
              const SizedBox(height: 18),
              Text('Before and after',
                style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(children: [
                  const Text('Before'),
                  ClipRRect(borderRadius: BorderRadius.circular(10),
                    child: preview(PhotoIndex.latestStage(records, 'Before'), root)),
                ])),
                const SizedBox(width: 10),
                Expanded(child: Column(children: [
                  const Text('After'),
                  ClipRRect(borderRadius: BorderRadius.circular(10),
                    child: preview(PhotoIndex.latestStage(records, 'After'), root)),
                ])),
              ]),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await JobPhotoReport.share(job, records, root);
                  } catch (_) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not export photo report.')));
                  }
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Share job photo report'),
              ),
              const SizedBox(height: 22),
              Text('Photo timeline (' + records.length.toString() + ')',
                style: Theme.of(context).textTheme.titleLarge),
              for (final record in records)
                Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  preview(record, root, height: 160),
                  ListTile(
                    title: Text(record.data['stage']?.toString() ?? 'Photo'),
                    subtitle: Text(
                      (record.data['note']?.toString() ?? '') +
                      '\n' + record.updatedAt.toLocal().toString().split('.').first,
                    ),
                  ),
                ])),
            ]);
          },
        );
      },
    ),
  );
}
