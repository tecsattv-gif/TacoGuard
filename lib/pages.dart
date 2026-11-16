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

Future<void> openMap(BuildContext context, double lat, double lon) async {
  try {
    await AndroidIntent(
      action: 'action_view',
      data: 'geo:$lat,$lon?q=$lat,$lon',
      flags: const [Flag.FLAG_ACTIVITY_NEW_TASK],
    ).launch();
  } catch (_) {
    if (context.mounted) _snack(context, 'Não foi possível abrir o mapa.');
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
              Icon(TG.icon(s.act), color: TG.act(s.act), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(actLabel(s.act),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(
                        '${fmtTime(s.start)} - '
                        '${s.end == null ? 'agora' : fmtTime(s.end!)}'
                        '${s.act == Act.drive && s.km > 0 ? '  •  ${fmtKm(s.km)}' : ''}'
                        '${s.note.isEmpty ? '' : '  •  ${s.note}'}',
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
      builder: (ctx) => Padding(
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
                  '${fmtTime(s.start)} - '
                  '${s.end == null ? 'agora' : fmtTime(s.end!)}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Corrigir a atividade deste trecho',
                  style: TextStyle(color: TG.muted)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in [Act.drive, Act.pause, Act.work, Act.load])
                  ChoiceChip(
                    avatar: Icon(TG.icon(a), size: 18, color: TG.act(a)),
                    label: Text(actLabel(a)),
                    selected: s.act == a,
                    onSelected: (_) {
                      Tracker.I.reclassify(s, a);
                      Navigator.pop(ctx);
                    },
                  ),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                    hintText: 'Nome do local ou nota (opcional)'),
                onSubmitted: (v) {
                  Tracker.I.setNote(s, v);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                if (s.hasCoords)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => openMap(ctx, s.lat!, s.lon!),
                      icon: const Icon(Icons.map_rounded),
                      label: Text(
                          '${s.lat!.toStringAsFixed(4)}, '
                          '${s.lon!.toStringAsFixed(4)}',
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                if (s.hasCoords) const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Tracker.I.setNote(s, note.text);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Salvar'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Ainda não há jornadas.\nInicie a primeira na tela Hoje.',
              textAlign: TextAlign.center,
              style: TextStyle(color: TG.muted, fontSize: 15)),
        ),
      );
    }
    final ordered = sorted(_t.shifts);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final s = list[i];
        final issues = shiftIssues(_t.shifts, s, now)
            .where((x) => !x.contains('classificadas'))
            .length;
        final idx = ordered.indexWhere((x) => identical(x, s));
        String? rest;
        if (idx > 0 && ordered[idx - 1].end != null) {
          final gap = s.start.difference(ordered[idx - 1].end!);
          rest = 'Descanso antes: ${fmtDur(gap)}';
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
                    const _Pill('Aberta', TG.accent)
                  else if (issues > 0)
                    _Pill('$issues aviso${issues > 1 ? 's' : ''}', TG.danger)
                  else
                    const _Pill('OK', TG.ok),
                ]),
                const SizedBox(height: 2),
                Text(
                    '${fmtTime(s.start)} às '
                    '${s.end == null ? 'agora' : fmtTime(s.end!)}'
                    '  •  ${fmtKm(s.km)}'
                    '${rest == null ? '' : '  •  $rest'}',
                    style: const TextStyle(color: TG.muted, fontSize: 13)),
                const SizedBox(height: 10),
                Row(children: [
                  _Mini('Condução', fmtDur(s.total(Act.drive, now)), TG.drive),
                  _Mini(
                      'Pausa',
                      fmtDur(s.total(Act.pause, now) +
                          s.total(Act.unknown, now)),
                      TG.pause),
                  _Mini('Martelo', fmtDur(s.total(Act.work, now)), TG.work),
                  _Mini('Amplitude', fmtDur(s.amplitude(now)), TG.text),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(color: TG.muted, fontSize: 11.5)),
          ],
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
        title: const Text('Apagar esta jornada?'),
        content: const Text('Ela sai do histórico e dos relatórios. '
            'Não dá para desfazer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true) return;
    await _t.deleteShift(widget.shift);
    if (mounted) Navigator.pop(context);
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
                tooltip: 'Apagar jornada',
                icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          TCard(
            child: Column(children: [
              Row(children: [
                _Mini('Início', fmtTime(s.start), TG.text),
                _Mini('Fim', s.end == null ? 'aberta' : fmtTime(s.end!),
                    TG.text),
                _Mini('Amplitude', fmtDur(s.amplitude(now)), TG.accent),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _Mini('Condução', fmtDur(s.total(Act.drive, now)), TG.drive),
                _Mini(
                    'Pausa',
                    fmtDur(
                        s.total(Act.pause, now) + s.total(Act.unknown, now)),
                    TG.pause),
                _Mini('Martelo', fmtDur(s.total(Act.work, now)), TG.work),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _Mini('Carga/Desc.', fmtDur(s.total(Act.load, now)), TG.load),
                _Mini('Maior cond. seguida',
                    fmtDur(maxContinuousDrive(s, now)), TG.text),
                _Mini('Km', fmtKm(s.km), TG.drive),
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
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Atividades (toque para corrigir)',
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
  DateTime _ref = DateTime.now();
  bool _busy = false;

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
      return await buildReport(_kind, _ref, _t.shifts, driver: _t.driver);
    } catch (e) {
      if (mounted) _snack(context, 'Não foi possível gerar o PDF: $e');
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
      _snack(context, 'Não há app para abrir PDF. Use Compartilhar.');
    }
  }

  Future<void> _share() async {
    final f = await _build();
    if (f == null) return;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(f.path, mimeType: 'application/pdf')],
      text: 'Relatório ${reportName(_kind)} do TacoGuard',
    ));
  }

  Future<void> _save() async {
    final f = await _build();
    if (f == null) return;
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar relatório',
        fileName: f.uri.pathSegments.last,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: await f.readAsBytes(),
      );
      if (path != null && mounted) _snack(context, 'Relatório salvo.');
    } catch (e) {
      if (mounted) _snack(context, 'Não foi possível salvar: $e');
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
          .where((x) => !x.contains('classificadas'))
          .length;
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        SegmentedButton<ReportKind>(
          showSelectedIcon: false,
          segments: [
            for (final k in ReportKind.values)
              ButtonSegment(
                  value: k,
                  label: Text(reportName(k),
                      style: const TextStyle(fontSize: 12.5))),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() => _kind = s.first),
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
              _Mini('Condução', fmtDur(drive), TG.drive),
              _Mini('Pausa', fmtDur(pause), TG.pause),
              _Mini('Martelo', fmtDur(work), TG.work),
              _Mini('Carga/Desc.', fmtDur(load), TG.load),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _Mini('Jornadas', '${list.length}', TG.text),
              _Mini('Avisos', '$issues', issues > 0 ? TG.danger : TG.ok),
              _Mini('Km', fmtKm(km), TG.drive),
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
            label: Text(_busy ? 'Gerando...' : 'Abrir PDF',
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
                label: const Text('Salvar no telefone'),
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
                label: const Text('Compartilhar'),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        const Text(
            'O PDF traz o resumo, cada jornada, os descansos, os avisos e '
            'todas as paradas com hora e coordenadas.',
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
    super.dispose();
  }

  Future<void> _battery() async {
    try {
      await AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
        flags: const [Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
    } catch (_) {
      if (mounted) {
        _snack(context, 'Abra Configurações > Bateria > TacoGuard e '
            'escolha "Sem restrições".');
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
      text: 'Backup do TacoGuard',
    ));
  }

  Future<void> _backupSave() async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar backup',
        fileName: 'TacoGuard-backup.json',
        bytes: Uint8List.fromList(utf8.encode(_t.exportJson())),
      );
      if (path != null && mounted) _snack(context, 'Backup salvo.');
    } catch (e) {
      if (mounted) _snack(context, 'Não foi possível salvar: $e');
    }
  }

  Future<void> _restore() async {
    if (_t.current != null) {
      _snack(context, 'Encerre a jornada antes de restaurar um backup.');
      return;
    }
    FilePickerResult? res;
    try {
      res = await FilePicker.platform
          .pickFiles(type: FileType.any, withData: true);
    } catch (_) {
      if (mounted) _snack(context, 'Não consegui abrir os arquivos.');
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
        title: const Text('Restaurar backup?'),
        content: const Text('As jornadas deste telefone serão substituídas '
            'pelas do backup.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restaurar')),
        ],
      ),
    );
    if (ok != true) return;
    final done =
        await _t.importJson(utf8.decode(bytes, allowMalformed: true));
    if (mounted) {
      _snack(context,
          done ? 'Backup restaurado.' : 'Este arquivo não é um backup do TacoGuard.');
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        _title('Paradas'),
        TCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Considerar parada depois de ${_t.stopMinutes} min parado',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const Text(
                  'Menos que isso é trânsito ou semáforo e conta como '
                  'condução.',
                  style: TextStyle(color: TG.muted, fontSize: 12.5)),
              Slider(
                value: _t.stopMinutes.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '${_t.stopMinutes} min',
                onChanged: (v) {
                  setState(() => _t.stopMinutes = v.round());
                },
                onChangeEnd: (_) => _t.saveSettings(),
              ),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pop-up ao parar'),
                subtitle: const Text(
                    'Pergunta: Pausa, Martelo ou Carga/Descarga'),
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
                    label: const Text('Liberar "Sobrepor a outros apps"'),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Avisos por voz'),
                subtitle: const Text(
                    'Fala quando falta pouco para a pausa e os limites'),
                value: _t.voice,
                onChanged: (v) {
                  setState(() => _t.voice = v);
                  _t.saveSettings();
                },
              ),
            ],
          ),
        ),
        _title('Funcionar com a tela apagada'),
        TCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Para o GPS não ser cortado pelo celular durante a '
                  'jornada, deixe o TacoGuard "Sem restrições" de bateria.',
                  style: TextStyle(fontSize: 14, height: 1.35)),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _battery,
                icon: const Icon(Icons.battery_saver_rounded),
                label: const Text('Abrir ajustes de bateria'),
              ),
            ],
          ),
        ),
        _title('Relatórios'),
        TCard(
          child: TextField(
            controller: _driver,
            decoration: const InputDecoration(
                labelText: 'Nome do motorista (sai no PDF)'),
            onChanged: (v) {
              _t.driver = v.trim();
              _t.saveSettings();
            },
          ),
        ),
        _title('Backup'),
        TCard(
          child: Column(children: [
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _backupSave,
                  icon: const Icon(Icons.save_alt_rounded),
                  label: const Text('Salvar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _backupShare,
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Compartilhar'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _restore,
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Restaurar backup'),
              ),
            ),
          ]),
        ),
        _title('Sobre'),
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
                      const Text('Desenvolvido por Luiz Alberto Cardoso',
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
                  label: const Text('Procurar atualização'),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                  'O TacoGuard é um auxiliar do motorista. O registro '
                  'oficial é o do tacógrafo, e pode haver pequenas '
                  'diferenças de minutos entre os dois.',
                  style: TextStyle(color: TG.muted, fontSize: 12.5)),
            ],
          ),
        ),
      ],
    );
  }
}
