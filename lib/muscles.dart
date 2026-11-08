import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

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

/// The pairs [balances] checks, all by done sets per week: side [a] against side [b], balanced while
/// b / a lies within [low]–[high] (guide values from training practice, not medical limits; the user
/// can change them, see [guideOf]). [aLabel] and [bLabel] name what's counted, [note] what counts half.
enum Pair {
  pushPullFlat('Brust', 'Oberer Rücken', 'Drücken', 'Rudern', 1, 1.5),
  pushPullOverhead('Schultern', 'Latissimus', 'Über Kopf drücken', 'Klimmzüge, Latzug', 1, double.infinity),
  rearDelts(
    'Vordere Schulter',
    'Hintere Schulter',
    'Vordere Schulter',
    'hintere Schulter',
    .5,
    double.infinity,
    note: 'Drückübungen zählen halb',
  ),
  quadsHamstrings('Quadrizeps', 'Hintere Oberschenkel', 'Quadrizeps', 'hintere Oberschenkel', .6, double.infinity),
  rotators(
    'Innenrotation',
    'Außenrotation',
    'Innenrotation',
    'Außenrotation',
    .5,
    double.infinity,
    note: 'Drückübungen zählen halb',
  ),
  core('Bauch', 'Unterer Rücken', 'Bauch', 'unterer Rücken', .75, 1.35, note: 'Kreuzheben und Kniebeuge zählen halb');

  const Pair(this.a, this.b, this.aLabel, this.bLabel, this.low, this.high, {this.note});
  final String a, b, aLabel, bLabel;
  final double low, high;
  final String? note;
}

/// The user's own guide values, by pair; the rest keep [Pair.low] and [Pair.high]. Loaded at start.
final balanceGuides = ValueNotifier<Map<Pair, (double, double)>>({});

(double, double) guideOf(Pair p) => balanceGuides.value[p] ?? (p.low, p.high);

void loadBalanceGuides() {
  final raw = prefs.getString('balance.guides');
  if (raw == null) return;
  final map = jsonDecode(raw) as Map<String, dynamic>;
  balanceGuides.value = {
    for (final MapEntry(:key, :value) in map.entries)
      ?Pair.values.asNameMap()[key]: (
        (value[0] as num).toDouble(),
        value[1] == null ? double.infinity : (value[1] as num).toDouble(),
      ),
  };
}

/// Stores [p]'s guide values; the defaults again remove the own ones. Null: all back to the defaults.
Future<void> setBalanceGuide(Pair? p, [double? low, double? high]) {
  final next = {...balanceGuides.value};
  if (p == null) {
    next.clear();
  } else if (low == p.low && high == p.high) {
    next.remove(p);
  } else {
    next[p] = (low!, high!);
  }
  balanceGuides.value = next;
  return prefs.setString(
    'balance.guides',
    jsonEncode({
      for (final MapEntry(:key, :value) in next.entries) key.name: [value.$1, value.$2.isFinite ? value.$2 : null],
    }),
  );
}

/// One pair over a stretch of time: sets per week on each side against the guide values.
class Balance {
  final Pair pair;
  final double aValue, bValue, low, high;
  Balance(this.pair, this.aValue, this.bValue) : low = guideOf(pair).$1, high = guideOf(pair).$2;

  String get title => '${pair.a} ↔ ${pair.b}';
  String get aGroup => pair.a;
  String get bGroup => pair.b;
  String get a => pair.aLabel;
  String get b => pair.bLabel;

  double get ratio => aValue == 0 ? double.infinity : bValue / aValue;

  /// The muscle group that falls behind, or null when balanced.
  String? get lagging => ratio < low
      ? bGroup
      : ratio > high
      ? aGroup
      : null;
}

// Lifts compared by strength, matched on the name; dumbbells (weight per hand), split and front squats,
// inclines, declines and machines don't compare.
bool _press(String k) => (k.contains('bankdrueck') || k.contains('benchpress')) && !_odd(k);
bool _row(String k) =>
    (k.contains('rudern') || k.endsWith('row')) && !_odd(k) && !k.contains('aufrecht') && !k.contains('upright');
bool _squat(String k) => (k.contains('kniebeuge') || k.contains('squat')) && !_odd(k);
bool _hinge(String k) =>
    (k.contains('kreuzheb') || k.contains('deadlift')) && !k.contains('rumaen') && !k.contains('romanian');
bool _odd(String k) => const [
  'kurzhantel',
  'dumbbell',
  'schraeg',
  'incline',
  'split',
  'bulgarian',
  'front',
  'goblet',
  'negativ',
  'decline',
  'hack',
  'maschine',
  'machine',
  'kabel',
  'cable',
  'tbar',
].any(k.contains);

// Rear delts and external rotation have no muscle of their own in the data, so by name.
bool _rearDelt(String k) => const [
  'facepull',
  'reversebutterfly',
  'reversefly',
  'reardelt',
  'hintereschulter',
  'vorgebeugtesseitheb',
].any(k.contains);
bool _externalRotation(String k) =>
    const ['facepull', 'aussenrot', 'externalrot', 'cubanpress', 'rotatorenmanschette'].any(k.contains);

/// How much one set of [name] counts on each side of [pair], as (side a, side b). Pressing: chest
/// (flat), or shoulders with the triceps helping (overhead); both work the front delts and rotate
/// inwards, there they count half. Pulling: rows train the middle back (flat, rear delts half),
/// pull-ups and pulldowns the lats (from above). Legs and core by the muscles, helpers half; lower
/// back in compound lifts (deadlift, squat) half too.
(double, double) shareOf(Pair pair, String name) {
  final (p, sec) = musclesOf(name) ?? (0, 0);
  bool has(int bits, Muscle m) => bits & m.bit != 0;
  double muscle(Muscle m) => has(p, m)
      ? 1
      : has(sec, m)
      ? .5
      : 0;
  final k = searchKey(name);
  final pulls = has(p, Muscle.middleBack) || has(p, Muscle.lats);
  final flat = !pulls && has(p, Muscle.chest);
  final overhead = !pulls && !flat && has(p, Muscle.shoulders) && has(sec, Muscle.triceps);
  return switch (pair) {
    Pair.pushPullFlat => (flat ? 1 : 0, has(p, Muscle.middleBack) ? 1 : 0),
    Pair.pushPullOverhead => (overhead ? 1 : 0, !has(p, Muscle.middleBack) && has(p, Muscle.lats) ? 1 : 0),
    Pair.rearDelts => (
      overhead || k.contains('frontheb') || k.contains('frontraise')
          ? 1
          : flat && has(sec, Muscle.shoulders)
          ? .5
          : 0,
      _rearDelt(k)
          ? 1
          : has(p, Muscle.middleBack)
          ? .5
          : 0,
    ),
    Pair.quadsHamstrings => (muscle(Muscle.quadriceps), muscle(Muscle.hamstrings)),
    Pair.rotators => (flat || overhead ? .5 : 0, _externalRotation(k) ? 1 : 0),
    Pair.core => (
      muscle(Muscle.abdominals),
      has(p, Muscle.lowerBack)
          ? (has(p, Muscle.hamstrings) || has(p, Muscle.glutes) || has(p, Muscle.quadriceps) || has(p, Muscle.traps)
                ? .5
                : 1)
          : has(sec, Muscle.lowerBack)
          ? .5
          : 0,
    ),
  };
}

/// Which side of [pair] an exercise mainly trains: 0 for side a, 1 for side b, null for neither.
int? sideOf(Pair pair, String name) {
  final (a, b) = shareOf(pair, name);
  return a > b
      ? 0
      : b > a
      ? 1
      : null;
}

/// How long the balance looks back: four weeks, the same on the card and in the findings.
const balanceDays = 28;

/// The pairs from [sessions] (newest first) over [weeks]; a pair shows once either side was trained
/// (nothing on one side is the clearest imbalance).
List<Balance> balances(List<Session> sessions, {double weeks = 1}) {
  final sums = {
    for (final p in Pair.values) p: [0.0, 0.0],
  };
  for (final s in sessions) {
    for (final e in s.exercises) {
      if (e.cardio || e.setsDone == 0) continue;
      for (final p in Pair.values) {
        final (a, b) = shareOf(p, e.name);
        sums[p]![0] += e.setsDone * a;
        sums[p]![1] += e.setsDone * b;
      }
    }
  }
  return [
    for (final MapEntry(key: p, value: v) in sums.entries)
      if (v[0] > 0 || v[1] > 0) Balance(p, v[0] / weeks, v[1] / weeks),
  ];
}

/// The two strength ratios of the barbell lifts over [sessions] (newest first, e.g. 90 days), as
/// (name, at the start, now) in percent: rows to bench press, deadlift to squat. Each lift's level is
/// its best 1RM of four trainings, the first four for the start, the latest four for now; the
/// strongest lift of a family counts. Shown as a course, not against values from the literature.
List<(String, double, double)> strengthTrends(List<Session> sessions) {
  double? level(Iterable<Session> ordered, bool Function(String) family) {
    final four = <String, List<double>>{};
    for (final s in ordered) {
      for (final e in s.exercises) {
        if (e.cardio || e.weight == 0 || e.setsDone == 0 || !family(searchKey(e.name))) continue;
        final list = four.putIfAbsent(e.name, () => []);
        if (list.length < 4) list.add(estimated1rm(e));
      }
    }
    return four.isEmpty ? null : four.values.map((v) => v.reduce(max)).reduce(max);
  }

  final result = <(String, double, double)>[];
  for (final (name, b, a) in [('Rudern : Bankdrücken', _row, _press), ('Kreuzheben : Kniebeuge', _hinge, _squat)]) {
    final (a0, b0, a1, b1) = (
      level(sessions.reversed, a),
      level(sessions.reversed, b),
      level(sessions, a),
      level(sessions, b),
    );
    if (a0 == null || b0 == null || a1 == null || b1 == null) continue;
    result.add((name, b0 / a0 * 100, b1 / a1 * 100));
  }
  return result;
}
