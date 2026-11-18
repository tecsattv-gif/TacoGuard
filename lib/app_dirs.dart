import 'dart:io';

import 'package:flutter/services.dart';

/// 1.10.3: pastas do app pedidas direto ao Android (MainActivity), sem o
/// plugin path_provider. A versão nova do path_provider_android passou a
/// falhar neste app ("ClassNotFoundException: Landroid/content/Context;"):
/// o app abria sem os dados e não gravava nada.
///
/// A pasta é a mesma de antes (app_flutter), então os dados antigos
/// continuam lá e voltam a abrir.
class AppDirs {
  static const _ch = MethodChannel('tacoguard/dirs');
  static String? _docs, _temp;

  static Future<void> _init() async {
    if (_docs != null && _temp != null) return;
    try {
      final m = await _ch.invokeMapMethod<String, String>('dirs');
      _docs = m?['docs'];
      _temp = m?['temp'];
    } catch (_) {}
    _docs ??= '/data/user/0/com.tecsattv.tacoguard/app_flutter';
    _temp ??= '/data/user/0/com.tecsattv.tacoguard/cache';
  }

  /// Igual ao getApplicationDocumentsDirectory() de antes.
  static Future<Directory> docs() async {
    await _init();
    final d = Directory(_docs!);
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Igual ao getTemporaryDirectory() de antes.
  static Future<Directory> temp() async {
    await _init();
    final d = Directory(_temp!);
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }
}
