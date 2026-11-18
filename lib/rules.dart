import 'i18n.dart';
import 'models.dart';

/// Regras do Regulamento (CE) n.º 561/2006 (com as alterações do
/// Regulamento (UE) 2020/1054), para transporte de mercadorias com um
/// condutor só. O app é um auxiliar: o que vale é o tacógrafo.
class Limits {
  static const continuousDrive = Duration(hours: 4, minutes: 30); // art. 7.º
  static const breakFull = Duration(minutes: 45);
  static const breakFirst = Duration(minutes: 15);
  static const breakSecond = Duration(minutes: 30);
  static const dailyDrive = Duration(hours: 9); // art. 6.º/1
  static const dailyDriveExt = Duration(hours: 10); // 2x por semana
  static const extPerWeek = 2;
  static const weeklyDrive = Duration(hours: 56); // art. 6.º/2
  static const fortnightDrive = Duration(hours: 90); // art. 6.º/3
  static const dailyRest = Duration(hours: 11); // art. 8.º
  static const dailyRestReduced = Duration(hours: 9);
  static const reducedRestsAllowed = 3; // entre dois descansos semanais
  static const amplitude = Duration(hours: 13); // 24 h - 11 h
  static const amplitudeExt = Duration(hours: 15); // 24 h - 9 h
  static const weeklyRest = Duration(hours: 45);
  static const weeklyRestReduced = Duration(hours: 24);
  static const maxBetweenWeeklyRests = Duration(hours: 144); // 6 x 24 h
}

/// Segunda-feira 00:00 UTC da semana de [t] (o tacógrafo conta em UTC).
DateTime weekStartUtc(DateTime t) {
  final u = t.toUtc();
  final day = DateTime.utc(u.year, u.month, u.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// Parte de [s] dentro de [from, to).
Duration _clip(Segment s, DateTime from, DateTime to, DateTime now) {
  var a = s.start;
  var b = s.end ?? now;
  if (a.isBefore(from)) a = from;
  if (b.isAfter(to)) b = to;
  final d = b.difference(a);
  return d.isNegative ? Duration.zero : d;
}

/// Condução somada de todas as jornadas dentro de [from, to).
Duration driveBetween(
    List<Shift> shifts, DateTime from, DateTime to, DateTime now) {
  var t = Duration.zero;
  for (final sh in shifts) {
    for (final s in sh.segments) {
      if (s.act == Act.drive) t += _clip(s, from, to, sh.end ?? now);
    }
  }
  return t;
}

/// Condução contínua e situação da pausa de uma jornada.
class BreakState {
  /// Condução acumulada desde a última pausa completa.
  final Duration driven;

  /// Já fez a 1ª parte (15 min) da pausa dividida.
  final bool firstPartDone;
  const BreakState(this.driven, this.firstPartDone);

  Duration get left {
    final d = Limits.continuousDrive - driven;
    return d.isNegative ? Duration.zero : d;
  }

  bool get exceeded => driven > Limits.continuousDrive;

  /// Pausa que ainda falta fazer para zerar a condução contínua.
  Duration get breakNeeded =>
      firstPartDone ? Limits.breakSecond : Limits.breakFull;
}

/// Trecho de condução tão curto que é "pulo" do GPS, não arranque de
/// verdade (menos de 1 min e menos de 100 m). Não interrompe a pausa.
bool _isBlip(Segment s, DateTime ref) =>
    s.act == Act.drive && s.dur(ref) < const Duration(minutes: 1) && s.km < 0.1;

bool _isRest(Act a) => a == Act.pause || a == Act.unknown;

/// Percorre a jornada contando a condução contínua.
///
/// 1.7.2: trechos de pausa seguidos (ex.: "a classificar" + pausa, ou a
/// pausa partida em dois por um toque na tela ou um pulo do GPS) somam
/// como UMA pausa só. Antes cada pedaço era avaliado sozinho e uma pausa
/// de 59 min partida em 30 + 29 não zerava as 4h30.
/// [onDrive] recebe a condução acumulada depois de cada trecho de condução.
BreakState _walk(Shift sh, DateTime now, [void Function(Duration)? onDrive]) {
  final ref = sh.end ?? now;
  var acc = Duration.zero;
  var first = false;
  var rest = Duration.zero; // pausa em curso (trechos seguidos somados)

  void closeRest() {
    if (rest >= Limits.breakFull || (first && rest >= Limits.breakSecond)) {
      acc = Duration.zero;
      first = false;
    } else if (!first && rest >= Limits.breakFirst) {
      first = true;
    }
    rest = Duration.zero;
  }

  for (final s in sh.segments) {
    final d = s.dur(ref);
    if (_isRest(s.act)) {
      rest += d;
    } else if (rest > Duration.zero && _isBlip(s, ref)) {
      // Pulo do GPS no meio da pausa: a pausa continua.
      rest += d;
    } else {
      if (rest > Duration.zero) closeRest();
      if (s.act == Act.drive) {
        acc += d;
        onDrive?.call(acc);
      }
    }
  }
  if (rest > Duration.zero) closeRest();
  return BreakState(acc, first);
}

/// Art. 7.º: depois de 4h30 de condução, pausa de 45 min seguidos, ou
/// 15 min + 30 min (nesta ordem). Martelo e carga/descarga não contam como
/// pausa. Parada "a classificar" conta como pausa, provisoriamente.
/// Depois de uma pausa completa a contagem recomeça das 4h30.
BreakState breakState(Shift sh, DateTime now) => _walk(sh, now);

/// Maior condução contínua da jornada (para relatório / infrações).
Duration maxContinuousDrive(Shift sh, DateTime now) {
  var best = Duration.zero;
  _walk(sh, now, (acc) {
    if (acc > best) best = acc;
  });
  return best;
}

/// Nome da pausa pelo tempo que durou: 15, 30 ou 45 minutos.
String pauseLabel(Duration d) {
  if (d >= Limits.breakFull) return tr('Pausa 45 min');
  if (d >= Limits.breakSecond) return tr('Pausa 30 min');
  if (d >= Limits.breakFirst) return tr('Pausa 15 min');
  return tr('Pausa curta');
}

/// Tipo do descanso entre duas jornadas.
enum RestKind { tooShort, dailyReduced, daily, weeklyReduced, weekly }

RestKind restKind(Duration gap) {
  if (gap >= Limits.weeklyRest) return RestKind.weekly;
  if (gap >= Limits.weeklyRestReduced) return RestKind.weeklyReduced;
  if (gap >= Limits.dailyRest) return RestKind.daily;
  if (gap >= Limits.dailyRestReduced) return RestKind.dailyReduced;
  return RestKind.tooShort;
}

String restLabel(RestKind k) {
  switch (k) {
    case RestKind.weekly:
      return tr('Descanso semanal (45 h)');
    case RestKind.weeklyReduced:
      return tr('Descanso semanal reduzido (24 h)');
    case RestKind.daily:
      return tr('Descanso diário (11 h)');
    case RestKind.dailyReduced:
      return tr('Descanso diário reduzido (9 h)');
    case RestKind.tooShort:
      return tr('Descanso insuficiente (menos de 9 h)');
  }
}

/// Resumo de tudo o que o painel mostra.
class Status {
  final BreakState brk;
  final Duration dayDrive;
  final Duration dayLimit; // 9 h ou 10 h
  final int extUsed; // dias de 10 h já usados na semana (sem contar hoje)
  final bool extToday; // hoje já passou de 9 h
  final Duration weekDrive;
  final Duration prevWeekDrive;
  final Duration weekLeft; // respeitando 56 h e 90 h
  final Duration amplitude;
  final int reducedRestsUsed; // desde o último descanso semanal
  final DateTime? weeklyRestDeadline;
  final Duration pauseToday, workToday, loadToday;
  const Status({
    required this.brk,
    required this.dayDrive,
    required this.dayLimit,
    required this.extUsed,
    required this.extToday,
    required this.weekDrive,
    required this.prevWeekDrive,
    required this.weekLeft,
    required this.amplitude,
    required this.reducedRestsUsed,
    required this.weeklyRestDeadline,
    required this.pauseToday,
    required this.workToday,
    required this.loadToday,
  });

  Duration get fortnightDrive => weekDrive + prevWeekDrive;

  /// Condução que ainda cabe hoje (até 9 h ou 10 h).
  Duration get dayLeft {
    final d = dayLimit - dayDrive;
    return d.isNegative ? Duration.zero : d;
  }

  /// 1.7.2: quanto ainda pode conduzir agora, pelo limite que chega
  /// primeiro: a pausa (4h30), o fim das 9 h/10 h do dia ou a semana.
  Duration get driveLeft {
    var l = brk.left;
    if (dayLeft < l) l = dayLeft;
    if (weekLeft < l) l = weekLeft;
    return l;
  }

  /// O que vem primeiro: 'pausa', 'dia' ou 'semana'.
  String get nextLimit {
    if (weekLeft < brk.left && weekLeft < dayLeft) return 'semana';
    if (dayLeft <= brk.left) return 'dia';
    return 'pausa';
  }



  /// Pode ir até 15 h hoje? (ainda tem descanso reduzido de 9 h disponível)
  bool get canExtendAmplitude =>
      reducedRestsUsed < Limits.reducedRestsAllowed;

  Duration get amplitudeLimit =>
      canExtendAmplitude ? Limits.amplitudeExt : Limits.amplitude;
}

/// Jornadas em ordem de início.
List<Shift> sorted(List<Shift> shifts) {
  final l = List<Shift>.from(shifts);
  l.sort((a, b) => a.start.compareTo(b.start));
  return l;
}

/// Quantas jornadas da semana UTC de [ref] passaram de 9 h de condução
/// (sem contar [except]).
int extendedDaysInWeek(List<Shift> shifts, DateTime ref, DateTime now,
    {Shift? except}) {
  final ws = weekStartUtc(ref);
  final we = ws.add(const Duration(days: 7));
  var n = 0;
  for (final sh in shifts) {
    if (identical(sh, except)) continue;
    final st = sh.start.toUtc();
    if (st.isBefore(ws) || !st.isBefore(we)) continue;
    if (sh.total(Act.drive, now) > Limits.dailyDrive) n++;
  }
  return n;
}

/// Descansos diários reduzidos (9 h a menos de 11 h) desde o último
/// descanso semanal, e o prazo para começar o próximo descanso semanal.
(int, DateTime?) _restInfo(List<Shift> all, Shift current) {
  final l = sorted(all);
  final idx = l.indexWhere((s) => identical(s, current));
  final upto = idx < 0 ? l.length - 1 : idx;
  var reduced = 0;
  DateTime? lastWeeklyEnd;
  for (var i = upto; i >= 1; i--) {
    final prev = l[i - 1];
    if (prev.end == null) continue;
    final gap = l[i].start.difference(prev.end!);
    final k = restKind(gap);
    if (k == RestKind.weekly || k == RestKind.weeklyReduced) {
      lastWeeklyEnd = l[i].start;
      break;
    }
    if (k == RestKind.dailyReduced || k == RestKind.tooShort) reduced++;
  }
  // Sem descanso semanal registrado: conta a partir da 1ª jornada.
  lastWeeklyEnd ??= l.isEmpty ? null : l.first.start;
  final deadline = lastWeeklyEnd?.add(Limits.maxBetweenWeeklyRests);
  return (reduced, deadline);
}

Status computeStatus(List<Shift> all, Shift current, DateTime now) {
  final ref = current.end ?? now;
  final ws = weekStartUtc(ref);
  final we = ws.add(const Duration(days: 7));
  final pws = ws.subtract(const Duration(days: 7));
  final week = driveBetween(all, ws, we, now);
  final prev = driveBetween(all, pws, ws, now);
  final dayDrive = current.total(Act.drive, now);
  final extUsed = extendedDaysInWeek(all, ref, now, except: current);
  final dayLimit = extUsed < Limits.extPerWeek
      ? Limits.dailyDriveExt
      : Limits.dailyDrive;
  var left = Limits.weeklyDrive - week;
  final left2 = Limits.fortnightDrive - prev - week;
  if (left2 < left) left = left2;
  if (left.isNegative) left = Duration.zero;
  final (reduced, deadline) = _restInfo(all, current);
  return Status(
    brk: breakState(current, now),
    dayDrive: dayDrive,
    dayLimit: dayLimit,
    extUsed: extUsed,
    extToday: dayDrive > Limits.dailyDrive,
    weekDrive: week,
    prevWeekDrive: prev,
    weekLeft: left,
    amplitude: current.amplitude(now),
    reducedRestsUsed: reduced,
    weeklyRestDeadline: deadline,
    pauseToday: current.total(Act.pause, now) + current.total(Act.unknown, now),
    workToday: current.total(Act.work, now),
    loadToday: current.total(Act.load, now),
  );
}

/// Infrações / avisos de uma jornada, em texto (para a tela e o relatório).
List<String> shiftIssues(List<Shift> all, Shift sh, DateTime now) {
  final out = <String>[];
  final mc = maxContinuousDrive(sh, now);
  if (mc > Limits.continuousDrive) {
    out.add(tr('Condução contínua de {0} sem a pausa de 45 min (limite 4h30).', [fmtDur(mc)]));
  }
  final dd = sh.total(Act.drive, now);
  final ext = extendedDaysInWeek(all, sh.end ?? now, now, except: sh);
  if (dd > Limits.dailyDriveExt) {
    out.add(tr('Condução diária de {0} (limite 10h).', [fmtDur(dd)]));
  } else if (dd > Limits.dailyDrive && ext >= Limits.extPerWeek) {
    out.add(tr('Condução diária de {0}: já havia 2 dias de 10h nesta semana (limite 9h).', [fmtDur(dd)]));
  }
  final amp = sh.amplitude(now);
  if (amp > Limits.amplitudeExt) {
    out.add(tr('Amplitude de {0} (limite 15h).', [fmtDur(amp)]));
  }
  final l = sorted(all);
  final i = l.indexWhere((s) => identical(s, sh));
  if (i > 0 && l[i - 1].end != null) {
    final gap = sh.start.difference(l[i - 1].end!);
    if (restKind(gap) == RestKind.tooShort) {
      out.add(tr('Descanso antes desta jornada de {0} (mínimo 9h).', [fmtDur(gap)]));
    }
  }
  // 1.7.9: excessos de velocidade (mais de 1 min acima do limite escolhido).
  for (final v in sh.speeding) {
    final d = v.dur(now);
    final m = d.inMinutes, sec = d.inSeconds % 60;
    final where = v.lat != null && v.lon != null
        ? tr(', em {0}, {1}', [v.lat!.toStringAsFixed(5), v.lon!.toStringAsFixed(5)])
        : '';
    out.add(tr('Excesso de velocidade às {0}: {1}min{2}s acima de {3} km/h (máx. {4} km/h){5}.', [fmtTime(v.start), m, sec.toString().padLeft(2, '0'), v.limit, v.maxKmh.round(), where]));
  }
  for (final s in sh.segments) {
    if (s.act == Act.unknown) {
      out.add(tr('Há paradas ainda não classificadas (contadas como pausa).'));
      break;
    }
  }
  return out;
}
