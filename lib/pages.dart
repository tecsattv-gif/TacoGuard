import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'i18n.dart';
import 'models.dart';
import 'popup.dart';
import 'report.dart';
import 'rules.dart';
import 'theme.dart';
import 'tracker.dart';
import 'update_service.dart';

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// 1.6.5: pergunta antes de gravar uma edição. Devolve true se confirmou.
Future<bool> confirmEdit(BuildContext context, String title, String text,
    {String? ok}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.edit_rounded, size: 32),
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancelar'))),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ok ?? tr('Confirmar'))),
      ],
    ),
  );
  return r == true;
}

/// 1.6.5: barra com "Desfazer" e contagem de 8 segundos depois de apagar.
void showUndo(ScaffoldMessengerState m, String text, VoidCallback onUndo,
    {int seconds = 8}) {
  m.hideCurrentSnackBar();
  var undone = false;
  final ctl = m.showSnackBar(SnackBar(
    duration: Duration(seconds: seconds),
    behavior: SnackBarBehavior.floating,
    content: _Countdown(text: text, seconds: seconds),
    action: SnackBarAction(
      label: tr('DESFAZER'),
      onPressed: () {
        if (undone) return;
        undone = true;
        onUndo();
      },
    ),
  ));
  // Garante que some aos 8 s mesmo quando o Android mantém barras com ação.
  final t = Timer(Duration(seconds: seconds), ctl.close);
  ctl.closed.then((_) => t.cancel());
}

class _Countdown extends StatefulWidget {
  final String text;
  final int seconds;
  const _Countdown({required this.text, required this.seconds});
  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late int _left = widget.seconds;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left = (_left - 1).clamp(0, widget.seconds));
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 26,
        height: 26,
        child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(
              value: _left / widget.seconds,
              strokeWidth: 3,
              color: Colors.white),
          Text('$_left',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ]),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(widget.text)),
    ]);
  }
}

Future<void> openMap(BuildContext context, double lat, double lon) async {
  try {
    await AndroidIntent(
      action: 'action_view',
      data: 'geo:$lat,$lon?q=$lat,$lon',
      flags: const [Flag.FLAG_ACTIVITY_NEW_TASK],
    ).launch();
  } catch (_) {
    if (context.mounted) _snack(context, tr('Não foi possível abrir o mapa.'));
  }
}

// ======================= Linha do tempo =======================

/// Lista dos trechos de uma jornada; tocar num trecho permite corrigir.
class SegmentList extends StatelessWidget {
  final Shift shift;
  const SegmentList({super.key, required this.shift});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final segs = shift.segments.reversed.toList();
    return Column(children: [
      for (final s in segs)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            onTap: () => _edit(context, s),
            child: Row(children: [
              Container(
                width: 6,
                height: 44,
                decoration: BoxDecoration(
                    color: TG.act(s.act),
                    borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 10),
              ActIcon(s.act, color: TG.act(s.act), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        s.act == Act.pause &&
                                s.dur(shift.end ?? now) >= Limits.breakFirst
                            ? pauseLabel(s.dur(shift.end ?? now))
                            : actLabel(s.act),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(
                        '${fmtTime(s.start)} - ${s.end == null ? tr('agora') : fmtTime(s.end!)}${s.act == Act.drive && s.km > 0 ? '  •  ${fmtKm(s.km)}' : ''}${s.note.isEmpty ? '' : '  •  ${s.note}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: TG.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              if (s.act != Act.drive && s.hasCoords)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child:
                      Icon(Icons.place_rounded, size: 16, color: TG.muted),
                ),
              Text(fmtDur(s.dur(shift.end ?? now)),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
    ]);
  }

  void _edit(BuildContext context, Segment s) {
    final note = TextEditingController(text: s.note);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
       Future<void> saveNote(String v) async {
        if (v.trim() == s.note) {
          Navigator.pop(ctx);
          return;
        }
        final ok = await confirmEdit(
            ctx,
            tr('Salvar a alteração?'),
            v.trim().isEmpty
                ? tr('A nota "{0}" deste trecho vai ser apagada.', [s.note])
                : tr('A nota deste trecho passa a ser "{0}".', [v.trim()]),
            ok: tr('Salvar'));
        if (!ok || !ctx.mounted) return;
        Tracker.I.setNote(s, v);
        Navigator.pop(ctx);
       }
       return Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 18,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${fmtTime(s.start)} - ${s.end == null ? tr('agora') : fmtTime(s.end!)}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(tr('Corrigir a atividade deste trecho'),
                  style: TextStyle(color: TG.muted)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in [Act.drive, Act.pause, Act.work, Act.load])
                  ChoiceChip(
                    avatar: ActIcon(a, size: 18, color: TG.act(a)),
                    label: Text(actLabel(a)),
                    selected: s.act == a,
                    onSelected: (_) async {
                      if (s.act == a) return;
                      final ok = await confirmEdit(
                          ctx,
                          tr('Mudar a atividade?'),
                          tr('O trecho das {0} passa de {1} para {2}. Os tempos do dia e da semana são recalculados.', [fmtTime(s.start), actLabel(s.act), actLabel(a)]),
                          ok: tr('Mudar'));
                      if (!ok || !ctx.mounted) return;
                      Tracker.I.reclassify(s, a);
                      Navigator.pop(ctx);
                    },
                  ),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: note,
                decoration: InputDecoration(
                    hintText: tr('Nome do local ou nota (opcional)')),
                onSubmitted: (v) => saveNote(v),
              ),
              const SizedBox(height: 12),
              Row(children: [
                if (s.hasCoords)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => openMap(ctx, s.lat!, s.lon!),
                      icon: const Icon(Icons.map_rounded),
                      label: Text(
                          '${s.lat!.toStringAsFixed(4)}, ${s.lon!.toStringAsFixed(4)}',
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                if (s.hasCoords) const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => saveNote(note.text),
                    child: Text(tr('Salvar')),
                  ),
                ),
              ]),
            ],
          ),
        ),
      );
      },
    );
  }
}

// ======================= Histórico =======================

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _t = Tracker.I;

  @override
  void initState() {
    super.initState();
    _t.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final list = sorted(_t.shifts).reversed.toList();
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(tr('Ainda não há jornadas.\nInicie a primeira na tela Hoje.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: TG.muted, fontSize: 15)),
        ),
      );
    }
    final ordered = sorted(_t.shifts);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final s = list[i];
        final issues = shiftIssues(_t.shifts, s, now)
            .where((x) => x != tr('Há paradas ainda não classificadas (contadas como pausa).'))
            .length;
        final idx = ordered.indexWhere((x) => identical(x, s));
        String? rest;
        if (idx > 0 && ordered[idx - 1].end != null) {
          final gap = s.start.difference(ordered[idx - 1].end!);
          rest = tr('Descanso antes: {0}', [fmtDur(gap)]);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TCard(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ShiftDetailPage(shift: s))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                        '${weekdayShort(s.start)} ${fmtDate(s.start)}',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  if (s.open)
                    _Pill(tr('Aberta'), TG.accent)
                  else if (issues > 0)
                    _Pill(issues > 1 ? tr('{0} avisos', [issues]) : tr('{0} aviso', [issues]), TG.danger)
                  else
                    const _Pill('OK', TG.ok),
                ]),
                const SizedBox(height: 2),
                Text(
                    '${fmtTime(s.start)} - ${s.end == null ? tr('agora') : fmtTime(s.end!)}  •  ${fmtKm(s.km)}${rest == null ? '' : '  •  $rest'}',
                    style: const TextStyle(color: TG.muted, fontSize: 13)),
                const SizedBox(height: 10),
                Row(children: [
                  _Mini(tr('Condução'), fmtDur(s.total(Act.drive, now)), TG.drive),
                  _Mini(
                      tr('Pausa'),
                      fmtDur(s.total(Act.pause, now) +
                          s.total(Act.unknown, now)),
                      TG.pause),
                  _Mini(tr('Martelo'), fmtDur(s.total(Act.work, now)), TG.work),
                  _Mini(tr('Amplitude'), fmtDur(s.amplitude(now)), TG.text),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      );
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Mini(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Fit(value,
                  alignment: Alignment.centerLeft,
                  style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              Fit(label,
                  alignment: Alignment.centerLeft,
                  style: const TextStyle(color: TG.muted, fontSize: 11.5)),
            ],
          ),
        ),
      );
}

class ShiftDetailPage extends StatefulWidget {
  final Shift shift;
  const ShiftDetailPage({super.key, required this.shift});
  @override
  State<ShiftDetailPage> createState() => _ShiftDetailPageState();
}

class _ShiftDetailPageState extends State<ShiftDetailPage> {
  final _t = Tracker.I;

  @override
  void initState() {
    super.initState();
    _t.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Apagar esta jornada?')),
        content: Text(tr('Ela sai do histórico e dos relatórios. Depois de apagar, tem 8 segundos para desfazer.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Cancelar'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('Apagar'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final m = ScaffoldMessenger.of(context);
    final sh = widget.shift;
    final day = '${weekdayShort(sh.start)} ${fmtDate(sh.start)}';
    final i = await _t.deleteShift(sh);
    if (mounted) Navigator.pop(context);
    if (i < 0) return;
    showUndo(m, tr('Jornada de {0} apagada', [day]), () async {
      await _t.restoreShift(sh, i);
      m.showSnackBar(SnackBar(
          content: Text(tr('Jornada de {0} restaurada', [day])),
          duration: const Duration(seconds: 2)));
    });
  }

  /// Descanso feito depois desta jornada, com o local (onde ela acabou).
  Widget _restCard(Shift s, DateTime now) {
    final ordered = sorted(_t.shifts);
    final i = ordered.indexWhere((x) => identical(x, s));
    final next = (i >= 0 && i + 1 < ordered.length) ? ordered[i + 1] : null;
    final gap = (next?.start ?? now).difference(s.end!);
    final k = restKind(gap);
    final label = next == null && k == RestKind.tooShort
        ? tr('Descanso em curso')
        : restLabel(k);
    final has = s.endLat != null && s.endLon != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: has ? () => openMap(context, s.endLat!, s.endLon!) : null,
        child: Row(children: [
          const Icon(Icons.hotel_rounded, color: TG.pause),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label  •  ${fmtDur(gap)}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                Text(
                    has
                        ? tr('Local: {0}, {1}', [s.endLat!.toStringAsFixed(5), s.endLon!.toStringAsFixed(5)])
                        : tr('Local não gravado (sem GPS ao encerrar)'),
                    style: const TextStyle(color: TG.muted, fontSize: 12.5)),
              ],
            ),
          ),
          if (has) const Icon(Icons.map_rounded, color: TG.muted, size: 20),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.shift;
    final now = DateTime.now();
    final issues = shiftIssues(_t.shifts, s, now);
    return Scaffold(
      appBar: AppBar(
        title: Text('${weekdayShort(s.start)} ${fmtDate(s.start)}'),
        actions: [
          if (!s.open)
            IconButton(
                onPressed: _delete,
                tooltip: tr('Apagar jornada'),
                icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          TCard(
            child: Column(children: [
              Row(children: [
                _Mini(tr('Início'), fmtTime(s.start), TG.text),
                _Mini(tr('Fim'), s.end == null ? tr('aberta') : fmtTime(s.end!),
                    TG.text),
                _Mini(tr('Amplitude'), fmtDur(s.amplitude(now)), TG.accent),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _Mini(tr('Condução'), fmtDur(s.total(Act.drive, now)), TG.drive),
                _Mini(
                    tr('Pausa'),
                    fmtDur(
                        s.total(Act.pause, now) + s.total(Act.unknown, now)),
                    TG.pause),
                _Mini(tr('Martelo'), fmtDur(s.total(Act.work, now)), TG.work),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _Mini(tr('Carga/Desc.'), fmtDur(s.total(Act.load, now)), TG.load),
                _Mini(tr('Maior cond. seguida'),
                    fmtDur(maxContinuousDrive(s, now)), TG.text),
                _Mini(tr('Km'), fmtKm(s.km), TG.drive),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          for (final i in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: TG.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: TG.danger.withValues(alpha: 0.6)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: TG.danger),
                  const SizedBox(width: 12),
                  Expanded(child: Text(i)),
                ]),
              ),
            ),
          if (s.end != null) _restCard(s, now),
          const SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(tr('Atividades (toque para corrigir)'),
                style: TextStyle(
                    color: TG.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
          SegmentList(shift: s),
        ],
      ),
    );
  }
}

// ======================= Relatórios =======================

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _t = Tracker.I;
  ReportKind _kind = ReportKind.day;
  bool _full = true; // 1.8.6: relatório completo ou simples
  DateTime _ref = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 1.8.4: a jornada conta no dia em que começou. Abre no dia da jornada
    // em curso (ou da última), não no dia de hoje: depois da meia-noite o
    // relatório de hoje ainda estaria vazio.
    final last = _t.current ?? (_t.shifts.isEmpty ? null : _t.shifts.last);
    if (last != null) _ref = last.start;
    _t.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_refresh);
    super.dispose();
  }

  void _move(int dir) {
    setState(() {
      switch (_kind) {
        case ReportKind.day:
          _ref = _ref.add(Duration(days: dir));
          break;
        case ReportKind.week:
          _ref = _ref.add(Duration(days: 7 * dir));
          break;
        case ReportKind.twoWeeks:
          _ref = _ref.add(Duration(days: 14 * dir));
          break;
        case ReportKind.month:
          _ref = DateTime(_ref.year, _ref.month + dir, 15);
          break;
      }
    });
  }

  Future<File?> _build() async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      return await buildReport(_kind, _ref, _t.shifts,
          driver: _t.driver, plate: _t.plate, full: _full);
    } catch (e) {
      if (mounted) _snack(context, tr('Não foi possível gerar o PDF: {0}', [e]));
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open() async {
    final f = await _build();
    if (f == null) return;
    final r = await OpenFilex.open(f.path, type: 'application/pdf');
    if (r.type != ResultType.done && mounted) {
      _snack(context, tr('Não há app para abrir PDF. Use Compartilhar.'));
    }
  }

  Future<void> _share() async {
    final f = await _build();
    if (f == null) return;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(f.path, mimeType: 'application/pdf')],
      text: tr('Relatório {0} do TacoGuard', [reportName(_kind)]),
    ));
  }

  Future<void> _save() async {
    final f = await _build();
    if (f == null) return;
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: tr('Salvar relatório'),
        fileName: f.uri.pathSegments.last,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: await f.readAsBytes(),
      );
      if (path != null && mounted) _snack(context, tr('Relatório salvo.'));
    } catch (e) {
      if (mounted) _snack(context, tr('Não foi possível salvar: {0}', [e]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final (from, to) = reportRange(_kind, _ref);
    final list = shiftsIn(_t.shifts, from, to);
    var drive = Duration.zero,
        pause = Duration.zero,
        work = Duration.zero,
        load = Duration.zero;
    var issues = 0;
    var km = 0.0;
    for (final s in list) {
      km += s.km;
      drive += s.total(Act.drive, now);
      pause += s.total(Act.pause, now) + s.total(Act.unknown, now);
      work += s.total(Act.work, now);
      load += s.total(Act.load, now);
      issues += shiftIssues(_t.shifts, s, now)
          .where((x) => x != tr('Há paradas ainda não classificadas (contadas como pausa).'))
          .length;
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        SegmentedButton<ReportKind>(
          showSelectedIcon: false,
          segments: [
            for (final k in ReportKind.values)
              ButtonSegment(
                  value: k,
                  label: Fit(reportName(k),
                      style: const TextStyle(fontSize: 12.5))),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: false, label: Text(tr('Simples'))),
            ButtonSegment(value: true, label: Text(tr('Completo'))),
          ],
          selected: {_full},
          onSelectionChanged: (s) => setState(() => _full = s.first),
        ),
        const SizedBox(height: 12),
        TCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(children: [
            IconButton(
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left_rounded, size: 30)),
            Expanded(
              child: Text(rangeLabel(from, to),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            IconButton(
                onPressed: () => _move(1),
                icon: const Icon(Icons.chevron_right_rounded, size: 30)),
          ]),
        ),
        const SizedBox(height: 12),
        TCard(
          child: Column(children: [
            Row(children: [
              _Mini(tr('Condução'), fmtDur(drive), TG.drive),
              _Mini(tr('Pausa'), fmtDur(pause), TG.pause),
              _Mini(tr('Martelo'), fmtDur(work), TG.work),
              _Mini(tr('Carga/Desc.'), fmtDur(load), TG.load),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _Mini(tr('Jornadas'), '${list.length}', TG.text),
              _Mini(tr('Avisos'), '$issues', issues > 0 ? TG.danger : TG.ok),
              _Mini(tr('Km'), fmtKm(km), TG.drive),
              const Spacer(),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: _busy ? null : _open,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: Fit(_busy ? tr('Gerando...') : tr('Abrir PDF'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save_alt_rounded),
                label: Fit(tr('Salvar')),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _share,
                icon: const Icon(Icons.share_rounded),
                label: Fit(tr('Compartilhar')),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Text(
            _full
                ? tr('Completo: o resumo, cada jornada, as pausas e descansos, os avisos e todas as atividades com hora e coordenadas.')
                : tr('Simples: o resumo, cada jornada, as pausas e descansos com o local, e os avisos e infrações.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: TG.muted, fontSize: 12.5)),
      ],
    );
  }
}

// ======================= Ajustes =======================

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _t = Tracker.I;
  String _version = '';
  bool _overlayOk = true;
  late final TextEditingController _driver =
      TextEditingController(text: _t.driver);
  late final TextEditingController _plate =
      TextEditingController(text: _t.plate);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = (await PackageInfo.fromPlatform()).version;
      final ok = await StopPopup.hasPermission();
      if (mounted) {
        setState(() {
          _version = v;
          _overlayOk = ok;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _driver.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _battery() async {
    // 1.7.7: pede direto ao Android para tirar o TacoGuard da economia de
    // bateria (uma janela com Permitir). Se o celular não aceitar, abre a
    // lista geral, como antes.
    try {
      await AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:com.tecsattv.tacoguard',
        flags: const [Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
      return;
    } catch (_) {}
    try {
      await AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
        flags: const [Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
    } catch (_) {
      if (mounted) {
        _snack(context, tr('Abra Configurações > Bateria > TacoGuard e escolha "Sem restrições".'));
      }
    }
  }

  Future<File> _backupFile() async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/TacoGuard-backup.json');
    await f.writeAsString(_t.exportJson(), flush: true);
    return f;
  }

  Future<void> _backupShare() async {
    final f = await _backupFile();
    await SharePlus.instance.share(ShareParams(
      files: [XFile(f.path, mimeType: 'application/json')],
      text: tr('Backup do TacoGuard'),
    ));
  }

  Future<void> _backupSave() async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: tr('Salvar backup'),
        fileName: 'TacoGuard-backup.json',
        bytes: Uint8List.fromList(utf8.encode(_t.exportJson())),
      );
      if (path != null && mounted) _snack(context, tr('Backup salvo.'));
    } catch (e) {
      if (mounted) _snack(context, tr('Não foi possível salvar: {0}', [e]));
    }
  }

  Future<void> _restore() async {
    if (_t.current != null) {
      _snack(context, tr('Encerre a jornada antes de restaurar um backup.'));
      return;
    }
    FilePickerResult? res;
    try {
      res = await FilePicker.platform
          .pickFiles(type: FileType.any, withData: true);
    } catch (_) {
      if (mounted) _snack(context, tr('Não consegui abrir os arquivos.'));
      return;
    }
    if (res == null || res.files.isEmpty) return;
    final pf = res.files.first;
    var bytes = pf.bytes;
    if (bytes == null && pf.path != null) {
      bytes = await File(pf.path!).readAsBytes();
    }
    if (bytes == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Restaurar backup?')),
        content: Text(tr('As jornadas deste telefone serão substituídas pelas do backup.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Cancelar'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('Restaurar'))),
        ],
      ),
    );
    if (ok != true) return;
    final done =
        await _t.importJson(utf8.decode(bytes, allowMalformed: true));
    if (mounted) {
      _snack(context,
          done ? tr('Backup restaurado.') : tr('Este arquivo não é um backup do TacoGuard.'));
    }
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, top: 18, bottom: 8),
        child: Text(t,
            style: const TextStyle(
                color: TG.muted, fontSize: 13, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 28 + MediaQuery.paddingOf(context).bottom),
      children: [
        // 1.9.0: idioma do app (automático = o do telefone).
        _title(tr('Idioma')),
        TCard(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: langChoice,
              items: [
                DropdownMenuItem(
                    value: '',
                    child: Text(tr('Automático (idioma do telefone)'))),
                for (final e in kLangs.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) async {
                await setLang(v ?? '');
                await _t.setVoiceLang();
                if (mounted) setState(() {});
              },
            ),
          ),
        ),
        _title(tr('Velocidade')),
        TCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Aviso de velocidade')),
                subtitle: Text(
                    tr('Bip acima do limite; mais de 1 min acima fica registado como infração, como no tacógrafo')),
                value: _t.speedAlert,
                onChanged: (v) {
                  setState(() => _t.speedAlert = v);
                  _t.saveSettings();
                },
              ),
              Text(tr('Limite: {0} km/h', [_t.speedLimit]),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              Slider(
                value: _t.speedLimit.toDouble(),
                min: 85,
                max: 100,
                divisions: 15,
                label: '${_t.speedLimit} km/h',
                onChanged: _t.speedAlert
                    ? (v) => setState(() => _t.speedLimit = v.round())
                    : null,
                onChangeEnd: (_) => _t.saveSettings(),
              ),
              // 1.9.1: margem (o tacógrafo mede pela roda e marca um pouco
              // mais que o GPS).
              Text(
                  _t.speedMargin == 0
                      ? tr('Avisar ao chegar a {0} km/h', [_t.speedLimit])
                      : tr('Avisar {0} km/h antes: a partir de {1} km/h',
                          [_t.speedMargin, _t.speedLimit - _t.speedMargin]),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              Text(
                  tr('O tacógrafo mede pela roda e costuma marcar 1 a 3 km/h a mais que o GPS. Se o tacógrafo registar antes do app, aumente a margem.'),
                  style: const TextStyle(color: TG.muted, fontSize: 12.5)),
              Slider(
                value: _t.speedMargin.toDouble(),
                min: 0,
                max: 5,
                divisions: 5,
                label: '${_t.speedMargin} km/h',
                onChanged: _t.speedAlert
                    ? (v) => setState(() => _t.speedMargin = v.round())
                    : null,
                onChangeEnd: (_) => _t.saveSettings(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Bip')),
                subtitle: Text(tr('Desligado: sem som; o cartão vermelho a piscar e o registo da infração continuam')),
                value: _t.speedBeep,
                onChanged: _t.speedAlert
                    ? (v) {
                        setState(() => _t.speedBeep = v);
                        _t.saveSettings();
                      }
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _t.beep(),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: Text(tr('Testar o bip')),
                ),
              ),
            ],
          ),
        ),
        _title(tr('Paradas')),
        TCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  _t.stopMinutes == 0
                      ? tr('Martelo na hora ao parar')
                      : tr('Considerar parada depois de {0} min parado',
                          [_t.stopMinutes]),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              Text(
                  _t.stopMinutes == 0
                      ? tr('Como o tacógrafo: velocidade zero, em poucos segundos passa para martelo e você escolhe se é pausa ou carga/descarga.')
                      : tr('Menos que isso é trânsito ou semáforo e conta como condução.'),
                  style: TextStyle(color: TG.muted, fontSize: 12.5)),
              Slider(
                value: _t.stopMinutes.toDouble(),
                min: 0,
                max: 5,
                divisions: 5,
                label: _t.stopMinutes == 0
                    ? tr('Na hora')
                    : tr('{0} min', [_t.stopMinutes]),
                onChanged: (v) {
                  setState(() => _t.stopMinutes = v.round());
                },
                onChangeEnd: (_) => _t.saveSettings(),
              ),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Pop-up ao parar')),
                subtitle: Text(
                    tr('Pergunta: Pausa, Martelo ou Carga/Descarga')),
                value: _t.popup,
                onChanged: (v) {
                  setState(() => _t.popup = v);
                  _t.saveSettings();
                },
              ),
              if (_t.popup && !_overlayOk)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await StopPopup.requestPermission();
                      await _load();
                    },
                    icon: const Icon(Icons.layers_rounded),
                    label: Fit(tr('Liberar "Sobrepor a outros apps"')),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Avisos por voz')),
                subtitle: Text(
                    tr('Fala quando falta pouco para a pausa e os limites')),
                value: _t.voice,
                onChanged: (v) {
                  setState(() => _t.voice = v);
                  _t.saveSettings();
                },
              ),
            ],
          ),
        ),
        _title(tr('Funcionar com a tela apagada')),
        TCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  tr('Para o GPS não ser cortado pelo celular durante a jornada, deixe o TacoGuard "Sem restrições" de bateria.'),
                  style: TextStyle(fontSize: 14, height: 1.35)),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _battery,
                icon: const Icon(Icons.battery_saver_rounded),
                label: Fit(tr('Abrir ajustes de bateria')),
              ),
            ],
          ),
        ),
        _title(tr('Relatórios')),
        TCard(
          child: Column(children: [
            TextField(
              controller: _driver,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                  labelText: tr('Nome do motorista (sai no PDF)')),
              onChanged: (v) {
                _t.driver = v.trim();
                _t.saveSettings();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                  labelText: tr('Matrícula do veículo (sai no PDF)'),
                  hintText: tr('Ex.: AA-00-BB')),
              onChanged: (v) {
                _t.plate = v.trim().toUpperCase();
                _t.saveSettings();
              },
            ),
          ]),
        ),
        _title(tr('Backup')),
        TCard(
          child: Column(children: [
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _backupSave,
                  icon: const Icon(Icons.save_alt_rounded),
                  label: Fit(tr('Salvar')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _backupShare,
                  icon: const Icon(Icons.share_rounded),
                  label: Fit(tr('Compartilhar')),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _restore,
                icon: const Icon(Icons.restore_rounded),
                label: Fit(tr('Restaurar backup')),
              ),
            ),
          ]),
        ),
        _title(tr('Sobre')),
        TCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      Image.asset('assets/icon.png', width: 48, height: 48),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TacoGuard $_version',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      Text(tr('Desenvolvido por Luiz Alberto Cardoso'),
                          style: TextStyle(color: TG.muted, fontSize: 13)),
                      const Text('tecsattv@gmail.com',
                          style: TextStyle(color: TG.muted, fontSize: 13)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => UpdateService.manualCheck(context),
                  icon: const Icon(Icons.system_update_rounded),
                  label: Fit(tr('Procurar atualização')),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                  tr('O TacoGuard é um auxiliar do motorista. O registro oficial é o do tacógrafo, e pode haver pequenas diferenças de minutos entre os dois.'),
                  style: TextStyle(color: TG.muted, fontSize: 12.5)),
            ],
          ),
        ),
      ],
    );
  }
}
