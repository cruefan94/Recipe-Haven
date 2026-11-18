import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_app_foundation/android_app_foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'photo_review_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = OfflineRecordStore(databaseName: 'jobproof_records');
  runApp(FieldApp(
    brand: const AppBrand(
      name: 'JobProof', subtitle: 'Capture the work and keep it organized',
      primary: Color(0xFF26B6D7), background: Color(0xFF0B1B29),
      icon: Icons.photo_camera_outlined, brightness: Brightness.dark,
    ),
    features: [
      AppFeature(title: 'Capture before / after', icon: Icons.add_a_photo_outlined,
        builder: (_) => CapturePage(store: store)),
      AppFeature(title: 'Review before and after', icon: Icons.compare,
        builder: (_) => PhotoReviewPage(store: store)),
      AppFeature(title: 'Job photo gallery', icon: Icons.photo_library_outlined,
        builder: (_) => EvidenceGallery(store: store)),
    ],
  ));
}

class CapturePage extends StatefulWidget {
  const CapturePage({super.key, required this.store});
  final OfflineRecordStore store;
  @override State<CapturePage> createState() => _CapturePageState();
}
class _CapturePageState extends State<CapturePage> {
  final job = TextEditingController(), note = TextEditingController();
  String stage = 'Before';
  bool busy = false;
  @override void dispose() { job.dispose(); note.dispose(); super.dispose(); }

  Future<void> capture() async {
    if (busy) return;
    if (job.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter the job name before adding evidence.')));
      return;
    }
    setState(() => busy = true);
    File? saved;
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera,
        maxWidth: 2048, imageQuality: 82);
      if (picked == null) return;
      final root = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(root.path, 'evidence'));
      await dir.create(recursive: true);
      final id = 'photo_${DateTime.now().microsecondsSinceEpoch}';
      final ext = p.extension(picked.path).toLowerCase();
      final safeExt = ['.jpg', '.jpeg', '.png', '.webp'].contains(ext) ? ext : '.jpg';
      final filename = '$id$safeExt';
      saved = await File(picked.path).copy(p.join(dir.path, filename));
      await widget.store.save(WorkRecord(
        id: id, kind: 'photo', updatedAt: DateTime.now().toUtc(),
        data: {'job': job.text.trim(), 'stage': stage,
          'note': note.text.trim(), 'filename': filename},
      ));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo saved on this device.')));
    } catch (_) {
      if (saved != null && await saved.exists()) await saved.delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo was not saved. Please try again.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Capture job evidence')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: job, decoration: const InputDecoration(labelText: 'Job name')),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: stage, decoration: const InputDecoration(labelText: 'Stage'),
        items: const [
          DropdownMenuItem(value: 'Before', child: Text('Before')),
          DropdownMenuItem(value: 'During', child: Text('During')),
          DropdownMenuItem(value: 'After', child: Text('After')),
        ],
        onChanged: (v) { if (v != null) setState(() => stage = v); },
      ),
      const SizedBox(height: 14),
      TextField(controller: note, maxLines: 3,
        decoration: const InputDecoration(labelText: 'Photo note (optional)')),
      const SizedBox(height: 22),
      FilledButton.icon(onPressed: busy ? null : capture,
        icon: const Icon(Icons.camera_alt_outlined),
        label: Text(busy ? 'Saving…' : 'Take photo')),
    ])),
  );
}

class EvidenceGallery extends StatelessWidget {
  const EvidenceGallery({super.key, required this.store});
  final OfflineRecordStore store;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Job photo gallery')),
    body: FutureBuilder<List<WorkRecord>>(
      future: store.list('photo'),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Could not load evidence.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final records = snapshot.data!;
        if (records.isEmpty) return const Center(child: Text('No photos yet.'));
        return FutureBuilder<Directory>(
          future: getApplicationDocumentsDirectory(),
          builder: (context, docs) {
            if (!docs.hasData) return const Center(child: CircularProgressIndicator());
            return ListView.builder(itemCount: records.length, itemBuilder: (context, i) {
              final record = records[i], data = record.data;
              final file = File(p.join(docs.data!.path, 'evidence', data['filename'] as String));
              return Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.file(file, width: double.infinity, height: 190,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 70, child: Center(child: Text('Photo unavailable')))),
                  ListTile(title: Text(data['job']?.toString() ?? 'Job'),
                    subtitle: Text('${data['stage']} • ${data['note'] ?? ''}')),
                ]));
            });
          },
        );
      },
    ),
  );
}
