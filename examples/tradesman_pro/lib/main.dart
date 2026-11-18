import 'package:android_app_foundation/android_app_foundation.dart';
import 'package:flutter/material.dart';
import 'estimate_math.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final records = OfflineRecordStore(databaseName: 'tradesman_records');
  runApp(FieldApp(
    brand: const AppBrand(
      name: 'Tradesman Pro', subtitle: 'Jobs, estimates and clear pricing',
      primary: Color(0xFFDE9F1D), background: Color(0xFF111A24),
      icon: Icons.construction, brightness: Brightness.dark,
    ),
    features: [
      AppFeature(title: 'Create an estimate', icon: Icons.calculate_outlined,
        builder: (_) => EstimatePage(records: records)),
      AppFeature(title: 'Saved estimates', icon: Icons.receipt_long_outlined,
        builder: (_) => SavedEstimates(records: records)),
    ],
  ));
}

class EstimatePage extends StatefulWidget {
  const EstimatePage({super.key, required this.records});
  final OfflineRecordStore records;
  @override State<EstimatePage> createState() => _EstimatePageState();
}

class _EstimatePageState extends State<EstimatePage> {
  final job = TextEditingController();
  final customer = TextEditingController();
  final materials = TextEditingController(text: '0.00');
  final labour = TextEditingController(text: '0.00');
  int overhead = 10;
  int margin = 15;
  bool saving = false;
  int? total;

  @override void dispose() {
    for (final input in [job, customer, materials, labour]) { input.dispose(); }
    super.dispose();
  }

  int calculate() => EstimateMath.totalCents(
    materialCents: EstimateMath.parseCents(materials.text),
    labourCents: EstimateMath.parseCents(labour.text),
    overheadPercent: overhead, marginPercent: margin,
  );

  Future<void> save() async {
    if (saving) return;
    if (job.text.trim().isEmpty || customer.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter both job and customer.')));
      return;
    }
    late final int value;
    try { value = calculate(); } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check material and labour amounts.')));
      return;
    }
    setState(() { saving = true; total = value; });
    try {
      await widget.records.save(WorkRecord(
        id: 'estimate_\$\{DateTime.now().microsecondsSinceEpoch\}',
        kind: 'estimate',
        updatedAt: DateTime.now().toUtc(),
        data: {
          'job': job.text.trim(), 'customer': customer.text.trim(),
          'materialCents': EstimateMath.parseCents(materials.text),
          'labourCents': EstimateMath.parseCents(labour.text),
          'overheadPercent': overhead, 'marginPercent': margin,
          'totalCents': value,
        },
      ));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estimate saved on this device.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. No estimate was confirmed.')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New estimate')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: job, decoration: const InputDecoration(labelText: 'Job name')),
      const SizedBox(height: 12),
      TextField(controller: customer, decoration: const InputDecoration(labelText: 'Customer')),
      const SizedBox(height: 12),
      TextField(controller: materials, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Materials (CAD)')),
      const SizedBox(height: 12),
      TextField(controller: labour, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Labour (CAD)')),
      const SizedBox(height: 18),
      Text('Overhead: \$overhead%'),
      Slider(value: overhead.toDouble(), min: 0, max: 100, divisions: 100,
        label: '$overhead%', onChanged: (v) => setState(() => overhead = v.round())),
      Text('Markup: \$margin%'),
      Slider(value: margin.toDouble(), min: 0, max: 100, divisions: 100,
        label: '$margin%', onChanged: (v) => setState(() => margin = v.round())),
      if (total != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('Estimated total (before tax): \$\{EstimateMath.formatCents(total!)\}',
          style: Theme.of(context).textTheme.titleLarge)),
      const SizedBox(height: 12),
      FilledButton(onPressed: saving ? null : save,
        child: Text(saving ? 'Saving…' : 'Calculate and save')),
    ])),
  );
}

class SavedEstimates extends StatefulWidget {
  const SavedEstimates({super.key, required this.records});
  final OfflineRecordStore records;
  @override State<SavedEstimates> createState() => _SavedEstimatesState();
}
class _SavedEstimatesState extends State<SavedEstimates> {
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Saved estimates')),
    body: FutureBuilder<List<WorkRecord>>(
      future: widget.records.list('estimate'),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Records could not be loaded.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        if (rows.isEmpty) return const Center(child: Text('No estimates yet.'));
        return ListView.builder(itemCount: rows.length, itemBuilder: (context, index) {
          final row = rows[index];
          return ListTile(
            title: Text(row.data['job']?.toString() ?? 'Estimate'),
            subtitle: Text(row.data['customer']?.toString() ?? ''),
            trailing: Text(EstimateMath.formatCents(row.data['totalCents'] as int)),
          );
        });
      },
    ),
  );
}
