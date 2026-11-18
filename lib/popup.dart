import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n.dart';
import 'models.dart';
import 'theme.dart';

/// Tamanho do pop-up, em dp.
const double kPopW = 330, kPopH = 250;

/// O que cada resposta quer dizer (linha pequena embaixo do nome).
String stopHint(Act a) {
  switch (a) {
    case Act.pause:
      return tr('conta para a pausa de 45 min');
    case Act.work:
      return tr('outros trabalhos');
    case Act.load:
      return tr('conta como trabalho');
    default:
      return '';
  }
}

/// Os três botões da pergunta "o que é esta parada?".
/// [compact]: lado a lado, para o pop-up por cima dos outros apps, que
/// tem tamanho fixo. Sem ele: um embaixo do outro, grandes, com a
/// explicação de cada um.
class StopChoices extends StatelessWidget {
  final void Function(Act) onPick;
  final bool compact;
  const StopChoices({super.key, required this.onPick, this.compact = false});

  Widget _tile(Act a) {
    final c = TG.act(a);
    if (compact) {
      // 1.7.6: no pop-up por cima dos outros apps, responde logo no toque
      // (onTapDown). Com o caminhão a vibrar, o dedo mexe e o toque normal
      // (que espera soltar sem arrastar) às vezes não era aceito.
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onPick(a),
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ActIcon(a, color: c, size: 32),
              const SizedBox(height: 8),
              Text(
                a == Act.load ? tr('Carga/\nDescarga') : actLabel(a),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: c,
                    fontSize: 13,
                    height: 1.1,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }
    return Material(
      color: c.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onPick(a),
        child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  ActIcon(a, color: c, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(actLabel(a),
                            style: TextStyle(
                                color: c,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                        Text(stopHint(a),
                            style: const TextStyle(
                                color: TG.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ]),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const acts = [Act.pause, Act.work, Act.load];
    if (compact) {
      return Row(children: [
        for (final a in acts)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _tile(a),
            ),
          ),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in acts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _tile(a),
          ),
      ],
    );
  }
}

/// Abre e fecha o pop-up por cima dos outros apps (Google Maps etc.).
class StopPopup {
  static bool shown = false;

  static Future<bool> hasPermission() async {
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestPermission() async {
    try {
      await FlutterOverlayWindow.requestPermission();
    } catch (_) {}
  }

  static Future<void> show(Segment seg, double screenWidthDp) async {
    try {
      if (!await hasPermission()) return;
      final p = await SharedPreferences.getInstance();
      await p.setString('popup_since', fmtTime(seg.start));
      await p.setBool('popup_auto', seg.act == Act.work);
      await p.remove('popup_answer');
      await p.setString('popup_mode', 'stop');
      await p.setInt('popup_nonce', DateTime.now().millisecondsSinceEpoch);
      if (shown || SpeedPopup.shown) await SpeedPopup.close();
      if (shown) await close();
      final dpr = WidgetsBinding
          .instance.platformDispatcher.views.first.devicePixelRatio;
      await FlutterOverlayWindow.showOverlay(
        height: (kPopH * dpr).round(),
        width: (kPopW * dpr).round(),
        alignment: OverlayAlignment.topLeft,
        // 1.7.6: sem arrastar. Com arrastar ligado, o toque nos botões
        // podia ser tomado como arrasto e a escolha não era aceita.
        enableDrag: false,
        positionGravity: PositionGravity.none,
        startPosition: OverlayPosition((screenWidthDp - kPopW) / 2, 80),
        overlayTitle: 'TacoGuard',
        overlayContent: tr('Parado há 15 min: é pausa?'),
      );
      shown = true;
    } catch (_) {}
  }

  static Future<void> close() async {
    if (!shown) return;
    shown = false;
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }
}

/// 1.9.3: aviso de velocidade por cima dos outros apps (WhatsApp, YouTube,
/// Google Maps…), com o app minimizado: cartão vermelho a piscar com a
/// velocidade e a contagem dos 60 s. Não recebe toques (o toque passa para o
/// app de baixo).
const double kSpeedW = 330, kSpeedH = 176;

class SpeedPopup {
  static bool shown = false;

  static Future<void> show({
    required int limit,
    required DateTime since,
    required double screenWidthDp,
  }) async {
    try {
      if (shown || StopPopup.shown) return;
      if (!await StopPopup.hasPermission()) return;
      final p = await SharedPreferences.getInstance();
      await p.setString('popup_mode', 'speed');
      await p.setInt('popup_nonce', DateTime.now().millisecondsSinceEpoch);
      await p.setInt('speed_limit', limit);
      await p.setInt('speed_since', since.millisecondsSinceEpoch);
      final dpr = WidgetsBinding
          .instance.platformDispatcher.views.first.devicePixelRatio;
      await FlutterOverlayWindow.showOverlay(
        height: (kSpeedH * dpr).round(),
        width: (kSpeedW * dpr).round(),
        alignment: OverlayAlignment.topLeft,
        enableDrag: false,
        flag: OverlayFlag.clickThrough,
        positionGravity: PositionGravity.none,
        startPosition: OverlayPosition((screenWidthDp - kSpeedW) / 2, 60),
        overlayTitle: 'TacoGuard',
        overlayContent: tr('Acima de {0} km/h', [limit]),
      );
      shown = true;
    } catch (_) {}
  }

  /// Velocidade atual para o cartão (a cada leitura do GPS).
  /// 1.9.4: manda também os segundos que faltam (a contagem não dependia
  /// mais só das preferências, que o pop-up às vezes não lia: ficava em 60).
  static void speed(double kmh, int? left) {
    if (!shown) return;
    try {
      FlutterOverlayWindow.shareData(
          jsonEncode({'kmh': kmh.round(), 'left': left ?? 0}));
    } catch (_) {}
  }

  static Future<void> close() async {
    if (!shown) return;
    shown = false;
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }
}

/// Raiz da janela por cima dos outros apps: mostra o pop-up da parada ou o
/// aviso de velocidade, conforme o que o app pediu.
class OverlayRoot extends StatefulWidget {
  const OverlayRoot({super.key});
  @override
  State<OverlayRoot> createState() => _OverlayRootState();
}

class _OverlayRootState extends State<OverlayRoot> {
  String _mode = 'stop';
  int _nonce = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _read();
    // A janela pode ser reaproveitada de uma vez para outra: confere o modo.
    _timer = Timer.periodic(
        const Duration(milliseconds: 500), (_) => _read());
  }

  Future<void> _read() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      final m = p.getString('popup_mode') ?? 'stop';
      final n = p.getInt('popup_nonce') ?? 0;
      if (mounted && (m != _mode || n != _nonce)) {
        setState(() {
          _mode = m;
          _nonce = n;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _mode == 'speed'
      ? SpeedPopupWindow(key: ValueKey('s$_nonce'))
      : StopPopupWindow(key: ValueKey('p$_nonce'));
}

class SpeedPopupWindow extends StatefulWidget {
  const SpeedPopupWindow({super.key});
  @override
  State<SpeedPopupWindow> createState() => _SpeedPopupWindowState();
}

class _SpeedPopupWindowState extends State<SpeedPopupWindow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450))
    ..repeat(reverse: true);
  int _limit = 90;
  DateTime? _since;
  int? _kmh;
  int? _left; // segundos que faltam, vindos do app
  DateTime _leftAt = DateTime.now();
  Timer? _tick;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
    try {
      _sub = FlutterOverlayWindow.overlayListener.listen((e) {
        try {
          final m = jsonDecode(e.toString()) as Map;
          final v = m['kmh'];
          final l = m['left'];
          if (!mounted) return;
          setState(() {
            if (v is num) _kmh = v.round();
            if (l is num) {
              _left = l.round();
              _leftAt = DateTime.now();
            }
          });
        } catch (_) {}
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      final s = p.getInt('speed_since');
      if (mounted) {
        setState(() {
          _limit = p.getInt('speed_limit') ?? 90;
          _since = s == null ? null : DateTime.fromMillisecondsSinceEpoch(s);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _blink.dispose();
    _tick?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Contagem: o valor que o app manda (a cada leitura do GPS), descontando
    // o tempo desde a última mensagem; sem mensagem ainda, pela hora salva.
    final secs = _left != null
        ? _left! - DateTime.now().difference(_leftAt).inSeconds
        : _since == null
            ? 60
            : 60 - DateTime.now().difference(_since!).inSeconds;
    final left = secs < 0 ? 0 : secs;
    final text = left > 0
        ? tr('Acima de {0} km/h. Reduza: em {1} s vira infração.',
            [_limit, left])
        : tr('Excesso de velocidade a ser registado. Reduza para {0} km/h.',
            [_limit]);
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Cartão da velocidade, vermelho a piscar (igual ao da tela Hoje).
          AnimatedBuilder(
            animation: _blink,
            builder: (context, _) => Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: Color.lerp(const Color(0xCC7F1D1D),
                    const Color(0xFFDC2626), _blink.value),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEF4444), width: 2),
              ),
              child: Row(children: [
                const Icon(Icons.speed_rounded, color: Colors.white, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(tr('Acima de {0} km/h', [_limit]),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_kmh == null ? '--' : '$_kmh',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          height: 1,
                          fontWeight: FontWeight.w900)),
                  const Text('km/h',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          // Faixa com a contagem regressiva.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: TG.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TG.danger, width: 1.5),
            ),
            child: Row(children: [
              Text(left > 0 ? '$left s' : '!',
                  style: const TextStyle(
                      color: TG.danger,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: TG.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Janela do pop-up (roda separada do app, por cima dos outros apps).
class StopPopupWindow extends StatefulWidget {
  const StopPopupWindow({super.key});
  @override
  State<StopPopupWindow> createState() => _StopPopupWindowState();
}

class _StopPopupWindowState extends State<StopPopupWindow> {
  String _since = '';
  bool _auto = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      if (mounted) {
        setState(() {
          _since = p.getString('popup_since') ?? '';
          _auto = p.getBool('popup_auto') ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _pick(String name) async {
    if (_busy) return;
    setState(() => _busy = true);
    // 1.7.6: grava a resposta também nas preferências. O app lê a cada 5 s,
    // mesmo que a mensagem direta (shareData) não chegue.
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('popup_answer', name);
    } catch (_) {}
    try {
      await FlutterOverlayWindow.shareData(jsonEncode({'stop': name}))
          .timeout(const Duration(seconds: 1));
    } catch (_) {}
    // Dá tempo de a resposta chegar ao app antes de fechar a janela.
    await Future.delayed(const Duration(milliseconds: 250));
    try {
      await FlutterOverlayWindow.closeOverlay()
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: TG.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: TG.accent, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.pause_circle_filled_rounded,
                    color: TG.accent, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _since.isEmpty
                            ? tr('Parada detectada')
                            : _auto
                                ? tr('Martelo desde {0}', [_since])
                                : tr('Parado desde {0}', [_since]),
                        style: const TextStyle(
                            color: TG.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800),
                      ),
                      Text(
                          _busy
                              ? tr('Registado ✓')
                              : _auto
                                  ? tr('Parado há 15 min. É pausa?')
                                  : tr('O que é esta parada?'),
                          style: const TextStyle(
                              color: TG.muted, fontSize: 13)),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _pick('later'),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.close_rounded,
                        color: TG.muted, size: 28),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            StopChoices(compact: true, onPick: (a) => _pick(a.name)),
            const SizedBox(height: 8),
            Text(
                _auto
                    ? tr('Sem resposta, continua martelo (como o tacógrafo).')
                    : tr('Sem resposta, fica "a classificar".'),
                style: const TextStyle(color: TG.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
