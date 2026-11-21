import 'dart:typed_data';

import 'models.dart';

/// 1.12.0: leitura do ficheiro .DDD do cartão de motorista (descarga do
/// cartão, Regulamento (UE) 2016/799, Anexo IC, Apêndice 7).
///
/// O ficheiro é uma sequência de blocos: identificador do ficheiro do
/// cartão (2 bytes), tipo (1 byte: 00 dados / 01 assinatura na 1.ª
/// geração; 02 dados / 03 assinatura na 2.ª), tamanho (2 bytes) e os dados.
/// As atividades estão no bloco 0504 (CardDriverActivity):
///   - ponteiro do registo diário mais antigo (2 bytes)
///   - ponteiro do registo diário mais recente (2 bytes)
///   - memória circular de registos diários. Cada registo:
///       tamanho do registo anterior (2), tamanho deste (2),
///       data (TimeReal, 4 bytes, segundos desde 1970 UTC),
///       contador de presença (2, BCD), distância do dia (2, km),
///       e as mudanças de atividade, 2 bytes cada:
///       bit 15 condutor/ajudante, 14 tripulação, 13 cartão retirado,
///       bits 12-11 atividade (0 pausa/descanso, 1 disponibilidade,
///       2 trabalho, 3 condução), bits 10-0 minutos desde 00:00 UTC.
class DddDay {
  final DateTime dateUtc;
  final int km;
  final List<(int minute, int activity, bool cardOut)> changes;
  DddDay(this.dateUtc, this.km, this.changes);
}

class DddResult {
  final List<DddDay> days;
  final List<Shift> shifts;
  DddResult(this.days, this.shifts);
}

class Ddd {
  /// Lê o ficheiro e devolve os dias e as jornadas montadas.
  /// Devolve null se não for um ficheiro de cartão de motorista.
  static DddResult? parse(Uint8List b) {
    final blocks = <(int fid, int type, Uint8List data)>[];
    var i = 0;
    while (i + 5 <= b.length) {
      final fid = (b[i] << 8) | b[i + 1];
      final type = b[i + 2];
      final len = (b[i + 3] << 8) | b[i + 4];
      if (type > 3 || i + 5 + len > b.length) break;
      blocks.add((fid, type, Uint8List.sublistView(b, i + 5, i + 5 + len)));
      i += 5 + len;
    }
    // Prefere a 2.ª geração (tipo 02), senão a 1.ª (tipo 00).
    Uint8List? act;
    for (final t in const [2, 0]) {
      for (final bl in blocks) {
        if (bl.$1 == 0x0504 && bl.$2 == t && bl.$3.length > 16) {
          act = bl.$3;
          break;
        }
      }
      if (act != null) break;
    }
    if (act == null) return null;
    final days = _days(act);
    if (days.isEmpty) return null;
    return DddResult(days, buildShifts(days));
  }

  static List<DddDay> _days(Uint8List a) {
    final oldest = (a[0] << 8) | a[1];
    final newest = (a[2] << 8) | a[3];
    final buf = Uint8List.sublistView(a, 4);
    final n = buf.length;
    if (n < 12 || oldest >= n || newest >= n) return [];
    int at(int p) => buf[p % n];
    int u16(int p) => (at(p) << 8) | at(p + 1);
    int u32(int p) =>
        (at(p) << 24) | (at(p + 1) << 16) | (at(p + 2) << 8) | at(p + 3);
    final out = <DddDay>[];
    var pos = newest;
    for (var guard = 0; guard < 2000; guard++) {
      final prevLen = u16(pos);
      final len = u16(pos + 2);
      if (len < 12 || len > n) break;
      final secs = u32(pos + 4);
      final km = u16(pos + 10);
      final ch = <(int, int, bool)>[];
      for (var k = 12; k + 1 < len; k += 2) {
        final v = u16(pos + k);
        final minute = v & 0x7FF;
        if (minute >= 1440) continue;
        ch.add((minute, (v >> 11) & 3, (v >> 13) & 1 == 1));
      }
      if (secs > 0) {
        out.add(DddDay(
            DateTime.fromMillisecondsSinceEpoch(secs * 1000, isUtc: true),
            km,
            ch));
      }
      if (pos == oldest || prevLen == 0) break;
      pos = ((pos - prevLen) % n + n) % n;
    }
    out.sort((x, y) => x.dateUtc.compareTo(y.dateUtc));
    return out;
  }

  static Act _act(int a) => switch (a) {
        3 => Act.drive,
        2 => Act.work,
        // Disponibilidade: não é pausa pela lei; entra como outros
        // trabalhos (martelo), com nota.
        1 => Act.work,
        _ => Act.pause,
      };

  /// Junta todos os dias numa linha do tempo e corta em jornadas: um
  /// descanso de 7 h ou mais separa duas jornadas.
  static List<Shift> buildShifts(List<DddDay> days) {
    // Linha do tempo: (início UTC, atividade bruta 0-3).
    final tl = <(DateTime, int)>[];
    for (final d in days) {
      final midnight =
          DateTime.utc(d.dateUtc.year, d.dateUtc.month, d.dateUtc.day);
      for (final c in d.changes) {
        final t = midnight.add(Duration(minutes: c.$1));
        if (tl.isNotEmpty && !t.isAfter(tl.last.$1)) {
          // Mesma hora: a última informação vale.
          if (t == tl.last.$1) tl[tl.length - 1] = (t, c.$2);
          continue;
        }
        if (tl.isNotEmpty && tl.last.$2 == c.$2) continue;
        tl.add((t, c.$2));
      }
    }
    if (tl.isEmpty) return [];
    final endAll = DateTime.utc(days.last.dateUtc.year, days.last.dateUtc.month,
            days.last.dateUtc.day)
        .add(const Duration(days: 1));
    final kmByDay = <String, int>{
      for (final d in days)
        '${d.dateUtc.year}-${d.dateUtc.month}-${d.dateUtc.day}': d.km
    };

    final shifts = <Shift>[];
    Shift? cur;
    for (var k = 0; k < tl.length; k++) {
      final s = tl[k].$1;
      var e = k + 1 < tl.length ? tl[k + 1].$1 : endAll;
      final now = DateTime.now().toUtc();
      if (e.isAfter(now)) e = now;
      if (!e.isAfter(s)) continue;
      final a = tl[k].$2;
      final rest = a == 0;
      if (rest && e.difference(s) >= const Duration(hours: 7)) {
        // Descanso diário/semanal: fecha a jornada aberta.
        if (cur != null) {
          cur.end = s.toLocal();
          shifts.add(cur);
          cur = null;
        }
        continue;
      }
      if (cur == null) {
        if (rest) continue; // pausa solta antes de começar: ignora
        cur = Shift(start: s.toLocal());
      }
      cur.segments.add(Segment(
          act: _act(a),
          start: s.toLocal(),
          end: e.toLocal(),
          note: a == 1 ? 'Disponibilidade (cartão .DDD)' : 'cartão .DDD'));
    }
    if (cur != null && cur.segments.isNotEmpty) {
      // Jornada que não fechou (fim do ficheiro): fecha no último trecho.
      while (cur.segments.isNotEmpty && cur.segments.last.act == Act.pause) {
        cur.segments.removeLast();
      }
      if (cur.segments.isNotEmpty) {
        cur.end = cur.segments.last.end;
        shifts.add(cur);
      }
    }
    // Pausa no fim da jornada (antes do descanso) não faz parte dela.
    for (final sh in shifts) {
      while (sh.segments.length > 1 && sh.segments.last.act == Act.pause) {
        sh.segments.removeLast();
      }
      if (sh.segments.isNotEmpty) sh.end = sh.segments.last.end;
      // Distância: os km do dia vão para o 1.º trecho de condução do dia.
      final seen = <String>{};
      for (final sg in sh.segments) {
        if (sg.act != Act.drive) continue;
        final u = sg.start.toUtc();
        final key = '${u.year}-${u.month}-${u.day}';
        if (seen.add(key) && !_used.contains(key)) {
          _used.add(key);
          sg.km = (kmByDay[key] ?? 0).toDouble();
        }
      }
    }
    _used.clear();
    return shifts.where((s) => s.segments.isNotEmpty).toList();
  }

  static final Set<String> _used = {};
}
