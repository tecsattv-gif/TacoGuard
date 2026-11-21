import 'dart:ui' as ui;

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// 1.14.0: paleta de cores. Modo (automático, escuro, claro, noite) e cor
/// de destaque escolhidos nos Ajustes; tudo o que usa TG.* segue a escolha.
class Palette {
  final Brightness brightness;
  final Color bg, surface, surfaceHigh, line, text, muted;
  final Color ok, warn, danger, drive, pause, work, load, unknown;
  const Palette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.line,
    required this.text,
    required this.muted,
    required this.ok,
    required this.warn,
    required this.danger,
    required this.drive,
    required this.pause,
    required this.work,
    required this.load,
    required this.unknown,
  });
}

/// Escuro: o visual de sempre (cabine de dia e de noite).
const _dark = Palette(
  brightness: Brightness.dark,
  bg: Color(0xFF0A111E),
  surface: Color(0xFF121C2D),
  surfaceHigh: Color(0xFF1A2740),
  line: Color(0xFF24324D),
  text: Color(0xFFE8EEF8),
  muted: Color(0xFF8A9BB5),
  ok: Color(0xFF34D399),
  warn: Color(0xFFFBBF24),
  danger: Color(0xFFF87171),
  drive: Color(0xFF38BDF8),
  pause: Color(0xFF34D399),
  work: Color(0xFFFBBF24),
  load: Color(0xFFFB923C),
  unknown: Color(0xFF94A3B8),
);

/// Noite: preto total, menos brilho a conduzir de noite (e gasta menos
/// bateria nos ecrãs AMOLED).
const _night = Palette(
  brightness: Brightness.dark,
  bg: Color(0xFF000000),
  surface: Color(0xFF0B0D12),
  surfaceHigh: Color(0xFF151922),
  line: Color(0xFF1F2430),
  text: Color(0xFFCDD5E1),
  muted: Color(0xFF7A8597),
  ok: Color(0xFF2FBF8A),
  warn: Color(0xFFE6AC1F),
  danger: Color(0xFFEF6B6B),
  drive: Color(0xFF34A9DD),
  pause: Color(0xFF2FBF8A),
  work: Color(0xFFE6AC1F),
  load: Color(0xFFE5853A),
  unknown: Color(0xFF8590A3),
);

/// Claro: fundo branco, para dia de muito sol. Cores mais fortes para
/// lerem bem sobre o branco.
const _light = Palette(
  brightness: Brightness.light,
  bg: Color(0xFFF2F5FA),
  surface: Color(0xFFFFFFFF),
  surfaceHigh: Color(0xFFE8EDF5),
  line: Color(0xFFD3DBE7),
  text: Color(0xFF0F172A),
  muted: Color(0xFF55657D),
  ok: Color(0xFF047857),
  warn: Color(0xFFB45309),
  danger: Color(0xFFDC2626),
  drive: Color(0xFF0369A1),
  pause: Color(0xFF047857),
  work: Color(0xFFB45309),
  load: Color(0xFFC2410C),
  unknown: Color(0xFF64748B),
);

/// Cor de destaque: versão para fundo escuro e para fundo claro.
class AccentColor {
  final String name;
  final Color dark, light;
  const AccentColor(this.name, this.dark, this.light);
}

const kAccents = <String, AccentColor>{
  'teal': AccentColor('Turquesa', Color(0xFF2DD4BF), Color(0xFF0F766E)),
  'blue': AccentColor('Azul', Color(0xFF60A5FA), Color(0xFF1D4ED8)),
  'green': AccentColor('Verde', Color(0xFF4ADE80), Color(0xFF15803D)),
  'yellow': AccentColor('Amarelo', Color(0xFFFACC15), Color(0xFFA16207)),
  'orange': AccentColor('Laranja', Color(0xFFFB923C), Color(0xFFC2410C)),
  'red': AccentColor('Vermelho', Color(0xFFF87171), Color(0xFFB91C1C)),
  'pink': AccentColor('Rosa', Color(0xFFF472B6), Color(0xFFBE185D)),
  'purple': AccentColor('Roxo', Color(0xFFA78BFA), Color(0xFF6D28D9)),
};

/// Modos do tema (o nome em português é traduzido com tr()).
const kThemeModes = <String, String>{
  'auto': 'Automático (como o telefone)',
  'dark': 'Escuro',
  'light': 'Claro',
  'night': 'Noite (preto)',
};

String themeModeChoice = 'dark';
String accentChoice = 'teal';

/// Avisa o app para redesenhar tudo quando a paleta muda.
final themeNotifier = ValueNotifier<int>(0);

Palette _pal = _dark;

void _resolve() {
  switch (themeModeChoice) {
    case 'light':
      _pal = _light;
    case 'night':
      _pal = _night;
    case 'auto':
      _pal = ui.PlatformDispatcher.instance.platformBrightness ==
              Brightness.light
          ? _light
          : _dark;
    default:
      _pal = _dark;
  }
}

/// Lê a paleta salva. Chamar no início do app e do pop-up (rodam separados).
Future<void> loadTheme({bool systemBars = true}) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    final m = p.getString('themeMode') ?? 'dark';
    final a = p.getString('themeAccent') ?? 'teal';
    themeModeChoice = kThemeModes.containsKey(m) ? m : 'dark';
    accentChoice = kAccents.containsKey(a) ? a : 'teal';
  } catch (_) {}
  _resolve();
  if (systemBars) applySystemBars();
}

/// Troca modo e/ou cor de destaque, salva e redesenha o app inteiro.
Future<void> setThemeChoice({String? mode, String? accent}) async {
  if (mode != null && kThemeModes.containsKey(mode)) themeModeChoice = mode;
  if (accent != null && kAccents.containsKey(accent)) accentChoice = accent;
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString('themeMode', themeModeChoice);
    await p.setString('themeAccent', accentChoice);
  } catch (_) {}
  refreshTheme();
}

/// Recalcula a paleta (ex.: o telefone passou de claro a escuro) e
/// redesenha todas as telas abertas.
void refreshTheme() {
  _resolve();
  applySystemBars();
  themeNotifier.value++;
  // As cores TG.* são lidas direto no build: marca tudo para redesenhar,
  // incluindo as telas que estão por baixo na pilha.
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(mark);
}

/// Barra de estado e de navegação com as cores da paleta.
void applySystemBars() {
  final light = _pal.brightness == Brightness.light;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
    statusBarBrightness: light ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: _pal.surface,
    systemNavigationBarIconBrightness:
        light ? Brightness.dark : Brightness.light,
  ));
}

/// Cores do TacoGuard (seguem a paleta escolhida).
class TG {
  static Palette get palette => _pal;
  static bool get isLight => _pal.brightness == Brightness.light;
  static Color get bg => _pal.bg;
  static Color get surface => _pal.surface;
  static Color get surfaceHigh => _pal.surfaceHigh;
  static Color get line => _pal.line;
  static Color get accent {
    final a = kAccents[accentChoice] ?? kAccents['teal']!;
    return isLight ? a.light : a.dark;
  }

  static Color get text => _pal.text;
  static Color get muted => _pal.muted;
  static Color get ok => _pal.ok;
  static Color get warn => _pal.warn;
  static Color get danger => _pal.danger;

  static Color get drive => _pal.drive;
  static Color get pause => _pal.pause;
  static Color get work => _pal.work;
  static Color get load => _pal.load;
  static Color get unknown => _pal.unknown;

  /// Cor do texto por cima de [c] (preto ou branco, o que ler melhor).
  static Color on(Color c) =>
      ThemeData.estimateBrightnessForColor(c) == Brightness.dark
          ? Colors.white
          : const Color(0xFF0A111E);

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
    final b = _pal.brightness;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: b,
    ).copyWith(
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      primary: accent,
      onPrimary: on(accent),
      outline: line,
      outlineVariant: line,
      error: danger,
    );
    // 1.14.1: FlexColorScheme dá tema completo a todos os componentes do
    // Material (botões, interruptores, chips, sliders, menus, caixas de
    // seleção...) com as cores da paleta. Os temas próprios abaixo (barra,
    // cartões, diálogos, campos) continuam a valer por cima.
    const sub = FlexSubThemesData(
      defaultRadius: 16,
      interactionEffects: true,
      tintedDisabledControls: true,
      alignedDropdown: true,
      useInputDecoratorThemeInDialogs: true,
    );
    final base = b == Brightness.light
        ? FlexThemeData.light(
            colorScheme: scheme,
            scaffoldBackground: bg,
            subThemesData: sub,
            useMaterial3: true,
          )
        : FlexThemeData.dark(
            colorScheme: scheme,
            scaffoldBackground: bg,
            subThemesData: sub,
            useMaterial3: true,
          );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
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
          side: BorderSide(color: line),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: 0.18),
        height: 68,
        labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: text),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
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
