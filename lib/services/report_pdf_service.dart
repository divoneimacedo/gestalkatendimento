import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/report_call.dart';
import '../models/report_metrics.dart';
import 'report_service.dart';

class ReportPdfService {
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final _dateFormat = DateFormat('dd/MM/yyyy');

  static Future<void> shareReport({
    required List<ReportCall> calls,
    required ReportMetrics metrics,
    required ReportFilters filters,
  }) async {
    final bytes = await buildReport(
      calls: calls,
      metrics: metrics,
      filters: filters,
    );

    final fileDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'relatorio_completo_$fileDate.pdf',
    );
  }

  static Future<Uint8List> buildReport({
    required List<ReportCall> calls,
    required ReportMetrics metrics,
    required ReportFilters filters,
  }) async {
    final doc = pw.Document();
    final generatedAt = _dateTimeFormat.format(DateTime.now());
    final headerColor = PdfColor.fromInt(0xFFB5056D);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Pagina ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.Text(
            _pdfText('Relatório Completo - Resultados Detalhados'),
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(_pdfText('Gerado em: $generatedAt')),
          pw.Text(_pdfText(_filtersSummary(filters))),
          pw.SizedBox(height: 14),
          _metricsTable(metrics, headerColor),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Protocolo',
              'Data/Hora',
              'Empresa',
              'Canal',
              'Status',
              'TME',
              'TMA',
              'TMO',
            ],
            data: calls.map(_row).toList(),
            border: null,
            headerDecoration: pw.BoxDecoration(color: headerColor),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.all(4),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF5F7F7),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _metricsTable(ReportMetrics metrics, PdfColor headerColor) {
    return pw.TableHelper.fromTextArray(
      headers: const [
        'Total',
        'Atendidos',
        'Nao atendidos',
        'Taxa',
        'TME medio',
        'TMA medio',
        'TMO medio',
      ],
      data: [
        [
          metrics.totalCalls.toString(),
          metrics.attendedCount.toString(),
          metrics.notAttendedCount.toString(),
          '${metrics.attendedRate}%',
          metrics.tmeAvg,
          metrics.tmaAvg,
          metrics.tmoAvg,
        ],
      ],
      border: null,
      headerDecoration: pw.BoxDecoration(color: headerColor),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 8,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellPadding: const pw.EdgeInsets.all(4),
    );
  }

  static List<String> _row(ReportCall call) {
    return [
      _pdfText(call.protocol.isEmpty ? '-' : call.protocol),
      call.startTime == null ? '-' : _dateTimeFormat.format(call.startTime!),
      _pdfText(call.company.isEmpty ? '-' : call.company),
      _pdfText(call.channel.isEmpty ? '-' : call.channel),
      _pdfText(_translateStatus(call.status)),
      _pdfText(call.tme ?? '-'),
      _pdfText(call.tma ?? '-'),
      _pdfText(call.tmo ?? '-'),
    ];
  }

  static String _filtersSummary(ReportFilters filters) {
    final start = filters.startDate == null
        ? '-'
        : _dateFormat.format(filters.startDate!);
    final end =
        filters.endDate == null ? '-' : _dateFormat.format(filters.endDate!);
    final status =
        filters.status == null ? 'Todos' : _translateStatus(filters.status!);

    return 'Periodo: $start a $end | Status: $status';
  }

  static String _translateStatus(String status) {
    return switch (status) {
      'FINISHED' => 'Finalizado',
      'CANCELED' => 'Cancelado',
      'IN_PROGRESS' => 'Em atendimento',
      'WAITING_FOR_RESPONSE' => 'Aguardando',
      _ => status.isEmpty ? '-' : status,
    };
  }
}

String _pdfText(String value) {
  const replacements = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'Á': 'A',
    'À': 'A',
    'Â': 'A',
    'Ã': 'A',
    'Ä': 'A',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'É': 'E',
    'È': 'E',
    'Ê': 'E',
    'Ë': 'E',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'Í': 'I',
    'Ì': 'I',
    'Î': 'I',
    'Ï': 'I',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'Ó': 'O',
    'Ò': 'O',
    'Ô': 'O',
    'Õ': 'O',
    'Ö': 'O',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'Ú': 'U',
    'Ù': 'U',
    'Û': 'U',
    'Ü': 'U',
    'ç': 'c',
    'Ç': 'C',
    '–': '-',
    '—': '-',
    '’': "'",
    '“': '"',
    '”': '"',
  };

  var text = value;
  for (final entry in replacements.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  return text;
}
