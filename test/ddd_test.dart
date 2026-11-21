import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tacoguard/ddd.dart';
import 'package:tacoguard/models.dart';

List<int> u16(int v) => [(v >> 8) & 0xFF, v & 0xFF];
List<int> u32(int v) =>
    [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];

List<int> day(int prevLen, DateTime d, int km, List<(int, int)> ch) {
  final body = <int>[];
  for (final c in ch) {
    body.addAll(u16((c.$2 << 11) | c.$1));
  }
  final len = 12 + body.length;
  return [
    ...u16(prevLen),
    ...u16(len),
    ...u32(d.millisecondsSinceEpoch ~/ 1000),
    ...u16(1),
    ...u16(km),
    ...body,
  ];
}

void main() {
  test('lê o .DDD do cartão e monta as jornadas', () {
    final d1 = day(0, DateTime.utc(2026, 11, 19), 310, [
      (0, 0),
      (360, 2), // 06:00 trabalho
      (375, 3), // 06:15 condução
      (645, 0), // 10:45 pausa
      (690, 3), // 11:30 condução
      (900, 2), // 15:00 trabalho
      (930, 0), // 15:30 descanso
    ]);
    final d2 = day(d1.length, DateTime.utc(2026, 11, 20), 150, [
      (0, 0),
      (420, 3), // 07:00 condução
      (540, 0), // 09:00 descanso
    ]);
    final buf = [...d1, ...d2, ...List.filled(20, 0)];
    final data = [...u16(0), ...u16(d1.length), ...buf];
    final file = Uint8List.fromList([
      0x00, 0x02, 0x00, ...u16(25), ...List.filled(25, 0), // ICC (outro bloco)
      0x05, 0x04, 0x00, ...u16(data.length), ...data,
    ]);
    final r = Ddd.parse(file)!;
    expect(r.days.length, 2);
    expect(r.shifts.length, 2);
    final a = r.shifts[0];
    expect(a.start.toUtc(), DateTime.utc(2026, 11, 19, 6));
    expect(a.end!.toUtc(), DateTime.utc(2026, 11, 19, 15, 30));
    expect(a.segments.map((s) => s.act).toList(),
        [Act.work, Act.drive, Act.pause, Act.drive, Act.work]);
    expect(a.total(Act.drive, DateTime.now()), const Duration(hours: 8));
    expect(a.km, 310);
    final b = r.shifts[1];
    expect(b.start.toUtc(), DateTime.utc(2026, 11, 20, 7));
    expect(b.end!.toUtc(), DateTime.utc(2026, 11, 20, 9));
    expect(b.km, 150);
  });

  test('ficheiro que não é de cartão', () {
    expect(Ddd.parse(Uint8List.fromList(List.filled(40, 7))), isNull);
  });
}
