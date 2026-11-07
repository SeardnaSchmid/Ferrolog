import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/muscles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('catalogue: every exercise has defaults and muscles, every name finds just one', () {
    expect(exerciseCatalogue.length, greaterThan(90));
    final seen = <String, String>{};
    for (final name in [...exerciseCatalogue.keys, ...cardioCatalogue.keys]) {
      if (exerciseCatalogue.containsKey(name)) expect(defaultMuscles(name), isNotNull, reason: name);
      for (final n in [name, ...?exerciseAliases[name]]) {
        expect(seen[searchKey(n)] ?? name, name, reason: '$n: $name and ${seen[searchKey(n)]}');
        seen[searchKey(n)] = name;
      }
    }
    expect(searchExercises('farmer', exerciseCatalogue.keys), ['Farmers Walk']);
    expect(defaultMuscles("Farmer's Walk")!.$1, Muscle.forearms.bit | Muscle.traps.bit);
  });

  test('muscles: own choice, catalogue, databases, word parts; secondary counts half', () async {
    SharedPreferences.setMockInitialValues({});
    store = await Store.open();
    expect(musclesOf('Kreuzheben')!.$1, Muscle.lowerBack.bit | Muscle.hamstrings.bit | Muscle.glutes.bit,
        reason: 'catalogue');
    expect(musclesOf('deadlift'), musclesOf('Kreuzheben'), reason: 'catalogue alias');
    expect(musclesIn(musclesOf('Frontkniebeuge')!.$1), contains(Muscle.quadriceps), reason: 'from the databases');
    expect(musclesOf('Barbell Shrug')!.$1 & Muscle.traps.bit, isNonZero, reason: 'free-exercise-db name');
    expect(musclesOf('Meine Spezial-Curls'), (Muscle.biceps.bit, 0), reason: 'word part');
    expect(musclesOf('Meditation'), isNull);

    final dips = (Muscle.chest.bit, Muscle.triceps.bit);
    await setMuscles('Dips', dips);
    expect(musclesOf('dips'), dips);
    final reopened = await Store.open();
    expect(reopened.muscles['Dips'], {'primary': ['chest'], 'secondary': ['triceps']}, reason: 'in the training data');
    await setMuscles('Dips', defaultMuscles('Dips')!); // back to the default: nothing stored
    expect(store.muscles, isEmpty);

    final s = Session(workoutId: 'w', workoutName: 'A', exercises: [
      ExerciseLog(name: 'Bankdrücken', weight: 60, targetReps: 5, reps: [5, 5, null]), // 2 sets
      ExerciseLog(name: 'Laufen', weight: 0, targetReps: 30, reps: [30], cardio: true),
    ]);
    final sets = setsPerSingleMuscle([s]);
    expect(sets[Muscle.chest], 2);
    expect(sets[Muscle.triceps], 1, reason: 'secondary: half');
    expect(sets[Muscle.quadriceps], 0, reason: 'cardio does not count');
    expect(exercisesFor(Muscle.triceps, [s]), [('Bankdrücken', 1.0)]);
  });

  // Uses the store from the test above (it can only be set once), with no own muscle choices left.
  test('balance: strength pairs from barbell lifts, pairs by sets from any exercise', () {
    Session s(List<ExerciseLog> logs) => Session(workoutId: 'w', workoutName: 'A', exercises: logs);
    ExerciseLog log(String name, double kg, [int sets = 3]) =>
        ExerciseLog(name: name, weight: kg, targetReps: 5, reps: List.filled(sets, 5));
    final sessions = [
      s([log('Bankdrücken', 100), log('Langhantelrudern', 60), log('Kniebeuge', 100), log('Kreuzheben', 120, 1)]),
      s([log('Bankdrücken', 90), log('Kurzhantel-Bankdrücken', 40)]), // dumbbells per hand: sets only
    ];
    final b = {for (final x in balances(sessions)) x.pair: x};
    final chest = b[Pair.chestBack]!;
    expect((chest.a, chest.b, chest.strength), ('Bankdrücken', 'Langhantelrudern', true));
    expect(chest.ratio, closeTo(.6, .001));
    expect(chest.lagging, 'Oberer Rücken', reason: '60 % is below 75 %');
    expect(b[Pair.squatHinge]!.lagging, isNull, reason: 'deadlift 120 % of the squat');
    expect((b[Pair.quadsHamstrings]!.aValue, b[Pair.quadsHamstrings]!.bValue), (3.5, 2.5),
        reason: 'helpers count half: squat and deadlift each help the other side');
    expect(b[Pair.quadsHamstrings]!.lagging, isNull, reason: '71 % is above 60 %');
    final flat = b[Pair.pushPullFlat]!;
    expect((flat.aValue, flat.bValue, flat.lagging), (9, 3, 'Oberer Rücken'), reason: 'every bench set, rows pull');
    expect(b.containsKey(Pair.pushPullOverhead), isFalse, reason: 'nothing pressed overhead');

    final overhead = balances([s([log('Schulterdrücken', 50, 5), log('Klimmzüge', 0)])]);
    expect([for (final x in overhead) (x.pair, x.aValue, x.bValue, x.lagging)],
        [(Pair.pushPullOverhead, 5, 3, 'Latissimus')]);
    expect(balances([s([log('Bizepscurls', 20)])]), isEmpty, reason: 'nothing to compare');
  });
}
