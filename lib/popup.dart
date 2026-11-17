import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'theme.dart';

/// Tamanho do pop-up, em dp.
const double kPopW = 330, kPopH = 250;

/// O que cada resposta quer dizer (linha pequena embaixo do nome).
String stopHint(Act a) {
  switch (a) {
    case Act.pause:
      return 'conta para a pausa de 45 min';
    case Act.work:
      return 'outros trabalhos';
    case Act.load:
      return 'conta como trabalho';
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
    return Material(
      color: c.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onPick(a),
        child: compact
            ? SizedBox(
                height: 96,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(TG.icon(a), color: c, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      a == Act.load ? 'Carga/\nDescarga' : actLabel(a),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: c,
                          fontSize: 13,
                          height: 1.1,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              )
            : Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Icon(TG.icon(a), color: c, size: 28),
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
      if (shown) await close();
      final dpr = WidgetsBinding
          .instance.platformDispatcher.views.first.devicePixelRatio;
      await FlutterOverlayWindow.showOverlay(
        height: (kPopH * dpr).round(),
        width: (kPopW * dpr).round(),
        alignment: OverlayAlignment.topLeft,
        enableDrag: true,
        positionGravity: PositionGravity.none,
        startPosition: OverlayPosition((screenWidthDp - kPopW) / 2, 80),
        overlayTitle: 'TacoGuard',
        overlayContent: 'Parada detectada: toque para classificar',
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

/// Janela do pop-up (roda separada do app, por cima dos outros apps).
class StopPopupWindow extends StatefulWidget {
  const StopPopupWindow({super.key});
  @override
  State<StopPopupWindow> createState() => _StopPopupWindowState();
}

class _StopPopupWindowState extends State<StopPopupWindow> {
  String _since = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      if (mounted) setState(() => _since = p.getString('popup_since') ?? '');
    } catch (_) {}
  }

  Future<void> _pick(String name) async {
    try {
      await FlutterOverlayWindow.shareData(jsonEncode({'stop': name}));
    } catch (_) {}
    // Dá tempo de a resposta chegar ao app antes de fechar a janela.
    await Future.delayed(const Duration(milliseconds: 250));
    try {
      await FlutterOverlayWindow.closeOverlay();
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
                            ? 'Parada detectada'
                            : 'Parado desde $_since',
                        style: const TextStyle(
                            color: TG.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800),
                      ),
                      const Text('O que é esta parada?',
                          style: TextStyle(color: TG.muted, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _pick('later'),
                  icon: const Icon(Icons.close_rounded, color: TG.muted),
                  tooltip: 'Depois',
                ),
              ],
            ),
            const SizedBox(height: 10),
            StopChoices(compact: true, onPick: (a) => _pick(a.name)),
            const SizedBox(height: 8),
            const Text('Sem resposta, fica "a classificar".',
                style: TextStyle(color: TG.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
