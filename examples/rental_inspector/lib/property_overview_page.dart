import 'dart:io';
import 'package:android_app_foundation/android_app_foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'property_report.dart';

class PropertyOverviewPage extends StatefulWidget {
  const PropertyOverviewPage({super.key, required this.store});
  final OfflineRecordStore store;
  @override State<PropertyOverviewPage> createState() => _PropertyOverviewPageState();
}

class _PropertyOverviewPageState extends State<PropertyOverviewPage> {
  late Future<List<List<WorkRecord>>> all;
  late Future<Directory> documents;
  String? selectedProperty;

  Future<List<List<WorkRecord>>> load() async => Future.wait([
    widget.store.list('room_checklist'),
    widget.store.list('condition'),
    widget.store.list('room_photo'),
  ]);
  @override void initState() {
    super.initState();
    all = load();
    documents = getApplicationDocumentsDirectory();
  }
  void reload() => setState(() => all = load());
  void notify(String message) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(message)));

  Future<void> share(String name, List<WorkRecord> inspections,
      List<WorkRecord> pictures) async {
    try {
      final docs = await documents;
      await PropertyPdf.share(
        property: name, inspections: inspections, photos: pictures,
        documents: docs);
    } catch (_) { if (mounted) notify('Could not export property report.'); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Properties'),
      actions: [IconButton(icon: const Icon(Icons.refresh),
        tooltip: 'Refresh', onPressed: reload)]),
    body: FutureBuilder<List<List<WorkRecord>>>(
      future: all, builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('Could not load properties.'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final entries = snap.data!;
        final inspections = [...entries[0], ...entries[1]];
        final pictures = entries[2];
        final names = PropertySummary.names([...inspections, ...pictures]);
        if (names.isEmpty) return const Center(
          child: Text('Save an inspection to start a property record.'));
        final name = names.contains(selectedProperty) ?
          selectedProperty! : names.first;
        final current = PropertySummary.select(inspections, name);
        final images = PropertySummary.select(pictures, name);
        return ListView(padding: const EdgeInsets.all(16), children: [
          DropdownButtonFormField<String>(
            isExpanded: true, initialValue: name,
            decoration: const InputDecoration(labelText: 'Property'),
            items: names.map((n) => DropdownMenuItem(value: n,
              child: Text(n, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => selectedProperty = v);
            },
          ),
          const SizedBox(height: 18),
          Text('Property summary', style: Theme.of(context).textTheme.titleLarge),
          Card(child: Padding(padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Room records: ' + current.length.toString()),
              Text('Unfinished checklists: ' +
                PropertySummary.incomplete(current).toString()),
              Text('Items needing attention: ' +
                PropertySummary.issues(current).toString()),
              Text('Attached photographs: ' + images.length.toString()),
            ]),
          )),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: current.isEmpty && images.isEmpty ?
              null : () => share(name, current, images),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Share property report'),
          ),
          const SizedBox(height: 16),
          Text('Inspection history', style: Theme.of(context).textTheme.titleMedium),
          for (final row in current)
            Card(child: ListTile(
              leading: Icon(row.data['draft'] == true ?
                Icons.edit_note : Icons.checklist),
              title: Text(row.data['room']?.toString() ?? 'Area'),
              subtitle: Text((row.data['inspectionType']?.toString() ?? '') +
                ' - ' + (row.data['draft'] == true ? 'Draft' : 'Saved')),
              trailing: Text(row.updatedAt.toLocal().toString().split(' ').first),
            )),
          const SizedBox(height: 16),
          Text('Property photos', style: Theme.of(context).textTheme.titleMedium),
          FutureBuilder<Directory>(future: documents, builder: (context, dir) {
            if (!dir.hasData) return const LinearProgressIndicator();
            return GridView.count(
              crossAxisCount: 2, childAspectRatio: 0.85,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true, mainAxisSpacing: 10, crossAxisSpacing: 10,
              children: [
                for (final row in images.take(40))
                  Card(child: Column(children: [
                    Expanded(child: Builder(builder: (context) {
                      final filename = row.data['filename']?.toString() ?? '';
                      if (!RegExp(r'^roomphoto_[0-9]+\.(jpg|jpeg|png)$')
                          .hasMatch(filename)) {
                        return const Center(child: Text('Unavailable image'));
                      }
                      return Image.file(File(p.join(
                        dir.data!.path, 'property_photos', filename)),
                        width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                          const Center(child: Text('Photo unavailable')));
                    })),
                    Padding(padding: const EdgeInsets.all(7),
                      child: Text((row.data['room']?.toString() ?? '') +
                        ': ' + (row.data['caption']?.toString() ?? ''),
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ])),
              ],
            );
          }),
        ]);
      },
    ),
  );
}
