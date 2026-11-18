import 'package:android_app_foundation/android_app_foundation.dart';
import 'package:flutter/material.dart';
import 'inspection_checklist.dart';

class GuidedInspectionPage extends StatefulWidget {
  const GuidedInspectionPage({super.key, required this.store, this.existing});
  final OfflineRecordStore store;
  final WorkRecord? existing;
  @override State<GuidedInspectionPage> createState() => _GuidedInspectionPageState();
}

class _GuidedInspectionPageState extends State<GuidedInspectionPage> {
  final property = TextEditingController(), room = TextEditingController(),
    notes = TextEditingController();
  String inspectionType = 'Move-in';
  Map<String, String> responses = RoomChecklist.empty();
  bool saving = false;
  static const inspectionTypes = ['Move-in', 'Move-out', 'Routine', 'Maintenance'];

  @override void initState() {
    super.initState();
    final previous = widget.existing?.data;
    if (previous == null) return;
    property.text = previous['property']?.toString() ?? '';
    room.text = previous['room']?.toString() ?? '';
    notes.text = previous['notes']?.toString() ?? '';
    final type = previous['inspectionType'];
    if (type is String && inspectionTypes.contains(type)) inspectionType = type;
    final saved = previous['ratings'];
    if (saved is Map) {
      for (final area in RoomChecklist.areas) {
        final rating = saved[area];
        if (rating is String && RoomChecklist.ratings.contains(rating)) {
          responses[area] = rating;
        }
      }
    }
  }

  @override void dispose() {
    property.dispose(); room.dispose(); notes.dispose();
    super.dispose();
  }
  void notify(String msg) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> save() async {
    if (saving) return;
    if (property.text.trim().isEmpty || room.text.trim().isEmpty) {
      notify('Enter both a property and room.');
      return;
    }
    final summary = RoomChecklist.summarize(responses);
    setState(() => saving = true);
    try {
      await widget.store.save(WorkRecord(
        id: widget.existing?.id ??
          'checklist_' + DateTime.now().microsecondsSinceEpoch.toString(),
        kind: 'room_checklist',
        updatedAt: DateTime.now().toUtc(),
        data: {
          'property': property.text.trim(), 'room': room.text.trim(),
          'inspectionType': inspectionType, 'ratings': Map<String, String>.from(responses),
          'notes': notes.text.trim(), 'summary': summary.toJson(),
          'draft': !summary.complete,
        },
      ));
      if (mounted) notify(summary.complete ?
        'Room checklist saved.' : 'Incomplete checklist saved as a draft.');
    } catch (_) {
      if (mounted) notify('Checklist could not be saved.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override Widget build(BuildContext context) {
    final summary = RoomChecklist.summarize(responses);
    return Scaffold(
      appBar: AppBar(title: const Text('Room inspection')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: property,
          decoration: const InputDecoration(labelText: 'Property')),
        const SizedBox(height: 12),
        TextField(controller: room,
          decoration: const InputDecoration(labelText: 'Room or area')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: inspectionType,
          decoration: const InputDecoration(labelText: 'Inspection type'),
          items: inspectionTypes.map((s) =>
            DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) { if (v != null) setState(() => inspectionType = v); },
        ),
        const SizedBox(height: 20),
        Text('Condition checklist', style: Theme.of(context).textTheme.titleLarge),
        Text(summary.completed.toString() + ' of ' +
          RoomChecklist.areas.length.toString() + ' rated'),
        const SizedBox(height: 12),
        for (final area in RoomChecklist.areas)
          Padding(padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              key: ValueKey(area),
              initialValue: responses[area],
              isExpanded: true,
              decoration: InputDecoration(labelText: area),
              items: RoomChecklist.ratings.map((rating) =>
                DropdownMenuItem(value: rating, child: Text(rating))).toList(),
              onChanged: (value) {
                if (value != null) setState(() => responses[area] = value);
              },
            )),
        TextField(controller: notes, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Notes or required repairs')),
        const SizedBox(height: 18),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(summary.issues.toString() + ' items need attention',
              style: Theme.of(context).textTheme.titleMedium),
            Text(summary.pending.toString() + ' items not yet checked'),
            if (!summary.complete) const Text('Save a draft to finish later.'),
          ],
        ))),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: saving ? null : save,
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? 'Saving…' :
            summary.complete ? 'Save inspection' : 'Save draft'),
        ),
      ])),
    );
  }
}

class ChecklistHistoryPage extends StatefulWidget {
  const ChecklistHistoryPage({super.key, required this.store});
  final OfflineRecordStore store;
  @override State<ChecklistHistoryPage> createState() => _ChecklistHistoryPageState();
}

class _ChecklistHistoryPageState extends State<ChecklistHistoryPage> {
  late Future<List<WorkRecord>> records;
  @override void initState() { super.initState(); refresh(); }
  void refresh() { records = widget.store.list('room_checklist'); }

  Future<void> edit(WorkRecord row) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => GuidedInspectionPage(store: widget.store, existing: row),
    ));
    if (mounted) setState(refresh);
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Room checklists'),
      actions: [IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh),
        onPressed: () => setState(refresh))]),
    body: FutureBuilder<List<WorkRecord>>(
      future: records,
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('Could not load checklists.'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snap.data!;
        if (rows.isEmpty) return const Center(child: Text('No saved checklists yet.'));
        return ListView.builder(itemCount: rows.length, itemBuilder: (context, i) {
          final data = rows[i].data;
          final summary = data['summary'];
          final s = summary is Map ? summary : <String, dynamic>{};
          return Card(child: ListTile(
            leading: Icon(data['draft'] == true ?
              Icons.edit_note_outlined : Icons.fact_check_outlined),
            title: Text(data['property'].toString() + ' • ' + data['room'].toString()),
            subtitle: Text(data['inspectionType'].toString() + ' • ' +
              (data['draft'] == true ? 'Draft' : 'Complete') + ' • ' +
              (s['issues'] ?? 0).toString() + ' need attention'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => edit(rows[i]),
          ));
        });
      },
    ),
  );
}
