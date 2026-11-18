import 'package:android_app_foundation/android_app_foundation.dart';
import 'package:flutter/material.dart';
import 'guided_inspection_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final records = OfflineRecordStore(databaseName: 'rental_inspections');
  runApp(FieldApp(
    brand: const AppBrand(
      name: 'Rental Inspector', subtitle: 'Every property, clearly documented',
      primary: Color(0xFF48A06C), background: Color(0xFFF5F8F4),
      icon: Icons.home_work_outlined,
    ),
    features: [
      AppFeature(title: 'Guided room checklist', icon: Icons.fact_check_outlined,
        builder: (_) => GuidedInspectionPage(store: records)),
      AppFeature(title: 'Saved room checklists', icon: Icons.list_alt_outlined,
        builder: (_) => ChecklistHistoryPage(store: records)),
      AppFeature(title: 'Quick condition entry', icon: Icons.fact_check_outlined,
        builder: (_) => InspectionPage(records: records)),
      AppFeature(title: 'Inspection history', icon: Icons.history_outlined,
        builder: (_) => InspectionHistory(records: records)),
    ],
  ));
}

class InspectionPage extends StatefulWidget {
  const InspectionPage({super.key, required this.records});
  final OfflineRecordStore records;
  @override State<InspectionPage> createState() => _InspectionPageState();
}
class _InspectionPageState extends State<InspectionPage> {
  final property = TextEditingController(), room = TextEditingController(),
    notes = TextEditingController();
  String condition = 'Good', inspectionType = 'Move-in';
  bool saving = false;
  @override void dispose() {
    property.dispose(); room.dispose(); notes.dispose(); super.dispose();
  }
  Future<void> save() async {
    if (saving) return;
    if (property.text.trim().isEmpty || room.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a property and room.')));
      return;
    }
    setState(() => saving = true);
    try {
      await widget.records.save(WorkRecord(
        id: 'inspection_${DateTime.now().microsecondsSinceEpoch}',
        kind: 'condition', updatedAt: DateTime.now().toUtc(),
        data: {
          'property': property.text.trim(), 'room': room.text.trim(),
          'inspectionType': inspectionType, 'condition': condition,
          'notes': notes.text.trim(),
        },
      ));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection entry saved.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the inspection entry.')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New inspection')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: property,
        decoration: const InputDecoration(labelText: 'Property name or address')),
      const SizedBox(height: 12),
      TextField(controller: room,
        decoration: const InputDecoration(labelText: 'Room / area')),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: inspectionType,
        decoration: const InputDecoration(labelText: 'Inspection type'),
        items: const [
          DropdownMenuItem(value: 'Move-in', child: Text('Move-in')),
          DropdownMenuItem(value: 'Move-out', child: Text('Move-out')),
          DropdownMenuItem(value: 'Routine', child: Text('Routine')),
        ], onChanged: (v) { if (v != null) setState(() => inspectionType = v); }),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: condition,
        decoration: const InputDecoration(labelText: 'Condition'),
        items: const [
          DropdownMenuItem(value: 'Good', child: Text('Good')),
          DropdownMenuItem(value: 'Fair', child: Text('Fair')),
          DropdownMenuItem(value: 'Needs repair', child: Text('Needs repair')),
        ], onChanged: (v) { if (v != null) setState(() => condition = v); }),
      const SizedBox(height: 12),
      TextField(controller: notes, maxLines: 3,
        decoration: const InputDecoration(labelText: 'Inspection notes')),
      const SizedBox(height: 20),
      FilledButton(onPressed: saving ? null : save,
        child: Text(saving ? 'Saving…' : 'Save condition entry')),
    ])),
  );
}

class InspectionHistory extends StatelessWidget {
  const InspectionHistory({super.key, required this.records});
  final OfflineRecordStore records;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Inspection history')),
    body: FutureBuilder<List<WorkRecord>>(
      future: records.list('condition'),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('History could not be loaded.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        if (rows.isEmpty) return const Center(child: Text('No inspections yet.'));
        return ListView.builder(itemCount: rows.length, itemBuilder: (context, i) {
          final data = rows[i].data;
          return ListTile(
            leading: const Icon(Icons.home_work_outlined),
            title: Text('${data['property']} — ${data['room']}'),
            subtitle: Text('${data['inspectionType']} • ${data['condition']}'),
          );
        });
      },
    ),
  );
}
