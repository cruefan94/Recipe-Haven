import 'package:android_app_foundation/android_app_foundation.dart';
import 'itemized_estimate.dart';

class EstimateReport {
  static List<ReportSection> sections(WorkRecord estimate) {
    final data = estimate.data;
    final lines = <String>[];
    if (data['lines'] is List) {
      for (final line in data['lines'] as List) {
        if (line is! Map) continue;
        final name = line['description']?.toString() ?? 'Item';
        final cost = line['totalCents'] is int
          ? ItemizedEstimate.money(line['totalCents'] as int) : '0.00';
        lines.add(name + ': CAD ' + cost);
      }
    } else {
      if (data['materialCents'] is int) {
        lines.add('Materials: CAD ' +
          ItemizedEstimate.money(data['materialCents'] as int));
      }
      if (data['labourCents'] is int) {
        lines.add('Labour: CAD ' +
          ItemizedEstimate.money(data['labourCents'] as int));
      }
    }
    return [
      ReportSection('Customer and job', [
        'Customer: ' + (data['customer']?.toString() ?? ''),
        'Job: ' + (data['job']?.toString() ?? ''),
        'Saved: ' + estimate.updatedAt.toLocal().toString().split('.').first,
      ]),
      ReportSection('Cost items', lines),
      ReportSection('Estimate summary', [
        'Overhead: ' + (data['overheadPercent'] ?? 0).toString() + '%',
        'Markup: ' + (data['markupPercent'] ?? data['marginPercent'] ?? 0).toString() + '%',
        'Total (before sales tax): CAD ' +
          ItemizedEstimate.money((data['totalCents'] as int?) ?? 0),
        'Review quantities, local tax requirements, and pricing before sending.',
      ]),
    ];
  }

  static Future<void> share(WorkRecord record) async {
    await BusinessPdf.share(
      filename: 'Tradesman-Quote-' + record.id + '.pdf',
      title: 'JOB ESTIMATE',
      subtitle: 'Contractor quotation',
      sections: sections(record),
    );
  }
}
