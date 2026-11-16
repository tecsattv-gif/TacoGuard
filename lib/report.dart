import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'models.dart';
import 'rules.dart';

enum ReportKind { day, week, twoWeeks, month }

String reportName(ReportKind k) {
  switch (k) {
    case ReportKind.day:
      return 'Diário';
    case ReportKind.week:
      return 'Semanal';
    case ReportKind.twoWeeks:
      return 'Bissemanal';
    case ReportKind.month:
      return 'Mensal';
  }
}

/// Período [from, to) do relatório que contém [ref].
(DateTime, DateTime) reportRange(ReportKind k, DateTime ref) {
  final day = DateTime(ref.year, ref.month, ref.day);
  switch (k) {
    case ReportKind.day:
      return (day, day.add(const Duration(days: 1)));
    case ReportKind.week:
      final mon = day.subtract(Duration(days: day.weekday - 1));
      return (mon, mon.add(const Duration(days: 7)));
    case ReportKind.twoWeeks:
      final mon = day.subtract(Duration(days: day.weekday - 1 + 7));
      return (mon, mon.add(const Duration(days: 14)));
    case ReportKind.month:
      return (DateTime(ref.year, ref.month), DateTime(ref.year, ref.month + 1));
  }
}

String rangeLabel(DateTime from, DateTime to) {
  final last = to.subtract(const Duration(days: 1));
  if (last.year == from.year &&
      last.month == from.month &&
      last.day == from.day) {
    return '${weekdayShort(from)} ${fmtDate(from)}';
  }
  return '${fmtDate(from)} a ${fmtDate(last)}';
}

/// Jornadas que começaram dentro do período.
List<Shift> shiftsIn(List<Shift> all, DateTime from, DateTime to) => sorted(all)
    .where((s) => !s.start.isBefore(from) && s.start.isBefore(to))
    .toList();

/// Letras sem acento não são problema, mas alguns símbolos não existem na
/// fonte padrão do PDF: troca por equivalentes simples.
String _t(String s) => s
    .replaceAll('…', '...')
    .replaceAll('→', '->')
    .replaceAll('≥', '>=')
    .replaceAll('•', '-');

const _blue = PdfColor.fromInt(0xFF0F2A4A);
const _teal = PdfColor.fromInt(0xFF0F9E8E);
const _grey = PdfColor.fromInt(0xFF5B6B80);
const _light = PdfColor.fromInt(0xFFEFF4FA);
const _red = PdfColor.fromInt(0xFFC62828);

pw.Widget _cell(String text,
        {bool bold = false, PdfColor? color, pw.TextAlign? align}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(_t(text),
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

pw.Widget _box(String label, String value) => pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 3),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
            color: _light, borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(_t(label),
                style: const pw.TextStyle(fontSize: 8, color: _grey)),
            pw.SizedBox(height: 2),
            pw.Text(_t(value),
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _blue)),
          ],
        ),
      ),
    );

String _coord(double? lat, double? lon) => (lat == null || lon == null)
    ? '-'
    : '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';

/// Monta o PDF e devolve o arquivo (um por tipo: o novo substitui o antigo).
Future<File> buildReport(ReportKind kind, DateTime ref, List<Shift> all,
    {String driver = ''}) async {
  final now = DateTime.now();
  final (from, to) = reportRange(kind, ref);
  final list = shiftsIn(all, from, to);

  var drive = Duration.zero,
      pause = Duration.zero,
      work = Duration.zero,
      load = Duration.zero,
      amp = Duration.zero;
  final issues = <String>[];
  var km = 0.0;
  for (final s in list) {
    km += s.km;
    drive += s.total(Act.drive, now);
    pause += s.total(Act.pause, now) + s.total(Act.unknown, now);
    work += s.total(Act.work, now);
    load += s.total(Act.load, now);
    amp += s.amplitude(now);
    for (final i in shiftIssues(all, s, now)) {
      issues.add('${fmtDate(s.start)}: $i');
    }
  }
  // Limites da semana e das duas semanas (pela condução no período).
  if (kind == ReportKind.week && drive > Limits.weeklyDrive) {
    issues.add('Condução na semana de ${fmtDur(drive)} (limite 56h).');
  }
  if (kind == ReportKind.twoWeeks && drive > Limits.fortnightDrive) {
    issues.add('Condução em duas semanas de ${fmtDur(drive)} (limite 90h).');
  }

  final doc = pw.Document(
      title: 'TacoGuard - Relatório ${reportName(kind)}', author: 'TacoGuard');

  final content = <pw.Widget>[
    pw.Row(children: [
      _box('Condução', fmtDur(drive)),
      _box('Pausa', fmtDur(pause)),
      _box('Martelo', fmtDur(work)),
      _box('Carga/Descarga', fmtDur(load)),
      _box('Amplitude', fmtDur(amp)),
      _box('Km', fmtKm(km)),
    ]),
    pw.SizedBox(height: 12),
  ];

  if (list.isEmpty) {
    content.add(pw.Padding(
      padding: const pw.EdgeInsets.all(20),
      child: pw.Text(_t('Nenhuma jornada registrada neste período.'),
          style: const pw.TextStyle(color: _grey)),
    ));
  } else {
    // Resumo por jornada.
    content.add(pw.Text('Jornadas',
        style: pw.TextStyle(
            fontSize: 12, fontWeight: pw.FontWeight.bold, color: _blue)));
    content.add(pw.SizedBox(height: 4));
    content.add(pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.3),
        4: pw.FlexColumnWidth(1.3),
        5: pw.FlexColumnWidth(1.2),
        6: pw.FlexColumnWidth(1.2),
        7: pw.FlexColumnWidth(1.4),
        8: pw.FlexColumnWidth(1.1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _blue),
          children: [
            for (final h in [
              'Dia',
              'Início',
              'Fim',
              'Amplitude',
              'Condução',
              'Pausa',
              'Martelo',
              'Carga/Desc.',
              'Km'
            ])
              _cell(h, bold: true, color: PdfColors.white),
          ],
        ),
        for (final s in list)
          pw.TableRow(children: [
            _cell('${weekdayShort(s.start)} ${fmtDate(s.start)}'),
            _cell(fmtTime(s.start)),
            _cell(s.end == null ? 'aberta' : fmtTime(s.end!)),
            _cell(fmtDur(s.amplitude(now))),
            _cell(fmtDur(s.total(Act.drive, now))),
            _cell(fmtDur(s.total(Act.pause, now) + s.total(Act.unknown, now))),
            _cell(fmtDur(s.total(Act.work, now))),
            _cell(fmtDur(s.total(Act.load, now))),
            _cell(fmtKm(s.km)),
          ]),
      ],
    ));
    content.add(pw.SizedBox(height: 12));

    // Descansos entre as jornadas.
    final ordered = sorted(all);
    final rests = <pw.TableRow>[];
    for (final s in list) {
      final i = ordered.indexWhere((x) => identical(x, s));
      if (i <= 0 || ordered[i - 1].end == null) continue;
      final gap = s.start.difference(ordered[i - 1].end!);
      final k = restKind(gap);
      rests.add(pw.TableRow(children: [
        _cell('${fmtDateTime(ordered[i - 1].end!)} a ${fmtDateTime(s.start)}'),
        _cell(fmtDur(gap)),
        _cell(restLabel(k),
            color: k == RestKind.tooShort ? _red : null,
            bold: k == RestKind.tooShort),
      ]));
    }
    if (rests.isNotEmpty) {
      content.add(pw.Text('Descansos',
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold, color: _blue)));
      content.add(pw.SizedBox(height: 4));
      content.add(pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(1),
          2: pw.FlexColumnWidth(2.6),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _blue),
            children: [
              _cell('Período', bold: true, color: PdfColors.white),
              _cell('Duração', bold: true, color: PdfColors.white),
              _cell('Tipo', bold: true, color: PdfColors.white),
            ],
          ),
          ...rests,
        ],
      ));
      content.add(pw.SizedBox(height: 12));
    }

    // Avisos.
    content.add(pw.Text('Avisos e infrações',
        style: pw.TextStyle(
            fontSize: 12, fontWeight: pw.FontWeight.bold, color: _blue)));
    content.add(pw.SizedBox(height: 4));
    if (issues.isEmpty) {
      content.add(pw.Text(_t('Nenhum limite excedido neste período.'),
          style: const pw.TextStyle(fontSize: 10, color: _teal)));
    } else {
      for (final i in issues) {
        content.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(_t('- $i'),
              style: const pw.TextStyle(fontSize: 10, color: _red)),
        ));
      }
    }
    content.add(pw.SizedBox(height: 14));

    // Detalhe: cada trecho, com hora e local.
    content.add(pw.Text('Detalhe das atividades',
        style: pw.TextStyle(
            fontSize: 12, fontWeight: pw.FontWeight.bold, color: _blue)));
    for (final s in list) {
      content.add(pw.SizedBox(height: 8));
      content.add(pw.Container(
        width: double.infinity,
        color: _light,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(
            _t('${weekdayShort(s.start)} ${fmtDate(s.start)}  -  '
                'início ${fmtTime(s.start)} (${_coord(s.startLat, s.startLon)})'
                '${s.end == null ? '' : '  -  fim ${fmtTime(s.end!)} (${_coord(s.endLat, s.endLon)})'}'),
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold, color: _blue)),
      ));
      content.add(pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.3),
        columnWidths: const {
          0: pw.FlexColumnWidth(1),
          1: pw.FlexColumnWidth(1),
          2: pw.FlexColumnWidth(1),
          3: pw.FlexColumnWidth(1.7),
          4: pw.FlexColumnWidth(2.4),
          5: pw.FlexColumnWidth(2.4),
        },
        children: [
          pw.TableRow(children: [
            for (final h in [
              'Início',
              'Fim',
              'Duração',
              'Atividade',
              'Coordenadas / km',
              'Local / nota'
            ])
              _cell(h, bold: true, color: _grey),
          ]),
          for (final g in s.segments)
            pw.TableRow(children: [
              _cell(fmtTime(g.start)),
              _cell(g.end == null ? '-' : fmtTime(g.end!)),
              _cell(fmtDur(g.dur(s.end ?? now))),
              _cell(actLabel(g.act), bold: g.act != Act.drive),
              _cell(g.act == Act.drive
                  ? (g.km > 0 ? fmtKm(g.km) : '')
                  : _coord(g.lat, g.lon)),
              _cell(g.note),
            ]),
        ],
      ));
    }
  }

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
    header: (ctx) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _teal, width: 2))),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('TacoGuard',
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: _blue)),
                pw.Text(_t('Relatório ${reportName(kind)}  -  '
                    '${rangeLabel(from, to)}'),
                    style: const pw.TextStyle(fontSize: 11, color: _grey)),
              ],
            ),
          ),
          if (driver.isNotEmpty)
            pw.Text(_t('Motorista: $driver'),
                style: const pw.TextStyle(fontSize: 10, color: _grey)),
        ],
      ),
    ),
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
            _t('Gerado em ${fmtDateTime(now)}. Auxiliar do motorista: o '
                'registro oficial é o do tacógrafo.'),
            style: const pw.TextStyle(fontSize: 7, color: _grey)),
        pw.Text('${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _grey)),
      ],
    ),
    build: (ctx) => content,
  ));

  final dir = await getApplicationDocumentsDirectory();
  final f = File('${dir.path}/TacoGuard-Relatorio-${reportName(kind)}.pdf'
      .replaceAll('á', 'a'));
  await f.writeAsBytes(await doc.save(), flush: true);
  return f;
}
