import 'package:flutter/material.dart';
import 'package:android_app_foundation/android_app_foundation.dart';

class CustomerDirectoryPage extends StatefulWidget {
  const CustomerDirectoryPage({super.key, required this.store});
  final OfflineRecordStore store;
  @override State<CustomerDirectoryPage> createState() => _CustomerDirectoryPageState();
}

class _CustomerDirectoryPageState extends State<CustomerDirectoryPage> {
  final name = TextEditingController(), phone = TextEditingController(),
    email = TextEditingController(), address = TextEditingController();
  late Future<List<WorkRecord>> entries;
  bool saving = false;
  @override void initState() { super.initState(); refresh(); }
  void refresh() { entries = widget.store.list('customer'); }
  @override void dispose() {
    name.dispose(); phone.dispose(); email.dispose(); address.dispose();
    super.dispose();
  }
  void notify(String message) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(message)));
  Future<void> add() async {
    if (saving) return;
    if (name.text.trim().isEmpty) { notify('Enter a customer name.'); return; }
    setState(() => saving = true);
    try {
      await widget.store.save(WorkRecord(
        id: 'customer_' + DateTime.now().microsecondsSinceEpoch.toString(),
        kind: 'customer', updatedAt: DateTime.now().toUtc(),
        data: {'name': name.text.trim(), 'phone': phone.text.trim(),
          'email': email.text.trim(), 'address': address.text.trim()},
      ));
      name.clear(); phone.clear(); email.clear(); address.clear();
      if (mounted) setState(refresh);
    } catch (_) { if (mounted) notify('Customer could not be saved.'); }
    finally { if (mounted) setState(() => saving = false); }
  }
  Future<void> delete(WorkRecord row) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) =>
      AlertDialog(title: const Text('Delete customer?'),
        content: const Text('This deletes only the saved customer entry.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete')),
        ]));
    if (confirmed != true) return;
    try { await widget.store.remove(row.id); if (mounted) setState(refresh); }
    catch (_) { if (mounted) notify('Customer could not be deleted.'); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Customers')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      Text('New customer', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
      const SizedBox(height: 12),
      TextField(controller: phone, keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Phone (optional)')),
      const SizedBox(height: 12),
      TextField(controller: email, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email (optional)')),
      const SizedBox(height: 12),
      TextField(controller: address,
        decoration: const InputDecoration(labelText: 'Address (optional)')),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: saving ? null : add,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Save customer')),
      const SizedBox(height: 22),
      Text('Saved customers', style: Theme.of(context).textTheme.titleLarge),
      FutureBuilder<List<WorkRecord>>(future: entries, builder: (context, snap) {
        if (snap.hasError) return const Text('Could not load customers.');
        if (!snap.hasData) return const LinearProgressIndicator();
        if (snap.data!.isEmpty) return const Text('No saved customers yet.');
        return Column(children: [
          for (final row in snap.data!)
            Card(child: ListTile(
              title: Text(row.data['name']?.toString() ?? ''),
              subtitle: Text((row.data['phone']?.toString() ?? '') +
                '\n' + (row.data['email']?.toString() ?? '')),
              trailing: IconButton(tooltip: 'Delete customer',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => delete(row)),
            )),
        ]);
      }),
    ])),
  );
}
