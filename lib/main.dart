import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'assistant.dart';
import 'law.dart';
import 'models.dart';
import 'pages.dart';
import 'popup.dart';
import 'rules.dart';
import 'theme.dart';
import 'tracker.dart';
import 'update_service.dart';

/// Ponto de entrada do pop-up por cima dos outros apps (roda separado).
/// ATENÇÃO: o @pragma tem de ficar colado na função.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: TG.theme(),
    builder: clampTextScale,
    home: const StopPopupWindow(),
  ));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: TG.surface,
  ));
  await Tracker.I.load();
  runApp(const TacoApp());
}

class TacoApp extends StatelessWidget {
  const TacoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TacoGuard',
        debugShowCheckedModeBanner: false,
        theme: TG.theme(),
        builder: clampTextScale,
        home: const SplashScreen(next: HomeShell()),
      );
}

/// Tela de abertura: velocímetro + nome + créditos, por 2,5 segundos.
class SplashScreen extends StatefulWidget {
  final Widget next;
  const SplashScreen({super.key, required this.next});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2500), _go);
    _loadVersion();
  }

  /// A versão vem do próprio APK instalado: muda sozinha a cada atualização.
  Future<void> _loadVersion() async {
    try {
      final v = (await PackageInfo.fromPlatform()).version;
      if (mounted) setState(() => _version = v);
    } catch (_) {}
  }

  void _go() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => widget.next,
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/splash.jpg',
              fit: BoxFit.cover, alignment: const Alignment(-0.35, 0)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x22000000),
                  Color(0xCC000000),
                  Color(0xF2000000),
                ],
                stops: [0, 0.35, 0.72, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
              child: Column(
                children: [
                  const Text('TacoGuard',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 18)
                          ])),
                  const SizedBox(height: 6),
                  const Text('Sua jornada dentro da lei do tacógrafo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 12)
                          ])),
                  const Spacer(),
                  // Créditos, em destaque no rodapé da abertura.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0x99000000),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0x55FFFFFF)),
                    ),
                    child: Column(children: [
                      const Text('DESENVOLVIDO POR',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2)),
                      const SizedBox(height: 4),
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Luiz Alberto Cardoso',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 2),
                      const Fit('tecsattv@gmail.com',
                          style: TextStyle(
                              color: Colors.white, fontSize: 14)),
                      if (_version.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Versão $_version',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Casca do app: barra de baixo com as 5 telas.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  bool _inFront = true;
  bool _sheetOpen = false;
  Segment? _asked; // parada já perguntada dentro do app
  StreamSubscription? _overlaySub;
  final _t = Tracker.I;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _t.onAsk = _ask;
    _t.onAskCancel = _cancelAsk;
    // Resposta vinda do pop-up por cima dos outros apps.
    try {
      _overlaySub = FlutterOverlayWindow.overlayListener.listen((event) {
        try {
          final m = jsonDecode(event.toString()) as Map;
          final v = m['stop'];
          if (v is! String) return;
          StopPopup.shown = false;
          if (v == 'later') return;
          if (_t.currentAct == Act.unknown) _t.setAct(actFromName(v));
        } catch (_) {}
      });
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Jornada ficou aberta (app fechado no meio): religa o GPS.
      if (_t.current != null) await _t.startGps();
      if (mounted) UpdateService.autoCheck(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlaySub?.cancel();
    _t.onAsk = null;
    _t.onAskCancel = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inFront = state == AppLifecycleState.resumed;
    if (_inFront) {
      StopPopup.close();
      final s = _t.currentSegment;
      if (s != null && s.act == Act.unknown && !identical(s, _asked)) {
        _ask(s);
      }
      if (mounted) UpdateService.autoCheck(context, resumed: true);
    }
  }

  void _ask(Segment seg) {
    if (!mounted) return;
    if (_inFront) {
      _askInApp(seg);
    } else {
      StopPopup.show(seg, MediaQuery.sizeOf(context).width);
    }
  }

  void _cancelAsk() {
    StopPopup.close();
    if (_sheetOpen && mounted) {
      Navigator.of(context, rootNavigator: true).maybePop();
    }
  }

  Future<void> _askInApp(Segment seg) async {
    if (_sheetOpen) return;
    _asked = seg;
    _sheetOpen = true;
    final a = await showModalBottomSheet<Act>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('O que é esta parada?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('Parado desde ${fmtTime(seg.start)}',
                  style: const TextStyle(color: TG.muted, fontSize: 13)),
              const SizedBox(height: 16),
              StopChoices(onPick: (a) => Navigator.pop(ctx, a)),
              const SizedBox(height: 4),
              SizedBox(
                height: 48,
                child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Responder depois')),
              ),
            ],
          ),
        ),
      ),
    );
    _sheetOpen = false;
    if (a != null && identical(_t.currentSegment, seg)) _t.setAct(a);
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['TacoGuard', 'Histórico', 'Relatórios', 'Lei', 'Ajustes'];
    final pages = <Widget>[
      const TodayPage(),
      const HistoryPage(),
      const ReportsPage(),
      const _LawTabs(),
      const SettingsPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          if (_tab == 0)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset('assets/icon.png', width: 32, height: 32),
              ),
            ),
          Text(titles[_tab]),
        ]),
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.speed_rounded), label: 'Hoje'),
          NavigationDestination(
              icon: Icon(Icons.history_rounded), label: 'Histórico'),
          NavigationDestination(
              icon: Icon(Icons.picture_as_pdf_rounded), label: 'Relatórios'),
          NavigationDestination(
              icon: Icon(Icons.gavel_rounded), label: 'Lei'),
          NavigationDestination(
              icon: Icon(Icons.settings_rounded), label: 'Ajustes'),
        ],
      ),
    );
  }
}

class _LawTabs extends StatelessWidget {
  const _LawTabs();
  @override
  Widget build(BuildContext context) => const DefaultTabController(
        length: 2,
        child: Column(children: [
          TabBar(
            dividerColor: TG.line,
            tabs: [Tab(text: 'Lei do tacógrafo'), Tab(text: 'Consulta')],
          ),
          Expanded(
            child: TabBarView(children: [LawPage(), AssistantPage()]),
          ),
        ]),
      );
}

// ======================= Tela "Hoje" =======================

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});
  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final _t = Tracker.I;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _t.addListener(_refresh);
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_refresh);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final now = DateTime.now();
    final rest = _t.restSoFar(now) ?? Limits.dailyRest;
    final short = _t.shifts.isNotEmpty && rest < Limits.dailyRestReduced;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(short ? Icons.warning_amber_rounded : Icons.play_arrow_rounded,
            color: short ? Colors.orange : null, size: 36),
        title: const Text('Iniciar a jornada?'),
        content: Text('A jornada começa agora, às ${fmtTime(now)}, e o GPS '
            'passa a contar a condução e as paradas.'
            '${short ? '\n\nAtenção: o descanso ainda tem só ${fmtDur(rest)} '
                '(faltam ${fmtDur(Limits.dailyRestReduced - rest)} para as 9 h).' : ''}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Iniciar')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final err = await _t.startShift();
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$err A jornada foi aberta, mas sem GPS as paradas '
              'não são detectadas sozinhas.')));
    }
    if (_t.popup && !await StopPopup.hasPermission() && mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pop-up das paradas'),
          content: const Text(
              'Para o TacoGuard perguntar "Pausa, Martelo ou '
              'Carga/Descarga?" por cima do Google Maps e de outros apps, '
              'libere a permissão "Sobrepor a outros apps".'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Agora não')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Liberar')),
          ],
        ),
      );
      if (ok == true) await StopPopup.requestPermission();
    }
  }

  Future<void> _reopen(Shift sh) async {
    final gap = DateTime.now().difference(sh.end!);
    final a = await showDialog<Act>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reabrir a jornada?'),
        content: Text(
            'A jornada iniciada às ${fmtTime(sh.start)} continua: a '
            'amplitude e os tempos seguem contando desde o início.\n\n'
            'Como contar o tempo desde que encerrou '
            '(${fmtDur(gap)})?'),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          Row(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton(
                onPressed: () => Navigator.pop(ctx, Act.work),
                child: const Text('Martelo')),
            const SizedBox(width: 8),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, Act.pause),
                child: const Text('Pausa')),
          ]),
        ],
      ),
    );
    if (a == null) return;
    final err = await _t.reopenShift(a);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _end() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar a jornada?'),
        content: const Text('A partir de agora começa a contar o descanso.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Encerrar')),
        ],
      ),
    );
    if (ok == true) await _t.endShift();
  }

  @override
  Widget build(BuildContext context) {
    final c = _t.current;
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: c == null ? _closed(now) : _open(c, now),
    );
  }

  // ---------- Jornada fechada ----------
  List<Widget> _closed(DateTime now) {
    final rest = _t.restSoFar(now);
    final ref = _t.shifts.isEmpty ? null : _t.shifts.last;
    final ws = weekStartUtc(now);
    final week = driveBetween(_t.shifts, ws, ws.add(const Duration(days: 7)), now);
    final prev =
        driveBetween(_t.shifts, ws.subtract(const Duration(days: 7)), ws, now);
    return [
      _Hero(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(children: [
          if (rest == null) ...[
            const Icon(Icons.hotel_rounded, color: TG.pause, size: 40),
            const SizedBox(height: 8),
            const Text('Pronto para começar',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ],
          if (rest != null) ...[
            Text(
                ref?.end == null
                    ? 'Em descanso'
                    : 'Em descanso desde ${fmtTime(ref!.end!)}',
                style: const TextStyle(color: TG.muted, fontSize: 14)),
            const SizedBox(height: 2),
            Text(fmtDur(rest),
                style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: TG.pause,
                    letterSpacing: -1,
                    fontFeatures: [FontFeature.tabularFigures()],
                    height: 1.05)),
            const SizedBox(height: 4),
            Text(_restText(rest),
                textAlign: TextAlign.center,
                style: const TextStyle(color: TG.muted, fontSize: 14)),
            if (ref != null && ref.endLat != null && ref.endLon != null)
              TextButton.icon(
                onPressed: () => openMap(context, ref.endLat!, ref.endLon!),
                icon: const Icon(Icons.place_rounded, size: 18),
                label: Text('Local do descanso: '
                    '${ref.endLat!.toStringAsFixed(5)}, '
                    '${ref.endLon!.toStringAsFixed(5)}'),
              ),
            const SizedBox(height: 12),
            _RestBar(rest: rest),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow_rounded, size: 30),
              label: const Fit('Iniciar jornada',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            ),
          ),
          if (_t.reopenable != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _reopen(_t.reopenable!),
                icon: const Icon(Icons.replay_rounded),
                label: Fit(
                    'Reabrir a jornada das ${fmtTime(_t.reopenable!.start)}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
          if (rest == null) ...[
            const SizedBox(height: 10),
            const Text(
                'Depois de iniciar, o GPS faz o resto: detecta as paradas, '
                'grava o local e conta os tempos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: TG.muted, fontSize: 12.5)),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      _LimitList(rows: [
        _Limit('Semana', week, Limits.weeklyDrive),
        _Limit('2 semanas', week + prev, Limits.fortnightDrive),
      ]),
      if (ref != null) ...[
        const SizedBox(height: 12),
        TCard(
          child: Row(children: [
            const Icon(Icons.flag_rounded, color: TG.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  'Última jornada: ${weekdayShort(ref.start)} '
                  '${fmtDate(ref.start)}, ${fmtTime(ref.start)} às '
                  '${ref.end == null ? '-' : fmtTime(ref.end!)}  •  '
                  'condução ${fmtDur(ref.total(Act.drive, now))}  •  '
                  '${fmtKm(ref.km)}',
                  style: const TextStyle(fontSize: 14)),
            ),
          ]),
        ),
      ],
    ];
  }

  String _restText(Duration rest) {
    if (rest >= Limits.weeklyRest) return 'Descanso semanal de 45 h cumprido';
    if (rest >= Limits.weeklyRestReduced) {
      return 'Descanso semanal reduzido (24 h) cumprido';
    }
    if (rest >= Limits.dailyRest) return 'Descanso diário de 11 h cumprido';
    if (rest >= Limits.dailyRestReduced) {
      return 'Descanso reduzido de 9 h cumprido • faltam '
          '${fmtDur(Limits.dailyRest - rest)} para as 11 h';
    }
    return 'Faltam ${fmtDur(Limits.dailyRestReduced - rest)} para 9 h e '
        '${fmtDur(Limits.dailyRest - rest)} para 11 h';
  }

  String _mmss(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  // ---------- Jornada aberta ----------
  List<Widget> _open(Shift c, DateTime now) {
    final st = computeStatus(_t.shifts, c, now);
    final act = _t.currentAct ?? Act.unknown;
    final seg = _t.currentSegment;
    final b = st.brk;
    final usedCd =
        b.driven.inSeconds / Limits.continuousDrive.inSeconds.toDouble();
    final issues = shiftIssues(_t.shifts, c, now);
    final alertFresh = _t.lastAlert != null &&
        _t.lastAlertAt != null &&
        now.difference(_t.lastAlertAt!).inMinutes < 10;
    return [
      // Estado atual: faixa na cor da atividade.
      _Tonal(
        color: TG.act(act),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          Icon(TG.icon(act), color: TG.act(act), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t.carMode ? '${actLabel(act)} • de carro' : actLabel(act),
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: TG.act(act))),
                Text(
                    seg == null
                        ? ''
                        : 'desde ${fmtTime(seg.start)}  •  ${fmtDur(seg.dur(now))}',
                    style: const TextStyle(color: TG.muted, fontSize: 13)),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${_t.speedKmh.round()}',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()])),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  _t.gpsOn && _t.gpsError == null
                      ? (_t.gpsStale
                          ? Icons.gps_not_fixed_rounded
                          : Icons.gps_fixed_rounded)
                      : Icons.gps_off_rounded,
                  size: 12,
                  color: _t.gpsOn && _t.gpsError == null
                      ? (_t.gpsStale ? TG.warn : TG.ok)
                      : TG.danger),
              const SizedBox(width: 3),
              const Text('km/h',
                  style: TextStyle(color: TG.muted, fontSize: 11)),
            ]),
          ]),
        ]),
      ),
      if (_t.gpsError == null && _t.gpsOn && _t.gpsStale) ...[
        const SizedBox(height: 10),
        const _Banner(
            icon: Icons.gps_not_fixed_rounded,
            color: TG.warn,
            text: 'Sem sinal de GPS no momento. Perto da janela ou do '
                'para-brisa o sinal volta.'),
      ],
      if (_t.gpsError != null) ...[
        const SizedBox(height: 10),
        _Banner(
            icon: Icons.gps_off_rounded,
            color: TG.danger,
            text: _t.gpsError!,
            action: 'Tentar',
            onAction: () => _t.startGps()),
      ],
      if (_t.stoppedSince != null &&
          now.difference(_t.stoppedSince!).inSeconds >= 10) ...[
        const SizedBox(height: 10),
        TCard(
          child: Column(children: [
            Text('Parado há ${_mmss(now.difference(_t.stoppedSince!))}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(
                'Com ${_t.stopMinutes} min parado vira parada e o pop-up '
                'aparece. Já pode responder:',
                textAlign: TextAlign.center,
                style: const TextStyle(color: TG.muted, fontSize: 12.5)),
            const SizedBox(height: 10),
            StopChoices(onPick: (a) => _t.stopNow(a)),
          ]),
        ),
      ],
      if (_t.carMode) ...[
        const SizedBox(height: 10),
        _Banner(
            icon: Icons.directions_car_rounded,
            color: TG.accent,
            text: 'De carro: o movimento não conta como condução e a '
                'parada continua. Volta ao normal sozinho quando você '
                'chegar ao caminhão.',
            action: 'Voltei',
            onAction: () => _t.endCar()),
      ] else if (act != Act.drive) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => _t.startCar(),
            style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            icon: const Icon(Icons.directions_car_rounded),
            label: const Fit('Vou sair de carro'),
          ),
        ),
      ],
      if (act == Act.unknown) ...[
        const SizedBox(height: 10),
        TCard(
          child: Column(children: [
            const Text('O que é esta parada?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            StopChoices(onPick: (a) => _t.setAct(a)),
          ]),
        ),
      ],
      if (alertFresh) ...[
        const SizedBox(height: 10),
        _Banner(
            icon: Icons.notifications_active_rounded,
            color: TG.warn,
            text: _t.lastAlert!),
      ],
      const SizedBox(height: 12),
      // Anel: condução contínua. É o número principal da tela.
      _Hero(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: _RingPainter(
                  used: usedCd.clamp(0.0, 1.0).toDouble(), color: TG.level(usedCd)),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(b.exceeded ? 'PAUSA JÁ' : 'Faltam',
                      style: TextStyle(
                          color: b.exceeded ? TG.danger : TG.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text(
                      b.exceeded
                          ? '+${fmtDur(b.driven - Limits.continuousDrive)}'
                          : fmtDur(b.left),
                      style: TextStyle(
                          fontSize: 54,
                          height: 1.1,
                          letterSpacing: -1,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: TG.level(usedCd))),
                  const Text('para a pausa',
                      style: TextStyle(color: TG.muted, fontSize: 14)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Fit('Condução contínua: ${fmtDur(b.driven)} de 4h30',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Fit(
              b.firstPartDone
                  ? '1ª parte (15 min) feita • falta a de 30 min'
                  : 'Próxima pausa: 45 min (ou 15 + 30)',
              style: const TextStyle(color: TG.muted, fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 12),
      // O dia numa faixa colorida, como o disco do tacógrafo.
      _DayStrip(shift: c, now: now),
      const SizedBox(height: 12),
      // Todos os limites numa lista só.
      _LimitList(rows: [
        _Limit('Condução hoje', st.dayDrive, st.dayLimit,
            mark: st.dayLimit > Limits.dailyDrive ? Limits.dailyDrive : null,
            note: st.dayLimit > Limits.dailyDrive
                ? 'dias de 10 h: ${st.extUsed + (st.extToday ? 1 : 0)}/2'
                : 'limite 9 h (já usou 2 dias de 10 h)'),
        _Limit('Amplitude', st.amplitude, st.amplitudeLimit,
            mark: st.canExtendAmplitude ? Limits.amplitude : null,
            note: st.canExtendAmplitude
                ? 'descansos de 9 h: ${st.reducedRestsUsed}/3'
                : 'limite 13 h (sem descanso reduzido)'),
        _Limit('Semana', st.weekDrive, Limits.weeklyDrive,
            note: 'pode conduzir ${fmtDur(st.weekLeft)}'),
        _Limit('2 semanas', st.fortnightDrive, Limits.fortnightDrive,
            note: 'semana anterior ${fmtDur(st.prevWeekDrive)}'),
      ]),
      const SizedBox(height: 12),
      // Totais do dia.
      TCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(children: [
          _Total(Act.pause, st.pauseToday),
          _Total(Act.work, st.workToday),
          _Total(Act.load, st.loadToday),
        ]),
      ),
      if (st.weeklyRestDeadline != null) ...[
        const SizedBox(height: 12),
        TCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            const Icon(Icons.weekend_rounded, color: TG.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  'Descanso semanal: começar até '
                  '${weekdayShort(st.weeklyRestDeadline!)} '
                  '${fmtDateTime(st.weeklyRestDeadline!)}',
                  style: const TextStyle(fontSize: 14)),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 16),
      // Trocar atividade à mão.
      const _Section('Trocar a atividade à mão'),
      _ActPicker(current: act, onPick: (a) => _t.setAct(a)),
      if (issues.isNotEmpty) ...[
        const SizedBox(height: 16),
        const _Section('Avisos'),
        for (final i in issues)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Banner(
                icon: Icons.warning_amber_rounded,
                color: i.contains('classificadas') ? TG.warn : TG.danger,
                text: i),
          ),
      ],
      const SizedBox(height: 16),
      _Section('Linha do tempo  •  início ${fmtTime(c.start)}'),
      SegmentList(shift: c),
      const SizedBox(height: 18),
      SizedBox(
        height: 56,
        child: OutlinedButton.icon(
          onPressed: _end,
          style: OutlinedButton.styleFrom(
              foregroundColor: TG.danger,
              side: const BorderSide(color: TG.danger, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18))),
          icon: const Icon(Icons.stop_rounded),
          label: const Fit('Encerrar jornada',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
      ),
    ];
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: TG.muted, fontSize: 13, fontWeight: FontWeight.w700)),
      );
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const _Banner(
      {required this.icon,
      required this.color,
      required this.text,
      this.action,
      this.onAction});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 14, height: 1.3))),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ]),
      );
}

/// Cartão principal da tela (sem contorno, um tom acima do fundo).
class _Hero extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Hero({required this.child, required this.padding});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
            color: TG.surface, borderRadius: BorderRadius.circular(24)),
        child: child,
      );
}

/// Faixa tingida com a cor da atividade atual.
class _Tonal extends StatelessWidget {
  final Color color;
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Tonal(
      {required this.color, required this.child, required this.padding});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18)),
        child: child,
      );
}

/// Um limite da lei: quanto já usou de quanto pode.
class _Limit {
  final String title;
  final Duration value;
  final Duration limit;
  final Duration? mark; // risco intermediário (9 h dentro de 10 h, 13 em 15)
  final String? note;
  const _Limit(this.title, this.value, this.limit, {this.mark, this.note});
}

/// Os limites numa lista só: nome, barra (verde, amarelo, vermelho) e valor.
class _LimitList extends StatelessWidget {
  final List<_Limit> rows;
  const _LimitList({required this.rows});

  Widget _row(_Limit l) {
    final used = l.limit.inSeconds == 0
        ? 0.0
        : l.value.inSeconds / l.limit.inSeconds.toDouble();
    final color = TG.level(used);
    return Semantics(
      label: '${l.title}: ${fmtDur(l.value)} de ${l.limit.inHours} horas',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                if (l.note != null)
                  Text(l.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: TG.muted, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 8,
              child: Stack(children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: TG.surfaceHigh,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: used.clamp(0.0, 1.0).toDouble(),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: color, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
                if (l.mark != null)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment(
                          -1 + 2 * (l.mark!.inSeconds / l.limit.inSeconds), 0),
                      child: Container(width: 2, height: 8, color: TG.text),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Fit('${fmtDur(l.value)} / ${l.limit.inHours}h',
                alignment: Alignment.centerRight,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: used >= 0.85 ? color : TG.text)),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => TCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(children: [for (final r in rows) _row(r)]),
      );
}

/// O dia numa faixa colorida, como o disco do tacógrafo: cada trecho da
/// jornada na cor da atividade, do início até agora.
class _DayStrip extends StatelessWidget {
  final Shift shift;
  final DateTime now;
  const _DayStrip({required this.shift, required this.now});

  @override
  Widget build(BuildContext context) {
    final segs = shift.segments.where((s) => s.dur(now).inSeconds > 0).toList();
    final hasUnknown = segs.any((s) => s.act == Act.unknown);
    Widget key(Act a) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
                color: TG.act(a), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 4),
          Text(a == Act.load ? 'Carga' : actLabel(a),
              style: const TextStyle(color: TG.muted, fontSize: 11.5)),
        ]);
    return TCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Dia  •  ${fmtTime(shift.start)} até agora',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const Icon(Icons.route_rounded, color: TG.drive, size: 16),
          const SizedBox(width: 4),
          Text(fmtKm(shift.km),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 10),
        Semantics(
          label: 'Linha do tempo do dia',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 16,
              child: segs.isEmpty
                  ? const ColoredBox(color: TG.surfaceHigh)
                  : Row(children: [
                      for (var i = 0; i < segs.length; i++) ...[
                        if (i > 0) const SizedBox(width: 1),
                        Expanded(
                          flex: math.max(1, segs[i].dur(now).inMinutes),
                          child: ColoredBox(color: TG.act(segs[i].act)),
                        ),
                      ],
                    ]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 4, children: [
          key(Act.drive),
          key(Act.pause),
          key(Act.work),
          key(Act.load),
          if (hasUnknown) key(Act.unknown),
        ]),
      ]),
    );
  }
}

class _Total extends StatelessWidget {
  final Act act;
  final Duration value;
  const _Total(this.act, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Icon(TG.icon(act), color: TG.act(act), size: 22),
          const SizedBox(height: 4),
          Text(fmtDur(value),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(actLabel(act),
              style: const TextStyle(color: TG.muted, fontSize: 11.5)),
        ]),
      );
}

/// Escolha da atividade à mão: quatro opções num bloco só, a atual
/// pintada com a cor dela.
class _ActPicker extends StatelessWidget {
  final Act current;
  final void Function(Act) onPick;
  const _ActPicker({required this.current, required this.onPick});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: TG.surface, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          for (final a in [Act.drive, Act.pause, Act.work, Act.load])
            Expanded(
              child: Semantics(
                button: true,
                selected: current == a,
                label: actLabel(a),
                onTap: () => onPick(a),
                excludeSemantics: true,
                child: Material(
                  color: current == a
                      ? TG.act(a).withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onPick(a),
                    child: SizedBox(
                      height: 64,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(TG.icon(a),
                              color: current == a ? TG.act(a) : TG.muted,
                              size: 24),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Fit(a == Act.load ? 'Carga' : actLabel(a),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        current == a ? TG.act(a) : TG.muted)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
}

/// Barra do descanso com as marcas de 9 h e 11 h.
class _RestBar extends StatelessWidget {
  final Duration rest;
  const _RestBar({required this.rest});
  @override
  Widget build(BuildContext context) {
    final used = (rest.inSeconds / Limits.dailyRest.inSeconds).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (ctx, box) {
      final w = box.maxWidth;
      return Column(children: [
        SizedBox(
          height: 12,
          child: Stack(children: [
            Container(
                decoration: BoxDecoration(
                    color: TG.surfaceHigh,
                    borderRadius: BorderRadius.circular(6))),
            Container(
                width: w * used,
                decoration: BoxDecoration(
                    color: TG.pause, borderRadius: BorderRadius.circular(6))),
            Positioned(
                left: w * 9 / 11 - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: TG.text)),
          ]),
        ),
        const SizedBox(height: 4),
        Row(children: [
          const Text('0', style: TextStyle(color: TG.muted, fontSize: 11)),
          const Spacer(flex: 9),
          const Text('9 h', style: TextStyle(color: TG.muted, fontSize: 11)),
          const Spacer(flex: 2),
          const Text('11 h', style: TextStyle(color: TG.muted, fontSize: 11)),
        ]),
      ]);
    });
  }
}

class _RingPainter extends CustomPainter {
  final double used;
  final Color color;
  _RingPainter({required this.used, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 12;
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..color = TG.surfaceHigh;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..color = color;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(rect, start, sweep, false, bg);
    if (used > 0) canvas.drawArc(rect, start, sweep * used, false, fg);
    // Marcas a cada 30 min (9 partes em 4h30).
    final tick = Paint()
      ..color = TG.muted.withValues(alpha: 0.7)
      ..strokeWidth = 2;
    for (var i = 0; i <= 9; i++) {
      final a = start + sweep * i / 9;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * (r - 16);
      final p2 = c + Offset(math.cos(a), math.sin(a)) * (r - 22);
      canvas.drawLine(p1, p2, tick);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.used != used || old.color != color;
}
