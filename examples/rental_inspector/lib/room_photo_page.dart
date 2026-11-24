import 'dart:io';
import 'package:android_app_foundation/android_app_foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class RoomPhotoPage extends StatefulWidget {
  const RoomPhotoPage({super.key, required this.store});
  final OfflineRecordStore store;
  @override State<RoomPhotoPage> createState() => _RoomPhotoPageState();
}

class _RoomPhotoPageState extends State<RoomPhotoPage> {
  final property = TextEditingController();
  final room = TextEditingController();
  final caption = TextEditingController();
  bool busy = false;
  @override void dispose() {
    property.dispose(); room.dispose(); caption.dispose();
    super.dispose();
  }
  void notify(String message) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(message)));

  Future<void> choose(ImageSource source) async {
    if (busy) return;
    if (property.text.trim().isEmpty || room.text.trim().isEmpty) {
      notify('Enter a property and room before adding a photo.');
      return;
    }
    setState(() => busy = true);
    File? copied;
    try {
      final picked = await ImagePicker().pickImage(
        source: source, maxWidth: 2048, imageQuality: 82);
      if (picked == null) return;
      final ext = p.extension(picked.path).toLowerCase();
      if (!['.jpg', '.jpeg', '.png'].contains(ext)) {
        notify('Choose a JPEG or PNG photograph.');
        return;
      }
      final directory = Directory(p.join(
        (await getApplicationDocumentsDirectory()).path, 'property_photos'));
      await directory.create(recursive: true);
      final id = 'roomphoto_' + DateTime.now().microsecondsSinceEpoch.toString();
      final filename = id + ext;
      copied = await File(picked.path).copy(p.join(directory.path, filename));
      await widget.store.save(WorkRecord(
        id: id, kind: 'room_photo',
        updatedAt: DateTime.now().toUtc(),
        data: {'property': property.text.trim(), 'room': room.text.trim(),
          'caption': caption.text.trim(), 'filename': filename},
      ));
      if (mounted) { notify('Room photo saved.'); caption.clear(); }
    } catch (_) {
      if (copied != null && await copied.exists()) {
        await copied.delete();
      }
      if (mounted) notify('Photo could not be saved.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Room photographs')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: property,
        decoration: const InputDecoration(labelText: 'Property name or address')),
      const SizedBox(height: 12),
      TextField(controller: room,
        decoration: const InputDecoration(labelText: 'Room or area')),
      const SizedBox(height: 12),
      TextField(controller: caption, maxLines: 3,
        decoration: const InputDecoration(labelText: 'Condition or damage notes')),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: busy ? null : () => choose(ImageSource.camera),
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Take inspection photo')),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: busy ? null : () => choose(ImageSource.gallery),
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Choose photo from gallery')),
    ])),
  );
}
