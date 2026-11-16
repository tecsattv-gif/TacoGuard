import 'package:flutter_test/flutter_test.dart';
import 'package:tacoguard/models.dart';
import 'package:tacoguard/rules.dart';

/// Monta uma jornada a partir de (atividade, minutos).
Shift mk(DateTime start, List<(Act, int)> parts, {bool close = true}) {
  final sh = Shift(start: start);
  var t = start;
  for (final p in parts) {
    final e = t.add(Duration(minutes: p.$2));
    sh.segments.add(Segment(act: p.$1, start: t, end: e));
    t = e;
  }
  if (close) sh.end = t;
  return sh;
}

void main() {
  // Segunda-feira, 9 de novembro de 2026, 06:00 UTC.
  final mon = DateTime.utc(2026, 11, 9, 6);

  test('condução contínua soma e zera com pausa de 45', () {
    final sh = mk(mon, [(Act.drive, 120), (Act.pause, 45), (Act.drive, 60)]);
    final b = breakState(sh, sh.end!);
    expect(b.driven, const Duration(minutes: 60));
    expect(b.firstPartDone, false);
  });

  test('pausa de 30 sozinha não zera', () {
    final sh = mk(mon, [(Act.drive, 120), (Act.pause, 30), (Act.drive, 60)]);
    final b = breakState(sh, sh.end!);
    expect(b.driven, const Duration(minutes: 180));
    expect(b.firstPartDone, true);
    expect(b.breakNeeded, const Duration(minutes: 30));
  });

  test('pausa dividida 15 + 30 zera', () {
    final sh = mk(mon, [
      (Act.drive, 120),
      (Act.pause, 15),
      (Act.drive, 120),
      (Act.pause, 30),
      (Act.drive, 10),
    ]);
    expect(breakState(sh, sh.end!).driven, const Duration(minutes: 10));
  });

  test('30 + 15 (ordem trocada) não zera', () {
    final sh = mk(mon, [
      (Act.drive, 120),
      (Act.pause, 30),
      (Act.drive, 120),
      (Act.pause, 15),
      (Act.drive, 10),
    ]);
    expect(breakState(sh, sh.end!).driven, const Duration(minutes: 250));
  });

  test('martelo e carga/descarga não contam como pausa', () {
    final sh = mk(mon, [
      (Act.drive, 200),
      (Act.work, 60),
      (Act.load, 60),
      (Act.drive, 80),
    ]);
    final b = breakState(sh, sh.end!);
    expect(b.driven, const Duration(minutes: 280));
    expect(b.exceeded, true);
    expect(maxContinuousDrive(sh, sh.end!), const Duration(minutes: 280));
  });

  test('parada a classificar conta como pausa', () {
    final sh = mk(mon, [(Act.drive, 200), (Act.unknown, 45), (Act.drive, 5)]);
    expect(breakState(sh, sh.end!).driven, const Duration(minutes: 5));
  });

  test('semana e duas semanas (UTC)', () {
    final prev = mk(mon.subtract(const Duration(days: 7)),
        [(Act.drive, 270), (Act.pause, 45), (Act.drive, 270)]);
    final a = mk(mon, [(Act.drive, 270), (Act.pause, 45), (Act.drive, 210)]);
    final all = [prev, a];
    final st = computeStatus(all, a, a.end!);
    expect(st.weekDrive, const Duration(hours: 8));
    expect(st.prevWeekDrive, const Duration(hours: 9));
    expect(st.fortnightDrive, const Duration(hours: 17));
    expect(st.weekLeft, const Duration(hours: 48));
    expect(weekStartUtc(mon), DateTime.utc(2026, 11, 9));
  });

  test('limite de 90 h manda quando a semana anterior foi cheia', () {
    final shifts = <Shift>[];
    // Semana anterior: 56 h em 6 dias.
    final pw = mon.subtract(const Duration(days: 7));
    for (var d = 0; d < 6; d++) {
      shifts.add(mk(pw.add(Duration(days: d)), [
        (Act.drive, 270),
        (Act.pause, 45),
        (Act.drive, d < 2 ? 330 : 270),
      ]));
    }
    final cur = mk(mon, [(Act.drive, 240)]);
    shifts.add(cur);
    final st = computeStatus(shifts, cur, cur.end!);
    expect(st.prevWeekDrive, const Duration(hours: 56));
    // 90 - 56 - 4 = 30 h (e não 56 - 4 = 52 h).
    expect(st.weekLeft, const Duration(hours: 30));
  });

  test('dias de 10 h: só 2 por semana', () {
    Shift ten(int day) => mk(mon.add(Duration(days: day)),
        [(Act.drive, 270), (Act.pause, 45), (Act.drive, 300)]);
    final d1 = ten(0), d2 = ten(1);
    final d3 = mk(mon.add(const Duration(days: 2)), [(Act.drive, 60)]);
    final all = [d1, d2, d3];
    final st = computeStatus(all, d3, d3.end!);
    expect(st.extUsed, 2);
    expect(st.dayLimit, Limits.dailyDrive);
    final st1 = computeStatus([d1], d1, d1.end!);
    expect(st1.dayLimit, Limits.dailyDriveExt);
    expect(st1.extToday, true);
    // 3º dia acima de 9 h na mesma semana é infração.
    final d3b = ten(2);
    final issues = shiftIssues([d1, d2, d3b], d3b, d3b.end!);
    expect(issues.any((i) => i.contains('2 dias de 10h')), true);
  });

  test('descansos: tipos e contagem de reduzidos', () {
    expect(restKind(const Duration(hours: 8)), RestKind.tooShort);
    expect(restKind(const Duration(hours: 9)), RestKind.dailyReduced);
    expect(restKind(const Duration(hours: 11)), RestKind.daily);
    expect(restKind(const Duration(hours: 24)), RestKind.weeklyReduced);
    expect(restKind(const Duration(hours: 45)), RestKind.weekly);

    // Jornadas de 15 h com 9 h de descanso: 3 reduzidos seguidos.
    final shifts = <Shift>[];
    var t = mon;
    for (var i = 0; i < 4; i++) {
      final sh = mk(t, [(Act.drive, 240), (Act.pause, 45), (Act.work, 615)]);
      shifts.add(sh);
      t = sh.end!.add(const Duration(hours: 9));
    }
    final st = computeStatus(shifts, shifts.last, shifts.last.end!);
    expect(st.reducedRestsUsed, 3);
    expect(st.canExtendAmplitude, false);
    expect(st.amplitudeLimit, Limits.amplitude);
    expect(st.amplitude, const Duration(hours: 15));
    // Prazo do descanso semanal: 144 h depois do início da 1ª jornada.
    expect(st.weeklyRestDeadline, mon.add(const Duration(hours: 144)));
  });

  test('descanso semanal zera a contagem de reduzidos', () {
    final a = mk(mon, [(Act.drive, 240)]);
    final b = mk(a.end!.add(const Duration(hours: 9)), [(Act.drive, 240)]);
    final c = mk(b.end!.add(const Duration(hours: 45)), [(Act.drive, 240)]);
    final st = computeStatus([a, b, c], c, c.end!);
    expect(st.reducedRestsUsed, 0);
    expect(st.weeklyRestDeadline, c.start.add(const Duration(hours: 144)));
  });

  test('infrações da jornada', () {
    final prev = mk(mon.subtract(const Duration(hours: 20)), [(Act.drive, 60)]);
    // Descanso de 19 h - 1 h... começa 8 h depois do fim da anterior.
    final sh = mk(prev.end!.add(const Duration(hours: 8)), [
      (Act.drive, 300),
      (Act.pause, 45),
      (Act.drive, 330),
      (Act.work, 300),
    ]);
    final issues = shiftIssues([prev, sh], sh, sh.end!);
    expect(issues.any((i) => i.contains('Condução contínua')), true);
    expect(issues.any((i) => i.contains('Condução diária')), true);
    expect(issues.any((i) => i.contains('Amplitude')), true);
    expect(issues.any((i) => i.contains('Descanso antes')), true);
  });

  test('jornada dentro da lei não tem aviso', () {
    final sh = mk(mon, [
      (Act.work, 15),
      (Act.drive, 270),
      (Act.pause, 45),
      (Act.drive, 270),
      (Act.load, 60),
    ]);
    expect(shiftIssues([sh], sh, sh.end!), isEmpty);
  });

  test('quilômetros: só a condução conta e o backup guarda', () {
    final sh = mk(mon, [(Act.drive, 60), (Act.pause, 45), (Act.drive, 30)]);
    sh.segments[0].km = 82.4;
    sh.segments[1].km = 3.0; // trecho corrigido para pausa: não conta
    sh.segments[2].km = 4.66;
    expect(sh.km, closeTo(87.06, 0.001));
    final back = Shift.fromJson(sh.toJson());
    expect(back.km, closeTo(87.06, 0.001));
    expect(fmtKm(87.06), '87 km');
    expect(fmtKm(4.66), '4,7 km');
  });

  test('formatos', () {
    expect(fmtDur(const Duration(hours: 4, minutes: 5)), '4h05');
    expect(fmtDur(const Duration(minutes: 45)), '0h45');
  });
}
