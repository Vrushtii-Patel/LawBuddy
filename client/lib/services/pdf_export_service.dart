import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'file_saver/save_file.dart';

class PdfExportService {
  /// Cleans text so Syncfusion PdfStandardFont (Helvetica) never throws font encoding exceptions
  static String _sanitizeText(String input) {
    if (input.isEmpty) return '';
    final String cleanSpecial = input
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('\u200B', '')
        .replaceAll('\u00A0', ' ');

    final StringBuffer buffer = StringBuffer();
    for (final char in cleanSpecial.runes) {
      if (char == 10 || char == 13 || char == 9 || (char >= 32 && char <= 126) || (char >= 160 && char <= 255)) {
        buffer.writeCharCode(char);
      } else {
        buffer.write(' ');
      }
    }
    return buffer.toString().replaceAll(RegExp(r' +'), ' ').trim();
  }

  /// Generates and downloads/saves a professional Legal Risk Assessment PDF Report
  static Future<void> exportAnalysisPdf({
    required String documentTitle,
    required String originalText,
    required List<dynamic> analysis,
    String sourceType = 'PDF Document',
    String? fileData,
  }) async {
    // 1. Create a PDF document
    final PdfDocument document = PdfDocument();
    document.pageSettings.margins.all = 36; // 0.5 inch margins

    // 2. Count risk categories directly from analysis array
    int redCount = 0;
    int yellowCount = 0;
    int greenCount = 0;
    for (final item in analysis) {
      final risk = (item['riskLevel'] ?? '').toString().toUpperCase();
      final cat = (item['category'] ?? '').toString().toLowerCase();
      if (risk == 'HIGH_RISK' || cat.contains('red')) {
        redCount++;
      } else if (risk == 'CAUTION' || cat.contains('yellow')) {
        yellowCount++;
      } else if (risk == 'COMPLIANT' || cat.contains('green')) {
        greenCount++;
      }
    }

    String overallRisk = 'No Risk';
    PdfColor overallColor = PdfColor(22, 163, 74); // Green
    if (redCount > 0) {
      overallRisk = 'High Risk';
      overallColor = PdfColor(220, 38, 38); // Red
    } else if (yellowCount > 0) {
      overallRisk = 'Medium Risk';
      overallColor = PdfColor(217, 119, 6); // Orange/Amber
    }

    final now = DateTime.now();
    final dateFormatted = '${now.day}/${now.month}/${now.year} at ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // 3. Add first page
    PdfPage page = document.pages.add();
    final Size pageSize = page.getClientSize();
    double currentY = 0;

    // --- Header Section ---
    final PdfFont headerFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfFont subHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 9.5);
    final PdfFont italicFont = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.italic);

    // Top Brand Bar
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(15, 23, 42)), // Slate 900
      bounds: Rect.fromLTWH(0, currentY, pageSize.width, 42),
    );
    page.graphics.drawString(
      'LEGALTECH REAL ESTATE AI ASSISTANT',
      PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      bounds: Rect.fromLTWH(12, currentY + 14, pageSize.width - 24, 20),
    );
    page.graphics.drawString(
      'CONFIDENTIAL REPORT',
      PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(148, 163, 184)),
      bounds: Rect.fromLTWH(pageSize.width - 160, currentY + 16, 150, 20),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );

    currentY += 56;

    // Report Title
    page.graphics.drawString(
      'Legal Risk Assessment Report',
      headerFont,
      brush: PdfSolidBrush(PdfColor(15, 23, 42)),
      bounds: Rect.fromLTWH(0, currentY, pageSize.width, 24),
    );
    currentY += 26;

    // Document Metadata Subtitle
    final rawTitle = documentTitle.isNotEmpty ? documentTitle : 'Property Agreement';
    final cleanTitle = _sanitizeText(rawTitle);
    page.graphics.drawString(
      'Document: ${cleanTitle.isNotEmpty ? cleanTitle : 'Property Contract'}   |   Type: $sourceType   |   Generated: $dateFormatted',
      subHeaderFont,
      brush: PdfSolidBrush(PdfColor(100, 116, 139)),
      bounds: Rect.fromLTWH(0, currentY, pageSize.width, 16),
    );
    currentY += 24;

    // Divider
    page.graphics.drawLine(
      PdfPen(PdfColor(226, 232, 240), width: 1),
      Offset(0, currentY),
      Offset(pageSize.width, currentY),
    );
    currentY += 16;

    // --- Executive Summary Box ---
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(248, 250, 252)),
      pen: PdfPen(PdfColor(203, 213, 225), width: 1),
      bounds: Rect.fromLTWH(0, currentY, pageSize.width, 68),
    );

    // Overall Risk Badge
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(overallColor),
      bounds: Rect.fromLTWH(12, currentY + 14, 110, 24),
    );
    page.graphics.drawString(
      overallRisk.toUpperCase(),
      PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      bounds: Rect.fromLTWH(12, currentY + 20, 110, 20),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    // Summary Stats
    final summaryText = 'Total Clauses Analyzed: ${analysis.length}   |   '
        'High Risk (Red): $redCount   |   '
        'Warnings (Yellow): $yellowCount   |   '
        'Standard (Green): $greenCount';

    page.graphics.drawString(
      'Executive Assessment',
      PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(15, 23, 42)),
      bounds: Rect.fromLTWH(134, currentY + 12, pageSize.width - 146, 16),
    );
    page.graphics.drawString(
      summaryText,
      bodyFont,
      brush: PdfSolidBrush(PdfColor(71, 85, 105)),
      bounds: Rect.fromLTWH(134, currentY + 34, pageSize.width - 146, 20),
    );

    currentY += 84;

    // --- Detailed Clause Grid ---
    final PdfGrid grid = PdfGrid();
    grid.columns.add(count: 1);
    grid.columns[0].width = pageSize.width;

    // Grid Header
    final PdfGridRow headerRow = grid.headers.add(1)[0];
    headerRow.cells[0].value = 'Detailed Clause Analysis & RERA Risk Rationale';
    headerRow.cells[0].style = PdfGridCellStyle(
      backgroundBrush: PdfSolidBrush(PdfColor(15, 23, 42)),
      textBrush: PdfSolidBrush(PdfColor(255, 255, 255)),
      font: PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold),
      cellPadding: PdfPaddings(left: 10, top: 8, right: 10, bottom: 8),
    );

    // Grid Rows
    for (int i = 0; i < analysis.length; i++) {
      final item = analysis[i];
      final String category = (item['category'] ?? 'Standard').toString();
      final String rawClauseText = (item['text'] ?? '').toString().trim();
      final String rawReason = (item['reason'] ?? '').toString().trim();

      final String clauseText = _sanitizeText(rawClauseText);
      final String reason = _sanitizeText(rawReason);

      String label = 'STANDARD / COMPLIANT';
      PdfColor bgBadgeColor = PdfColor(241, 245, 249);

      if (category.toLowerCase().contains('red')) {
        label = 'HIGH RISK / NON-COMPLIANT';
        bgBadgeColor = PdfColor(254, 242, 242);
      } else if (category.toLowerCase().contains('yellow')) {
        label = 'CAUTION / MISSING SAFEGUARD';
        bgBadgeColor = PdfColor(255, 251, 235);
      } else if (category.toLowerCase().contains('green')) {
        label = 'STANDARD / COMPLIANT';
        bgBadgeColor = PdfColor(236, 253, 245);
      }

      final String cellText = 'Clause ${i + 1}:  $label\n\n'
          'Original Text:\n"${clauseText.isNotEmpty ? clauseText : rawClauseText}"\n\n'
          'Risk Assessment & Rationale:\n${reason.isNotEmpty ? reason : rawReason}';

      final PdfGridRow row = grid.rows.add();
      row.cells[0].value = cellText;
      row.cells[0].style = PdfGridCellStyle(
        backgroundBrush: PdfSolidBrush(bgBadgeColor),
        textBrush: PdfSolidBrush(PdfColor(15, 23, 42)),
        font: PdfStandardFont(PdfFontFamily.helvetica, 9.5),
        cellPadding: PdfPaddings(left: 12, top: 10, right: 12, bottom: 10),
      );
    }

    // Draw grid natively
    final PdfLayoutResult layoutResult = grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, currentY, pageSize.width, 0),
    )!;

    page = layoutResult.page;
    currentY = layoutResult.bounds.bottom + 20;

    // Disclaimer
    if (page.getClientSize().height - currentY < 40) {
      page = document.pages.add();
      currentY = 20;
    }

    const String disclaimer =
        'Disclaimer: This report is generated by AI for advisory & negotiation guidance only. '
        'It does not constitute formal legal representation under the Advocates Act, 1961. Always consult a registered property advocate.';

    final PdfTextElement disclaimerElement = PdfTextElement(
      text: disclaimer,
      font: italicFont,
      brush: PdfSolidBrush(PdfColor(148, 163, 184)),
      format: PdfStringFormat(lineSpacing: 2),
    );

    disclaimerElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, page.getClientSize().height - 30, page.getClientSize().width, 30),
    );

    // 4. Save and export file
    final List<int> bytes = await document.save();
    document.dispose();

    final safeFileName = 'Legal_Risk_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await saveAndLaunchPdf(bytes, safeFileName);
  }
}
