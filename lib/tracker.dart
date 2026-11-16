import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'rules.dart';

/// Coração do app: guarda as jornadas, recebe o GPS, descobre sozinho
/// quando o caminhão parou ou arrancou e solta os avisos.
class Tracker extends ChangeNotifier {
  Tracker._();
  static final Tracker I = Tracker._();

  final List<Shift> shifts = [];
  Shift? get current {
    for (final s in shifts) {
      if (s.open) return s;
    }
    return null;
  }

  // ---------- Ajustes ----------
  int stopMinutes = 2; // parado este tempo = parada (antes disso é trânsito)
  bool voice = true;
  bool popup = true;
  String driver = '';

  // ---------- GPS ----------
  StreamSubscription<Position>? _sub;
  Timer? _timer;
  double speedKmh = 0;
  double? lat, lon;
  DateTime? lastFix;
  bool gpsOn = false;
  String? gpsError;

  DateTime? _stopSince; // parado desde (candidato a parada)
  double? _stopLat, _stopLon; // onde parou

  /// Parado desde quando (ainda contando para virar parada), ou null.
  DateTime? get stoppedSince => currentAct == Act.drive ? _stopSince : null;

  /// 1.1.0 "De carro": o motorista deixou o caminhão parado e saiu de
  /// carro (ex.: almoçar na pausa). O movimento é ignorado e a parada
  /// continua contando, até ele voltar para perto do caminhão.
  bool carMode = false;
  double? _truckLat, _truckLon; // onde o caminhão ficou
  bool _carAway = false; // já se afastou do caminhão

  Future<void> _saveCar() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('carMode', carMode);
      if (_truckLat != null && _truckLon != null) {
        await p.setDouble('truckLat', _truckLat!);
        await p.setDouble('truckLon', _truckLon!);
      } else {
        await p.remove('truckLat');
        await p.remove('truckLon');
      }
      await p.setBool('carAway', _carAway);
    } catch (_) {}
  }

  /// Liga o modo "De carro" (só com o caminhão parado).
  void startCar() {
    final s = currentSegment;
    if (s == null || s.act == Act.drive) return;
    carMode = true;
    _truckLat = s.lat ?? lat;
    _truckLon = s.lon ?? lon;
    _carAway = false;
    _moveSince = null;
    _saveCar();
    notifyListeners();
  }

  /// Desliga o modo "De carro" (voltou ao caminhão).
  void endCar({bool spoken = false}) {
    if (!carMode) return;
    carMode = false;
    _carAway = false;
    _moveSince = null;
    _saveCar();
    if (spoken && voice) _say('De volta ao caminhão.');
    notifyListeners();
  }

  /// GPS sem leitura boa há mais de 20 s.
  bool get gpsStale =>
      lastFix == null || DateTime.now().difference(lastFix!).inSeconds > 20;
  DateTime? _moveSince; // andando desde (candidato a arranque)
  final List<(DateTime, double, double)> _hist = [];

  /// Chamado quando uma parada é detectada: a tela mostra o pop-up.
  void Function(Segment seg)? onAsk;

  /// Chamado quando o caminhão arranca: fecha o pop-up, se ainda aberto.
  void Function()? onAskCancel;

  /// Último aviso (aparece na tela "Hoje").
  String? lastAlert;
  DateTime? lastAlertAt;

  final _tts = FlutterTts();
  final Set<String> _fired = {};
  Duration _lastDriven = Duration.zero;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  // ---------- Arquivo ----------
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/tacoguard.json');
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      stopMinutes = p.getInt('stopMinutes') ?? 2;
      voice = p.getBool('voice') ?? true;
      popup = p.getBool('popup') ?? true;
      driver = p.getString('driver') ?? '';
      carMode = p.getBool('carMode') ?? false;
      _truckLat = p.getDouble('truckLat');
      _truckLon = p.getDouble('truckLon');
      _carAway = p.getBool('carAway') ?? false;
    } catch (_) {}
    try {
      final f = await _file();
      if (await f.exists()) {
        _fromJson(await f.readAsString());
      }
    } catch (_) {}
    try {
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(0.5);
    } catch (_) {}
    notifyListeners();
  }

  void _fromJson(String text) {
    final m = jsonDecode(text) as Map;
    final l = ((m['shifts'] as List?) ?? [])
        .map((x) => Shift.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList();
    shifts
      ..clear()
      ..addAll(sorted(l));
  }

  String exportJson() => jsonEncode({
        'app': 'TacoGuard',
        'v': 1,
        'shifts': shifts.map((s) => s.toJson()).toList(),
      });

  /// Restaura um backup (substitui tudo). Devolve false se o arquivo
  /// não for um backup do TacoGuard.
  Future<bool> importJson(String text) async {
    try {
      final m = jsonDecode(text);
      if (m is! Map || m['app'] != 'TacoGuard') return false;
      await stopGps();
      _fromJson(text);
      await save();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> save() async {
    _lastSave = DateTime.now();
    try {
      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(exportJson(), flush: true);
      await tmp.rename(f.path);
    } catch (_) {}
  }

  Future<void> saveSettings() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('stopMinutes', stopMinutes);
      await p.setBool('voice', voice);
      await p.setBool('popup', popup);
      await p.setString('driver', driver);
    } catch (_) {}
    notifyListeners();
  }

  // ---------- Jornada ----------
  Segment? get currentSegment {
    final c = current;
    if (c == null || c.segments.isEmpty) return null;
    final s = c.segments.last;
    return s.end == null ? s : null;
  }

  Act? get currentAct => currentSegment?.act;

  /// Descanso desde o fim da última jornada (com a jornada fechada).
  Duration? restSoFar(DateTime now) {
    if (current != null || shifts.isEmpty) return null;
    final e = shifts.last.end;
    if (e == null) return null;
    return now.difference(e);
  }

  Future<String?> startShift() async {
    if (current != null) return null;
    final err = await startGps();
    final now = DateTime.now();
    final sh = Shift(start: now, startLat: lat, startLon: lon);
    // Até arrancar, conta como outros trabalhos (verificação do veículo).
    sh.segments.add(Segment(act: Act.work, start: now, lat: lat, lon: lon));
    shifts.add(sh);
    _fired.clear();
    _lastDriven = Duration.zero;
    _stopSince = null;
    _moveSince = null;
    await save();
    notifyListeners();
    return err;
  }

  Future<void> endShift() async {
    final c = current;
    if (c == null) return;
    final now = DateTime.now();
    final s = currentSegment;
    if (s != null) s.end = now;
    c.end = now;
    c.endLat = lat;
    c.endLon = lon;
    onAskCancel?.call();
    if (carMode) {
      carMode = false;
      _carAway = false;
      await _saveCar();
    }
    await stopGps();
    await save();
    notifyListeners();
  }

  /// Troca a atividade atual (manual, ou resposta do pop-up).
  void setAct(Act a, {DateTime? at}) {
    final c = current;
    if (c == null) return;
    final now = at ?? DateTime.now();
    if (a == Act.drive && carMode) {
      carMode = false;
      _carAway = false;
      _saveCar();
    }
    final s = currentSegment;
    if (s != null) {
      if (s.act == a) return;
      // Parada "a classificar": só muda o tipo, mantém o início e o local.
      if (s.act == Act.unknown && a != Act.drive) {
        s.act = a;
        save();
        notifyListeners();
        return;
      }
      s.end = now;
      // Trecho de menos de 5 s não vale a pena guardar.
      if (s.dur(now).inSeconds < 5 && c.segments.length > 1) {
        c.segments.removeLast();
      }
    }
    c.segments.add(Segment(act: a, start: now, lat: lat, lon: lon));
    _stopSince = null;
    _moveSince = null;
    save();
    notifyListeners();
  }

  /// Corrige o tipo de um trecho já gravado.
  void reclassify(Segment s, Act a) {
    s.act = a;
    // 1.1.0: junta trechos vizinhos do mesmo tipo. Ex.: um trajeto de carro
    // contado como condução no meio da pausa, corrigido para Pausa, volta a
    // formar uma pausa só (senão não somava os 45 minutos).
    for (final sh in shifts) {
      if (!sh.segments.contains(s)) continue;
      var i = 0;
      while (i < sh.segments.length - 1) {
        final x = sh.segments[i], y = sh.segments[i + 1];
        if (x.act == y.act &&
            x.end != null &&
            y.start.difference(x.end!).inSeconds.abs() <= 2) {
          x.end = y.end;
          if (x.note.isEmpty) x.note = y.note;
          if (!x.hasCoords) {
            x.lat = y.lat;
            x.lon = y.lon;
          }
          sh.segments.removeAt(i + 1);
        } else {
          i++;
        }
      }
    }
    save();
    notifyListeners();
  }

  void setNote(Segment s, String note) {
    s.note = note.trim();
    save();
    notifyListeners();
  }

  Future<void> deleteShift(Shift sh) async {
    if (sh.open) return;
    shifts.remove(sh);
    await save();
    notifyListeners();
  }

  // ---------- GPS ----------
  /// Liga o GPS em segundo plano. Devolve um texto de erro, ou null.
  Future<String?> startGps() async {
    if (_sub != null) return null;
    gpsError = null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        gpsError = 'Ative o GPS do celular.';
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          gpsError = 'Permissão de localização negada. Libere nas '
              'configurações do celular.';
        }
      }
    } catch (e) {
      gpsError = 'Erro no GPS: $e';
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
    if (gpsError != null) {
      notifyListeners();
      return gpsError;
    }
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 2),
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationTitle: 'TacoGuard ativo',
        notificationText: 'Controlando a jornada pelo GPS',
        enableWakeLock: true,
      ),
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (e) {
        gpsError = 'Erro no GPS: $e';
        notifyListeners();
      },
    );
    gpsOn = true;
    notifyListeners();
    return null;
  }

  Future<void> stopGps() async {
    await _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _timer = null;
    gpsOn = false;
    speedKmh = 0;
    _hist.clear();
  }

  /// Parado de verdade? O GPS do celular "anda" sozinho quando parado.
  bool _isStill(Position p, DateTime now) {
    _hist.add((now, p.latitude, p.longitude));
    _hist.removeWhere((h) => now.difference(h.$1).inSeconds > 10);
    if (p.speed * 3.6 < 4) return true;
    final old = _hist.first;
    final secs = now.difference(old.$1).inMilliseconds / 1000;
    if (secs >= 6) {
      final moved = Geolocator.distanceBetween(
          old.$2, old.$3, p.latitude, p.longitude);
      if (moved < 8) return true;
    }
    return false;
  }

  void _onPosition(Position p) {
    // Leitura de antena/Wi-Fi (imprecisa): ignora.
    if (p.accuracy > 60) return;
    final now = DateTime.now();
    lastFix = now;
    lat = p.latitude;
    lon = p.longitude;
    gpsError = null;
    final still = _isStill(p, now);
    speedKmh = still ? 0 : p.speed * 3.6;
    _motion(still, speedKmh, now);
    notifyListeners();
  }

  /// Distância (m) da posição atual até um ponto, ou null se não há GPS.
  double? _distTo(double? la, double? lo) {
    if (la == null || lo == null || lat == null || lon == null) return null;
    return Geolocator.distanceBetween(la, lo, lat!, lon!);
  }

  /// Máquina de estados parado/andando.
  ///
  /// 1.0.1: parado, o GPS do celular "pula" e às vezes marca velocidade.
  /// Antes, cada pulo zerava a contagem da parada e o pop-up não aparecia.
  /// Agora a contagem só é cancelada se o caminhão sair de verdade do lugar
  /// (mais de 40 m), e o arranque só vale se ele se afastar 30 m da parada.
  void _motion(bool still, double kmh, DateTime now) {
    final c = current;
    if (c == null) return;
    final act = currentAct;
    // De carro: nada de condução. Volta ao normal quando o motorista
    // se afastou (150 m), voltou para perto do caminhão (60 m) e parou.
    if (carMode && act != Act.drive) {
      final d = _distTo(_truckLat, _truckLon);
      if (d != null) {
        if (d > 150 && !_carAway) {
          _carAway = true;
          _saveCar();
        } else if (_carAway && d < 60 && still) {
          endCar(spoken: true);
        }
      }
      return;
    }
    if (act == Act.drive) {
      _moveSince = null;
      if (still) {
        if (_stopSince == null) {
          _stopSince = now;
          _stopLat = lat;
          _stopLon = lon;
        }
      } else if (_stopSince != null && kmh >= 8) {
        final d = _distTo(_stopLat, _stopLon);
        if (d == null || d > 40) _stopSince = null;
      }
      if (_stopSince != null &&
          now.difference(_stopSince!) >= Duration(minutes: stopMinutes)) {
        _beginStop(_stopSince!);
      }
    } else {
      _stopSince = null;
      if (!still && kmh >= 8) {
        _moveSince ??= now;
        final seg = currentSegment;
        final d = _distTo(seg?.lat, seg?.lon);
        // 6 s andando e já longe do ponto da parada = arrancou.
        if (now.difference(_moveSince!).inSeconds >= 6 &&
            (d == null || d > 30)) {
          final at = _moveSince!;
          onAskCancel?.call();
          setAct(Act.drive, at: at);
        }
      } else if (still) {
        _moveSince = null;
      }
    }
  }

  /// O motorista respondeu antes de o pop-up aparecer (cartão "Parado há…"
  /// da tela Hoje): fecha a condução no instante em que parou.
  void stopNow(Act a) {
    final c = current;
    final s = currentSegment;
    if (c == null || s == null || s.act != Act.drive) return;
    final since = _stopSince ?? DateTime.now();
    s.end = since;
    c.segments.add(Segment(
        act: a, start: since, lat: _stopLat ?? lat, lon: _stopLon ?? lon));
    _stopSince = null;
    save();
    notifyListeners();
  }

  /// O caminhão parou há [stopMinutes]: fecha a condução no instante em
  /// que parou e abre uma parada "a classificar", com as coordenadas.
  void _beginStop(DateTime since) {
    final c = current;
    final s = currentSegment;
    if (c == null || s == null) return;
    s.end = since;
    final seg = Segment(
        act: Act.unknown,
        start: since,
        lat: _stopLat ?? lat,
        lon: _stopLon ?? lon);
    c.segments.add(seg);
    _stopSince = null;
    save();
    notifyListeners();
    if (voice) {
      _say('Parada detectada. Pausa, martelo ou carga e descarga?');
    }
    if (popup) onAsk?.call(seg);
  }

  void _tick() {
    final now = DateTime.now();
    final c = current;
    if (c == null) return;
    // Sem leitura há 20 s (garagem, túnel): se vinha devagar, está parado.
    // 1.0.1: vale também quando o GPS ainda não deu nenhuma leitura boa.
    if (gpsStale && speedKmh < 15) {
      speedKmh = 0;
      _motion(true, 0, now);
    }
    _alerts(c, now);
    if (now.difference(_lastSave).inSeconds >= 60) save();
    notifyListeners();
  }

  // ---------- Avisos ----------
  void _say(String text) {
    try {
      _tts.speak(text);
    } catch (_) {}
  }

  void _alert(String key, String text) {
    if (_fired.contains(key)) return;
    _fired.add(key);
    lastAlert = text;
    lastAlertAt = DateTime.now();
    if (voice) _say(text);
  }

  void _alerts(Shift c, DateTime now) {
    final st = computeStatus(shifts, c, now);
    final b = st.brk;
    // Pausa feita: os avisos de condução contínua valem de novo.
    if (b.driven < _lastDriven) {
      _fired.removeWhere((k) => k.startsWith('cd'));
    }
    _lastDriven = b.driven;
    final act = currentAct;
    if (act == Act.drive) {
      final left = Limits.continuousDrive - b.driven;
      final need = b.breakNeeded.inMinutes;
      if (left.inSeconds <= 0) {
        _alert('cd0', 'Atenção. Quatro horas e meia de condução. '
            'Faça a pausa de $need minutos agora.');
      } else if (left.inMinutes < 15) {
        _alert('cd15', 'Faltam 15 minutos para a pausa de $need minutos.');
      } else if (left.inMinutes < 30) {
        _alert('cd30', 'Faltam 30 minutos para a pausa de $need minutos.');
      }
      final dl = st.dayLimit - st.dayDrive;
      final lim = st.dayLimit.inHours;
      if (dl.inSeconds <= 0) {
        _alert('dd0', 'Atenção. Limite de $lim horas de condução do dia '
            'atingido.');
      } else if (dl.inMinutes < 30) {
        _alert('dd30', 'Faltam 30 minutos para o limite de $lim horas de '
            'condução do dia.');
      }
      if (st.dayDrive >= Limits.dailyDrive && st.dayLimit > Limits.dailyDrive) {
        _alert('dd9', 'Nove horas de condução. A partir de agora conta como '
            'dia de dez horas.');
      }
      if (st.weekLeft.inSeconds <= 0) {
        _alert('wk0', 'Atenção. Limite de condução da semana atingido.');
      } else if (st.weekLeft.inMinutes < 60) {
        _alert('wk60', 'Falta menos de uma hora de condução nesta semana.');
      }
    }
    // Pausa em curso: avisa quando completa.
    final seg = currentSegment;
    if (seg != null && seg.act == Act.pause) {
      final d = seg.dur(now);
      final id = seg.start.millisecondsSinceEpoch;
      if (d >= Limits.breakFull) {
        _alert('p45-$id', 'Pausa de 45 minutos completa.');
      } else if (b.firstPartDone && d >= Limits.breakSecond) {
        // firstPartDone já inclui esta pausa se ela passou de 15 min:
        // só vale como 2ª parte se houve uma 1ª parte antes.
        if (_hadFirstPartBefore(c, seg)) {
          _alert('p30-$id', 'Pausa de 30 minutos completa. '
              'Pausa de 45 minutos cumprida.');
        }
      } else if (d >= Limits.breakFirst && !_hadFirstPartBefore(c, seg)) {
        _alert('p15-$id', 'Pausa de 15 minutos completa. '
            'Falta uma de 30 minutos.');
      }
    }
    // Amplitude.
    final amp = st.amplitude;
    if (amp >= Limits.amplitudeExt) {
      _alert('a15', 'Atenção. Quinze horas de amplitude. '
          'Encerre a jornada.');
    } else if (amp >= Limits.amplitudeExt - const Duration(minutes: 30)) {
      _alert('a1430', 'Faltam 30 minutos para as quinze horas de amplitude.');
    } else if (amp >= Limits.amplitude) {
      _alert(
          'a13',
          st.canExtendAmplitude
              ? 'Treze horas de amplitude. A partir de agora o descanso '
                  'desta noite será reduzido, de nove horas.'
              : 'Atenção. Treze horas de amplitude e já não há descanso '
                  'reduzido disponível. Encerre a jornada.');
    } else if (amp >= Limits.amplitude - const Duration(minutes: 30)) {
      _alert('a1230', 'Faltam 30 minutos para as treze horas de amplitude.');
    }
  }

  /// Já havia uma pausa de 15 a 44 min desde a última pausa completa,
  /// antes de [seg]?
  bool _hadFirstPartBefore(Shift c, Segment seg) {
    var first = false;
    for (final s in c.segments) {
      if (identical(s, seg)) break;
      if (s.act != Act.pause && s.act != Act.unknown) continue;
      final d = s.dur(DateTime.now());
      if (d >= Limits.breakFull || (first && d >= Limits.breakSecond)) {
        first = false;
      } else if (!first && d >= Limits.breakFirst) {
        first = true;
      }
    }
    return first;
  }
}
