import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Lightweight user-controlled document export. PDF files shared outside the
/// application are plaintext and must be treated as personal/business records.
class ReportSection {
  const ReportSection(this.title, this.lines);
  final String title;
  final List<String> lines;
}

class ReportPicture {
  const ReportPicture(this.caption, this.bytes);
  final String caption;
  final Uint8List bytes;
}

class BusinessPdf {
  static Future<Uint8List> render({
    required String title,
    required String subtitle,
    required List<ReportSection> sections,
    List<ReportPicture> pictures = const [],
  }) async {
    if (title.trim().isEmpty || sections.length > 150 || pictures.length > 30) {
      throw const FormatException('Invalid document size');
    }
    final doc = pw.Document();
    final contents = <pw.Widget>[
      pw.Text(title, style: pw.TextStyle(fontSize: 21, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      pw.SizedBox(height: 16),
    ];
    for (final section in sections) {
      contents.add(pw.SizedBox(height: 12));
      contents.add(pw.Text(section.title,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)));
      contents.add(pw.Divider(color: PdfColors.grey300));
      for (final line in section.lines.take(100)) {
        contents.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(line, style: const pw.TextStyle(fontSize: 10)),
        ));
      }
    }
    for (final picture in pictures) {
      if (picture.bytes.isEmpty || picture.bytes.length > 8 * 1024 * 1024) continue;
      contents.add(pw.SizedBox(height: 12));
      contents.add(pw.Text(picture.caption, style: const pw.TextStyle(fontSize: 10)));
      contents.add(pw.SizedBox(height: 5));
      contents.add(pw.Image(pw.MemoryImage(picture.bytes),
        height: 215, fit: pw.BoxFit.contain));
    }
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => contents,
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ' + context.pageNumber.toString(),
          style: const pw.TextStyle(fontSize: 8)),
      ),
    ));
    return doc.save();
  }

  static Future<void> share({
    required String filename,
    required String title,
    required String subtitle,
    required List<ReportSection> sections,
    List<ReportPicture> pictures = const [],
  }) async {
    final safe = RegExp(r'^[A-Za-z0-9_.-]{1,90}\.pdf$');
    if (!safe.hasMatch(filename)) throw const FormatException('Invalid report name');
    final bytes = await render(
      title: title, subtitle: subtitle, sections: sections, pictures: pictures);
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
