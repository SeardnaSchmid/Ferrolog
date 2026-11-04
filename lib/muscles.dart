import 'main.dart';
import 'model.dart';
import 'muscle_data.dart';

/// Coarse body regions, for summaries like "Rücken kam zu kurz".
enum MuscleGroup {
  chest('Brust'),
  shoulders('Schultern'),
  arms('Arme'),
  back('Rücken'),
  core('Rumpf'),
  legs('Beine');

  const MuscleGroup(this.label);
  final String label;
}

/// The muscles an exercise is tagged with (the free-exercise-db set). The order is the bit order of
/// [Muscles] and of tool/exercise_muscles.py; append only.
enum Muscle {
  chest('Brust', MuscleGroup.chest),
  shoulders('Schultern', MuscleGroup.shoulders),
  triceps('Trizeps', MuscleGroup.arms),
  biceps('Bizeps', MuscleGroup.arms),
  forearms('Unterarme', MuscleGroup.arms),
  lats('Latissimus', MuscleGroup.back),
  middleBack('Mittlerer Rücken', MuscleGroup.back),
  lowerBack('Unterer Rücken', MuscleGroup.back),
  traps('Trapez', MuscleGroup.back),
  neck('Nacken', MuscleGroup.back),
  abdominals('Bauch', MuscleGroup.core),
  quadriceps('Quadrizeps', MuscleGroup.legs),
  hamstrings('Beinbeuger', MuscleGroup.legs),
  glutes('Gesäß', MuscleGroup.legs),
  calves('Waden', MuscleGroup.legs),
  adductors('Adduktoren', MuscleGroup.legs),
  abductors('Abduktoren', MuscleGroup.legs);

  const Muscle(this.label, this.group);
  final String label;
  final MuscleGroup group;
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
    ('Hip Thrust', [Muscle.glutes], [Muscle.hamstrings]),
    ('Wadenheben', [Muscle.calves], <Muscle>[]),
    ('Bizepscurls', [Muscle.biceps], [Muscle.forearms]),
    ('Hammercurls', [Muscle.biceps, Muscle.forearms], <Muscle>[]),
    ('Trizepsdrücken am Kabel', [Muscle.triceps], <Muscle>[]),
    ('French Press', [Muscle.triceps], <Muscle>[]),
    ('Seitheben', [Muscle.shoulders], [Muscle.traps]),
    ('Face Pulls', [Muscle.shoulders], [Muscle.traps, Muscle.middleBack]),
    ('Butterfly', [Muscle.chest], [Muscle.shoulders]),
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

/// Done sets per region: a set counts 1 for a region with a primary muscle, else ½ for one with a
/// secondary muscle. Cardio and exercises of unknown muscles don't count.
Map<MuscleGroup, double> setsPerMuscle(Iterable<Session> sessions) {
  final sets = {for (final g in MuscleGroup.values) g: 0.0};
  for (final s in sessions) {
    for (final e in s.exercises) {
      if (e.cardio || e.setsDone == 0) continue;
      final (p, sec) = musclesOf(e.name) ?? (0, 0);
      final primary = {for (final m in musclesIn(p)) m.group};
      for (final g in primary) {
        sets[g] = sets[g]! + e.setsDone;
      }
      for (final g in {for (final m in musclesIn(sec)) m.group}.difference(primary)) {
        sets[g] = sets[g]! + e.setsDone / 2;
      }
    }
  }
  return sets;
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
