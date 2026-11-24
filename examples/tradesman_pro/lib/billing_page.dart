import 'package:flutter/material.dart';
import 'package:android_app_foundation/android_app_foundation.dart';
import 'itemized_estimate.dart';

class BillingMath {
  /// A saved estimate must not silently generate multiple final invoices.
  static bool alreadyInvoiced(Iterable<WorkRecord> invoices, String estimateId) =>
    invoices.any((invoice) =>
      invoice.kind == 'invoice' && invoice.data['quoteId'] == estimateId);

  static int taxBasisPoints(String percent) {
    final rate = ItemizedEstimate.parseHundredths(percent, allowZero: true);
    if (rate > 10000) throw const FormatException('Tax rate must be 0 to 100%');
    return rate;
  }
  static int taxAmount(int amount, int basisPoints) {
    if (amount < 0 || basisPoints < 0 || basisPoints > 10000) {
      throw const FormatException('Invalid tax calculation');
    }
    return (amount * basisPoints + 5000) ~/ 10000;
  }
}

class BillingPage extends StatefulWidget {
  const BillingPage({super.key, required this.store});
  final OfflineRecordStore store;
  @override State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  late Future<List<WorkRecord>> quotes;
  late Future<List<WorkRecord>> invoices;
  final taxRate = TextEditingController(text: '0.00');
  String? selectedId;
  bool saving = false;

  @override void initState() { super.initState(); reload(); }
  @override void dispose() { taxRate.dispose(); super.dispose(); }
  void reload() {
    quotes = widget.store.list('estimate');
    invoices = widget.store.list('invoice');
  }
  void notify(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)));

  Future<void> create(List<WorkRecord> available) async {
    if (saving) return;
    final matches = available.where((row) => row.id == selectedId).toList();
    if (matches.isEmpty) { notify('Choose a saved estimate first.'); return; }
    late final int rate;
    try { rate = BillingMath.taxBasisPoints(taxRate.text); }
    on FormatException catch (e) { notify(e.message); return; }
    final quote = matches.first;
    final base = quote.data['totalCents'];
    if (base is! int || base < 0) { notify('Saved estimate has invalid totals.'); return; }
    final tax = BillingMath.taxAmount(base, rate);
    setState(() => saving = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm final invoice'),
          content: Text(
            'Customer: ' + (quote.data['customer']?.toString() ?? '') + '\n' +
            'Job: ' + (quote.data['job']?.toString() ?? '') + '\n' +
            'Subtotal: CAD ' + ItemizedEstimate.money(base) + '\n' +
            'Tax (' + (rate / 100).toStringAsFixed(2) + '%): CAD ' +
              ItemizedEstimate.money(tax) + '\n' +
            'Total: CAD ' + ItemizedEstimate.money(base + tax) + '\n\n' +
            'Review the amounts and applicable tax rate before creating the ' +
              'final invoice. Each estimate can create only one final invoice.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Create invoice'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      final now = DateTime.now();
      final previousInvoices = await widget.store.list('invoice');
      if (BillingMath.alreadyInvoiced(previousInvoices, quote.id)) {
        if (mounted) notify('This estimate already has an invoice. Review it below.');
        return;
      }
      await widget.store.save(WorkRecord(
        id: 'invoice_' + now.microsecondsSinceEpoch.toString(),
        kind: 'invoice', updatedAt: now.toUtc(),
        data: {
          'invoiceNo': 'INV-' + now.microsecondsSinceEpoch.toString(),
          'customer': quote.data['customer']?.toString() ?? '',
          'job': quote.data['job']?.toString() ?? '',
          'quoteId': quote.id,
          'subtotalCents': base,
          'taxBasisPoints': rate,
          'taxCents': tax,
          'totalCents': base + tax,
          'status': 'Unpaid',
          'createdAt': now.toUtc().toIso8601String(),
        },
      ));
      if (mounted) { notify('Invoice saved.'); setState(reload); }
    } catch (_) { if (mounted) notify('Could not create invoice.'); }
    finally { if (mounted) setState(() => saving = false); }
  }

  Future<void> updateStatus(WorkRecord invoice, String status) async {
    try {
      await widget.store.save(WorkRecord(
        id: invoice.id, kind: invoice.kind, updatedAt: DateTime.now().toUtc(),
        data: {...invoice.data, 'status': status},
      ));
      if (mounted) setState(reload);
    } catch (_) { if (mounted) notify('Could not update invoice.'); }
  }

  Future<void> share(WorkRecord invoice) async {
    final d = invoice.data;
    try {
      await BusinessPdf.share(
        filename: 'Tradesman-Invoice-' + invoice.id + '.pdf',
        title: 'INVOICE',
        subtitle: d['invoiceNo']?.toString() ?? '',
        sections: [
          ReportSection('Customer', [
            d['customer']?.toString() ?? '',
            'Job: ' + (d['job']?.toString() ?? ''),
            'Issued: ' + (d['createdAt']?.toString() ?? ''),
            'Payment: ' + (d['status']?.toString() ?? ''),
          ]),
          ReportSection('Amounts (CAD)', [
            'Estimate subtotal: ' + ItemizedEstimate.money(d['subtotalCents'] as int),
            'Tax rate: ' + ((d['taxBasisPoints'] as int) / 100).toStringAsFixed(2) + '%',
            'Tax: ' + ItemizedEstimate.money(d['taxCents'] as int),
            'Total due: ' + ItemizedEstimate.money(d['totalCents'] as int),
          ]),
        ],
      );
    } catch (_) { if (mounted) notify('Could not share the invoice PDF.'); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Invoices')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      Text('Create from an estimate',
        style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      FutureBuilder<List<WorkRecord>>(future: quotes, builder: (context, snap) {
        if (snap.hasError) return const Text('Estimates unavailable.');
        if (!snap.hasData) return const LinearProgressIndicator();
        final rows = snap.data!;
        if (rows.isEmpty) return const Text('Save an estimate to create an invoice.');
        return DropdownButtonFormField<String>(
          initialValue: rows.any((r) => r.id == selectedId) ? selectedId : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Saved estimate'),
          items: rows.map((row) => DropdownMenuItem(
            value: row.id,
            child: Text((row.data['job']?.toString() ?? 'Job') +
              ' - ' + (row.data['customer']?.toString() ?? ''),
              overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (value) => setState(() => selectedId = value),
        );
      }),
      const SizedBox(height: 12),
      TextField(controller: taxRate,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Sales tax rate (%)')),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text('Confirm the applicable tax rate before issuing. Each saved estimate can create one final invoice; deposit or progress billing is not supported. No payment collection is performed.'),
      ),
      FutureBuilder<List<WorkRecord>>(future: quotes, builder: (context, snap) =>
        FilledButton.icon(
          onPressed: saving || !snap.hasData || snap.data!.isEmpty ?
            null : () => create(snap.data!),
          icon: const Icon(Icons.add),
          label: const Text('Create invoice'),
        ),
      ),
      const SizedBox(height: 20),
      Text('Saved invoices', style: Theme.of(context).textTheme.titleLarge),
      FutureBuilder<List<WorkRecord>>(future: invoices, builder: (context, snap) {
        if (snap.hasError) return const Text('Invoices unavailable.');
        if (!snap.hasData) return const LinearProgressIndicator();
        if (snap.data!.isEmpty) return const Text('No invoices yet.');
        return Column(children: [
          for (final row in snap.data!)
            Card(child: ListTile(
              title: Text(row.data['invoiceNo']?.toString() ?? 'Invoice'),
              subtitle: Text((row.data['customer']?.toString() ?? '') +
                ' - CAD ' + ItemizedEstimate.money(row.data['totalCents'] as int)),
              onTap: () => share(row),
              trailing: PopupMenuButton<String>(
                tooltip: 'Invoice status',
                onSelected: (status) => updateStatus(row, status),
                itemBuilder: (context) => ['Unpaid', 'Paid'].map((s) =>
                  PopupMenuItem(value: s, child: Text(s))).toList(),
                child: Chip(label: Text(row.data['status']?.toString() ?? 'Unpaid')),
              ),
            )),
        ]);
      }),
    ])),
  );
}
