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

  // Format number
  String _fmtNum(num n) => (n % 1 == 0)
      ? n.toInt().toString()
      : n.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');

  // Convert decimal inch to fraction string
  String _fmtInchFraction(double value) {
    final whole = value.floor();
    final frac = value - whole;

    const denom = 8; // 1/8 inch precision
    final num = (frac * denom).round();

    if (num == 0) return whole.toString();
    if (whole == 0) return '$num/$denom';
    return '$whole $num/$denom';
  }

  String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

  Future<String> exportDeliveryPdf(
    String deliveryId, {
    String shopHeader = 'Dilankara Enterprises (Pvt) Ltd',
  }) async {
    final repo = Repository.instance;

    final deliveries = await repo.getDeliveries();
    final delivery = deliveries.firstWhere((d) => d.id == deliveryId);

    final groups = await repo.getGroups(deliveryId);

    /// thickness -> rows
    final Map<double, List<_LenRow>> byThickness = {};

    for (final g in groups) {
      final widths = await repo.getWidths(g.id);
      final widthValues = widths.map((w) => w.width).toList();

      final totalWidth = widthValues.fold(0.0, (sum, w) => sum + w);

      /// ✅ ROW: ft² ONLY
      final areaFt2 = totalWidth * g.length;

      final row = _LenRow(
        length: g.length,
        widths: widthValues,
        totalWidth: totalWidth,
        areaFt2: areaFt2,
      );

      byThickness.putIfAbsent(g.thickness, () => []).add(row);
    }

    final sortedThickness = byThickness.keys.toList()..sort();
    for (final t in sortedThickness) {
      byThickness[t]!.sort((a, b) => a.length.compareTo(b.length));
    }

    /// ✅ GRAND TOTAL + thickness calculations
    double grandTotalFt = 0;
    final List<Map<String, dynamic>> thicknessCalcs = [];

  for (final t in sortedThickness) {
  final rows = byThickness[t]!;

  double thicknessAreaFt2 = 0;
  int thicknessItemCount = 0;

  for (final r in rows) {
    thicknessAreaFt2 += r.areaFt2;
    thicknessItemCount += r.widths.length;
  }

  final ft = thicknessAreaFt2 / 12;
  grandTotalFt += ft;

  thicknessCalcs.add({
    'thickness': t,
    'areaFt2': thicknessAreaFt2,
    'ft': ft,
    'items': thicknessItemCount, // optional, but useful
  });
}


    // ---- Colors ----
    const cPrimary = PdfColor.fromInt(0xFF5D4037);
    const cOnPrimary = PdfColor.fromInt(0xFFFFFFFF);
    const cPrimaryContainer = PdfColor.fromInt(0xFFD7CCC8);
    const cAccent = PdfColor.fromInt(0xFFFFC107);
    const cAccentContainer = PdfColor.fromInt(0xFFFFE082);
    const cSurface = PdfColor.fromInt(0xFFFFFBF2);
    const cOnSurface = PdfColor.fromInt(0xFF3E2723);
    const cOutline = PdfColor.fromInt(0xFFBCAAA4);

    final pdf = pw.Document();

    final dateStr =
        DateFormat('dd-MM-yyyy HH:mm').format(delivery.date.toLocal());
    final idShort = _shortId(delivery.id);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
            italic: pw.Font.helveticaOblique(),
          ),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: cSurface),
          ),
        ),
        build: (context) => [
          /// HEADER
          pw.Container(
            decoration: pw.BoxDecoration(
              color: cPrimary,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Dilankara Enterprises (PVT) Ltd',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: cOnPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                '0776144829 | info@dilankaraenterprises.com\n89, Siyambalagoda, Polgasowita, Sri Lanka',
                style: pw.TextStyle(
                  font: pw.Font.helvetica(),
                  fontSize: 10,
                  fontWeight: pw.FontWeight.normal,
                  // letterSpacing: 0.8,
                  color: cAccent,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          decoration: pw.BoxDecoration(
            color: cAccent,
            borderRadius: pw.BorderRadius.circular(8),
          ),
        ),
      ],
    ),
    pw.SizedBox(height: 12),
    pw.Container(height: 2, color: cAccent),
    pw.SizedBox(height: 10),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Name: ${delivery.lorryName}',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: cOnPrimary,
                letterSpacing: 0.3,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Date: $dateStr',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: cOnPrimary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ],
    ),
  ],
)
          ),

          pw.SizedBox(height: 16),

          /// THICKNESS SECTIONS
          ...sortedThickness.expand((t) {
            final rows = byThickness[t]!;

            double thicknessAreaFt2 = 0;
            int thicknessItemCount = 0;
            for (final r in rows) {
              thicknessAreaFt2 += r.areaFt2;
              thicknessItemCount += r.widths.length;
            }

            final thicknessTotalFt = (thicknessAreaFt2 / 12).ceil();

            return [
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: pw.BoxDecoration(
                  color: cPrimaryContainer,
                  border: pw.Border.all(width: 0.6, color: cOutline),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  children: [
                    pw.Text(
                      'Thickness: ${_fmtInchFraction(t)}"',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: cOnSurface,
                      ),
                    ),
                    pw.Spacer(),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: cAccentContainer,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: cAccent, width: 0.7),
                      ),
                      child: pw.Text(
                      'Total: ${_fmtNum(thicknessTotalFt)} ft² | Items: $thicknessItemCount',
                         style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF3E2723),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
...rows.map((r) {
final widthsComma = r.widths.map(_fmtNum).join(', ');
final widthsPlus = r.widths.map(_fmtNum).join(' + ');
final widthsCount = r.widths.length;

  return pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFFFFFFFF),
      border: pw.Border.all(width: 0.35, color: cOutline),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ✅ Length on top, widths below
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Length: ${_fmtNum(r.length)} ft',
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: cOnSurface),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
            'Widths ($widthsCount): ($widthsComma)',
              style: const pw.TextStyle(fontSize: 12, color: cOnSurface),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Total width = $widthsPlus = ${_fmtNum(r.totalWidth)}',
          style: const pw.TextStyle(fontSize: 11, color: cOnSurface),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Total (ft.inch) = ${_fmtNum(r.totalWidth)} × ${_fmtNum(r.length)} = ${_fmtNum(r.areaFt2)} ft.inch',
          style: const pw.TextStyle(fontSize: 11, color: cOnSurface),
        ),
      ],
    ),
  );
}),

              pw.SizedBox(height: 16),
            ];
          }),

          /// THICKNESS CALCULATION SUMMARY
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: cPrimaryContainer,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: cOutline),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Thickness Calculations',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: cOnSurface,
                  ),
                ),
                pw.SizedBox(height: 8),

                ...thicknessCalcs.map((e) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text(
                      'Thickness ${_fmtInchFraction(e['thickness'])}" : ${_fmtNum(e['areaFt2'])} ÷ 12 = ${_fmtNum(e['ft'])} ft',
                      style: pw.TextStyle(fontSize: 11, color: cOnSurface),
                    ),
                  );
                }),

                pw.Divider(color: cOutline),
                // pw.Text(
                //   'Sum = ${thicknessCalcs.map((e) => _fmtNum(e['ft'])).join(' + ')} = ${_fmtNum(grandTotalFt)} ft',
                //   style: pw.TextStyle(
                //     fontSize: 12,
                //     fontWeight: pw.FontWeight.bold,
                //     color: cOnSurface,
                //   ),
                // ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          /// GRAND TOTAL
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: cAccentContainer,
              border: pw.Border.all(width: 1, color: cAccent),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Center(
              child: pw.Text(
                'Thank you for choosing us - we value your trust.',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF3E2723),
                ),
              ),
            ),
          ),
        ],
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 14),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Dilankara Enterprises (PVT) Ltd',
                style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF6D4C41)),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount} | ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF6D4C41)),
              ),
            ],
          ),
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'delivery_$idShort.pdf';
    final path = p.join(dir.path, fileName);
    final file = File(path);
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }
}

class _LenRow {
  final double length;
  final List<double> widths;
  final double totalWidth;
  final double areaFt2;

  _LenRow({
    required this.length,
    required this.widths,
    required this.totalWidth,
    required this.areaFt2,
  });
}
