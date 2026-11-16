/// Tipos de atividade, como no tacógrafo.
enum Act {
  drive, // condução (volante)
  pause, // pausa / descanso (cama)
  work, // outros trabalhos (martelo)
  load, // carga / descarga (conta como outros trabalhos)
  unknown, // parada ainda não classificada
}

Act actFromName(String? s) {
  for (final a in Act.values) {
    if (a.name == s) return a;
  }
  return Act.unknown;
}

String actLabel(Act a) {
  switch (a) {
    case Act.drive:
      return 'Condução';
    case Act.pause:
      return 'Pausa';
    case Act.work:
      return 'Martelo';
    case Act.load:
      return 'Carga/Descarga';
    case Act.unknown:
      return 'A classificar';
  }
}

/// Um trecho da jornada: uma atividade com início e fim.
class Segment {
  Act act;
  DateTime start;
  DateTime? end; // null = ainda em curso
  double? lat;
  double? lon;
  String note;

  Segment({
    required this.act,
    required this.start,
    this.end,
    this.lat,
    this.lon,
    this.note = '',
  });

  /// Duração até [now] (ou até o fim, se já fechado).
  Duration dur(DateTime now) {
    final e = end ?? now;
    final d = e.difference(start);
    return d.isNegative ? Duration.zero : d;
  }

  bool get hasCoords => lat != null && lon != null;

  Map<String, dynamic> toJson() => {
        'a': act.name,
        's': start.toUtc().millisecondsSinceEpoch,
        'e': end?.toUtc().millisecondsSinceEpoch,
        'la': lat,
        'lo': lon,
        'n': note,
      };

  static Segment fromJson(Map<String, dynamic> m) => Segment(
        act: actFromName(m['a'] as String?),
        start: DateTime.fromMillisecondsSinceEpoch((m['s'] as num).toInt(),
                isUtc: true)
            .toLocal(),
        end: m['e'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((m['e'] as num).toInt(),
                    isUtc: true)
                .toLocal(),
        lat: (m['la'] as num?)?.toDouble(),
        lon: (m['lo'] as num?)?.toDouble(),
        note: (m['n'] as String?) ?? '',
      );
}

/// Uma jornada: do "Iniciar jornada" ao "Encerrar jornada".
/// O tempo entre duas jornadas é o descanso (diário ou semanal).
class Shift {
  DateTime start;
  DateTime? end; // null = jornada aberta
  List<Segment> segments;
  double? startLat, startLon, endLat, endLon;

  Shift({
    required this.start,
    this.end,
    List<Segment>? segments,
    this.startLat,
    this.startLon,
    this.endLat,
    this.endLon,
  }) : segments = segments ?? [];

  bool get open => end == null;

  /// Amplitude: do início ao fim (ou até agora).
  Duration amplitude(DateTime now) {
    final d = (end ?? now).difference(start);
    return d.isNegative ? Duration.zero : d;
  }

  Duration total(Act a, DateTime now) {
    var t = Duration.zero;
    for (final s in segments) {
      if (s.act == a) t += s.dur(end ?? now);
    }
    return t;
  }

  Map<String, dynamic> toJson() => {
        's': start.toUtc().millisecondsSinceEpoch,
        'e': end?.toUtc().millisecondsSinceEpoch,
        'g': segments.map((x) => x.toJson()).toList(),
        'sla': startLat,
        'slo': startLon,
        'ela': endLat,
        'elo': endLon,
      };

  static Shift fromJson(Map<String, dynamic> m) => Shift(
        start: DateTime.fromMillisecondsSinceEpoch((m['s'] as num).toInt(),
                isUtc: true)
            .toLocal(),
        end: m['e'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((m['e'] as num).toInt(),
                    isUtc: true)
                .toLocal(),
        segments: ((m['g'] as List?) ?? [])
            .map((x) => Segment.fromJson(Map<String, dynamic>.from(x as Map)))
            .toList(),
        startLat: (m['sla'] as num?)?.toDouble(),
        startLon: (m['slo'] as num?)?.toDouble(),
        endLat: (m['ela'] as num?)?.toDouble(),
        endLon: (m['elo'] as num?)?.toDouble(),
      );
}

/// "4h05", "0h45".
String fmtDur(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes - h * 60;
  return '${h}h${m.toString().padLeft(2, '0')}';
}

String two(int n) => n.toString().padLeft(2, '0');
String fmtTime(DateTime t) => '${two(t.hour)}:${two(t.minute)}';
String fmtDate(DateTime t) => '${two(t.day)}/${two(t.month)}/${t.year}';
String fmtDateTime(DateTime t) => '${fmtDate(t)} ${fmtTime(t)}';

const _dias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
String weekdayShort(DateTime t) => _dias[t.weekday - 1];
