import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, AppLifecycleState;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_dirs.dart';
import 'gps_filter.dart';
import 'i18n.dart';
import 'models.dart';
import 'popup.dart';
import 'rules.dart';
import 'tacho_link.dart';

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
  // Parado este tempo = parada. 1.9.2: 0 = na hora (5 s), como o tacógrafo,
  // que passa para martelo assim que o caminhão para (é o padrão).
  int stopMinutes = 0;
  bool voice = true;
  bool popup = true;
  String driver = '';
  String plate = ''; // matrícula do veículo (sai no PDF)
  // 1.7.9: aviso de velocidade (bip acima do limite; 1 min acima = infração)
  bool speedAlert = true;
  int speedLimit = 90; // 85 a 100 km/h
  int speedMargin = 0; // 1.9.1: avisar X km/h antes do limite (0 a 5)
  int speedBeepVol = 100; // 1.9.6: volume do bip (10 a 100 %)
  bool speedBeep = true; // 1.8.3: bip ligado/desligado (o cartão pisca igual)

  // ---------- GPS ----------
  StreamSubscription<Position>? _sub;
  Timer? _timer;
  double speedKmh = 0;
  final _gps = GpsFilter(); // 1.9.8: filtro do SpeedGuard
  double _rawKmh = 0; // 1.9.1: última leitura, sem a mediana (sem atraso)
  DateTime? _belowSince; // 1.14.29: abaixo do limite desde
  DateTime? _overCand; // 1.9.5: 1ª leitura acima do limite, à espera da 2ª
  double? lat, lon;
  DateTime? lastFix;
  bool gpsOn = false;
  String? gpsError;

  DateTime? _stopSince; // parado desde (candidato a parada)
  double? _stopLat, _stopLon; // onde parou

  /// Parado desde quando (ainda contando para virar parada), ou null.
  // 1.14.4: com o tacógrafo ao vivo, é ele que diz se parou (o GPS sem
  // sinal fazia aparecer "Parado há…" a 91 km/h).
  DateTime? get stoppedSince =>
      currentAct == Act.drive && !tachoLive ? _stopSince : null;

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
    if (spoken && voice) _say(tr('De volta ao caminhão.'));
    notifyListeners();
  }

  /// GPS sem leitura boa há mais de 20 s.
  bool get gpsStale =>
      lastFix == null || DateTime.now().difference(lastFix!).inSeconds > 20;
  DateTime? _moveSince; // andando desde (candidato a arranque)
  // (hora, lat, lon, precisão em m)
  final List<(DateTime, double, double, double)> _hist = [];
  final List<double> _lastKmh = []; // últimas velocidades (mediana)
  double? _prevLat, _prevLon; // leitura anterior (para somar os km)
  DateTime? _prevAt;
  DateTime _lastRaw = DateTime.fromMillisecondsSinceEpoch(0); // qualquer leitura
  DateTime _lastRestart = DateTime.fromMillisecondsSinceEpoch(0);

  /// Chamado quando uma parada é detectada: a tela mostra o pop-up.
  void Function(Segment seg)? onAsk;

  /// Chamado quando o caminhão arranca: fecha o pop-up, se ainda aberto.
  void Function()? onAskCancel;

  /// 1.7.6: parada que virou martelo sozinha (como o tacógrafo, que fica
  /// em martelo quando o caminhão para). Enquanto for esta, escolher Pausa
  /// ou Carga/Descarga troca desde o início da parada, sem criar trecho novo.
  Segment? autoStop;

  /// Já perguntou (aos 15 min parado) se a parada automática é pausa.
  bool autoAsked = false;

  /// A parada atual é martelo automático, à espera de confirmação.
  bool get isAutoStop =>
      autoStop != null && identical(currentSegment, autoStop);

  /// Parada atual que pode ser trocada pelo pop-up / cartão.
  bool get canClassify => currentAct == Act.unknown || isAutoStop;

  /// Último aviso (aparece na tela "Hoje").
  String? lastAlert;
  DateTime? lastAlertAt;

  final _tts = FlutterTts();
  final Set<String> _fired = {};
  Duration _lastDriven = Duration.zero;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  // ---------- Arquivo ----------
  Future<File> _file() async {
    final dir = await AppDirs.docs();
    return File('${dir.path}/tacoguard.json');
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      // 1.9.2: chave nova, para todos passarem a "na hora" (padrão).
      stopMinutes = (p.getInt('stopMinutes2') ?? 0).clamp(0, 5);
      voice = p.getBool('voice') ?? true;
      voiceGender = p.getString('voiceGender') ?? 'f';
      popup = p.getBool('popup') ?? true;
      driver = p.getString('driver') ?? '';
      plate = p.getString('plate') ?? '';
      speedAlert = p.getBool('speedAlert') ?? true;
      speedLimit = (p.getInt('speedLimit') ?? 90).clamp(85, 100);
      speedBeep = p.getBool('speedBeep') ?? true;
      // 1.10.1: a margem saiu dos Ajustes; avisa sempre no limite.
      speedMargin = 0;
      speedBeepVol = (p.getInt('speedBeepVol') ?? 100).clamp(10, 100);
      carMode = p.getBool('carMode') ?? false;
      _truckLat = p.getDouble('truckLat');
      _truckLon = p.getDouble('truckLon');
      _carAway = p.getBool('carAway') ?? false;
    } catch (_) {}
    // 1.10.2: proteção dos dados. Se o arquivo não abrir, não grava por
    // cima (antes uma gravação podia apagar tudo) e tenta a cópia diária.
    try {
      final f = await _file();
      if (await f.exists()) {
        try {
          _fromJson(await f.readAsString());
        } catch (_) {
          _loadFailed = true;
        }
      }
      if (shifts.isEmpty) await _fromDailyCopy();
    } catch (_) {}
    try {
      await _tts.setSpeechRate(0.5);
    } catch (_) {}
    await setVoiceLang();
    TachoLink.I.addListener(_onTacho);
    notifyListeners();
  }

  // ---------- 1.12.0: atividade vinda do tacógrafo ----------
  int? _tachoState;
  DateTime? _tachoChangeAt;
  bool _tachoBusy = false;

  /// O tacógrafo está ligado e a mandar a atividade: ele manda, o GPS só
  /// conta os km e a velocidade.
  bool get tachoLive =>
      TachoLink.I.live && TachoLink.I.workingState != null;

  static Act _tachoAct(int st) => switch (st) {
        3 => Act.drive,
        2 => Act.work,
        1 => Act.work, // disponibilidade (não é pausa pela lei)
        _ => Act.pause,
      };

  Future<void> _onTacho() async {
    final t = TachoLink.I;
    final st = t.workingState;
    if (!t.live || st == null) {
      _tachoState = null;
      return;
    }
    if (_tachoBusy) return;
    _tachoBusy = true;
    final c0m = current;
    if (c0m != null) _mergeSame(c0m);
    // 1.14.19: sem GPS, o aviso de velocidade segue cada leitura do
    // tacógrafo (não só de 5 em 5 s).
    // 1.14.26: com o tacógrafo ligado, o aviso usa sempre a velocidade dele.
    if (_tachoKmh != null) _speedCheck(DateTime.now());
    try {
      final now = DateTime.now();
      final act = _tachoAct(st);
      final note = st == 1 ? 'Disponibilidade (tacógrafo)' : 'tacógrafo';
      if (st != _tachoState) {
        _tachoState = st;
        _tachoChangeAt = now;
        if (current == null) {
          if (st == 0) return; // descanso e sem jornada: nada a fazer
          // 1.12.5: arrancou/trabalho depois de um fecho automático com
          // menos de 9 h de descanso: reabre a mesma jornada (o tempo
          // parado conta como pausa). Senão, jornada nova.
          if (reopenable != null) {
            await reopenShift(Act.pause);
          } else {
            await startShift();
            final c = current;
            if (c != null && c.segments.isNotEmpty) c.segments.first.note = note;
          }
        }
        if (currentAct != act) {
          onAskCancel?.call();
          autoStop = null;
          setAct(act, at: now);
        }
        final seg = currentSegment;
        if (seg != null && seg.note.isEmpty) seg.note = note;
        // 1.14.14: trechos iguais seguidos (ex.: condução partida em dois)
        // voltam a ser um só.
        final cm = current;
        if (cm != null) _mergeSame(cm);
        save();
        notifyListeners();
      }
      // 1.12.5: descanso (cama) no tacógrafo há 1 h ou mais: encerra a
      // jornada na hora em que o descanso começou. Se voltar a conduzir
      // antes das 9 h de descanso, a jornada é reaberta (ver acima).
      if (st == 0) {
        final c0 = current;
        final sg = currentSegment;
        if (c0 != null && sg != null && sg.act == Act.pause) {
          final restStart = sg.start;
          if (now.difference(restStart) >= const Duration(hours: 1) &&
              c0.segments.any((x) => x.act != Act.pause)) {
            await endShift();
            if (c0.segments.length > 1 && identical(c0.segments.last, sg)) {
              c0.segments.removeLast();
            }
            c0.end = restStart;
            await save();
            notifyListeners();
            return;
          }
        }
      }
      // Acerta o início do trecho com a duração que o tacógrafo indica
      // (lida depois da mudança, para não usar o valor da atividade antiga).
      final c = current;
      final seg = currentSegment;
      final m = t.minutes(0xF927);
      final when = t.didTime[0xF927];
      if (c != null &&
          seg != null &&
          m != null &&
          when != null &&
          _tachoChangeAt != null &&
          when.isAfter(_tachoChangeAt!) &&
          seg.note.contains('tacógrafo')) {
        final start = when.subtract(Duration(minutes: m));
        final i = c.segments.indexOf(seg);
        final prev = i > 0 ? c.segments[i - 1] : null;
        final floor = prev?.start ?? c.start;
        if (start.isBefore(seg.start) &&
            start.isAfter(floor.add(const Duration(minutes: 1)))) {
          seg.start = start;
          if (prev != null) prev.end = start;
          _tachoChangeAt = null; // já acertado
          save();
          notifyListeners();
        }
      }
    } finally {
      _tachoBusy = false;
    }
  }

  /// 1.12.0: junta as jornadas lidas do cartão (.DDD). As jornadas do
  /// telefone que se sobrepõem às do cartão são trocadas pelas do cartão;
  /// a jornada aberta (e o que vem depois dela) não é mexida.
  Future<(int added, int replaced)> importShifts(List<Shift> imp) async {
    final open = current;
    final list = imp
        .where((s) => s.end != null &&
            (open == null || s.end!.isBefore(open.start)))
        .toList();
    if (list.isEmpty) return (0, 0);
    var replaced = 0;
    shifts.removeWhere((old) {
      if (old.open) return false;
      final oe = old.end!;
      final hit = list.any((n) => old.start.isBefore(n.end!) && oe.isAfter(n.start));
      if (hit) replaced++;
      return hit;
    });
    shifts.addAll(list);
    final s2 = sorted(shifts);
    shifts
      ..clear()
      ..addAll(s2);
    await save();
    notifyListeners();
    return (list.length, replaced);
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
        'driver': driver,
        'plate': plate,
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
      // Backups a partir da 1.5.0 trazem o motorista e a matrícula.
      final d = m['driver'], pl = m['plate'];
      if (d is String && d.isNotEmpty) driver = d;
      if (pl is String && pl.isNotEmpty) plate = pl;
      await saveSettings();
      await save();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _loadFailed = false;

  Future<void> save() async {
    _lastSave = DateTime.now();
    if (_loadFailed) return; // não grava por cima de dados que não abriram
    try {
      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(exportJson(), flush: true);
      await tmp.rename(f.path);
      await _dailyCopy(f);
    } catch (_) {}
  }

  /// 1.10.2: uma cópia por dia dos dados (guarda as 14 últimas), na pasta
  /// do app. Só copia quando há jornadas.
  Future<void> _dailyCopy(File f) async {
    if (shifts.isEmpty) return;
    try {
      final dir = Directory('${f.parent.path}/copias');
      if (!await dir.exists()) await dir.create(recursive: true);
      final d = DateTime.now();
      final name = 'tacoguard-${d.year}${d.month.toString().padLeft(2, '0')}'
          '${d.day.toString().padLeft(2, '0')}.json';
      await f.copy('${dir.path}/$name');
      final all = dir
          .listSync()
          .whereType<File>()
          .where((x) => x.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      while (all.length > 14) {
        await all.removeAt(0).delete();
      }
    } catch (_) {}
  }

  /// 1.10.2: sem dados no arquivo principal, abre a cópia diária mais nova.
  Future<void> _fromDailyCopy() async {
    try {
      final f = await _file();
      final dir = Directory('${f.parent.path}/copias');
      if (!await dir.exists()) return;
      final all = dir
          .listSync()
          .whereType<File>()
          .where((x) => x.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final c in all) {
        try {
          _fromJson(await c.readAsString());
          if (shifts.isNotEmpty) {
            _loadFailed = false;
            return;
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> saveSettings() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('stopMinutes2', stopMinutes);
      await p.setBool('voice', voice);
      await p.setString('voiceGender', voiceGender);
      await p.setBool('popup', popup);
      await p.setString('driver', driver);
      await p.setString('plate', plate);
      await p.setBool('speedAlert', speedAlert);
      await p.setInt('speedLimit', speedLimit);
      await p.setBool('speedBeep', speedBeep);
      await p.setInt('speedMargin', speedMargin);
      await p.setInt('speedBeepVol', speedBeepVol);
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
    lastAlert = null; // 1.7.7: aviso da jornada anterior não fica na tela
    lastAlertAt = null;
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
    if (_overSince != null) _endOver(now);
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

  /// 1.4.0: a última jornada pode ser reaberta enquanto o descanso ainda
  /// não chegou a 9 h (depois disso já é um descanso diário feito, e o
  /// certo é iniciar uma jornada nova).
  Shift? get reopenable {
    if (current != null || shifts.isEmpty) return null;
    final last = shifts.last;
    final e = last.end;
    if (e == null) return null;
    if (DateTime.now().difference(e) >= Limits.dailyRestReduced) return null;
    return last;
  }

  /// Reabre a última jornada (viagem de última hora). A amplitude continua
  /// contando desde o início original; o tempo entre o encerramento e agora
  /// entra como [gap] (pausa ou martelo).
  Future<String?> reopenShift(Act gap) async {
    final sh = reopenable;
    if (sh == null) return null;
    final closedAt = sh.end!;
    final last = sh.segments.isEmpty ? null : sh.segments.last;
    if (last != null &&
        last.act == gap &&
        last.end != null &&
        closedAt.difference(last.end!).inSeconds.abs() <= 2) {
      // O último trecho já era do mesmo tipo: continua o mesmo trecho.
      last.end = null;
    } else {
      sh.segments.add(Segment(
          act: gap, start: closedAt, lat: sh.endLat, lon: sh.endLon));
    }
    sh.end = null;
    sh.endLat = null;
    sh.endLon = null;
    _stopSince = null;
    _moveSince = null;
    final err = await startGps();
    await save();
    notifyListeners();
    return err;
  }

  /// Troca a atividade atual (manual, ou resposta do pop-up).
  void setAct(Act a, {DateTime? at}) {
    final c = current;
    if (c == null) return;
    final now = at ?? DateTime.now();
    // 1.7.7: arrancou: o aviso da parada ("Pausa completa"…) sai da tela.
    if (a == Act.drive && currentAct != Act.drive) {
      lastAlert = null;
      lastAlertAt = null;
    }
    if (a == Act.drive && carMode) {
      carMode = false;
      _carAway = false;
      _saveCar();
    }
    final s = currentSegment;
    // 1.7.6: martelo automático: a escolha vale desde o início da parada.
    if (s != null && identical(s, autoStop)) {
      autoStop = null;
      autoAsked = false;
      if (a != Act.drive) {
        s.act = a;
        save();
        notifyListeners();
        return;
      }
    }
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
          x.km += y.km;
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

  /// Apaga a jornada e devolve a posição dela na lista (para desfazer).
  Future<int> deleteShift(Shift sh) async {
    if (sh.open) return -1;
    final i = shifts.indexOf(sh);
    if (i < 0) return -1;
    shifts.removeAt(i);
    await save();
    notifyListeners();
    return i;
  }

  /// 1.6.5: desfaz a exclusão (botão Desfazer nos 8 segundos).
  Future<void> restoreShift(Shift sh, int index) async {
    if (shifts.contains(sh)) return;
    shifts.insert(index.clamp(0, shifts.length), sh);
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
        gpsError = tr('Ative o GPS do celular.');
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          gpsError = tr('Permissão de localização negada. Libere nas configurações do celular.');
        }
        locationAlways = perm == LocationPermission.always;
      }
    } catch (e) {
      gpsError = tr('Erro no GPS: {0}', [e]);
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
    if (gpsError != null) {
      notifyListeners();
      return gpsError;
    }
    _listen();
    gpsOn = true;
    notifyListeners();
    return null;
  }

  /// 1.7.7: abre (ou reabre) a leitura do GPS.
  /// 1.9.8: mesmo GPS do SpeedGuard (onde a velocidade funciona bem):
  /// localização "fundida" do Android, a cada 1 s, e o filtro [GpsFilter]
  /// que descarta as leituras ruins (repetidas, de antena, saltos e quedas
  /// impossíveis — eram elas que davam 0 km/h com o caminhão a 60).
  void _listen() {
    _sub?.cancel();
    _lastRaw = DateTime.now();
    _gps.reset();
    // 1.14.11: se o GPS "fundido" do Google não manda nada, alterna a cada
    // religação com o GPS direto do Android (LocationManager).
    // 1.14.16: o GPS direto do Android dava só posições da rede (500 m a
    // 3 km de precisão, todas inúteis) — volta a usar sempre o fundido.
    const direct = false;
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 1),
      forceLocationManager: direct,
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationTitle: tr('TacoGuard ativo'),
        notificationText: tr('Controlando a jornada pelo GPS'),
        enableWakeLock: true,
        // 1.11.10: ícone de tacógrafo na barra de estado (perto das horas).
        notificationIcon:
            const AndroidResource(name: 'ic_stat_tacho', defType: 'drawable'),
      ),
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      // 1.7.7: erro ou fim da leitura: o vigia do _tick religa sozinho.
      onError: (e) {
        gpsStreamError = '$e';
        _lastRaw = DateTime.fromMillisecondsSinceEpoch(0);
        notifyListeners();
      },
      onDone: () {
        gpsStreamError = 'fim da leitura';
        _lastRaw = DateTime.fromMillisecondsSinceEpoch(0);
      },
      cancelOnError: false,
    );
  }

  /// 1.7.7: vigia do GPS. Sem nenhuma leitura há 15 s, fecha e reabre o
  /// GPS (no máximo a cada 20 s). Antes, se a leitura caía, nunca voltava
  /// e a velocidade ficava congelada.
  void _watchdog(DateTime now) {
    if (!gpsOn) return;
    // 1.14.11: espera 30 s (o 1.º sinal pode demorar) antes de religar.
    if (now.difference(_lastRaw).inSeconds < 30) return;
    if (now.difference(_lastRestart).inSeconds < 35) return;
    // 1.14.13: com só "durante o uso", religar com o app escondido faz o
    // Android cortar o GPS de vez: espera o app voltar ao ecrã.
    if (!locationAlways &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _lastRestart = now;
    gpsRestarts++;
    _hist.clear();
    _lastKmh.clear();
    _listen();
  }

  Future<void> stopGps() async {
    await _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _timer = null;
    gpsOn = false;
    speedKmh = 0;
    _hist.clear();
    _lastKmh.clear();
    _prevLat = null;
    _prevLon = null;
    _prevAt = null;
  }

  /// Velocidade (km/h) e se está parado de verdade.
  ///
  /// 1.7.8: a velocidade do GPS (efeito Doppler) é a mais certa e vale
  /// sempre que vier. Só quando ela vem 0 ou inválida (o Xiaomi às vezes
  /// manda 0 com o caminhão a andar) é calculada pela distância, e só com
  /// leituras precisas (até 30 m), para um pulo de posição não virar
  /// 100 km/h. No fim, mediana das 3 últimas para tirar picos.
  /// Velocidade (km/h) e se está parado.
  /// 1.9.8: igual ao SpeedGuard: a velocidade é a do próprio GPS, sem
  /// cálculo por cima (as leituras ruins já foram tiradas pelo [GpsFilter],
  /// que também põe 0 quando o caminhão está parado). Os cálculos da 1.7.7
  /// a 1.9.7 (distância, mediana, picos) davam velocidade errada.
  (bool, double) _speedOf(Position p, DateTime now) {
    final kmh = p.speed * 3.6;
    final v = kmh < 4 ? 0.0 : (kmh > 140 ? 140.0 : kmh);
    _rawKmh = v;
    return (v == 0, v);
  }

  // 1.14.9: diagnóstico do GPS (aparece no aviso "Sem sinal").
  DateTime? rawAt;
  double? rawAcc;
  int rawCount = 0, rawRejected = 0, gpsRestarts = 0;
  /// 1.14.13: localização "o tempo todo" (senão, com o app atrás de outro,
  /// o Android pode deixar de dar o GPS ao religar).
  bool locationAlways = true;

  /// Pede "Permitir o tempo todo" (abre os ajustes do app se preciso).
  Future<void> askLocationAlways() async {
    try {
      var perm = await Geolocator.requestPermission();
      if (perm != LocationPermission.always) {
        await Geolocator.openAppSettings();
        perm = await Geolocator.checkPermission();
      }
      locationAlways = perm == LocationPermission.always;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> checkLocationAlways() async {
    try {
      locationAlways =
          await Geolocator.checkPermission() == LocationPermission.always;
      notifyListeners();
    } catch (_) {}
  }
  String? gpsStreamError;

  void _onPosition(Position raw) {
    var p = raw;
    final now = DateTime.now();
    _lastRaw = now;
    rawAt = now;
    rawAcc = raw.accuracy;
    rawCount++;
    // 1.9.8: filtro do SpeedGuard (leitura ruim volta null: ignora).
    var f = _gps.accept(p);
    // 1.14.8: leituras a chegar mas o filtro a rejeitar tudo há 15 s:
    // recomeça o filtro e aceita esta (não fica "Sem sinal" à toa).
    if (f == null &&
        p.accuracy <= 50 &&
        (lastFix == null || now.difference(lastFix!).inSeconds > 15)) {
      _gps.reset();
      f = _gps.accept(p);
    }
    if (f == null) {
      rawRejected++;
      return;
    }
    p = f;
    // Leitura muito imprecisa (dentro da cabine, antena): ignora.
    if (p.accuracy > 100) {
      rawRejected++;
      return;
    }
    lastFix = now;
    lat = p.latitude;
    lon = p.longitude;
    gpsError = null;
    final (still, kmh) = _speedOf(p, now);
    speedKmh = kmh;
    // 1.2.0: quilômetros. Soma a distância entre as leituras enquanto a
    // atividade é condução e o caminhão anda (parado, o GPS "pula" e
    // somaria metros falsos). De carro não soma (a atividade não é condução).
    final seg = currentSegment;
    if (!still &&
        p.accuracy <= 60 &&
        seg != null &&
        seg.act == Act.drive &&
        _prevLat != null &&
        _prevLon != null &&
        _prevAt != null) {
      final d = Geolocator.distanceBetween(
          _prevLat!, _prevLon!, p.latitude, p.longitude);
      final dt = now.difference(_prevAt!).inMilliseconds / 1000;
      // Até 3 min sem leitura (túnel) entra em linha reta; salto
      // impossível (mais de 45 m/s = 162 km/h) fica de fora.
      if (dt > 0 && dt <= 180 && d / dt < 45) seg.km += d / 1000;
    }
    if (!still || _prevLat == null) {
      _prevLat = p.latitude;
      _prevLon = p.longitude;
    }
    _prevAt = now;
    // 1.12.0: com o tacógrafo ligado, é ele que diz a atividade.
    if (!tachoLive) {
      _motion(still, speedKmh, now);
    } else {
      _stopSince = null;
      _moveSince = null;
    }
    _speedCheck(now);
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
          now.difference(_stopSince!) >=
              (stopMinutes == 0
                  ? const Duration(seconds: 5)
                  : Duration(minutes: stopMinutes))) {
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
          // 1.7.1: parada curta (menos de 15 min) sem resposta vira martelo.
          // Menos de 15 min não conta como pausa pela lei; as de 15 min ou
          // mais continuam "a classificar" (contam como pausa até corrigir).
          if (seg != null &&
              seg.act == Act.unknown &&
              at.difference(seg.start) < Limits.breakFirst) {
            seg.act = Act.work;
          }
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
  /// que parou e abre a parada, com as coordenadas.
  /// 1.7.6: como no tacógrafo, a parada começa em MARTELO, sem pergunta.
  /// Só aos 15 min parado (quando já pode contar como pausa) o app pergunta
  /// se é pausa. Sem resposta, continua martelo, igual ao tacógrafo.
  void _beginStop(DateTime since) {
    final c = current;
    final s = currentSegment;
    if (c == null || s == null) return;
    s.end = since;
    final seg = Segment(
        act: Act.work,
        start: since,
        lat: _stopLat ?? lat,
        lon: _stopLon ?? lon);
    c.segments.add(seg);
    autoStop = seg;
    autoAsked = false;
    _stopSince = null;
    save();
    notifyListeners();
  }

  /// 1.7.6: martelo automático há 15 min: pergunta se é pausa.
  void _checkAutoAsk(DateTime now) {
    final seg = autoStop;
    if (seg == null || autoAsked || !identical(currentSegment, seg)) return;
    if (now.difference(seg.start) < Limits.breakFirst) return;
    autoAsked = true;
    if (voice) {
      _say(tr('Parado há 15 minutos, em martelo. Se for pausa, mude para pausa.'));
    }
    if (popup) onAsk?.call(seg);
  }

  /// 1.7.6: resposta do pop-up guardada também nas preferências, para não
  /// se perder se a mensagem direta do pop-up não chegar ao app.
  Future<void> _checkPopupAnswer() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      final v = p.getString('popup_answer');
      if (v == null) return;
      await p.remove('popup_answer');
      applyPopupAnswer(v);
    } catch (_) {}
  }

  /// Aplica a resposta do pop-up ('pause', 'work', 'load' ou 'later').
  void applyPopupAnswer(String v) {
    if (v == 'later') return;
    if (!canClassify) return;
    setAct(actFromName(v));
  }

  void _tick() {
    final now = DateTime.now();
    final c = current;
    if (c == null) return;
    _watchdog(now);
    // 1.14.10: sem GPS e com o tacógrafo ao vivo, os km continuam a contar
    // pela velocidade do tacógrafo (velocidade × tempo, a cada segundo).
    final tkm = _tachoKmh;
    final sg = currentSegment;
    if (gpsStale && tkm != null && sg != null && sg.act == Act.drive) {
      final last = _tachoKmAt;
      if (last != null) {
        final dt = now.difference(last).inMilliseconds / 1000;
        if (dt > 0 && dt <= 10) sg.km += tkm * dt / 3600;
      }
      _tachoKmAt = now;
      // Quando o GPS voltar, não somar outra vez a linha reta do buraco.
      _prevAt = null;
    } else {
      _tachoKmAt = null;
    }
    // 1.14.21: fora do excesso, garante que o aviso não fica no ecrã
    // (fecha mesmo que o app ache que já está fechado).
    if (_overSince == null) SpeedPopup.close();
    // 1.14.20: enquanto acima do limite, o aviso por cima dos apps recebe
    // notícias a cada volta do relógio (senão, sem leituras novas do GPS,
    // fechava-se sozinho a meio da contagem).
    if (_overSince != null) {
      SpeedPopup.speed(_tachoKmh ?? speedKmh, overSecondsLeft,
          since: _overEvent == null ? _overSince : null);
    }
    // 1.14.6: sem GPS, o aviso de velocidade usa a do tacógrafo.
    if (_tachoKmh != null) {
      // 1.14.26: o tacógrafo manda, com ou sem GPS.
      _speedCheck(now);
    } else if (gpsStale) {
      if (_overSince != null) {
        _endOver(lastFix ?? now);
      }
    }
    // Sem leitura há 20 s (garagem, túnel): se vinha devagar, está parado.
    // 1.0.1: vale também quando o GPS ainda não deu nenhuma leitura boa.
    // 1.14.5: com o tacógrafo ao vivo, não (era isto que punha "Parado
    // há…" e, aos 5 min, martelo a conduzir sem sinal de GPS).
    if (gpsStale && speedKmh < 15) {
      speedKmh = 0;
      if (tachoLive || _waitTacho(now)) {
        _stopSince = null;
      } else {
        _motion(true, 0, now);
      }
    }
    if (!locationAlways && now.second < 5) checkLocationAlways();
    _checkAutoAsk(now);
    _checkPopupAnswer();
    _alerts(c, now);
    if (now.difference(_lastSave).inSeconds >= 60) save();
    notifyListeners();
  }

  // ---------- Velocidade (1.7.9) ----------
  static const _beep = MethodChannel('tacoguard/beep');
  DateTime? _overSince; // acima do limite desde
  double _overMax = 0;
  Speeding? _overEvent; // infração em curso (já passou de 1 min)
  DateTime _lastBeep = DateTime.fromMillisecondsSinceEpoch(0);

  /// Acima do limite escolhido agora (o cartão da velocidade pisca).
  bool get overSpeed => _overSince != null;
  DateTime? get overSince => _overSince;

  /// 1.9.3: avisa a tela quando passa do limite (true) ou volta (false),
  /// para abrir/fechar o aviso por cima dos outros apps.
  void Function(bool on)? onOverSpeed;

  /// Segundos que faltam para virar infração (null se não está acima).
  int? get overSecondsLeft {
    if (_overSince == null || _overEvent != null) return null;
    final s = 60 - DateTime.now().difference(_overSince!).inSeconds;
    return s < 0 ? 0 : s;
  }

  Future<void> beep() async {
    try {
      await _beep.invokeMethod('beep', {'vol': speedBeepVol / 100.0});
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  DateTime? _tachoKmAt;
  final DateTime _startedAt = DateTime.now();

  /// 1.14.14: com o tacógrafo escolhido, nos primeiros 2 min depois de o
  /// app abrir espera por ele antes de achar que o camião parou (ao
  /// atualizar o app a conduzir, sem GPS, partia a condução em dois).
  bool _waitTacho(DateTime now) =>
      TachoLink.I.enabled &&
      TachoLink.I.deviceAddress.isNotEmpty &&
      now.difference(_startedAt).inSeconds < 120;

  /// Junta trechos seguidos do mesmo tipo na jornada aberta.
  void _mergeSame(Shift sh) {
    var i = 0;
    while (i < sh.segments.length - 1) {
      final x = sh.segments[i], y = sh.segments[i + 1];
      if (x.act == y.act &&
          x.end != null &&
          y.start.difference(x.end!).inSeconds.abs() <= 60) {
        x.end = y.end;
        x.km += y.km;
        if (x.note.isEmpty) x.note = y.note;
        sh.segments.removeAt(i + 1);
      } else {
        i++;
      }
    }
  }

  /// 1.14.6: velocidade do tacógrafo (só com ele ao vivo).
  double? get _tachoKmh => tachoLive ? TachoLink.I.speedKmh : null;
  double? get _tachoKmhRecent {
    final v = _tachoKmh;
    final t = TachoLink.I.didTime[0xF902];
    if (v == null || t == null) return null;
    return DateTime.now().difference(t).inSeconds <= 6 ? v : null;
  }

  void _speedCheck(DateTime now) {
    final c = current;
    // 1.14.26: a velocidade do tacógrafo (a que conta para a infração) tem
    // prioridade sobre a do GPS, que às vezes vinha mais baixa e o aviso
    // não disparava a 94 km/h.
    // 1.14.29: só leituras do tacógrafo com até 6 s (antes valiam 30 s).
    final tk = _tachoKmhRecent;
    final on = speedAlert &&
        c != null &&
        !carMode &&
        currentAct == Act.drive &&
        (!gpsStale || tk != null);
    // 1.9.1: o aviso usa a leitura mais recente (a mediana da tela atrasa
    // 1 a 2 s) e começa JÁ ao chegar ao limite do seletor (menos a margem
    // escolhida, porque o tacógrafo mede pela roda e costuma marcar um pouco
    // mais que o GPS).
    // 1.14.29: a maior entre o GPS e o tacógrafo (o tacógrafo só chega a
    // cada ~4 s; o GPS a cada segundo).
    final g = gpsStale ? null : (_rawKmh > speedKmh ? _rawKmh : speedKmh);
    final kmh = g == null ? (tk ?? 0) : (tk != null && tk > g ? tk : g);
    final trigger = speedLimit - speedMargin;
    // 1.14.29: dispara só ACIMA do seletor (91 → a partir de 92).
    if (!on || kmh.round() <= trigger) {
      _overCand = null;
      if (_overSince != null) {
        // 1.14.29: só termina depois de 3 s seguidos abaixo (a 90-92 o
        // aviso ligava e desligava e a contagem recomeçava).
        _belowSince ??= now;
        if (!on || now.difference(_belowSince!).inSeconds >= 3) {
          _belowSince = null;
          _endOver(now);
        }
      }
      return;
    }
    _belowSince = null;
    // 1.9.5: confirma com 2 leituras seguidas acima do limite (1 a 2 s).
    // Uma leitura sozinha pode ser erro do GPS (na serra disparava a 60
    // km/h). A contagem começa na hora da 1ª leitura, sem perder tempo.
    if (_overSince == null && tk != null) {
      // Do tacógrafo (pela roda): uma leitura chega.
      _overCand = now;
    }
    if (_overSince == null) {
      final cand = _overCand;
      if (tk == null && (cand == null || now.difference(cand).inSeconds > 4)) {
        _overCand = now;
        return;
      }
      _overCand = null;
      _overSince = cand;
      _overMax = kmh;
      onOverSpeed?.call(true);
      // 1.8.1: um bip só, ao passar do limite.
      _lastBeep = now;
      if (speedBeep) beep();
    }
    if (kmh > _overMax) _overMax = kmh;
    SpeedPopup.speed(kmh, overSecondsLeft,
        since: _overEvent == null ? _overSince : null);
    // 1.8.1: depois de 40 s acima, bip seguido (a cada 1 s) até voltar
    // ao limite escolhido. Entre o 1º bip e os 40 s, só o cartão pisca.
    if (now.difference(_overSince!).inSeconds >= 40 &&
        now.difference(_lastBeep).inMilliseconds >= 950) {
      _lastBeep = now;
      if (speedBeep) beep();
    }
    final ev = _overEvent;
    if (ev == null) {
      // Mais de 1 min seguido acima: o tacógrafo regista a infração.
      if (now.difference(_overSince!).inSeconds >= 60) {
        final e = Speeding(
            start: _overSince!,
            maxKmh: _overMax,
            limit: speedLimit,
            lat: lat,
            lon: lon);
        c!.speeding.add(e);
        _overEvent = e;
        lastAlert = tr('Excesso de velocidade registado: mais de 1 minuto acima de {0} km/h.', [speedLimit]);
        lastAlertAt = now;
        if (voice) _say(tr('Atenção. Excesso de velocidade registado.'));
        save();
      }
    } else {
      ev.maxKmh = _overMax;
      ev.end = now;
    }
  }

  void _endOver(DateTime at) {
    final ev = _overEvent;
    if (ev != null) {
      ev.end = at;
      ev.maxKmh = _overMax;
      save();
    }
    final was = _overSince != null;
    _overSince = null;
    _overEvent = null;
    _overMax = 0;
    if (was) onOverSpeed?.call(false);
    notifyListeners();
  }

  // ---------- Avisos ----------
  /// 1.10.5: voz feminina ('f') ou masculina ('m').
  String voiceGender = 'f';

  // Códigos das vozes masculinas do motor de voz do Google (o nome da voz
  // não diz o sexo; estes são os conhecidos).
  static const _maleCodes = [
    'jmn', 'pmj', 'ptd', 'ptz', // português
    'gbb', 'gbd', 'rjs', 'iob', 'iom', 'tpd', 'tpf', // inglês
    'eed', 'eef', 'esd', 'esf', // espanhol
    'frb', 'frd', 'cab', // francês
  ];

  static bool _isMale(String name) {
    final n = name.toLowerCase();
    if (n.contains('female')) return false;
    if (n.contains('male')) return true;
    return _maleCodes.any((c) => n.contains('-x-$c'));
  }

  /// 1.9.0: voz no idioma escolhido (chamado ao trocar o idioma).
  /// 1.10.5: e com o sexo escolhido. Procura entre as vozes do telefone
  /// uma do idioma e do sexo certos (de preferência sem internet); se não
  /// houver, usa a voz normal com o tom mais grave (masculina) ou mais agudo
  /// (feminina).
  Future<void> setVoiceLang() async {
    try {
      await _tts.setLanguage(ttsLang);
    } catch (_) {}
    var found = false;
    try {
      final all = await _tts.getVoices;
      final lang = ttsLang.toLowerCase();
      final base = lang.split('-').first;
      final mine = <Map>[];
      for (final v in (all as List? ?? const [])) {
        if (v is! Map) continue;
        final loc = '${v['locale'] ?? ''}'.toLowerCase().replaceAll('_', '-');
        if (loc == lang) mine.add(v);
      }
      if (mine.isEmpty) {
        for (final v in (all as List? ?? const [])) {
          if (v is! Map) continue;
          final loc = '${v['locale'] ?? ''}'.toLowerCase().replaceAll('_', '-');
          if (loc.startsWith(base)) mine.add(v);
        }
      }
      final want = voiceGender == 'm';
      final pick = mine.where((v) => _isMale('${v['name']}') == want).toList()
        ..sort((a, b) {
          // primeiro as que funcionam sem internet
          int score(Map v) {
            final n = '${v['name']}'.toLowerCase();
            return n.contains('local') ? 0 : (n.contains('network') ? 2 : 1);
          }

          return score(a).compareTo(score(b));
        });
      if (pick.isNotEmpty) {
        await _tts.setVoice({
          'name': '${pick.first['name']}',
          'locale': '${pick.first['locale']}',
        });
        await _tts.setPitch(1.0);
        found = true;
      }
    } catch (_) {}
    if (!found) {
      try {
        await _tts.setPitch(voiceGender == 'm' ? 0.75 : 1.1);
      } catch (_) {}
    }
  }

  /// Toca um exemplo da voz (Ajustes).
  Future<void> testVoice() async {
    await setVoiceLang();
    _say(tr('Faltam 15 minutos para a pausa de {0} minutos.', [45]));
  }

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
        _alert('cd0', tr('Atenção. Quatro horas e meia de condução. Faça a pausa de {0} minutos agora.', [need]));
      } else if (left.inMinutes < 15) {
        _alert('cd15', tr('Faltam 15 minutos para a pausa de {0} minutos.', [need]));
      } else if (left.inMinutes < 30) {
        _alert('cd30', tr('Faltam 30 minutos para a pausa de {0} minutos.', [need]));
      }
      final dl = st.dayLimit - st.dayDrive;
      final lim = st.dayLimit.inHours;
      if (dl.inSeconds <= 0) {
        _alert('dd0', tr('Atenção. Limite de {0} horas de condução do dia atingido.', [lim]));
      } else if (dl.inMinutes < 30) {
        _alert('dd30', tr('Faltam 30 minutos para o limite de {0} horas de condução do dia.', [lim]));
      }
      if (st.dayDrive >= Limits.dailyDrive && st.dayLimit > Limits.dailyDrive) {
        _alert('dd9', tr('Nove horas de condução. A partir de agora conta como dia de dez horas.'));
      }
      if (st.weekLeft.inSeconds <= 0) {
        _alert('wk0', tr('Atenção. Limite de condução da semana atingido.'));
      } else if (st.weekLeft.inMinutes < 60) {
        _alert('wk60', tr('Falta menos de uma hora de condução nesta semana.'));
      }
    }
    // Pausa em curso: avisa quando completa.
    final seg = currentSegment;
    if (seg != null && seg.act == Act.pause) {
      final d = seg.dur(now);
      final id = seg.start.millisecondsSinceEpoch;
      if (d >= Limits.breakFull) {
        _alert('p45-$id', tr('Pausa de 45 minutos completa.'));
      } else if (b.firstPartDone && d >= Limits.breakSecond) {
        // firstPartDone já inclui esta pausa se ela passou de 15 min:
        // só vale como 2ª parte se houve uma 1ª parte antes.
        if (_hadFirstPartBefore(c, seg)) {
          _alert('p30-$id', tr('Pausa de 30 minutos completa. Pausa de 45 minutos cumprida.'));
        }
      } else if (d >= Limits.breakFirst && !_hadFirstPartBefore(c, seg)) {
        _alert('p15-$id', tr('Pausa de 15 minutos completa. Falta uma de 30 minutos.'));
      }
    }
    // Amplitude.
    final amp = st.amplitude;
    if (amp >= Limits.amplitudeExt) {
      _alert('a15', tr('Atenção. Quinze horas de amplitude. Encerre a jornada.'));
    } else if (amp >= Limits.amplitudeExt - const Duration(minutes: 30)) {
      _alert('a1430', tr('Faltam 30 minutos para as quinze horas de amplitude.'));
    } else if (amp >= Limits.amplitude) {
      _alert(
          'a13',
          st.canExtendAmplitude
              ? tr('Treze horas de amplitude. A partir de agora o descanso desta noite será reduzido, de nove horas.')
              : tr('Atenção. Treze horas de amplitude e já não há descanso reduzido disponível. Encerre a jornada.'));
    } else if (amp >= Limits.amplitude - const Duration(minutes: 30)) {
      _alert('a1230', tr('Faltam 30 minutos para as treze horas de amplitude.'));
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
