import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'i18n.dart';
import 'models.dart';
import 'rules.dart';
import 'tacho_link.dart';
import 'tacho_page.dart';
import 'theme.dart';
import 'tracker.dart';

/// 1.13.0: tela de gráficos (atalho no cartão do tacógrafo ao vivo).
/// Tacógrafo agora (barras contra os limites), condução por dia e por
/// semana, atividades da semana e quilómetros por dia. Tudo desenhado à
/// mão (sem pacotes novos) e atualizado ao vivo.
class ChartsPage extends StatelessWidget {
  const ChartsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Gráficos'))),
      body: ListenableBuilder(
        listenable: Listenable.merge([Tracker.I, TachoLink.I]),
        builder: (context, _) {
          final now = DateTime.now();
          final shifts = Tracker.I.shifts;
          final t = TachoLink.I;
          final children = <Widget>[];

          if (t.connected && t.didData.isNotEmpty) {
            children.add(_tachoNow(t));
          }

          if (shifts.isEmpty) {
            children.add(_Section(
              title: tr('Condução por dia'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                    tr('Ainda não há jornadas registadas no app.'),
                    style: const TextStyle(color: TG.muted)),
              ),
            ));
          } else {
            children.addAll([
              _dailyDrive(shifts, now),
              _weeklyDrive(shifts, now),
              _weekActivities(shifts, now),
              _dailyKm(shifts, now),
            ]);
          }

          return LayoutBuilder(builder: (context, c) {
            // Tablet / deitado: duas colunas.
            if (c.maxWidth >= 720) {
              final left = <Widget>[], right = <Widget>[];
              for (var i = 0; i < children.length; i++) {
                (i.isEven ? left : right).add(children[i]);
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(children: left)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(children: right)),
                    ]),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: children,
            );
          });
        },
      ),
    );
  }

  // ---------- Tacógrafo agora ----------
  Widget _tachoNow(TachoLink t) {
    final cont = TachoLiveCard.value(t, 0xF923);
    final today = TachoLiveCard.value(t, 0xF99A);
    final week = TachoLiveCard.value(t, 0xF99B);
    final fn = TachoLiveCard.value(t, -1);
    final rows = <Widget>[
      if (cont != null) _LimitBar(tr('Condução contínua'), cont, 270),
      if (today != null)
        _LimitBar(tr('Condução hoje'), today, today > 9 * 60 ? 600 : 540),
      if (week != null) _LimitBar(tr('Condução na semana'), week, 56 * 60),
      if (fn != null) _LimitBar(tr('Condução bissemanal'), fn, 90 * 60),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: tr('Tacógrafo (agora)'),
      icon: Icons.bluetooth_connected,
      child: Column(children: rows),
    );
  }

  // ---------- Condução por dia (14 dias) ----------
  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Jornada conta no dia em que começou (como nos relatórios).
  static List<Shift> _shiftsOn(List<Shift> all, DateTime day) =>
      [for (final s in all) if (_day(s.start) == day) s];

  Widget _dailyDrive(List<Shift> shifts, DateTime now) {
    final today = _day(now);
    final days = [
      for (var i = 13; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i)
    ];
    final vals = <double>[];
    for (final d in days) {
      var m = 0;
      for (final s in _shiftsOn(shifts, d)) {
        m += s.total(Act.drive, now).inMinutes;
      }
      vals.add(m / 60);
    }
    return _Section(
      title: tr('Condução por dia'),
      subtitle: tr('últimos 14 dias'),
      child: _BarChart(
        values: vals,
        labels: [for (final d in days) '${d.day}'],
        highlightLast: true,
        refLines: const [(9.0, '9 h'), (10.0, '10 h')],
        minMax: 11,
        colorOf: (v) => v > 10
            ? TG.danger
            : v > 9
                ? TG.warn
                : TG.drive,
        fmt: _hmFromHours,
      ),
    );
  }

  // ---------- Condução por semana (8 semanas, UTC como o tacógrafo) ----------
  Widget _weeklyDrive(List<Shift> shifts, DateTime now) {
    final ws = weekStartUtc(now);
    final starts = [
      for (var i = 7; i >= 0; i--) ws.subtract(Duration(days: 7 * i))
    ];
    final vals = [
      for (final s in starts)
        driveBetween(shifts, s, s.add(const Duration(days: 7)), now)
                .inMinutes /
            60
    ];
    // Bissemanal das 2 últimas semanas (texto por baixo).
    final last2 = vals.length >= 2 ? vals[vals.length - 1] + vals[vals.length - 2] : 0.0;
    return _Section(
      title: tr('Condução por semana'),
      subtitle: tr('últimas 8 semanas'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _BarChart(
          values: vals,
          labels: [
            for (final s in starts) '${s.toLocal().day}/${s.toLocal().month}'
          ],
          highlightLast: true,
          refLines: const [(56.0, '56 h')],
          minMax: 60,
          colorOf: (v) => TG.level(v / 56),
          fmt: _hmFromHours,
        ),
        const SizedBox(height: 10),
        _LimitBar(tr('Bissemanal (esta + anterior)'), (last2 * 60).round(),
            90 * 60),
      ]),
    );
  }

  // ---------- Atividades da semana (donut) ----------
  Widget _weekActivities(List<Shift> shifts, DateTime now) {
    final from = weekStartUtc(now);
    final to = from.add(const Duration(days: 7));
    final tot = <Act, int>{for (final a in Act.values) a: 0};
    for (final sh in shifts) {
      for (final s in sh.segments) {
        final e = s.end ?? sh.end ?? now;
        final a = s.start.isBefore(from) ? from : s.start;
        final b = e.isAfter(to) ? to : e;
        final d = b.difference(a);
        if (!d.isNegative) tot[s.act] = tot[s.act]! + d.inMinutes;
      }
    }
    final acts = [for (final a in Act.values) if (tot[a]! > 0) a];
    final sum = acts.fold<int>(0, (p, a) => p + tot[a]!);
    return _Section(
      title: tr('Atividades da semana'),
      subtitle: tr('dentro das jornadas'),
      child: sum == 0
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(tr('Sem atividades nesta semana.'),
                  style: const TextStyle(color: TG.muted)),
            )
          : Row(children: [
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _DonutPainter([
                    for (final a in acts) (tot[a]! / sum, TG.act(a))
                  ]),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_hm(sum),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 18)),
                      Text(tr('total'),
                          style:
                              const TextStyle(color: TG.muted, fontSize: 12)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final a in acts)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                    color: TG.act(a),
                                    borderRadius: BorderRadius.circular(3))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(actLabel(a),
                                    overflow: TextOverflow.ellipsis)),
                            Text(_hm(tot[a]!),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ])),
                            SizedBox(
                              width: 44,
                              child: Text(
                                  '${(tot[a]! * 100 / sum).round()}%',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      color: TG.muted, fontSize: 12)),
                            ),
                          ]),
                        ),
                    ]),
              ),
            ]),
    );
  }

  // ---------- Km por dia (14 dias) ----------
  Widget _dailyKm(List<Shift> shifts, DateTime now) {
    final today = _day(now);
    final days = [
      for (var i = 13; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i)
    ];
    final vals = [
      for (final d in days)
        _shiftsOn(shifts, d).fold<double>(0, (p, s) => p + s.km)
    ];
    final total = vals.fold<double>(0, (p, v) => p + v);
    return _Section(
      title: tr('Quilómetros por dia'),
      subtitle: '${tr('últimos 14 dias')} · ${total.round()} km',
      child: _BarChart(
        values: vals,
        labels: [for (final d in days) '${d.day}'],
        highlightLast: true,
        refLines: const <(double, String)>[],
        minMax: 100,
        colorOf: (_) => TG.accent,
        fmt: (v) => '${v.round()}',
      ),
    );
  }

  static String _hm(int m) => '${m ~/ 60}h${(m % 60).toString().padLeft(2, '0')}';
  static String _hmFromHours(double h) => _hm((h * 60).round());
}

// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;
  const _Section(
      {required this.title, this.subtitle, this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[
              Icon(icon, color: TG.accent, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ]),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!,
                  style: const TextStyle(color: TG.muted, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }
}

/// Linha "nome — valor / limite" com barra verde, amarela ou vermelha.
class _LimitBar extends StatelessWidget {
  final String label;
  final int minutes;
  final int limit;
  const _LimitBar(this.label, this.minutes, this.limit);

  @override
  Widget build(BuildContext context) {
    final f = limit == 0 ? 0.0 : minutes / limit;
    final c = TG.level(f);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label)),
          Text('${ChartsPage._hm(minutes)} / ${ChartsPage._hm(limit)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: f.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: TG.line,
            valueColor: AlwaysStoppedAnimation(c),
          ),
        ),
      ]),
    );
  }
}

/// Gráfico de barras simples com linhas de referência (ex.: 9 h, 10 h).
/// Tocar numa barra mostra o valor dela.
class _BarChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final List<(double, String)> refLines;
  final double minMax;
  final bool highlightLast;
  final Color Function(double) colorOf;
  final String Function(double) fmt;
  const _BarChart({
    required this.values,
    required this.labels,
    required this.refLines,
    required this.minMax,
    required this.colorOf,
    required this.fmt,
    this.highlightLast = false,
  });

  @override
  State<_BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<_BarChart> {
  int? _sel;

  @override
  Widget build(BuildContext context) {
    final n = widget.values.length;
    final sel = _sel ?? (widget.highlightLast ? n - 1 : null);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (sel != null && sel < n)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            '${widget.labels[sel]}: ${widget.fmt(widget.values[sel])}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      LayoutBuilder(builder: (context, c) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final i = (d.localPosition.dx / (c.maxWidth / n))
                .floor()
                .clamp(0, n - 1);
            setState(() => _sel = i);
          },
          child: SizedBox(
            width: c.maxWidth,
            height: 170,
            child: CustomPaint(
              painter: _BarPainter(
                values: widget.values,
                labels: widget.labels,
                refLines: widget.refLines,
                minMax: widget.minMax,
                colorOf: widget.colorOf,
                selected: sel,
              ),
            ),
          ),
        );
      }),
    ]);
  }
}

class _BarPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final List<(double, String)> refLines;
  final double minMax;
  final Color Function(double) colorOf;
  final int? selected;
  _BarPainter({
    required this.values,
    required this.labels,
    required this.refLines,
    required this.minMax,
    required this.colorOf,
    required this.selected,
  });

  void _text(Canvas c, String s, Offset at, Color col, double size,
      {bool center = true, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              color: col,
              fontSize: size,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(center ? at.dx - tp.width / 2 : at.dx, at.dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const bottom = 20.0; // espaço das legendas
    final h = size.height - bottom;
    final n = values.length;
    if (n == 0) return;
    var maxV = minMax;
    for (final v in values) {
      maxV = math.max(maxV, v);
    }
    maxV *= 1.08;
    double y(double v) => h - (v / maxV) * h;

    // base
    canvas.drawLine(Offset(0, h), Offset(size.width, h),
        Paint()
          ..color = TG.line
          ..strokeWidth = 1);

    final slot = size.width / n;
    final bw = math.max(4.0, slot * 0.62);
    for (var i = 0; i < n; i++) {
      final v = values[i];
      final cx = slot * i + slot / 2;
      final top = y(v);
      final col = colorOf(v);
      final sel = i == selected;
      if (v > 0) {
        final r = RRect.fromRectAndCorners(
          Rect.fromLTRB(cx - bw / 2, top, cx + bw / 2, h),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(
            r, Paint()..color = sel ? col : col.withValues(alpha: 0.75));
      }
      if (sel) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(cx - slot / 2 + 1, 0, cx + slot / 2 - 1, h),
              const Radius.circular(6)),
          Paint()..color = Colors.white.withValues(alpha: 0.06),
        );
      }
      // legendas: todas se couberem, senão uma sim, uma não
      if (slot >= 22 || i.isEven || i == n - 1) {
        _text(canvas, labels[i], Offset(cx, h + 4),
            sel ? TG.text : TG.muted, 11,
            bold: sel);
      }
    }

    // linhas de referência (tracejadas)
    for (final (v, name) in refLines) {
      final yy = y(v);
      final p = Paint()
        ..color = TG.muted.withValues(alpha: 0.8)
        ..strokeWidth = 1;
      for (double x = 0; x < size.width; x += 8) {
        canvas.drawLine(
            Offset(x, yy), Offset(math.min(x + 4, size.width), yy), p);
      }
      _text(canvas, name, Offset(size.width - 2, yy - 15), TG.muted, 11,
          center: false);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter o) =>
      o.values != values || o.selected != selected;
}

class _DonutPainter extends CustomPainter {
  final List<(double, Color)> parts;
  _DonutPainter(this.parts);

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2 - 9;
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = TG.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18);
    var a = -math.pi / 2;
    for (final (f, col) in parts) {
      final sweep = f * 2 * math.pi;
      canvas.drawArc(
          rect,
          a + 0.02,
          math.max(0.0, sweep - 0.04),
          false,
          Paint()
            ..color = col
            ..style = PaintingStyle.stroke
            ..strokeWidth = 18);
      a += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter o) => true;
}
