import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
class TachoLink extends ChangeNotifier {
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
    } catch (_) {}
    _sub ??= _ev.receiveBroadcastStream().listen(_onEvent, onError: (_) {});
    if (enabled && deviceAddress.isNotEmpty) connect();
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
        // Primeiro pedido logo; depois de 15 em 15 s.
        requestAll();
        _poll?.cancel();
        _poll = Timer.periodic(const Duration(seconds: 15), (_) => requestAll());
      } else if (state == 'disconnected') {
        _poll?.cancel();
        // Volta a tentar sozinho daqui a 30 s, se a opção estiver ligada.
        if (enabled && deviceAddress.isNotEmpty) {
          Future.delayed(const Duration(seconds: 30), () {
            if (enabled && !connected && state == 'disconnected') connect();
          });
        }
      }
      notifyListeners();
    } else if (type == 'info') {
      _log('$d');
    } else if (type == 'error') {
      lastError = '$d';
      _log('erro: $d');
    } else if (type == 'data' && d is Uint8List) {
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
    sb
      ..writeln()
      ..writeAll(log, '\n');
    await f.writeAsString(sb.toString());
    return f;
  }
}
