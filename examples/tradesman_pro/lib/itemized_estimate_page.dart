import 'package:android_app_foundation/android_app_foundation.dart';
import 'package:flutter/material.dart';
import 'itemized_estimate.dart';

class ItemizedEstimatePage extends StatefulWidget {
  const ItemizedEstimatePage({super.key, required this.store});
  final OfflineRecordStore store;
  @override State<ItemizedEstimatePage> createState() => _ItemizedEstimatePageState();
}

class _ItemizedEstimatePageState extends State<ItemizedEstimatePage> {
  final job = TextEditingController(), customer = TextEditingController();
  final item = TextEditingController(), quantity = TextEditingController(text: '1');
  final unitPrice = TextEditingController();
  final lines = <EstimateLine>[];
  String unit = 'each';
  int overhead = 10, markup = 15;
  bool saving = false;
  static const units = ['each', 'hour', 'sq ft', 'board ft', 'linear ft', 'day'];
  @override void dispose() {
    for (final field in [job, customer, item, quantity, unitPrice]) {
      field.dispose();
    }
    super.dispose();
  }

  void notify(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  void addLine() {
    if (item.text.trim().isEmpty) { notify('Enter an item description.'); return; }
    try {
      final q = ItemizedEstimate.parseHundredths(quantity.text);
      final price = ItemizedEstimate.parseHundredths(unitPrice.text, allowZero: true);
      setState(() => lines.add(EstimateLine(item.text.trim(), q, price, unit)));
      item.clear(); quantity.text = '1'; unitPrice.clear();
    } on FormatException catch (error) { notify(error.message); }
  }

  Future<void> save() async {
    if (saving) return;
    if (job.text.trim().isEmpty || customer.text.trim().isEmpty || lines.isEmpty) {
      notify('Enter a job, customer, and at least one line item.');
      return;
    }
    setState(() => saving = true);
    try {
      await widget.store.save(WorkRecord(
        id: 'estimate_' + DateTime.now().microsecondsSinceEpoch.toString(),
        kind: 'estimate', updatedAt: DateTime.now().toUtc(),
        data: {
          'job': job.text.trim(), 'customer': customer.text.trim(),
          'lines': lines.map((e) => e.toJson()).toList(),
          'subtotalCents': ItemizedEstimate.subtotal(lines),
          'overheadPercent': overhead, 'markupPercent': markup,
          'totalCents': ItemizedEstimate.total(lines, overhead, markup),
          'currency': 'CAD', 'includesTax': false,
        },
      ));
      if (mounted) notify('Estimate saved on this device.');
    } catch (_) { if (mounted) notify('Unable to save estimate.'); }
    finally { if (mounted) setState(() => saving = false); }
  }

  @override Widget build(BuildContext context) {
    final total = lines.isEmpty ? 0 : ItemizedEstimate.total(lines, overhead, markup);
    return Scaffold(
      appBar: AppBar(title: const Text('Itemized estimate')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: job, decoration: const InputDecoration(labelText: 'Job name')),
        const SizedBox(height: 12),
        TextField(controller: customer, decoration: const InputDecoration(labelText: 'Customer')),
        const SizedBox(height: 18),
        Text('Cost items', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        TextField(controller: item, decoration: const InputDecoration(labelText: 'Material or work')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantity'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: unitPrice,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Unit price (CAD)'))),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: unit,
          decoration: const InputDecoration(labelText: 'Unit'),
          items: units.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
          onChanged: (v) { if (v != null) setState(() => unit = v); },
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: addLine, icon: const Icon(Icons.add),
          label: const Text('Add cost item')),
        for (var i = 0; i < lines.length; i++)
          Card(child: ListTile(
            title: Text(lines[i].description),
            subtitle: Text((lines[i].units100 / 100).toString() + ' ' + lines[i].unit),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(ItemizedEstimate.money(lines[i].totalCents)),
              IconButton(tooltip: 'Remove item', icon: const Icon(Icons.close),
                onPressed: () => setState(() => lines.removeAt(i))),
            ]),
          )),
        const SizedBox(height: 12),
        Text('Overhead: ' + overhead.toString() + '%'),
        Slider(value: overhead.toDouble(), min: 0, max: 50, divisions: 50,
          onChanged: (v) => setState(() => overhead = v.round())),
        Text('Markup: ' + markup.toString() + '%'),
        Slider(value: markup.toDouble(), min: 0, max: 50, divisions: 50,
          onChanged: (v) => setState(() => markup = v.round())),
        Text('Estimated total: CAD ' + ItemizedEstimate.money(total),
          style: Theme.of(context).textTheme.titleLarge),
        const Text('Before sales tax. Confirm actual pricing before sending a quote.'),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: saving ? null : save,
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? 'Saving…' : 'Save estimate')),
      ])),
    );
  }
}
