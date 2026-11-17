import 'package:flutter/material.dart';

import 'models.dart';

/// Cores do TacoGuard (tema escuro, para usar na cabine de dia e de noite).
class TG {
  static const bg = Color(0xFF0A111E);
  static const surface = Color(0xFF121C2D);
  static const surfaceHigh = Color(0xFF1A2740);
  static const line = Color(0xFF24324D);
  static const accent = Color(0xFF2DD4BF);
  static const text = Color(0xFFE8EEF8);
  static const muted = Color(0xFF8A9BB5);
  static const ok = Color(0xFF34D399);
  static const warn = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);

  static const drive = Color(0xFF38BDF8);
  static const pause = Color(0xFF34D399);
  static const work = Color(0xFFFBBF24);
  static const load = Color(0xFFFB923C);
  static const unknown = Color(0xFF94A3B8);

  static Color act(Act a) {
    switch (a) {
      case Act.drive:
        return drive;
      case Act.pause:
        return pause;
      case Act.work:
        return work;
      case Act.load:
        return load;
      case Act.unknown:
        return unknown;
    }
  }

  static IconData icon(Act a) {
    switch (a) {
      case Act.drive:
        return Icons.local_shipping_rounded;
      case Act.pause:
        return Icons.hotel_rounded;
      case Act.work:
        return Icons.construction_rounded;
      case Act.load:
        return Icons.forklift;
      case Act.unknown:
        return Icons.help_outline_rounded;
    }
  }

  /// Verde, amarelo ou vermelho conforme a fração usada do limite.
  static Color level(double used) {
    if (used >= 1.0) return danger;
    if (used >= 0.85) return warn;
    return ok;
  }

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(surface: surface, primary: accent);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            color: text, fontSize: 22, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: line),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: 0.18),
        height: 68,
        labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: text),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Cartão padrão do app.
class TCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const TCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      decoration: BoxDecoration(
        color: TG.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TG.line),
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return box;
    return InkWell(
        borderRadius: BorderRadius.circular(20), onTap: onTap, child: box);
  }
}

/// Texto de uma linha que encolhe para caber (botões, abas, números).
/// Evita palavras partidas ao meio quando a letra do telefone é grande.
class Fit extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Alignment alignment;
  const Fit(this.text,
      {super.key, this.style, this.alignment = Alignment.center});

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(text, maxLines: 1, softWrap: false, style: style),
      );
}

/// Limita o aumento de letra do sistema, para as telas não desmontarem.
Widget clampTextScale(BuildContext context, Widget? child) =>
    MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3, child: child ?? const SizedBox.shrink());


/// 1.8.4: ícone da atividade. Condução é um volante (desenhado aqui, o
/// Material não tem); as outras usam os ícones de [TG.icon].
class ActIcon extends StatelessWidget {
  final Act act;
  final Color? color;
  final double size;
  const ActIcon(this.act, {super.key, this.color, this.size = 24});

  @override
  Widget build(BuildContext context) {
    if (act != Act.drive) return Icon(TG.icon(act), color: color, size: size);
    final c = color ?? IconTheme.of(context).color ?? Colors.white;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _WheelPainter(c)),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final Color color;
  _WheelPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final r = s * 0.40;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.10;
    // Aro.
    canvas.drawCircle(c, r, stroke);
    // Raios: esquerda, direita e baixo.
    final hub = s * 0.11;
    stroke.strokeWidth = s * 0.09;
    canvas.drawLine(c.translate(-hub, 0), c.translate(-r, 0), stroke);
    canvas.drawLine(c.translate(hub, 0), c.translate(r, 0), stroke);
    canvas.drawLine(c.translate(0, hub), c.translate(0, r), stroke);
    // Centro.
    canvas.drawCircle(c, hub * 1.15, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.color != color;
}
