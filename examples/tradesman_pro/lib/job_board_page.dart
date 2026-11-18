import 'package:android_app_foundation/android_app_foundation.dart';
import 'package:flutter/material.dart';
import 'job_workflow.dart';

class JobBoardPage extends StatefulWidget {
  const JobBoardPage({super.key, required this.store});
  final OfflineRecordStore store;
  @override State<JobBoardPage> createState() => _JobBoardPageState();
}

class _JobBoardPageState extends State<JobBoardPage> {
  final job = TextEditingController(), customer = TextEditingController();
  String newStatus = JobWorkflow.statuses.first;
  late Future<List<WorkRecord>> records;
  bool saving = false;

  @override void initState() { super.initState(); refresh(); }
  @override void dispose() { job.dispose(); customer.dispose(); super.dispose(); }
  void refresh() { records = widget.store.list('job'); }
  void notify(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)));

  Future<void> add() async {
    if (saving) return;
    String name;
    try { name = JobWorkflow.validateTitle(job.text); }
    on FormatException catch (e) { notify(e.message); return; }
    if (customer.text.trim().isEmpty) {
      notify('Enter a customer.');
      return;
    }
    setState(() => saving = true);
    try {
      await widget.store.save(WorkRecord(
        id: 'job_' + DateTime.now().microsecondsSinceEpoch.toString(),
        kind: 'job', updatedAt: DateTime.now().toUtc(),
        data: {'name': name, 'customer': customer.text.trim(),
          'status': JobWorkflow.validated(newStatus)},
      ));
      job.clear(); customer.clear();
      setState(refresh);
    } catch (_) { if (mounted) notify('Could not save job.'); }
    finally { if (mounted) setState(() => saving = false); }
  }

  Future<void> changeStatus(WorkRecord row, String next) async {
    try {
      await widget.store.save(WorkRecord(
        id: row.id, kind: row.kind, updatedAt: DateTime.now().toUtc(),
        data: {...row.data, 'status': JobWorkflow.validated(next)},
      ));
      if (mounted) setState(refresh);
    } catch (_) { if (mounted) notify('Could not update job status.'); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Job board')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      Text('Add a job', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      TextField(controller: job,
        decoration: const InputDecoration(labelText: 'Job name')),
      const SizedBox(height: 12),
      TextField(controller: customer,
        decoration: const InputDecoration(labelText: 'Customer')),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: newStatus,
        decoration: const InputDecoration(labelText: 'Initial status'),
        items: JobWorkflow.statuses.map((s) =>
          DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) { if (v != null) setState(() => newStatus = v); },
      ),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: saving ? null : add,
        icon: const Icon(Icons.add),
        label: Text(saving ? 'Saving…' : 'Add job')),
      const SizedBox(height: 20),
      Text('My jobs', style: Theme.of(context).textTheme.titleLarge),
      FutureBuilder<List<WorkRecord>>(future: records,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Text('Jobs could not be loaded.');
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!;
          if (rows.isEmpty) return const Text('No jobs saved yet.');
          return Column(children: [
            for (final row in rows)
              Card(child: ListTile(
                title: Text(row.data['name']?.toString() ?? 'Job'),
                subtitle: Text(row.data['customer']?.toString() ?? ''),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Update status',
                  onSelected: (value) => changeStatus(row, value),
                  itemBuilder: (context) => JobWorkflow.statuses
                    .map((s) => PopupMenuItem(value: s, child: Text(s))).toList(),
                  child: Chip(label: Text(row.data['status']?.toString() ?? 'Quoted')),
                ),
              )),
          ]);
        },
      ),
    ])),
  );
}
