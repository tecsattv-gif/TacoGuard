import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, WidgetsBindingObserver, AppLifecycleState;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_dirs.dart';

/// 1.11.0 (experimental): ligação ao tacógrafo inteligente pela interface
/// ITS (Regulamento (UE) 2016/799, Anexo IC, Apêndice 13).
///
/// Mensagem: TGT, SRC, LEN | SID, TRTP, CC, CM, DADOS | CS
///  - TGT/SRC: o tacógrafo é sempre EE; o telefone começa com A0 e depois
///    usa o número que o tacógrafo lhe dá (SendITSID).
///  - CS: soma de todos os bytes anteriores, módulo 256.
///  - Big endian.
/// O conteúdo dos dados (ASN.1) não está em texto no regulamento: esta
/// etapa liga, emparelha com PIN, pede os dados e GRAVA tudo o que vem, para
/// decodificar com as respostas reais do tacógrafo na etapa seguinte.
///
/// Nada disto mexe nas contas do app: sem ligação, tudo segue pelo GPS.
class TachoLink extends ChangeNotifier with WidgetsBindingObserver {
  TachoLink._();
  static final TachoLink I = TachoLink._();

  static const _ch = MethodChannel('tacoguard/bt');
  static const _ev = EventChannel('tacoguard/bt/events');

  // Mensagens (SID)
  static const sidRequestPin = 0x01;
  static const sidSendItsId = 0x02;
  static const sidSendPin = 0x03;
  static const sidPairingResult = 0x04;
  static const sidSendPuc = 0x05;
  static const sidBanLifting = 0x06;
  static const sidRejected = 0x07;
  static const sidRequestData = 0x08;
  static const sidAccepted = 0x09;
  static const sidUnavailable = 0x0A;
  static const sidNegative = 0x0B;

  // Pedidos de dados (TRTP)
  static const trtpNames = {
    0x01: 'standardTachData',
    0x02: 'personalTachData',
    0x03: 'gnssData',
    0x04: 'standardEventData',
    0x05: 'personalEventData',
    0x06: 'standardFaultData',
    0x07: 'manufacturerData',
  };

  bool enabled = false;
  String deviceName = '';
  String deviceAddress = '';
  int itsId = 0xA0;
  int channels = 0; // 1.11.3: canais Bluetooth LE do tacógrafo
  int channel = 0; // canal por onde enviar
  bool _gotReply = false;
  String state = 'disconnected';
  bool get connected => state == 'connected';
  bool needPin = false;
  bool? paired; // resultado do último PIN
  String? lastError;
  DateTime? lastData;

  /// Últimas respostas recebidas por tipo (TRTP), em bruto.
  final Map<int, Uint8List> data = {};

  /// Registo de tudo (para mandar ao desenvolvedor).
  final List<String> log = [];

  StreamSubscription? _sub;
  Timer? _poll;
  final List<int> _buf = [];

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      enabled = p.getBool('tacho_on') ?? false;
      deviceName = p.getString('tacho_name') ?? '';
      deviceAddress = p.getString('tacho_addr') ?? '';
      itsId = p.getInt('tacho_itsid') ?? 0xA0;
      for (final e in p.getStringList('tacho_weeks') ?? const <String>[]) {
        final kv = e.split(':');
        if (kv.length == 2) {
          final k = int.tryParse(kv[0]), v = int.tryParse(kv[1]);
          if (k != null && v != null) _weeks[k] = v;
        }
      }
      _bad.addAll((p.getStringList('tacho_bad_dids') ?? const [])
          .map((e) => int.tryParse(e) ?? 0));
      _bad.removeAll(core);
    } catch (_) {}
    _sub ??= _ev.receiveBroadcastStream().listen(_onEvent, onError: (_) {});
    if (enabled && deviceAddress.isNotEmpty) connect();
    // 1.12.3: vigia da ligação. Com a opção ligada e um tacógrafo
    // escolhido, volta a ligar sozinho sempre que a ligação cair, ficar
    // presa a "a ligar" ou o app voltar ao ecrã.
    _guard ??= Timer.periodic(const Duration(seconds: 15), (_) => _keepAlive());
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
  }

  Timer? _guard;
  DateTime _lastTry = DateTime(2000);

  void _keepAlive({bool now = false}) {
    if (!enabled || deviceAddress.isEmpty || connected) return;
    final since = DateTime.now().difference(_lastTry);
    if (state.startsWith('a ligar') || state.startsWith('à espera')) {
      // Preso a ligar há muito tempo: recomeça.
      if (since.inSeconds < 45) return;
      _log('a ligação demorou demais; a tentar de novo');
      disconnect();
    } else if (!now && since.inSeconds < 25) {
      return;
    }
    connect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _keepAlive(now: true);
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('tacho_on', enabled);
      await p.setString('tacho_name', deviceName);
      await p.setString('tacho_addr', deviceAddress);
      await p.setInt('tacho_itsid', itsId);
    } catch (_) {}
  }

  void _log(String s) {
    final t = DateTime.now();
    final hh = '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
    log.add('$hh $s');
    if (log.length > 400) log.removeRange(0, log.length - 400);
    notifyListeners();
  }

  static String hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

  // ---------- Ligação ----------

  Future<bool> askPermission() async {
    try {
      return await _ch.invokeMethod<bool>('perm') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Aparelhos já emparelhados no Bluetooth do telefone.
  Future<List<Map<String, String>>> bonded() async {
    await askPermission();
    try {
      final l = await _ch.invokeListMethod<Map>('bonded') ?? const [];
      return [
        for (final m in l)
          {'name': '${m['name'] ?? ''}', 'address': '${m['address'] ?? ''}'}
      ];
    } catch (e) {
      lastError = '$e';
      notifyListeners();
      return const [];
    }
  }

  Future<void> choose(String name, String address) async {
    deviceName = name;
    deviceAddress = address;
    enabled = true;
    await _save();
    await connect();
  }

  Future<void> setEnabled(bool v) async {
    enabled = v;
    await _save();
    if (v && deviceAddress.isNotEmpty) {
      await connect();
    } else if (!v) {
      await disconnect();
    }
    notifyListeners();
  }

  Future<void> connect() async {
    if (deviceAddress.isEmpty) return;
    _lastTry = DateTime.now();
    await askPermission();
    _log('ligar a $deviceName ($deviceAddress)');
    try {
      await _ch.invokeMethod('connect', {'address': deviceAddress});
    } catch (e) {
      lastError = '$e';
      _log('erro: $e');
    }
  }

  /// Alternativa: o telefone espera que o tacógrafo ligue.
  Future<void> listen() async {
    await askPermission();
    _log('à espera do tacógrafo (2 min)');
    try {
      await _ch.invokeMethod('listen');
    } catch (e) {
      _log('erro: $e');
    }
  }

  Future<void> disconnect() async {
    _poll?.cancel();
    try {
      await _ch.invokeMethod('disconnect');
    } catch (_) {}
  }

  void _onEvent(dynamic e) {
    if (e is! Map) return;
    final type = e['type'];
    final d = e['data'];
    if (type == 'state') {
      state = '$d';
      _log('estado: $state');
      if (connected) {
        lastError = null;
        _buf.clear();
        // Primeiro pedido logo; depois de 15 em 15 s. (No Bluetooth LE
        // quem começa é a procura do canal, ver _probe.)
        if (channels == 0) requestAll();
        _poll?.cancel();
        _poll = Timer.periodic(const Duration(seconds: 15), (_) => requestAll());
      } else if (state == 'disconnected') {
        _poll?.cancel();
        // 1.14.3: já não se marca um dado como recusado só porque a ligação
        // caiu (o rádio a ligar-se fazia cair e o F903 ficava de fora).
        _lastDid = null;
        _v2 = false;
        _txCredits = 0;
        _firstPoll = true;
        // Volta a tentar sozinho daqui a 30 s, se a opção estiver ligada.
        // (1.12.3: o vigia _keepAlive volta a ligar.)
      }
      notifyListeners();
    } else if (type == 'channels') {
      channels = (d as num).toInt();
      _log('$channels canais (tacógrafo versão 2, Bluetooth LE)');
      _v2Start();
    } else if (type == 'rx' && d is Map) {
      _gotReply = true;
      _v2Rx('${d['uuid']}'.toLowerCase(), d['data'] as Uint8List);
    } else if (type == 'info') {
      _log('$d');
    } else if (type == 'error') {
      lastError = '$d';
      _log('erro: $d');
    } else if (type == 'data' && d is Uint8List) {
      _gotReply = true;
      _log('<- ${hex(d)}');
      _buf.addAll(d);
      _parse();
    }
  }

  // ---------- Mensagens ----------

  /// Monta e envia uma mensagem: TGT=EE, SRC=itsId, LEN, SID, dados, CS.
  /// LEN = número de bytes depois do LEN (SID e dados), sem o CS.
  Future<void> send(int sid, List<int> body) async {
    final msg = <int>[0xEE, itsId & 0xFF, (1 + body.length) & 0xFF, sid, ...body];
    final cs = msg.fold<int>(0, (a, b) => (a + b) & 0xFF);
    msg.add(cs);
    await sendRaw(msg);
  }

  Future<void> sendRaw(List<int> bytes) async {
    _log('-> ${hex(bytes)}');
    try {
      await _ch.invokeMethod('write', {'data': Uint8List.fromList(bytes)});
    } catch (e) {
      _log('erro ao enviar: $e');
    }
  }

  /// 1.11.3: escolhe o canal por onde enviar.
  Future<void> setChannel(int i) async {
    channel = i;
    try {
      await _ch.invokeMethod('target', {'index': i});
    } catch (_) {}
    notifyListeners();
  }

  /// 1.11.3: manda o pedido por cada canal até um responder.
  Future<void> _probe() async {
    for (var i = 0; i < channels; i++) {
      if (!connected) return;
      _gotReply = false;
      await setChannel(i);
      await requestData(0x01);
      for (var k = 0; k < 6 && !_gotReply; k++) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (_gotReply) {
        _log('o tacógrafo respondeu: canal ${i + 1}');
        return;
      }
    }
    _log('nenhum canal respondeu ao pedido');
  }

  /// Pede os dados normais e os pessoais (tempos do motorista).
  Future<void> requestAll() async {
    if (!connected) return;
    await requestData(0x01);
    await Future.delayed(const Duration(milliseconds: 600));
    await requestData(0x02);
  }

  /// RequestData: TRTP, CC=FF, CM=FF (mensagem numa parte só).
  Future<void> requestData(int trtp) => send(sidRequestData, [trtp, 0xFF, 0xFF]);

  /// SendPIN: os 4 algarismos (0 a 9), um por byte.
  Future<void> sendPin(String pin) async {
    final digits = pin.trim().split('').map(int.tryParse).whereType<int>().toList();
    if (digits.length < 4) return;
    needPin = false;
    notifyListeners();
    await send(sidSendPin, [0xFF, 0xFF, 0xFF, ...digits]);
  }

  /// Lê mensagens completas do que chegou: procura o cabeçalho e confere o
  /// CS (aceita LEN com e sem o SID, porque o texto oficial é ambíguo).
  void _parse() {
    var guard = 0;
    while (_buf.length >= 5 && guard++ < 50) {
      // Mensagem do tacógrafo começa com TGT=nosso id (ou A0) e SRC=EE.
      final start = _findStart();
      if (start < 0) {
        if (_buf.length > 600) _buf.clear();
        return;
      }
      if (start > 0) _buf.removeRange(0, start);
      if (_buf.length < 5) return;
      final len = _buf[2];
      int? total;
      for (final t in [4 + len, 3 + len, 4 + len + 1, 4 + len + 3]) {
        if (t < 5 || t > _buf.length) continue;
        final cs = _buf.sublist(0, t - 1).fold<int>(0, (a, b) => (a + b) & 0xFF);
        if (cs == _buf[t - 1]) {
          total = t;
          break;
        }
      }
      if (total == null) {
        if (_buf.length >= 4 + len + 3) {
          // Não fecha o CS: descarta este byte e procura outro começo.
          _log('mensagem sem CS válido, a ignorar 1 byte');
          _buf.removeAt(0);
          continue;
        }
        return; // espera mais bytes
      }
      final m = Uint8List.fromList(_buf.sublist(0, total));
      _buf.removeRange(0, total);
      _handle(m);
    }
  }

  int _findStart() {
    for (var i = 0; i + 1 < _buf.length; i++) {
      if (_buf[i + 1] == 0xEE && (_buf[i] == itsId || _buf[i] == 0xA0)) {
        return i;
      }
    }
    return -1;
  }

  void _handle(Uint8List m) {
    final sid = m[3];
    final body = m.sublist(4, m.length - 1);
    switch (sid) {
      case sidRequestPin:
        needPin = true;
        _log('o tacógrafo pede o PIN');
        break;
      case sidSendItsId:
        if (body.isNotEmpty) {
          itsId = body.last;
          _save();
          _log('número dado pelo tacógrafo: ${hex([itsId])}');
        }
        break;
      case sidPairingResult:
        paired = body.isNotEmpty && body.last != 0;
        _log(paired! ? 'PIN aceite' : 'PIN errado');
        if (paired!) requestAll();
        break;
      case sidRejected:
        _log('bloqueado pelo tacógrafo (muitos PIN errados): ${hex(body)}');
        break;
      case sidAccepted:
        final trtp = body.isNotEmpty ? body.first : 0;
        data[trtp] = Uint8List.fromList(body);
        lastData = DateTime.now();
        _log('dados ${trtpNames[trtp] ?? hex([trtp])}: ${body.length} bytes');
        break;
      case sidUnavailable:
        final code = body.isNotEmpty ? body.last : 0;
        _log(code == 0x11
            ? 'dados pessoais não partilhados (falta autorizar no tacógrafo)'
            : 'sem dados disponíveis (${hex(body)})');
        break;
      case sidNegative:
        _log('pedido recusado: ${hex(body)}');
        break;
      default:
        _log('mensagem SID ${hex([sid])}: ${hex(body)}');
    }
    notifyListeners();
  }


  // ---------- Tacógrafo versão 2 (Bluetooth LE) — 1.11.4 ----------
  // "Smart tachograph version 2 – Transport protocol for ITS" (JRC, v1.0):
  //  - serviço de Diagnóstico fa213def…: FIFO e413960c… (dados) e
  //    Credits e168d1a6… (controlo de fluxo: sem créditos não há dados);
  //  - serviço de Download eef90782…: FIFO 29d3a479…, Credits db9c4128….
  // Cada pacote começa com 2 bytes: no 1.º o total de pacotes e 01; nos
  // seguintes 00 e o número do pacote. Por dentro vai o diagnóstico
  // ISO 14229: ReadDataByIdentifier 22 DID → resposta 62 DID dados.
  static const diagFifo = 'e413960c-75ba-4ca9-8a67-99bc052a1b13';
  static const diagCredits = 'e168d1a6-304f-42b4-ab96-4cd1d4efebd9';
  static const dlFifo = '29d3a479-1592-47df-80a4-afa742d369bb';
  static const dlCredits = 'db9c4128-bff3-41fe-a306-fb6f9a8aeb2d';

  /// Dados do motorista 1 (códigos DID da ISO 16844-7).
  static const dids = <int, String>{
    0xF903: 'Driver1WorkingState',
    0xF902: 'TachographVehicleSpeed',
    0xF923: 'Driver1ContinuousDrivingTime',
    0xF925: 'Driver1CumulativeBreakTime',
    0xF927: 'Driver1CurrentDurationOfSelectedActivity',
    0xF99A: 'Driver1CurrentDailyDrivingTime',
    0xF99B: 'Driver1CurrentWeeklyDrivingTime',
    0xF9B3: 'Driver1Remaining2WeeksDrivingTime',
    0xF9B1: 'Driver1RemainingDrivingTimeOfCurrentWeek',
    0xF9AD: 'Driver1RemainingCurrentDrivingTime',
    0xF9AF: 'Driver1RemainingDrivingTimeOnCurrentShift',
    0xF9C2: 'Driver1RemainingTimeUntilNextBreakOrRest',
    0xF9C0: 'Driver1RemainingTimeOfCurrentBreakRest',
    0xF9B9: 'Driver1DurationOfNextBreakRest',
    0xF99C: 'Driver1TimeLeftUntilNewDailyRestPeriod',
    0xF9A1: 'Driver1TimeLeftUntilNewWeeklyRestPeriod',
    0xF997: 'Driver1EndOfLastDailyRestPeriod',
    0xF998: 'Driver1EndOfLastWeeklyRestPeriod',
    0xF9AB: 'Driver1NumberOfUsedReducedDailyRestPeriods',
    0xF9A0: 'Driver1NumberOfTimes9hDailyDrivingTimesExceeded',
    0xF90B: 'TimeDate',
    0xF906: 'Driver1TimeRelatedStates',
  };

  /// Minutos de um dado de tempo (null se não houver ou não for válido).
  int? minutes(int did) {
    final v = didData[did];
    if (v == null || v.length != 2) return null;
    final n = (v[0] << 8) | v[1];
    return n >= 0xFB00 ? null : n;
  }

  /// Atividade do motorista 1: 0 descanso, 1 disponível, 2 trabalho, 3 condução.
  int? get workingState {
    if (!fresh(0xF903)) return null;
    final v = didData[0xF903];
    return v == null || v.isEmpty ? null : v.first;
  }

  /// O dado chegou há menos de 2 minutos.
  bool fresh(int did) {
    final t = didTime[did];
    return t != null && DateTime.now().difference(t).inSeconds < 120;
  }

  /// 1.11.11: condução da semana segundo o tacógrafo (só ligado).
  Duration? get weekDrive {
    if (!connected) return null;
    final m = minutes(0xF99B);
    return m == null ? null : Duration(minutes: m);
  }

  /// Condução das 2 semanas: 90 h menos o que o tacógrafo diz que falta.
  Duration? get fortnightDrive {
    if (!connected) return null;
    final left = minutes(0xF9B3);
    if (left != null && left <= 90 * 60) {
      return Duration(minutes: 90 * 60 - left);
    }
    // 1.12.6: o DTCO 4.1 não dá F9B3. Bissemanal = semana atual do
    // tacógrafo + semana anterior (guardada pelo app ou escrita à mão).
    final w = minutes(0xF99B);
    final p = prevWeekMinutes;
    if (w == null || p == null) return null;
    return Duration(minutes: w + p);
  }

  /// 1.12.8: o que falta conduzir (calculado; o DTCO 4.1 não o dá).
  int? get leftFortnightMinutes {
    final fn = fortnightDrive?.inMinutes;
    return fn == null ? null : (90 * 60 - fn).clamp(0, 90 * 60);
  }

  int? get leftWeekMinutes {
    final wk = minutes(0xF99B);
    if (!connected || wk == null) return null;
    var l = 56 * 60 - wk;
    final f = leftFortnightMinutes;
    if (f != null && f < l) l = f;
    return l.clamp(0, 56 * 60);
  }

  // ---------- 1.12.6: condução por semana (para a bissemanal) ----------
  /// Segunda-feira 00:00 UTC da semana de [t] (a semana do tacógrafo).
  static DateTime weekStart(DateTime t) {
    final u = t.toUtc();
    final d = DateTime.utc(u.year, u.month, u.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  final Map<int, int> _weeks = {}; // início da semana (ms) → minutos

  int? get prevWeekMinutes => _weeks[weekStart(DateTime.now())
      .subtract(const Duration(days: 7))
      .millisecondsSinceEpoch];

  /// Escreve à mão a condução da semana passada (ex.: tirada do ecrã do
  /// DTCO: bissemanal menos a semana atual).
  Future<void> setPrevWeek(int minutes) async {
    _weeks[weekStart(DateTime.now())
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch] = minutes;
    await _saveWeeks();
    notifyListeners();
  }

  void _noteWeek(int minutes) {
    final k = weekStart(DateTime.now()).millisecondsSinceEpoch;
    if (_weeks[k] == minutes) return;
    _weeks[k] = minutes;
    // Guarda só as últimas 8 semanas.
    final keys = _weeks.keys.toList()..sort();
    while (keys.length > 8) {
      _weeks.remove(keys.removeAt(0));
    }
    _saveWeeks();
  }

  Future<void> _saveWeeks() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(
          'tacho_weeks', [for (final e in _weeks.entries) '${e.key}:${e.value}']);
    } catch (_) {}
  }

  /// Há dados recentes do tacógrafo (menos de 3 minutos).
  bool get live => connected && fresh(0xF903);


  /// Texto legível de um dado (tempos em minutos, 2 bytes → h:mm).
  static String pretty(int did, Uint8List v) {
    final n = v.fold<int>(0, (a, b) => (a << 8) | b);
    if (did == 0xF902) return '${(n / 256).toStringAsFixed(0)} km/h';
    if (did == 0xF903) return '$n';
    if (did == 0xF9AB || did == 0xF9A0) return '$n';
    if ((did == 0xF90B || did == 0xF997 || did == 0xF998) && v.length >= 6) {
      final t = j1939Time(v);
      if (t != null) {
        final l = t.toLocal();
        String two(int x) => x.toString().padLeft(2, '0');
        return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
      }
    }
    if (v.length == 2 && n < 0xFB00) {
      return '${n ~/ 60}h${(n % 60).toString().padLeft(2, '0')}';
    }
    return hex(v);
  }

  /// Data/hora no formato J1939 (seg×0,25, min, hora, mês, dia×0,25,
  /// ano−1985), em UTC.
  static DateTime? j1939Time(Uint8List v) {
    final sec = v[0] ~/ 4, min = v[1], hour = v[2], mon = v[3];
    final day = (v[4] + 3) ~/ 4, year = 1985 + v[5];
    if (min > 59 || hour > 23 || mon < 1 || mon > 12 || day < 1 || day > 31) {
      return null;
    }
    return DateTime.utc(year, mon, day, hour, min, sec);
  }

  /// Últimas respostas por DID (em bruto).
  final Map<int, Uint8List> didData = {};
  final Map<int, DateTime> didTime = {};
  DateTime? didAt;

  bool _v2 = false;
  bool _hdr = true; // pacote com os 2 bytes de cabeçalho (troca se não houver resposta)
  final List<int> _msg = [];
  int _msgTotal = 0, _msgGot = 0;
  int _rxSinceCredit = 0;
  int _txCredits = 0; // créditos que o tacógrafo nos deu
  final Set<int> _bad = {};

  /// Dados principais: nunca ficam de fora.
  static const core = {0xF903, 0xF902, 0xF923, 0xF925, 0xF927, 0xF99A, 0xF99B, 0xF99C};
  int? _lastDid;
  DateTime _lastAt = DateTime(2000);

  /// Esquece a lista de dados recusados (tela de teste).
  Future<void> resetBadDids() async {
    _bad.clear();
    final p = await SharedPreferences.getInstance();
    await p.remove('tacho_bad_dids');
    _log('lista de dados recusados apagada');
  }
  bool _firstPoll = true;
  Completer<void>? _wait;

  Future<void> _writeChar(String uuid, List<int> data) async {
    // 1.12.6: o DTCO aceita os pedidos mesmo a mostrar 0 créditos (o
    // número desce a cada pacote nos dois sentidos); não esperar por eles,
    // só manter um intervalo entre pedidos.
    _log('-> [${uuid.substring(0, 8)}] ${hex(data)}');
    try {
      await _ch.invokeMethod(
          'writeChar', {'uuid': uuid, 'data': Uint8List.fromList(data)});
    } catch (e) {
      _log('erro ao enviar: $e');
    }
  }

  Future<void> _v2Start() async {
    _v2 = true;
    _poll?.cancel();
    await Future.delayed(const Duration(milliseconds: 300));
    // Dá créditos ao tacógrafo (quantos pacotes pode mandar).
    // Só o serviço de diagnóstico: o de Download é para empresa/controlo
    // e mexer nele fazia o tacógrafo desligar (1.11.4).
    _txCredits = 0;
    await _writeChar(diagCredits, [0x02]);
    // Os pedidos começam quando o tacógrafo devolve os créditos dele.
    Future.delayed(const Duration(seconds: 3), () {
      if (_v2 && connected && _txCredits == 0) {
        _log('o tacógrafo não deu créditos; a pedir mesmo assim');
        _v2Poll();
      }
    });
  }

  bool _polling = false;
  Future<void> _v2Poll() async {
    if (!_v2 || !connected || _polling) return;
    _polling = true;
    var answered = 0;
    try {
      // 1.12.0: o estado (F903) é repetido a cada 4 pedidos, para o app
      // ver depressa quando a atividade muda.
      final order = <int>[];
      var k = 0;
      for (final d in dids.keys) {
        if (k > 0 && k % 4 == 0) order.add(0xF903);
        order.add(d);
        k++;
      }
      for (final did in order) {
        if (!_v2 || !connected) break;
        if (_bad.contains(did)) continue;
        await Future.delayed(const Duration(milliseconds: 1200));
        _lastDid = did;
        _lastAt = DateTime.now();
        final req = [0x22, did >> 8, did & 0xFF];
        _wait = Completer<void>();
        await _writeChar(diagFifo, _hdr ? [0x01, 0x01, ...req] : req);
        try {
          await _wait!.future.timeout(const Duration(seconds: 3));
          answered++;
        } catch (_) {}
        // Se o 1.º pedido não teve resposta, tenta do outro jeito.
        if (answered == 0 && did == dids.keys.first) {
          _hdr = !_hdr;
          _log(_hdr
              ? 'sem resposta: a tentar com cabeçalho de pacote'
              : 'sem resposta: a tentar sem cabeçalho de pacote');
          _wait = Completer<void>();
          await _writeChar(diagFifo, _hdr ? [0x01, 0x01, ...req] : req);
          try {
            await _wait!.future.timeout(const Duration(seconds: 3));
            answered++;
          } catch (_) {
            _log('o tacógrafo não respondeu ao pedido de dados');
            break;
          }
        }
      }
    } finally {
      _polling = false;
    }
    if (answered > 0) {
      didAt = DateTime.now();
      lastData = didAt;
      notifyListeners();
    }
  }

  void _v2Rx(String uuid, Uint8List d) {
    if (uuid == diagCredits || uuid == dlCredits) {
      final v = d.isEmpty ? -1 : d.first;
      _log('créditos do tacógrafo (${uuid == diagCredits ? 'diagnóstico' : 'download'}): $v');
      if (v == 0xFF) {
        _log('o tacógrafo recusou a ligação (créditos FF)');
        return;
      }
      if (uuid == diagCredits) {
        // O DTCO manda o total de créditos que temos (2, 1, 0…).
        final first = _firstPoll && v > 0;
        _txCredits = v;
        if (first) {
          _firstPoll = false;
          _v2Poll();
          _poll?.cancel();
          _poll = Timer.periodic(const Duration(seconds: 20), (_) => _v2Poll());
        }
      }
      return;
    }
    _log('<- [${uuid.substring(0, 8)}] ${hex(d)}');
    if (uuid != diagFifo) return;
    // Devolve créditos de vez em quando.
    _writeChar(diagCredits, [0x01]);
    List<int> body = d;
    if (_hdr && d.length >= 2) {
      final a = d[0], b = d[1];
      if (b == 0x01 && a >= 1) {
        // 1.º pacote: a = total de pacotes
        _msg
          ..clear()
          ..addAll(d.sublist(2));
        _msgTotal = a;
        _msgGot = 1;
      } else if (a == 0x00) {
        _msg.addAll(d.sublist(2));
        _msgGot++;
      } else {
        _msg
          ..clear()
          ..addAll(d);
        _msgTotal = 1;
        _msgGot = 1;
      }
      if (_msgGot < _msgTotal) return;
      body = List<int>.from(_msg);
    }
    _uds(Uint8List.fromList(body));
  }

  void _uds(Uint8List m) {
    if (m.isEmpty) return;
    if (m[0] == 0x62 && m.length >= 3) {
      final did = (m[1] << 8) | m[2];
      final v = Uint8List.fromList(m.sublist(3));
      didData[did] = v;
      didTime[did] = DateTime.now();
      if (did == 0xF99B && v.length == 2) _noteWeek((v[0] << 8) | v[1]);
      didAt = DateTime.now();
      lastData = didAt;
      final n = v.length == 1
          ? '${v[0]}'
          : v.length == 2
              ? '${(v[0] << 8) | v[1]}'
              : '';
      _log('${dids[did] ?? hex([m[1], m[2]])} = ${hex(v)}${n.isEmpty ? '' : ' ($n)'} → ${pretty(did, v)}');
      notifyListeners();
      if (!(_wait?.isCompleted ?? true)) _wait!.complete();
    } else if (m[0] == 0x7F && m.length >= 3) {
      if (m[2] == 0x78) {
        _log('o tacógrafo pede para esperar');
        return;
      }
      const why = {
        0x11: 'serviço não suportado',
        0x13: 'tamanho errado',
        0x22: 'condições não corretas (falta autorizar/ cartão?)',
        0x31: 'dado não existe neste tacógrafo',
        0x33: 'acesso negado (segurança)',
      };
      _log('recusado: ${hex(m)} ${why[m[2]] ?? ''}');
      if (m[2] == 0x31 && _lastDid != null && !core.contains(_lastDid)) {
        // Não existe neste tacógrafo: não volta a ser pedido.
        _bad.add(_lastDid!);
        SharedPreferences.getInstance().then((p) => p.setStringList(
            'tacho_bad_dids', _bad.map((e) => '$e').toList()));
      }
      if (!(_wait?.isCompleted ?? true)) _wait!.complete();
    } else {
      _log('resposta: ${hex(m)}');
      if (!(_wait?.isCompleted ?? true)) _wait!.complete();
    }
  }

  /// Pede um DID à mão (tela de teste).
  Future<void> readDid(int did) async {
    final req = [0x22, did >> 8, did & 0xFF];
    await _writeChar(diagFifo, _hdr ? [0x01, 0x01, ...req] : req);
  }

  /// Grava o registo num arquivo de texto (para partilhar).
  Future<File> exportLog() async {
    final dir = await AppDirs.temp();
    final f = File('${dir.path}/tacoguard-tacografo.txt');
    final sb = StringBuffer()
      ..writeln('TacoGuard - registo da ligação ao tacógrafo')
      ..writeln('Aparelho: $deviceName ($deviceAddress)  ITS ID: ${hex([itsId])}')
      ..writeln('Estado: $state  Último erro: ${lastError ?? '-'}')
      ..writeln();
    for (final e in data.entries) {
      sb.writeln('Dados ${trtpNames[e.key] ?? e.key}: ${hex(e.value)}');
    }
    for (final e in didData.entries) {
      sb.writeln('${dids[e.key] ?? e.key.toRadixString(16)}: ${hex(e.value)} → ${pretty(e.key, e.value)}');
    }
    sb
      ..writeln()
      ..writeAll(log, '\n');
    await f.writeAsString(sb.toString());
    return f;
  }
}
