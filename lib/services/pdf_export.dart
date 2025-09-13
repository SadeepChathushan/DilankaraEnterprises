// lib/services/pdf_export.dart
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import '../core/models.dart';
import '../core/repository.dart';

class DeliveryPdfService {
  DeliveryPdfService._();
  static final DeliveryPdfService instance = DeliveryPdfService._();

  String _fmtNum(num n) => (n % 1 == 0) ? n.toInt().toString() : n.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

  /// Builds and saves the PDF. Returns the saved file path.
  Future<String> exportDeliveryPdf(
    String deliveryId, {
    String shopHeader = 'Shop Header',
  }) async {
    final repo = Repository.instance;

    // Load header
    final deliveries = await repo.getDeliveries();
    final delivery = deliveries.firstWhere((d) => d.id == deliveryId);

    // Load groups+widths and aggregate by thickness -> length rows
    final groups = await repo.getGroups(deliveryId);

    // thickness -> list of rows
    final Map<double, List<_LenRow>> byThickness = {};

    for (final g in groups) {
      final widths = await repo.getWidths(g.id); // list of WoodWidth
      final widthValues = widths.map((w) => w.width).toList();

      final distinct = widthValues.toSet().toList()..sort();
      final countWidth = widthValues.length;
      final product = countWidth * g.length;

      final row = _LenRow(
        length: g.length,
        widthsDistinct: distinct,
        countWidth: countWidth,
        productCountTimesLength: product,
      );

      byThickness.putIfAbsent(g.thickness, () => []).add(row);
    }

    // Sort thickness asc; and lengths asc inside
    final sortedThickness = byThickness.keys.toList()..sort();
    for (final t in sortedThickness) {
      byThickness[t]!.sort((a, b) => a.length.compareTo(b.length));
    }

    // Build the PDF
    final pdf = pw.Document();

    final dateStr = DateFormat('dd-MM-yyyy HH:mm').format(delivery.date.toLocal());
    final idShort = _shortId(delivery.id);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
            italic: pw.Font.helveticaOblique(),
          ),
        ),
        build: (context) => [
          // Header
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(shopHeader, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text(
                'Lorry: ${delivery.lorryName}    Date: $dateStr    Delivery ID: $idShort',
                style: const pw.TextStyle(fontSize: 11),
              ),
              if ((delivery.notes ?? '').trim().isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text('Notes: ${delivery.notes}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ],
          ),
          pw.SizedBox(height: 16),

          // Body: thickness sections
          ...sortedThickness.expand((t) {
            final rows = byThickness[t]!;
            return [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(width: 0.6, color: PdfColors.grey600)),
                ),
                child: pw.Text('Thickness: ${_fmtNum(t)}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 6),

              // Each length row
              ...rows.map((r) {
                final widthsStr = r.widthsDistinct.map(_fmtNum).join(', ');
                final productStr = _fmtNum(r.productCountTimesLength);
                final lengthStr = _fmtNum(r.length);

                // Visual line like: "  8 →  (2, 3, 4)    countwidth: 9   countwidth×length: 9×8=72"
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(width: 8), // indent
                      pw.Text(lengthStr, style: const pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(width: 6),
                      pw.Text('→', style: const pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(width: 6),
                      pw.Expanded(
                        child: pw.Text(
                          '($widthsStr)    '
                          'countwidth: ${r.countWidth}   '
                          'countwidth×length: ${r.countWidth}×$lengthStr=$productStr',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  
                );
              }),

              pw.SizedBox(height: 10),
            ];
          }),

          // Optional grand totals (comment out if not needed)
          // pw.Divider(),
          // _grandTotalsSection(byThickness),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())} • Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
      ),
    );

    // Save file
    final dir = await getApplicationDocumentsDirectory(); // user-accessible app docs
    final fileName = 'delivery_${idShort}.pdf';
    final path = p.join(dir.path, fileName);
    final file = File(path);
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  // If you want a totals summary, uncomment this and the call above.
  pw.Widget _grandTotalsSection(Map<double, List<_LenRow>> byThickness) {
    int totalCount = 0;
    double totalProduct = 0;

    byThickness.values.expand((rows) => rows).forEach((r) {
      totalCount += r.countWidth;
      totalProduct += r.productCountTimesLength;
    });

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text('Totals: ',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text('countwidth=$totalCount, ', style: const pw.TextStyle(fontSize: 12)),
          pw.Text('Σ(count×length)=${_fmtNum(totalProduct)}',
              style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _LenRow {
  final double length;
  final List<double> widthsDistinct;
  final int countWidth;
  final double productCountTimesLength;

  _LenRow({
    required this.length,
    required this.widthsDistinct,
    required this.countWidth,
    required this.productCountTimesLength,
  });
}
