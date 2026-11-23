import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'app_dirs.dart';
import 'i18n.dart';
import 'models.dart';
import 'rules.dart';
import 'tacho_link.dart';

enum ReportKind { day, week, twoWeeks, month }

String reportName(ReportKind k) {
  switch (k) {
    case ReportKind.day:
      return tr('Diário');
    case ReportKind.week:
      return tr('Semanal');
    case ReportKind.twoWeeks:
      return tr('Bissemanal');
    case ReportKind.month:
      return tr('Mensal');
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
  return tr('{0} a {1}', [fmtDate(from), fmtDate(last)]);
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

/// 1.7.4: "Local / nota" vazio leva as coordenadas do trecho.
String _noteOr(String note, double? lat, double? lon) {
  final n = note.trim();
  if (n.isNotEmpty) return n;
  final c = _coord(lat, lon);
  return c == '-' ? '' : c;
}

String _coord(double? lat, double? lon) => (lat == null || lon == null)
    ? '-'
    : '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';

/// Monta o PDF e devolve o arquivo (um por tipo: o novo substitui o antigo).
/// 1.8.6: [full] = completo (com o detalhe de cada trecho); simples = só
/// o resumo, as jornadas, as pausas/descansos e os avisos.
Future<File> buildReport(ReportKind kind, DateTime ref, List<Shift> all,
    {String driver = '', String plate = '', bool full = true}) async {
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
    // 1.12.9: amplitude não se soma (é de cada jornada): mostra a maior.
    final a = s.amplitude(now);
    if (a > amp) amp = a;
    for (final i in shiftIssues(all, s, now)) {
      issues.add('${fmtDate(s.start)}: $i');
    }
  }
  // Limites da semana e das duas semanas (pela condução no período).
  if (kind == ReportKind.week && drive > Limits.weeklyDrive) {
    issues.add(tr('Condução na semana de {0} (limite 56h).', [fmtDur(drive)]));
  }
  if (kind == ReportKind.twoWeeks && drive > Limits.fortnightDrive) {
    issues.add(tr('Condução em duas semanas de {0} (limite 90h).', [fmtDur(drive)]));
  }

  final doc = pw.Document(
      title: tr('TacoGuard - Relatório {0}', [reportName(kind)]), author: 'TacoGuard');

  final content = <pw.Widget>[
    pw.Row(children: [
      _box(tr('Condução'), fmtDur(drive)),
      _box(tr('Pausa'), fmtDur(pause)),
      _box(tr('Martelo'), fmtDur(work)),
      _box(tr('Carga/Descarga'), fmtDur(load)),
      _box(tr('Amplitude máx.'), fmtDur(amp)),
      _box(tr('Km'), fmtKm(km)),
    ]),
    pw.SizedBox(height: 12),
  ];

  // 1.12.8: período atual com o tacógrafo ligado: os totais do DTCO.
  final t = TachoLink.I;
  if (t.connected && !now.isBefore(from) && now.isBefore(to)) {
    String hm(int? m) =>
        m == null ? '—' : '${m ~/ 60}h${(m % 60).toString().padLeft(2, '0')}';
    final wk = t.minutes(0xF99B);
    final fn = t.fortnightDrive?.inMinutes;
    final boxes = <pw.Widget>[
      if (kind == ReportKind.day && t.minutes(0xF99A) != null)
        _box(tr('Condução hoje'), hm(t.minutes(0xF99A))),
      if (wk != null) _box(tr('Condução na semana'), '${hm(wk)} / 56h'),
      if (fn != null) _box(tr('Condução bissemanal'), '${hm(fn)} / 90h'),
      if (t.leftWeekMinutes != null)
        _box(tr('Falta conduzir na semana'), hm(t.leftWeekMinutes)),
      if (t.leftFortnightMinutes != null)
        _box(tr('Falta conduzir em 2 semanas'), hm(t.leftFortnightMinutes)),
    ];
    if (boxes.isNotEmpty) {
      content.add(pw.Text(
          '${tr('Tacógrafo (agora)')} - ${fmtDateTime(now)}',
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold, color: _blue)));
      content.add(pw.SizedBox(height: 4));
      content.add(pw.Row(children: boxes));
      content.add(pw.SizedBox(height: 12));
    }
  }

  if (list.isEmpty) {
    content.add(pw.Padding(
      padding: const pw.EdgeInsets.all(20),
      child: pw.Text(_t(tr('Nenhuma jornada registrada neste período.')),
          style: const pw.TextStyle(color: _grey)),
    ));
  } else {
    // Resumo por jornada.
    content.add(pw.Text(tr('Jornadas'),
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
              tr('Dia'),
              tr('Início'),
              tr('Fim'),
              tr('Amplitude'),
              tr('Condução'),
              tr('Pausa'),
              tr('Martelo'),
              tr('Carga/Desc.'),
              tr('Km')
            ])
              _cell(h, bold: true, color: PdfColors.white),
          ],
        ),
        for (final s in list)
          pw.TableRow(children: [
            _cell('${weekdayShort(s.start)} ${fmtDate(s.start)}'),
            _cell(fmtTime(s.start)),
            _cell(s.end == null ? tr('aberta') : fmtTime(s.end!)),
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

    // Pausas (15, 30, 45 min) e descansos (9 h, 11 h, 24 h, 45 h), cada um
    // com as coordenadas do local. O descanso fica no local onde a jornada
    // foi encerrada.
    final ordered = sorted(all);
    final rows = <pw.TableRow>[];
    for (final s in list) {
      for (final g in s.segments) {
        if (g.act != Act.pause && g.act != Act.unknown) continue;
        final d = g.dur(s.end ?? now);
        if (d < Limits.breakFirst) continue;
        rows.add(pw.TableRow(children: [
          _cell(fmtDateTime(g.start)),
          _cell(g.end == null ? tr('em curso') : fmtTime(g.end!)),
          _cell(fmtDur(d)),
          _cell(g.act == Act.unknown
              ? tr('{0} (a classificar)', [pauseLabel(d)])
              : pauseLabel(d)),
          _cell(_coord(g.lat, g.lon)),
          _cell(_noteOr(g.note, g.lat, g.lon)),
        ]));
      }
      if (s.end == null) continue;
      final i = ordered.indexWhere((x) => identical(x, s));
      final next = (i >= 0 && i + 1 < ordered.length) ? ordered[i + 1] : null;
      final restEnd = next?.start ?? now;
      final gap = restEnd.difference(s.end!);
      final k = restKind(gap);
      final bad = next != null && k == RestKind.tooShort;
      rows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: _light),
        children: [
          _cell(fmtDateTime(s.end!), bold: true),
          _cell(next == null ? tr('em curso') : fmtDateTime(next.start),
              bold: true),
          _cell(fmtDur(gap), bold: true),
          _cell(next == null && k == RestKind.tooShort
              ? tr('Descanso em curso')
              : restLabel(k),
              bold: true, color: bad ? _red : null),
          _cell(_coord(s.endLat, s.endLon), bold: true),
          _cell(_noteOr('', s.endLat, s.endLon)),
        ],
      ));
    }
    if (rows.isNotEmpty) {
      content.add(pw.Text(tr('Pausas e descansos, com o local'),
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold, color: _blue)));
      content.add(pw.SizedBox(height: 4));
      content.add(pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.9),
          1: pw.FlexColumnWidth(1.9),
          2: pw.FlexColumnWidth(1),
          3: pw.FlexColumnWidth(2.6),
          4: pw.FlexColumnWidth(2.3),
          5: pw.FlexColumnWidth(1.8),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _blue),
            children: [
              for (final h in [
                tr('Início'),
                tr('Fim'),
                tr('Duração'),
                tr('Tipo'),
                tr('Coordenadas'),
                tr('Local / nota')
              ])
                _cell(h, bold: true, color: PdfColors.white),
            ],
          ),
          ...rows,
        ],
      ));
      content.add(pw.SizedBox(height: 12));
    }

    // Avisos.
    content.add(pw.Text(tr('Avisos e infrações'),
        style: pw.TextStyle(
            fontSize: 12, fontWeight: pw.FontWeight.bold, color: _blue)));
    content.add(pw.SizedBox(height: 4));
    if (issues.isEmpty) {
      content.add(pw.Text(_t(tr('Nenhum limite excedido neste período.')),
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

    // Detalhe: cada trecho, com hora e local (só no relatório completo).
    if (full) {
    content.add(pw.Text(tr('Detalhe das atividades'),
        style: pw.TextStyle(
            fontSize: 12, fontWeight: pw.FontWeight.bold, color: _blue)));
    for (final s in list) {
      content.add(pw.SizedBox(height: 8));
      content.add(pw.Container(
        width: double.infinity,
        color: _light,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(
            _t(tr('{0} {1}  -  início {2} ({3}){4}', [weekdayShort(s.start), fmtDate(s.start), fmtTime(s.start), _coord(s.startLat, s.startLon), s.end == null ? '' : '  -  fim ${fmtTime(s.end!)} (${_coord(s.endLat, s.endLon)})'])),
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
              tr('Início'),
              tr('Fim'),
              tr('Duração'),
              tr('Atividade'),
              tr('Coordenadas / km'),
              tr('Local / nota')
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
              _cell(_noteOr(g.note, g.lat, g.lon)),
            ]),
        ],
      ));
    }
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
                pw.Text(_t(tr('Relatório {0}  -  {1}', [reportName(kind), rangeLabel(from, to)])),
                    style: const pw.TextStyle(fontSize: 11, color: _grey)),
              ],
            ),
          ),
          if (driver.isNotEmpty || plate.isNotEmpty)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (driver.isNotEmpty)
                  pw.Text(_t(tr('Motorista: {0}', [driver])),
                      style: const pw.TextStyle(fontSize: 10, color: _grey)),
                if (plate.isNotEmpty)
                  pw.Text(_t(tr('Matrícula: {0}', [plate])),
                      style: const pw.TextStyle(fontSize: 10, color: _grey)),
              ],
            ),
        ],
      ),
    ),
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
            _t(tr('Gerado em {0}. Auxiliar do motorista: o registro oficial é o do tacógrafo.', [fmtDateTime(now)])),
            style: const pw.TextStyle(fontSize: 7, color: _grey)),
        pw.Text('${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _grey)),
      ],
    ),
    build: (ctx) => content,
  ));

  final dir = await AppDirs.docs();
  final f = File('${dir.path}/TacoGuard-Relatorio-${reportName(kind)}${full ? '' : '-simples'}.pdf'
      .replaceAll('á', 'a'));
  await f.writeAsBytes(await doc.save(), flush: true);
  return f;
}
