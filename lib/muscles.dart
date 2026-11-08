import 'dart:math';

import 'main.dart';
import 'model.dart';
import 'muscle_data.dart';

/// The muscles an exercise is tagged with (the free-exercise-db set). The order is the bit order of
/// [Muscles] and of tool/exercise_muscles.py; append only.
enum Muscle {
  chest('Brust'),
  shoulders('Schultern'),
  triceps('Trizeps'),
  biceps('Bizeps'),
  forearms('Unterarme'),
  lats('Latissimus'),
  middleBack('Mittlerer Rücken'),
  lowerBack('Unterer Rücken'),
  traps('Trapez'),
  neck('Nacken'),
  abdominals('Bauch'),
  quadriceps('Quadrizeps'),
  hamstrings('Beinbeuger'),
  glutes('Gesäß'),
  calves('Waden'),
  adductors('Adduktoren'),
  abductors('Abduktoren');

  const Muscle(this.label);
  final String label;
  int get bit => 1 << index;
}

/// Primary and secondary muscles as bit masks; secondary counts half.
typedef Muscles = (int, int);

Set<Muscle> musclesIn(int bits) => {for (final m in Muscle.values) if (bits & m.bit != 0) m};

int _bits(List<Muscle> muscles) => muscles.fold(0, (b, m) => b | m.bit);

/// The curated catalogue, by hand: the databases miss some of these names or their helpers.
final Map<String, Muscles> _catalogue = {
  for (final (name, p, s) in const <(String, List<Muscle>, List<Muscle>)>[
    ('Kniebeuge', [Muscle.quadriceps, Muscle.glutes], [Muscle.hamstrings, Muscle.lowerBack, Muscle.adductors]),
    ('Kreuzheben', [Muscle.lowerBack, Muscle.hamstrings, Muscle.glutes], [Muscle.quadriceps, Muscle.traps, Muscle.forearms]),
    ('Rumänisches Kreuzheben', [Muscle.hamstrings, Muscle.glutes], [Muscle.lowerBack]),
    ('Bankdrücken', [Muscle.chest], [Muscle.shoulders, Muscle.triceps]),
    ('Schrägbankdrücken', [Muscle.chest, Muscle.shoulders], [Muscle.triceps]),
    ('Kurzhantel-Bankdrücken', [Muscle.chest], [Muscle.shoulders, Muscle.triceps]),
    ('Schulterdrücken', [Muscle.shoulders], [Muscle.triceps, Muscle.traps, Muscle.abdominals]),
    ('Kurzhantel-Schulterdrücken', [Muscle.shoulders], [Muscle.triceps]),
    ('Langhantelrudern', [Muscle.middleBack, Muscle.lats], [Muscle.biceps, Muscle.lowerBack, Muscle.shoulders]),
    ('Kurzhantelrudern', [Muscle.middleBack, Muscle.lats], [Muscle.biceps, Muscle.shoulders]),
    ('Kabelrudern', [Muscle.middleBack, Muscle.lats], [Muscle.biceps]),
    ('Klimmzüge', [Muscle.lats], [Muscle.biceps, Muscle.middleBack, Muscle.forearms]),
    ('Latzug', [Muscle.lats], [Muscle.biceps, Muscle.middleBack]),
    ('Dips', [Muscle.triceps, Muscle.chest], [Muscle.shoulders]),
    ('Beinpresse', [Muscle.quadriceps], [Muscle.glutes, Muscle.hamstrings]),
    ('Ausfallschritte', [Muscle.quadriceps, Muscle.glutes], [Muscle.hamstrings, Muscle.calves]),
    ('Bulgarian Split Squat', [Muscle.quadriceps, Muscle.glutes], [Muscle.hamstrings, Muscle.adductors]),
    ('Beinstrecker', [Muscle.quadriceps], <Muscle>[]),
    ('Beinbeuger', [Muscle.hamstrings], [Muscle.calves]),
    ('Nordic Curls', [Muscle.hamstrings], <Muscle>[]),
    ('Hip Thrust', [Muscle.glutes], [Muscle.hamstrings]),
    ('Wadenheben', [Muscle.calves], <Muscle>[]),
    ('Bizepscurls', [Muscle.biceps], [Muscle.forearms]),
    ('Hammercurls', [Muscle.biceps, Muscle.forearms], <Muscle>[]),
    ('Trizepsdrücken am Kabel', [Muscle.triceps], <Muscle>[]),
    ('French Press', [Muscle.triceps], <Muscle>[]),
    ('Seitheben', [Muscle.shoulders], [Muscle.traps]),
    ('Face Pulls', [Muscle.shoulders], [Muscle.traps, Muscle.middleBack]),
    ('Butterfly', [Muscle.chest], [Muscle.shoulders]),
    ('Crunches', [Muscle.abdominals], <Muscle>[]),
    ('Enges Bankdrücken', [Muscle.triceps, Muscle.chest], [Muscle.shoulders]),
    ('Negativbankdrücken', [Muscle.chest], [Muscle.triceps, Muscle.shoulders]),
    ('Kurzhantel-Schrägbankdrücken', [Muscle.chest, Muscle.shoulders], [Muscle.triceps]),
    ('Kurzhantel-Fliegende', [Muscle.chest], [Muscle.shoulders]),
    ('Kabelzug-Crossover', [Muscle.chest], [Muscle.shoulders]),
    ('Brustpresse', [Muscle.chest], [Muscle.shoulders, Muscle.triceps]),
    ('Liegestütze', [Muscle.chest], [Muscle.triceps, Muscle.shoulders, Muscle.abdominals]),
    ('Überzüge', [Muscle.chest, Muscle.lats], [Muscle.triceps]),
    ('Arnold Press', [Muscle.shoulders], [Muscle.triceps]),
    ('Push Press', [Muscle.shoulders], [Muscle.triceps, Muscle.quadriceps, Muscle.glutes]),
    ('Maschinen-Schulterdrücken', [Muscle.shoulders], [Muscle.triceps]),
    ('Frontheben', [Muscle.shoulders], <Muscle>[]),
    ('Reverse Butterfly', [Muscle.shoulders], [Muscle.middleBack, Muscle.traps]),
    ('Aufrechtes Rudern', [Muscle.shoulders, Muscle.traps], [Muscle.biceps]),
    ('Shrugs', [Muscle.traps], [Muscle.forearms]),
    ('T-Bar-Rudern', [Muscle.middleBack, Muscle.lats], [Muscle.biceps, Muscle.lowerBack]),
    ('Maschinenrudern', [Muscle.middleBack, Muscle.lats], [Muscle.biceps]),
    ('Umgekehrtes Rudern', [Muscle.middleBack, Muscle.lats], [Muscle.biceps]),
    ('Klimmzüge im Untergriff', [Muscle.lats, Muscle.biceps], [Muscle.middleBack]),
    ('Latzug eng', [Muscle.lats], [Muscle.biceps, Muscle.middleBack]),
    ('Überzüge am Kabel', [Muscle.lats], [Muscle.triceps]),
    ('Rückenstrecker', [Muscle.lowerBack], [Muscle.glutes, Muscle.hamstrings]),
    ('Good Mornings', [Muscle.hamstrings, Muscle.lowerBack], [Muscle.glutes]),
    ('Rack Pulls', [Muscle.lowerBack, Muscle.traps], [Muscle.glutes, Muscle.hamstrings, Muscle.forearms]),
    ('Frontkniebeuge', [Muscle.quadriceps], [Muscle.glutes, Muscle.abdominals]),
    ('Goblet Squat', [Muscle.quadriceps, Muscle.glutes], [Muscle.abdominals]),
    ('Hackenschmidt-Kniebeuge', [Muscle.quadriceps], [Muscle.glutes]),
    ('Sumo-Kreuzheben', [Muscle.glutes, Muscle.adductors, Muscle.lowerBack], [Muscle.quadriceps, Muscle.hamstrings, Muscle.traps, Muscle.forearms]),
    ('Trap-Bar-Kreuzheben', [Muscle.quadriceps, Muscle.glutes, Muscle.lowerBack], [Muscle.hamstrings, Muscle.traps, Muscle.forearms]),
    ('Kreuzheben mit gestreckten Beinen', [Muscle.hamstrings], [Muscle.lowerBack, Muscle.glutes]),
    ('Einbeiniges Kreuzheben', [Muscle.hamstrings, Muscle.glutes], [Muscle.lowerBack]),
    ('Step-ups', [Muscle.quadriceps, Muscle.glutes], [Muscle.hamstrings]),
    ('Ausfallschritte gehend', [Muscle.quadriceps, Muscle.glutes], [Muscle.hamstrings]),
    ('Adduktorenmaschine', [Muscle.adductors], <Muscle>[]),
    ('Abduktorenmaschine', [Muscle.abductors], [Muscle.glutes]),
    ('Wadenheben sitzend', [Muscle.calves], <Muscle>[]),
    ('SZ-Curls', [Muscle.biceps], [Muscle.forearms]),
    ('Langhantelcurls', [Muscle.biceps], [Muscle.forearms]),
    ('Konzentrationscurls', [Muscle.biceps], <Muscle>[]),
    ('Scottcurls', [Muscle.biceps], <Muscle>[]),
    ('Kabelcurls', [Muscle.biceps], [Muscle.forearms]),
    ('Trizeps-Überkopfdrücken', [Muscle.triceps], <Muscle>[]),
    ('Trizeps-Kickbacks', [Muscle.triceps], <Muscle>[]),
    ('Bankdips', [Muscle.triceps], [Muscle.chest, Muscle.shoulders]),
    ('Handgelenkcurls', [Muscle.forearms], <Muscle>[]),
    ('Plank', [Muscle.abdominals], <Muscle>[]),
    ('Seitstütz', [Muscle.abdominals], <Muscle>[]),
    ('Beinheben hängend', [Muscle.abdominals], <Muscle>[]),
    ('Beinheben liegend', [Muscle.abdominals], <Muscle>[]),
    ('Sit-ups', [Muscle.abdominals], <Muscle>[]),
    ('Russian Twists', [Muscle.abdominals], <Muscle>[]),
    ('Kabel-Crunches', [Muscle.abdominals], <Muscle>[]),
    ('Ab Wheel', [Muscle.abdominals], [Muscle.lats, Muscle.shoulders]),
    ('Pallof Press', [Muscle.abdominals], <Muscle>[]),
    ('Dead Bug', [Muscle.abdominals], <Muscle>[]),
    ('Farmers Walk', [Muscle.forearms, Muscle.traps], [Muscle.abdominals, Muscle.quadriceps, Muscle.glutes, Muscle.lowerBack]),
    ('Suitcase Carry', [Muscle.abdominals, Muscle.forearms], [Muscle.traps]),
    ('Kettlebell Swings', [Muscle.glutes, Muscle.hamstrings], [Muscle.lowerBack, Muscle.shoulders, Muscle.abdominals]),
    ('Turkish Get-up', [Muscle.shoulders, Muscle.abdominals], [Muscle.glutes, Muscle.triceps]),
    ('Thruster', [Muscle.quadriceps, Muscle.shoulders], [Muscle.glutes, Muscle.triceps]),
    ('Burpees', [Muscle.quadriceps, Muscle.chest], [Muscle.shoulders, Muscle.triceps, Muscle.abdominals]),
    ('Umsetzen', [Muscle.glutes, Muscle.hamstrings, Muscle.traps], [Muscle.quadriceps, Muscle.shoulders, Muscle.lowerBack, Muscle.calves]),
    ('Reißen', [Muscle.glutes, Muscle.hamstrings, Muscle.shoulders], [Muscle.quadriceps, Muscle.traps, Muscle.lowerBack, Muscle.triceps]),
  ])
    for (final n in [name, ...?exerciseAliases[name]]) searchKey(n): (_bits(p), _bits(s)),
};

/// Last resort for own exercises: word parts in German or English, first match wins.
const _keywords = <(String, Muscle)>[
  ('hammer', Muscle.forearms), ('handgelenk', Muscle.forearms), ('wrist', Muscle.forearms),
  ('curl', Muscle.biceps), ('bizeps', Muscle.biceps), ('biceps', Muscle.biceps),
  ('trizeps', Muscle.triceps), ('triceps', Muscle.triceps), ('dip', Muscle.triceps),
  ('schulter', Muscle.shoulders), ('shoulder', Muscle.shoulders), ('seitheb', Muscle.shoulders),
  ('lateral', Muscle.shoulders), ('overhead', Muscle.shoulders),
  ('bank', Muscle.chest), ('bench', Muscle.chest), ('brust', Muscle.chest), ('chest', Muscle.chest),
  ('fly', Muscle.chest), ('liegestue', Muscle.chest), ('pushup', Muscle.chest),
  ('shrug', Muscle.traps), ('nacken', Muscle.neck), ('neck', Muscle.neck),
  ('latzug', Muscle.lats), ('pulldown', Muscle.lats), ('klimmzug', Muscle.lats), ('pullup', Muscle.lats),
  ('rudern', Muscle.middleBack), ('row', Muscle.middleBack), ('zug', Muscle.lats), ('pull', Muscle.lats),
  ('kreuzheb', Muscle.lowerBack), ('deadlift', Muscle.lowerBack), ('hyperext', Muscle.lowerBack),
  ('ruecken', Muscle.middleBack),
  ('wade', Muscle.calves), ('calf', Muscle.calves),
  ('hip', Muscle.glutes), ('glute', Muscle.glutes), ('gesaess', Muscle.glutes),
  ('beinbeug', Muscle.hamstrings), ('legcurl', Muscle.hamstrings),
  ('adduk', Muscle.adductors), ('adduct', Muscle.adductors), ('abduk', Muscle.abductors), ('abduct', Muscle.abductors),
  ('squat', Muscle.quadriceps), ('kniebeug', Muscle.quadriceps), ('lunge', Muscle.quadriceps),
  ('ausfall', Muscle.quadriceps), ('bein', Muscle.quadriceps), ('leg', Muscle.quadriceps),
  ('bauch', Muscle.abdominals), ('crunch', Muscle.abdominals), ('plank', Muscle.abdominals),
  ('situp', Muscle.abdominals), ('abs', Muscle.abdominals),
];

/// The user's choice from the exercise editor, kept in the training data (Store.muscles).
Muscles? _custom(String name) {
  final k = searchKey(name);
  for (final MapEntry(:key, :value) in store.muscles.entries) {
    if (searchKey(key) == k) return (_named(value['primary']), _named(value['secondary']));
  }
  return null;
}

/// Muscle names from the data; unknown ones (e.g. from an older version) are skipped.
int _named(List<dynamic>? names) =>
    _bits([for (final n in names ?? const []) ?Muscle.values.asNameMap()[n]]);

/// Muscles found without the user's choice: catalogue, then the databases, then word parts.
/// Null = unknown.
Muscles? defaultMuscles(String name) {
  final k = searchKey(name);
  if (_catalogue[k] ?? exerciseMuscles[k] case final m?) return m;
  for (final (word, muscle) in _keywords) {
    if (k.contains(word)) return (muscle.bit, 0);
  }
  return null;
}

/// What an exercise trains: the user's choice, else [defaultMuscles].
Muscles? musclesOf(String name) => _custom(name) ?? defaultMuscles(name);

/// Stores the user's choice for [name]; removed again when it matches the default.
Future<void> setMuscles(String name, Muscles m) {
  final k = searchKey(name);
  store.muscles.removeWhere((key, _) => searchKey(key) == k);
  if (m != defaultMuscles(name)) {
    List<String> names(int bits) => [for (final x in musclesIn(bits)) x.name];
    store.muscles[name] = {'primary': names(m.$1), 'secondary': names(m.$2)};
  }
  return store.saveMuscles();
}

/// Done sets per muscle: 1 where it's a primary muscle, ½ where it helps.
Map<Muscle, double> setsPerSingleMuscle(Iterable<Session> sessions) {
  final sets = {for (final m in Muscle.values) m: 0.0};
  for (final s in sessions) {
    for (final e in s.exercises) {
      if (e.cardio || e.setsDone == 0) continue;
      final (p, sec) = musclesOf(e.name) ?? (0, 0);
      for (final m in musclesIn(p)) {
        sets[m] = sets[m]! + e.setsDone;
      }
      for (final m in musclesIn(sec)) {
        sets[m] = sets[m]! + e.setsDone / 2;
      }
    }
  }
  return sets;
}

/// What trained [m]: done sets per exercise, ½ where it helps; most first.
List<(String, double)> exercisesFor(Muscle m, Iterable<Session> sessions) {
  final sets = <String, double>{};
  for (final s in sessions) {
    for (final e in s.exercises) {
      if (e.cardio || e.setsDone == 0) continue;
      final (p, sec) = musclesOf(e.name) ?? (0, 0);
      final share = p & m.bit != 0 ? 1.0 : sec & m.bit != 0 ? .5 : 0.0;
      if (share > 0) sets[e.name] = (sets[e.name] ?? 0) + e.setsDone * share;
    }
  }
  return [for (final e in sets.entries) (e.key, e.value)]..sort((a, b) => b.$2.compareTo(a.$2));
}

/// The pairs [balances] checks.
enum Pair { chestBack, squatHinge, quadsHamstrings, pushPullFlat, pushPullOverhead }

/// Two opposing sides, [b] against [a]: balanced while b / a lies within [low]–[high] (guide values from
/// training practice, not medical limits). [strength]: the sides are lifts and the values their
/// current 1RM in kg; else the values are sets per week.
class Balance {
  final Pair pair;
  final String title, a, b, aGroup, bGroup;
  final double aValue, bValue, low, high;
  final bool strength;
  Balance(this.pair, this.title, (String, String, double) sideA, (String, String, double) sideB, this.low, this.high,
      {this.strength = false})
      : aGroup = sideA.$1,
        a = sideA.$2,
        aValue = sideA.$3,
        bGroup = sideB.$1,
        b = sideB.$2,
        bValue = sideB.$3;

  double get ratio => aValue == 0 ? double.infinity : bValue / aValue;

  /// The muscle group that falls behind, or null when balanced.
  String? get lagging => ratio < low ? bGroup : ratio > high ? aGroup : null;
}

// Lifts compared by strength, matched on the name; dumbbells (weight per hand), split and front squats,
// inclines, declines and machines don't compare. Other exercises still count in the pairs by sets.
bool _press(String k) => (k.contains('bankdrueck') || k.contains('benchpress')) && !_odd(k);
bool _row(String k) => (k.contains('rudern') || k.endsWith('row')) && !_odd(k) && !k.contains('aufrecht') && !k.contains('upright');
bool _squat(String k) => (k.contains('kniebeuge') || k.contains('squat')) && !_odd(k);
bool _hinge(String k) => (k.contains('kreuzheb') || k.contains('deadlift')) && !k.contains('rumaen') && !k.contains('romanian');
bool _odd(String k) => const ['kurzhantel', 'dumbbell', 'schraeg', 'incline', 'split', 'bulgarian', 'front', 'goblet',
      'negativ', 'decline', 'hack', 'maschine', 'machine', 'kabel', 'cable', 'tbar']
    .any(k.contains);

/// Which side of a pair by sets an exercise counts on: 0 for side a, 1 for side b, null for neither.
/// Pressing: chest (flat), or shoulders with the triceps helping (overhead). Pulling: rows train the
/// middle back (flat), pull-ups and pulldowns only the lats (from above). Legs by the primary muscle.
int? sideOf(Pair pair, String name) {
  final (p, sec) = musclesOf(name) ?? (0, 0);
  bool has(int bits, Muscle m) => bits & m.bit != 0;
  final push = has(p, Muscle.middleBack) || has(p, Muscle.lats)
      ? null
      : has(p, Muscle.chest)
          ? Pair.pushPullFlat
          : has(p, Muscle.shoulders) && has(sec, Muscle.triceps)
              ? Pair.pushPullOverhead
              : null;
  return switch (pair) {
    Pair.pushPullFlat => has(p, Muscle.middleBack) ? 1 : push == Pair.pushPullFlat ? 0 : null,
    Pair.pushPullOverhead => !has(p, Muscle.middleBack) && has(p, Muscle.lats) ? 1 : push == Pair.pushPullOverhead ? 0 : null,
    Pair.quadsHamstrings => has(p, Muscle.quadriceps) ? 0 : has(p, Muscle.hamstrings) ? 1 : null,
    Pair.chestBack || Pair.squatHinge => null,
  };
}

/// Pairs that drift apart easily, from [sessions] (newest first) over [weeks]. Guide values:
/// - Brust ↔ oberer Rücken by strength: barbell rows at 75–120 % of the bench press (coaching practice),
/// - Quadrizeps ↔ hintere Kette by strength: the deadlift at 100–140 % of the squat (in powerlifting
///   it's mostly 110–125 %),
/// - Quadrizeps ↔ Beinbeuger by sets: at least 60 % (hamstrings to quadriceps, the one ratio with some
///   evidence on strains),
/// - Drücken ↔ Ziehen, flat and overhead, by sets: at least as much pulling as pressing.
/// The strength pairs need both barbell lifts; the pairs by sets work with any exercise and show once
/// side [a] was trained (nothing on side b is the clearest imbalance).
List<Balance> balances(List<Session> sessions, {double weeks = 1}) {
  // Current level: the best 1RM of an exercise's latest four trainings; the strongest exercise counts.
  (String, double)? strongest(bool Function(String) family) {
    final recent = <String, List<double>>{};
    for (final s in sessions) {
      for (final e in s.exercises) {
        if (e.cardio || e.weight == 0 || e.setsDone == 0 || !family(searchKey(e.name))) continue;
        final list = recent.putIfAbsent(e.name, () => []);
        if (list.length < 4) list.add(estimated1rm(e));
      }
    }
    (String, double)? best;
    for (final MapEntry(key: name, value: v) in recent.entries) {
      final top = v.reduce(max);
      if (best == null || top > best.$2) best = (name, top);
    }
    return best;
  }

  final result = <Balance>[];
  if ((strongest(_press), strongest(_row)) case ((final na, final va)?, (final nb, final vb)?)) {
    result.add(Balance(Pair.chestBack, 'Brust ↔ oberer Rücken', ('Brust', na, va), ('Oberer Rücken', nb, vb), .75, 1.2,
        strength: true));
  }
  if ((strongest(_squat), strongest(_hinge)) case ((final na, final va)?, (final nb, final vb)?)) {
    result.add(Balance(Pair.squatHinge, 'Quadrizeps ↔ hintere Kette', ('Quadrizeps', na, va), ('Hintere Kette', nb, vb), 1,
        1.4, strength: true));
  }

  final perMuscle = setsPerSingleMuscle(sessions);
  final (quads, hams) = (perMuscle[Muscle.quadriceps]!, perMuscle[Muscle.hamstrings]!);
  if (quads > 0) {
    result.add(Balance(Pair.quadsHamstrings, 'Quadrizeps ↔ Beinbeuger', ('Quadrizeps', 'Quadrizeps', quads / weeks),
        ('Beinbeuger', 'Beinbeuger', hams / weeks), .6, double.infinity));
  }

  var (pushFlat, pushUp, pullFlat, pullUp) = (0.0, 0.0, 0.0, 0.0);
  for (final s in sessions) {
    for (final e in s.exercises) {
      if (e.cardio || e.setsDone == 0) continue;
      switch ((sideOf(Pair.pushPullFlat, e.name), sideOf(Pair.pushPullOverhead, e.name))) {
        case (0, _):
          pushFlat += e.setsDone;
        case (1, _):
          pullFlat += e.setsDone;
        case (_, 0):
          pushUp += e.setsDone;
        case (_, 1):
          pullUp += e.setsDone;
      }
    }
  }
  if (pushFlat > 0) {
    result.add(Balance(Pair.pushPullFlat, 'Drücken ↔ Rudern', ('Brust', 'Drücken', pushFlat / weeks),
        ('Oberer Rücken', 'Rudern', pullFlat / weeks), 1, double.infinity));
  }
  if (pushUp > 0) {
    result.add(Balance(Pair.pushPullOverhead, 'Über Kopf ↔ Klimmzüge', ('Schultern', 'Über Kopf drücken', pushUp / weeks),
        ('Latissimus', 'Klimmzüge, Latzug', pullUp / weeks), 1, double.infinity));
  }
  return result;
}
