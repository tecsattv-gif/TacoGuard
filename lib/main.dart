import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'i18n.dart';
import 'assistant.dart';
import 'charts_page.dart';
import 'law.dart';
import 'models.dart';
import 'pages.dart';
import 'popup.dart';
import 'rules.dart';
import 'theme.dart';
import 'tacho_link.dart';
import 'tacho_page.dart';
import 'tracker.dart';
import 'update_service.dart';

/// Ponto de entrada do pop-up por cima dos outros apps (roda separado).
/// ATENÇÃO: o @pragma tem de ficar colado na função.
@pragma('vm:entry-point')
Future<void> overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadLang();
  await loadTheme(systemBars: false); // 1.14.0: mesma paleta do app
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: TG.theme(),
    builder: clampTextScale,
    home: const OverlayRoot(),
  ));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadLang();
  await loadTheme(); // 1.14.0: paleta de cores (também acerta as barras)
  await Tracker.I.load();
  await TachoLink.I.load(); // 1.11.0: ligação ao tacógrafo (se ligada)
  runApp(const TacoApp());
}

class TacoApp extends StatefulWidget {
  const TacoApp({super.key});
  @override
  State<TacoApp> createState() => _TacoAppState();
}

class _TacoAppState extends State<TacoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 1.14.0: no modo automático, segue o telefone quando muda claro/escuro.
  @override
  void didChangePlatformBrightness() {
    if (themeModeChoice == 'auto') refreshTheme();
  }

  @override
  // 1.9.0: troca de idioma redesenha o app inteiro.
  // 1.14.0: troca da paleta de cores também.
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([langNotifier, themeNotifier]),
        builder: (context, _) => MaterialApp(
          title: 'TacoGuard',
          debugShowCheckedModeBanner: false,
          theme: TG.theme(),
          builder: clampTextScale,
          home: const SplashScreen(next: HomeShell()),
        ),
      );
}

/// Tela de abertura: escudo do TacoGuard + frase + créditos, por 2,5 segundos.
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
          // 1.12.9: splash nova (escudo + disco 24 h + volante + estrada),
          // feita em pé. Em pé enche o ecrã; deitado/tablet largo mostra a
          // imagem inteira sobre ela mesma desfocada.
          LayoutBuilder(builder: (context, c) {
            if (c.maxHeight >= c.maxWidth) {
              return Image.asset('assets/splash.jpg',
                  fit: BoxFit.cover, alignment: Alignment.topCenter);
            }
            return Stack(fit: StackFit.expand, children: [
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Image.asset('assets/splash.jpg', fit: BoxFit.cover),
              ),
              const ColoredBox(color: Color(0x88000000)),
              Image.asset('assets/splash.jpg', fit: BoxFit.contain),
            ]);
          }),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
              child: Column(
                children: [
                  const Spacer(),
                  Text(tr('Sua jornada dentro da lei do tacógrafo'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 12)
                          ])),
                  const SizedBox(height: 12),
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
                      Text(tr('DESENVOLVIDO POR'),
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
                        Text(tr('Versão {0}', [_version]),
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
    _t.onOverSpeed = _overSpeed;
    // Resposta vinda do pop-up por cima dos outros apps.
    try {
      _overlaySub = FlutterOverlayWindow.overlayListener.listen((event) {
        try {
          final m = jsonDecode(event.toString()) as Map;
          final v = m['stop'];
          if (v is! String) return;
          StopPopup.shown = false;
          _t.applyPopupAnswer(v);
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
    _t.onOverSpeed = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inFront = state == AppLifecycleState.resumed;
    if (!_inFront && _t.overSpeed) _overSpeed(true);
    if (_inFront) {
      SpeedPopup.close();
      StopPopup.close();
      final s = _t.currentSegment;
      final pending = s != null &&
          (s.act == Act.unknown || (_t.isAutoStop && _t.autoAsked));
      if (pending && !identical(s, _asked)) {
        _ask(s);
      }
      if (mounted) UpdateService.autoCheck(context, resumed: true);
    }
  }

  /// 1.9.3: acima do limite com o app minimizado: aviso por cima dos outros
  /// apps; voltou ao limite (ou o app veio para a frente): fecha.
  void _overSpeed(bool on) {
    if (!mounted) return;
    if (on && !_inFront && _t.overSince != null) {
      SpeedPopup.show(
          limit: _t.speedLimit,
          since: _t.overSince!,
          screenWidthDp: MediaQuery.sizeOf(context).width);
    } else if (!on) {
      SpeedPopup.close();
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
              Text(
                  seg.act == Act.work
                      ? tr('Parado há 15 min. É pausa?')
                      : tr('O que é esta parada?'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                  seg.act == Act.work
                      ? tr('Em martelo desde {0}, como o tacógrafo. Escolha para mudar desde essa hora:', [fmtTime(seg.start)])
                      : tr('Parado desde {0}', [fmtTime(seg.start)]),
                  style: TextStyle(color: TG.muted, fontSize: 13)),
              const SizedBox(height: 16),
              StopChoices(onPick: (a) => Navigator.pop(ctx, a)),
              const SizedBox(height: 4),
              SizedBox(
                height: 48,
                child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(tr('Responder depois'))),
              ),
            ],
          ),
        ),
      ),
    );
    _sheetOpen = false;
    if (a != null && identical(_t.currentSegment, seg)) _t.setAct(a);
    // "Responder depois" no martelo automático: fica martelo, como o tacógrafo.
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['TacoGuard', tr('Histórico'), tr('Relatórios'), tr('Lei'), tr('Ajustes')];
    final pages = <Widget>[
      const TodayPage(),
      const HistoryPage(),
      const ReportsPage(),
      const _LawTabs(),
      const SettingsPage(),
    ];
    final dests = [
      (Icons.speed_rounded, tr('Hoje')),
      (Icons.history_rounded, tr('Histórico')),
      (Icons.picture_as_pdf_rounded, tr('Relatórios')),
      (Icons.gavel_rounded, tr('Lei')),
      (Icons.settings_rounded, tr('Ajustes')),
    ];
    final size = MediaQuery.sizeOf(context);
    // 1.8.5: tablet ou telefone deitado: menu na lateral (sobra altura para
    // o conteúdo) e as outras telas com largura de leitura, centradas.
    final wide = size.width >= 640;
    Widget page(int i) {
      final p = pages[i];
      if (!wide || i == 0) return p;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820), child: p),
      );
    }

    final body = IndexedStack(
        index: _tab, children: [for (var i = 0; i < pages.length; i++) page(i)]);
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
        // 1.13.0: atalho para os gráficos (também sem tacógrafo ligado).
        actions: [
          if (_tab <= 1)
            IconButton(
              tooltip: tr('Gráficos'),
              icon: const Icon(Icons.bar_chart_rounded),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChartsPage())),
            ),
        ],
      ),
      body: wide
          ? Row(children: [
              SafeArea(
                right: false,
                child: NavigationRail(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  groupAlignment: 0,
                  // Telefone deitado tem pouca altura: só os ícones.
                  labelType: size.height >= 520
                      ? NavigationRailLabelType.all
                      : NavigationRailLabelType.none,
                  destinations: [
                    for (final d in dests)
                      NavigationRailDestination(
                          icon: Icon(d.$1), label: Text(d.$2)),
                  ],
                ),
              ),
              VerticalDivider(width: 1, color: TG.line),
              // Deitado, os botões do Android ficam à direita: o conteúdo
              // não pode ficar por baixo deles.
              Expanded(
                  child: SafeArea(
                      left: false, top: false, bottom: false, child: body)),
            ])
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                for (final d in dests)
                  NavigationDestination(icon: Icon(d.$1), label: d.$2),
              ],
            ),
    );
  }
}

class _LawTabs extends StatelessWidget {
  const _LawTabs();
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Column(children: [
          TabBar(
            dividerColor: TG.line,
            tabs: [Tab(text: tr('Lei do tacógrafo')), Tab(text: tr('Consulta'))],
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
    TachoLink.I.addListener(_refresh);
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_refresh);
    TachoLink.I.removeListener(_refresh);
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
        title: Text(tr('Iniciar a jornada?')),
        content: Text(tr('A jornada começa agora, às {0}, e o GPS passa a contar a condução e as paradas.', [fmtTime(now)]) +
            (short
                ? '\n\n${tr('Atenção: o descanso ainda tem só {0} (faltam {1} para as 9 h).', [fmtDur(rest), fmtDur(Limits.dailyRestReduced - rest)])}'
                : '')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Cancelar'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('Iniciar'))),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final err = await _t.startShift();
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('{0} A jornada foi aberta, mas sem GPS as paradas não são detectadas sozinhas.', [err]))));
    }
    if (_t.popup && !await StopPopup.hasPermission() && mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('Pop-up das paradas')),
          content: Text(
              tr('Para o TacoGuard perguntar "Pausa, Martelo ou Carga/Descarga?" por cima do Google Maps e de outros apps, libere a permissão "Sobrepor a outros apps".')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('Agora não'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr('Liberar'))),
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
        title: Text(tr('Reabrir a jornada?')),
        content: Text(
            tr('A jornada iniciada às {0} continua: a amplitude e os tempos seguem contando desde o início.\n\nComo contar o tempo desde que encerrou ({1})?', [fmtTime(sh.start), fmtDur(gap)])),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('Cancelar'))),
          Row(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton(
                onPressed: () => Navigator.pop(ctx, Act.work),
                child: Text(tr('Martelo'))),
            const SizedBox(width: 8),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, Act.pause),
                child: Text(tr('Pausa'))),
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
        title: Text(tr('Encerrar a jornada?')),
        content: Text(tr('A partir de agora começa a contar o descanso.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Cancelar'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('Encerrar'))),
        ],
      ),
    );
    if (ok != true) return;
    await _t.endShift();
    if (!mounted) return;
    await _askAlarm();
  }

  /// 1.8.2: ao encerrar, pergunta se quer pôr o despertador do telefone
  /// para o fim do descanso de 9 h ou de 11 h.
  Future<void> _askAlarm() async {
    final end = DateTime.now();
    final h = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Acertar o despertador?')),
        content: Text(
            tr('O despertador do telefone toca no fim do descanso.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 0),
              child: Text(tr('Não'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 9),
              child: Text('9 h  (${fmtTime(end.add(const Duration(hours: 9)))})')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 11),
              child: Text('11 h  (${fmtTime(end.add(const Duration(hours: 11)))})')),
        ],
      ),
    );
    if (h == null || h == 0) return;
    final at = end.add(Duration(hours: h));
    try {
      await AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: <String, dynamic>{
          'android.intent.extra.alarm.HOUR': at.hour,
          'android.intent.extra.alarm.MINUTES': at.minute,
          'android.intent.extra.alarm.MESSAGE': tr('TacoGuard: fim do descanso de {0} h', [h]),
          'android.intent.extra.alarm.SKIP_UI': true,
        },
      ).launch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Despertador acertado para {0} (descanso de {1} h).', [fmtTime(at), h]))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Não deu para acertar o despertador. Acerte à mão para {0}.', [fmtTime(at)]))));
      }
    }
  }

  /// 1.14.17: velocidade mostrada. GPS normalmente; sem GPS, ou se o GPS
  /// discordar do tacógrafo em mais de 15 km/h (ex.: 0 a andar a 91, logo a
  /// seguir a o GPS voltar), vale a do tacógrafo.
  String _shownSpeed() {
    final tk = TachoLink.I.speedKmh;
    if (_t.gpsStale) return tk != null ? '${tk.round()}' : '--';
    final g = _t.speedKmh;
    if (tk != null && (g - tk).abs() > 15) return '${tk.round()}';
    return '${g.round()}';
  }

  /// 1.14.9: o que o GPS está a mandar (para saber porque não há sinal).
  String _gpsDiag() {
    final at = _t.rawAt;
    if (at == null) {
      final err = _t.gpsStreamError;
      return '${tr('GPS: nenhuma leitura recebida.')} (${_t.gpsRestarts}×)${err == null ? '' : '\n$err'}';
    }
    final secs = DateTime.now().difference(at).inSeconds;
    return tr('GPS: última leitura há {0} s, precisão {1} m, {2} de {3} recusadas.', [
      '$secs',
      (_t.rawAcc ?? 0).round().toString(),
      '${_t.rawRejected}',
      '${_t.rawCount}',
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = _t.current;
    final now = DateTime.now();
    final items = c == null ? _closed(now) : _open(c, now);
    // 1.11.8: tempos do tacógrafo (só com Bluetooth ligado).
    if (items.isNotEmpty) items.insert(1, const TachoLiveCard());
    final pad = EdgeInsets.fromLTRB(
        16, 4, 16, 28 + MediaQuery.paddingOf(context).bottom);
    return LayoutBuilder(builder: (context, box) {
      final cut = items.indexWhere((w) => w is _ColBreak);
      // 1.8.5: tela larga (tablet ou telefone deitado): duas colunas. À
      // esquerda o estado e o anel; à direita o dia, os limites e o resto.
      // 1.8.8: deitado (paisagem), a esquerda fica FIXA: o cartão da
      // atividade e o anel do que falta para a pausa, encolhidos para
      // caber na altura. A direita rola sozinha (avisos, dia, limites,
      // linha do tempo e botões).
      if (box.maxWidth >= 700 && box.maxWidth > box.maxHeight && cut > 0) {
        // 1.13.2: deitado, as duas colunas rolam cada uma por si (antes a
        // esquerda era fixa e encolhia tudo para caber na altura).
        // Esquerda: o estado, o tacógrafo ao vivo e o anel; direita: o dia,
        // os limites e o resto.
        final bottom = 28 + MediaQuery.paddingOf(context).bottom;
        final left = [
          for (final w in items.sublist(0, cut))
            if (!(w is SizedBox && w.child == null)) ...[
              w,
              const SizedBox(height: 10),
            ],
        ];
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 5,
            child: ListView(
              primary: false,
              padding: EdgeInsets.fromLTRB(16, 4, 0, bottom),
              children: left,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: ListView(
              primary: false,
              padding: EdgeInsets.fromLTRB(0, 4, 16, bottom),
              children: items.sublist(cut + 1),
            ),
          ),
        ]);
      }
      if (box.maxWidth >= 700 && cut > 0) {
        return SingleChildScrollView(
          padding: pad,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                flex: 5,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: items.sublist(0, cut))),
            const SizedBox(width: 16),
            Expanded(
                flex: 6,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: items.sublist(cut + 1))),
          ]),
        );
      }
      return ListView(
        padding: pad,
        children: [
          for (final w in items)
            if (w is _ColBreak) const SizedBox(height: 12) else w,
        ],
      );
    });
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
            Icon(Icons.hotel_rounded, color: TG.pause, size: 40),
            const SizedBox(height: 8),
            Text(tr('Pronto para começar'),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ],
          if (rest != null) ...[
            Text(
                ref?.end == null
                    ? tr('Em descanso')
                    : tr('Em descanso desde {0}', [fmtTime(ref!.end!)]),
                style: TextStyle(color: TG.muted, fontSize: 14)),
            const SizedBox(height: 2),
            Text(fmtDur(rest),
                style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: TG.pause,
                    letterSpacing: -1,
                    fontFeatures: [FontFeature.tabularFigures()],
                    height: 1.05)),
            const SizedBox(height: 4),
            Text(_restText(rest),
                textAlign: TextAlign.center,
                style: TextStyle(color: TG.muted, fontSize: 14)),
            if (ref != null && ref.endLat != null && ref.endLon != null)
              TextButton.icon(
                onPressed: () => openMap(context, ref.endLat!, ref.endLon!),
                icon: const Icon(Icons.place_rounded, size: 18),
                label: Text(tr('Local do descanso: {0}, {1}', [ref.endLat!.toStringAsFixed(5), ref.endLon!.toStringAsFixed(5)])),
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
              label: Fit(tr('Iniciar jornada'),
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
                    tr('Reabrir a jornada das {0}', [fmtTime(_t.reopenable!.start)]),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
          if (rest == null) ...[
            const SizedBox(height: 10),
            Text(
                tr('Depois de iniciar, o GPS faz o resto: detecta as paradas, grava o local e conta os tempos.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: TG.muted, fontSize: 12.5)),
          ],
        ]),
      ),
      const _ColBreak(),
      // 1.11.11: com o tacógrafo ligado, os valores vêm dele.
      _LimitList(rows: [
        _Limit(tr('Semanal'), TachoLink.I.weekDrive ?? week, Limits.weeklyDrive,
            note: TachoLink.I.weekDrive != null ? tr('do tacógrafo') : null),
        _Limit(
            tr('Bissemanal'),
            TachoLink.I.fortnightDrive ??
                ((TachoLink.I.weekDrive ?? week) + prev),
            Limits.fortnightDrive,
            note: TachoLink.I.fortnightDrive != null
                ? tr('do tacógrafo')
                : TachoLink.I.weekDrive != null
                    ? tr('semana do tacógrafo + semana anterior do app')
                    : null),
      ]),
      if (ref != null) ...[
        const SizedBox(height: 12),
        TCard(
          child: Row(children: [
            Icon(Icons.flag_rounded, color: TG.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  tr('Última jornada: {0} {1}, {2} às {3}  •  condução {4}  •  {5}', [weekdayShort(ref.start), fmtDate(ref.start), fmtTime(ref.start), ref.end == null ? '-' : fmtTime(ref.end!), fmtDur(ref.total(Act.drive, now)), fmtKm(ref.km)]),
                  style: const TextStyle(fontSize: 14)),
            ),
          ]),
        ),
      ],
    ];
  }

  String _restText(Duration rest) {
    if (rest >= Limits.weeklyRest) return tr('Descanso semanal de 45 h cumprido');
    if (rest >= Limits.weeklyRestReduced) {
      return tr('Descanso semanal reduzido (24 h) cumprido');
    }
    if (rest >= Limits.dailyRest) return tr('Descanso diário de 11 h cumprido');
    if (rest >= Limits.dailyRestReduced) {
      return tr('Descanso reduzido de 9 h cumprido • faltam {0} para as 11 h', [fmtDur(Limits.dailyRest - rest)]);
    }
    return tr('Faltam {0} para 9 h e {1} para 11 h', [fmtDur(Limits.dailyRestReduced - rest), fmtDur(Limits.dailyRest - rest)]);
  }

  String _mmss(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  /// Ex.: 7h de condução num dia em que ainda há dias de 10 h:
  /// "Ainda pode conduzir: 2h00 (9h) ou 3h00 (10h)".
  String _canDriveText(Status st, DateTime shiftStart) {
    Duration rest(Duration lim) {
      final d = lim - st.dayDrive;
      return d.isNegative ? Duration.zero : d;
    }

    var r9 = rest(Limits.dailyDrive);
    var r10 = rest(Limits.dailyDriveExt);
    // 1.10.1: o fim da amplitude também limita (antes dava as 10 h inteiras
    // e passava da amplitude).
    final amp = st.amplitudeDriveLeft;
    final end = fmtTime(shiftStart.add(st.amplitudeLimit));
    final top = st.dayLimit < Limits.dailyDriveExt ? r9 : r10;
    if (amp < top) {
      if (amp == Duration.zero) {
        return tr('Fim da amplitude ({0}): encerre a jornada', [end]);
      }
      if (st.dayLimit >= Limits.dailyDriveExt && amp > r9 && r9 > Duration.zero) {
        return tr('Ainda pode conduzir: {0} (9h) ou {1} (amplitude, até {2})',
            [fmtDur(r9), fmtDur(amp), end]);
      }
      return tr('Ainda pode conduzir: {0} (amplitude, até {1})',
          [fmtDur(amp), end]);
    }
    if (amp < r10) r10 = amp;
    if (amp < r9) r9 = amp;
    if (st.dayLimit < Limits.dailyDriveExt) {
      return r9 == Duration.zero
          ? tr('Limite de 9h do dia atingido')
          : tr('Ainda pode conduzir: {0} (até 9h)', [fmtDur(r9)]);
    }
    if (r10 == Duration.zero) return tr('Limite de 10h do dia atingido');
    if (r9 == Duration.zero) {
      return tr('Ainda pode conduzir: {0} (até 10h)', [fmtDur(r10)]);
    }
    return tr('Ainda pode conduzir: {0} (9h) ou {1} (10h)', [fmtDur(r9), fmtDur(r10)]);
  }

  // ---------- Jornada aberta ----------
  List<Widget> _open(Shift c, DateTime now) {
    final st = computeStatus(_t.shifts, c, now);
    final act = _t.currentAct ?? Act.unknown;
    final seg = _t.currentSegment;
    final b = st.brk;
    // 1.7.2: o anel mostra o que falta pelo limite que chega primeiro
    // (pausa das 4h30, fim das 9 h/10 h do dia ou a semana). Depois de
    // uma pausa completa volta às 4h30, ou ao que sobra do dia, se for menos.
    final left = st.driveLeft;
    final next = st.nextLimit;
    final usedCd = b.exceeded
        ? b.driven.inSeconds / Limits.continuousDrive.inSeconds.toDouble()
        : 1 - left.inSeconds / Limits.continuousDrive.inSeconds.toDouble();
    final stopNow = !b.exceeded && left == Duration.zero;
    final issues = shiftIssues(_t.shifts, c, now);
    final alertFresh = _t.lastAlert != null &&
        _t.lastAlertAt != null &&
        now.difference(_t.lastAlertAt!).inMinutes < 10;
    return [
      // Estado atual: faixa na cor da atividade.
      _Tonal(
        color: TG.act(act),
        blink: _t.overSpeed, // 1.7.9: acima do limite: vermelho a piscar
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          ActIcon(act, color: TG.act(act), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t.carMode ? tr('{0} • de carro', [actLabel(act)]) : actLabel(act),
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: TG.act(act))),
                Text(
                    seg == null
                        ? ''
                        : tr('desde {0}  •  {1}', [fmtTime(seg.start), fmtDur(seg.dur(now))]),
                    style: TextStyle(color: TG.muted, fontSize: 13)),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // 1.14.4: sem GPS, mostra a velocidade do tacógrafo (se ligado).
            Text(
                _shownSpeed(),
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
              Text('km/h',
                  style: TextStyle(color: TG.muted, fontSize: 11)),
            ]),
          ]),
        ]),
      ),
      if (_t.overSpeed) ...[
        const SizedBox(height: 10),
        // 1.9.9: igual ao aviso por cima dos outros apps: contagem grande
        // à esquerda, texto à direita.
        _SpeedCountdown(left: _t.overSecondsLeft, limit: _t.speedLimit),
      ],
      if (_t.gpsError == null && _t.gpsOn && _t.gpsStale) ...[
        const SizedBox(height: 10),
        _Banner(
            icon: Icons.gps_not_fixed_rounded,
            color: TG.warn,
            text: '${tr('Sem sinal de GPS no momento. Perto da janela ou do para-brisa o sinal volta.')}\n${_gpsDiag()}',
            action: _t.locationAlways ? null : tr('Localização o tempo todo'),
            onAction: _t.locationAlways ? null : () => _t.askLocationAlways()),
      ],
      if (_t.gpsError != null) ...[
        const SizedBox(height: 10),
        _Banner(
            icon: Icons.gps_off_rounded,
            color: TG.danger,
            text: _t.gpsError!,
            action: tr('Tentar'),
            onAction: () => _t.startGps()),
      ],
      if (_t.stoppedSince != null &&
          now.difference(_t.stoppedSince!).inSeconds >= 10) ...[
        const SizedBox(height: 10),
        TCard(
          child: Column(children: [
            Text(tr('Parado há {0}', [_mmss(now.difference(_t.stoppedSince!))]),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(
                tr('Com {0} min parado vira martelo, como o tacógrafo. Já pode escolher:', [_t.stopMinutes]),
                textAlign: TextAlign.center,
                style: TextStyle(color: TG.muted, fontSize: 12.5)),
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
            text: tr('De carro: o movimento não conta como condução e a parada continua. Volta ao normal sozinho quando você chegar ao caminhão.'),
            action: tr('Voltei'),
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
            label: Fit(tr('Vou sair de carro')),
          ),
        ),
      ],
      if (_t.isAutoStop) ...[
        const SizedBox(height: 10),
        TCard(
          child: Column(children: [
            Text(tr('Martelo automático desde {0}', [fmtTime(_t.autoStop!.start)]),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(
                tr('Como no tacógrafo, a parada fica em martelo. Se for pausa ou carga/descarga, toque para mudar desde essa hora:'),
                textAlign: TextAlign.center,
                style: TextStyle(color: TG.muted, fontSize: 12.5)),
            const SizedBox(height: 10),
            StopChoices(onPick: (a) => _t.setAct(a)),
          ]),
        ),
      ],
      if (act == Act.unknown) ...[
        const SizedBox(height: 10),
        TCard(
          child: Column(children: [
            Text(tr('O que é esta parada?'),
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
                  Text(
                      b.exceeded
                          ? tr('PAUSA JÁ')
                          : stopNow
                              ? tr('PARAR')
                              : tr('Faltam'),
                      style: TextStyle(
                          color: b.exceeded || stopNow ? TG.danger : TG.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text(
                      b.exceeded
                          ? '+${fmtDur(b.driven - Limits.continuousDrive)}'
                          : fmtDur(left),
                      style: TextStyle(
                          fontSize: 54,
                          height: 1.1,
                          letterSpacing: -1,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: TG.level(usedCd))),
                  // 1.10.4: cabe dentro do anel (antes o texto da amplitude
                  // passava por cima do arco).
                  SizedBox(
                    width: 140,
                    child: Text(
                        b.exceeded || next == 'pausa'
                            ? tr('para a pausa')
                            : next == 'dia'
                                ? tr('para as {0}h do dia', [st.dayLimit.inHours])
                                : next == 'amplitude'
                                    ? tr('fim da amplitude às {0}',
                                        [fmtTime(c.start.add(st.amplitudeLimit))])
                                    : tr('para o limite da semana'),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: TG.muted, fontSize: 13, height: 1.2)),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Fit(tr('Condução contínua: {0} de 4h30', [fmtDur(b.driven)]),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Fit(tr('Condução do dia: {0}', [fmtDur(st.dayDrive)]),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          // 1.7.5: quanto ainda pode conduzir hoje, nas 9 h e nas 10 h.
          // 1.10.4: até duas linhas, sem encolher a letra.
          Text(_canDriveText(st, c.start),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: TG.ok)),
          const SizedBox(height: 2),
          Fit(
              b.firstPartDone
                  ? tr('1ª parte (15 min) feita • falta a de 30 min')
                  : tr('Próxima pausa: 45 min (ou 15 + 30)'),
              style: TextStyle(color: TG.muted, fontSize: 13)),
        ]),
      ),
      const _ColBreak(),
      // O dia numa faixa colorida, como o disco do tacógrafo.
      _DayStrip(shift: c, now: now),
      const SizedBox(height: 12),
      // Todos os limites numa lista só.
      _LimitList(rows: [
        _Limit(tr('Condução hoje'), st.dayDrive, st.dayLimit,
            mark: st.dayLimit > Limits.dailyDrive ? Limits.dailyDrive : null,
            note: st.dayLimit > Limits.dailyDrive
                ? tr('dias de 10 h: {0}/2', [st.extUsed + (st.extToday ? 1 : 0)])
                : tr('limite 9 h (já usou 2 dias de 10 h)')),
        _Limit(tr('Amplitude'), st.amplitude, st.amplitudeLimit,
            mark: st.canExtendAmplitude ? Limits.amplitude : null,
            note: st.canExtendAmplitude
                ? tr('descansos de 9 h: {0}/3', [st.reducedRestsUsed])
                : tr('limite 13 h (sem descanso reduzido)')),
        _Limit(tr('Semanal'), TachoLink.I.weekDrive ?? st.weekDrive,
            Limits.weeklyDrive,
            note: TachoLink.I.weekDrive != null
                ? tr('do tacógrafo')
                : tr('pode conduzir {0}', [fmtDur(st.weekLeft)])),
        _Limit(
            tr('Bissemanal'),
            TachoLink.I.fortnightDrive ??
                (TachoLink.I.weekDrive != null
                    ? TachoLink.I.weekDrive! + st.prevWeekDrive
                    : st.fortnightDrive),
            Limits.fortnightDrive,
            note: TachoLink.I.fortnightDrive != null
                ? tr('do tacógrafo')
                : tr('semana anterior {0}', [fmtDur(st.prevWeekDrive)])),
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
            Icon(Icons.weekend_rounded, color: TG.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  tr('Descanso semanal: começar até {0} {1}', [weekdayShort(st.weeklyRestDeadline!), fmtDateTime(st.weeklyRestDeadline!)]),
                  style: const TextStyle(fontSize: 14)),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 16),
      // Trocar atividade à mão.
      _Section(tr('Trocar a atividade à mão')),
      _ActPicker(current: act, onPick: (a) => _t.setAct(a)),
      if (issues.isNotEmpty) ...[
        const SizedBox(height: 16),
        _Section(tr('Avisos')),
        for (final i in issues)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Banner(
                icon: Icons.warning_amber_rounded,
                color: i == tr('Há paradas ainda não classificadas (contadas como pausa).') ? TG.warn : TG.danger,
                text: i),
          ),
      ],
      const SizedBox(height: 16),
      _Section(tr('Linha do tempo  •  início {0}', [fmtTime(c.start)])),
      SegmentList(shift: c),
      const SizedBox(height: 18),
      SizedBox(
        height: 56,
        child: OutlinedButton.icon(
          onPressed: _end,
          style: OutlinedButton.styleFrom(
              foregroundColor: TG.danger,
              side: BorderSide(color: TG.danger, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18))),
          icon: const Icon(Icons.stop_rounded),
          label: Fit(tr('Encerrar jornada'),
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
            style: TextStyle(
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
/// 1.9.9: faixa do aviso de velocidade com a contagem regressiva grande
/// (igual à do aviso por cima dos outros apps).
class _SpeedCountdown extends StatelessWidget {
  final int? left;
  final int limit;
  const _SpeedCountdown({required this.left, required this.limit});

  @override
  Widget build(BuildContext context) {
    final l = left;
    final text = l != null
        ? tr('Acima de {0} km/h. Reduza em {1} s, senão vira infração.', [limit, l])
        : tr('Excesso de velocidade a ser registado. Reduza para {0} km/h.',
            [limit]);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: TG.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TG.danger, width: 2),
      ),
      child: Row(children: [
        SizedBox(
          width: 96,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(l != null ? '$l s' : '!',
                style: TextStyle(
                    color: TG.danger,
                    fontSize: 40,
                    height: 1,
                    fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: TG.text, fontSize: 17, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

/// 1.8.5: onde a tela Hoje se divide em duas colunas na tela larga.
/// Na tela estreita vira só um espaço de 12.
class _ColBreak extends StatelessWidget {
  const _ColBreak();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 12);
}

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
  final bool blink;
  const _Tonal(
      {required this.color,
      required this.child,
      required this.padding,
      this.blink = false});
  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18)),
      child: child,
    );
    return blink ? _RedBlink(child: box) : box;
  }
}

/// 1.7.9: cartão vermelho a piscar (velocidade acima do limite).
class _RedBlink extends StatefulWidget {
  final Widget child;
  const _RedBlink({required this.child});
  @override
  State<_RedBlink> createState() => _RedBlinkState();
}

class _RedBlinkState extends State<_RedBlink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        child: widget.child,
        builder: (context, child) => Container(
          decoration: BoxDecoration(
            color: Color.lerp(const Color(0x33DC2626), const Color(0xFFDC2626),
                _a.value),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEF4444), width: 2),
          ),
          child: child,
        ),
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
      label: tr('{0}: {1} de {2} horas', [l.title, fmtDur(l.value), l.limit.inHours]),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                if (l.note != null)
                  Text(l.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: TG.muted, fontSize: 11.5)),
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
          Text(a == Act.load ? tr('Carga') : actLabel(a),
              style: TextStyle(color: TG.muted, fontSize: 11.5)),
        ]);
    return TCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(tr('Dia  •  {0} até agora', [fmtTime(shift.start)]),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          Icon(Icons.route_rounded, color: TG.drive, size: 16),
          const SizedBox(width: 4),
          Text(fmtKm(shift.km),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 10),
        Semantics(
          label: tr('Linha do tempo do dia'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 16,
              child: segs.isEmpty
                  ? ColoredBox(color: TG.surfaceHigh)
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
          ActIcon(act, color: TG.act(act), size: 22),
          const SizedBox(height: 4),
          Text(fmtDur(value),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(actLabel(act),
              style: TextStyle(color: TG.muted, fontSize: 11.5)),
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
                          ActIcon(a,
                              color: current == a ? TG.act(a) : TG.muted,
                              size: 24),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Fit(a == Act.load ? tr('Carga') : actLabel(a),
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
          Text('0', style: TextStyle(color: TG.muted, fontSize: 11)),
          const Spacer(flex: 9),
          Text('9 h', style: TextStyle(color: TG.muted, fontSize: 11)),
          const Spacer(flex: 2),
          Text('11 h', style: TextStyle(color: TG.muted, fontSize: 11)),
        ]),
      ]);
    });
  }
}

class _RingPainter extends CustomPainter {
  final double used;
  final Color color;
  // 1.14.0: redesenha quando a paleta de cores muda.
  final int _gen = themeNotifier.value;
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
      old.used != used || old.color != color || old._gen != _gen;
}
