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
  test('balance: six pairs by sets, helpers and presses half, own guide values; strength as a course', () async {
    Session s(List<ExerciseLog> logs, [int daysAgo = 0]) =>
        Session(workoutId: 'w', workoutName: 'A', exercises: logs, date: DateTime(2026, 11, 8).subtract(Duration(days: daysAgo)));
    ExerciseLog log(String name, double kg, [int sets = 3]) =>
        ExerciseLog(name: name, weight: kg, targetReps: 5, reps: List.filled(sets, 5));
    final sessions = [
      s([log('Bankdrücken', 100), log('Langhantelrudern', 60), log('Kniebeuge', 100), log('Kreuzheben', 120, 1)]),
      s([log('Bankdrücken', 90), log('Kurzhantel-Bankdrücken', 40)]),
    ];
    final b = {for (final x in balances(sessions)) x.pair: x};
    final flat = b[Pair.pushPullFlat]!;
    expect((flat.aValue, flat.bValue, flat.lagging), (9, 3, 'Oberer Rücken'), reason: 'every chest press, rows pull');
    expect((b[Pair.rearDelts]!.aValue, b[Pair.rearDelts]!.bValue, b[Pair.rearDelts]!.lagging), (4.5, 1.5, 'Hintere Schulter'),
        reason: 'presses and rows count half for the delts');
    expect((b[Pair.quadsHamstrings]!.aValue, b[Pair.quadsHamstrings]!.bValue), (3.5, 2.5),
        reason: 'helpers count half: squat and deadlift each help the other side');
    expect(b[Pair.quadsHamstrings]!.lagging, isNull, reason: '71 % is above 60 %');
    expect((b[Pair.rotators]!.aValue, b[Pair.rotators]!.lagging), (4.5, 'Außenrotation'), reason: 'nothing rotates outwards');
    expect((b[Pair.core]!.aValue, b[Pair.core]!.bValue, b[Pair.core]!.lagging), (0, 3.5, 'Bauch'),
        reason: 'lower back: squat and rows help, the deadlift counts half');
    expect(b.containsKey(Pair.pushPullOverhead), isFalse, reason: 'nothing pressed overhead, no pull-ups');

    final overhead = balances([s([log('Schulterdrücken', 50, 5), log('Klimmzüge', 0)])]);
    final o = {for (final x in overhead) x.pair: x};
    expect((o[Pair.pushPullOverhead]!.aValue, o[Pair.pushPullOverhead]!.bValue, o[Pair.pushPullOverhead]!.lagging),
        (5, 3, 'Latissimus'));
    expect(balances([s([log('Bizepscurls', 20)])]), isEmpty, reason: 'nothing to compare');
    expect(sideOf(Pair.rotators, 'Face Pulls'), 1);
    expect(sideOf(Pair.rearDelts, 'Face Pulls'), 1);

    // Own guide values, kept in the settings.
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setBalanceGuide(Pair.pushPullFlat, .3, 1.5);
    expect(balances(sessions).firstWhere((x) => x.pair == Pair.pushPullFlat).lagging, isNull, reason: '33 % within 30–150 %');
    balanceGuides.value = {};
    loadBalanceGuides();
    expect(guideOf(Pair.pushPullFlat), (.3, 1.5));
    await setBalanceGuide(null);
    expect(guideOf(Pair.pushPullFlat), (1, 1.5));

    // Strength: the first four trainings against the latest four.
    final trend = strengthTrends([
      for (var i = 0; i < 4; i++) s([log('Bankdrücken', 100), log('Langhantelrudern', 65)], i * 2),
      for (var i = 0; i < 4; i++) s([log('Bankdrücken', 80), log('Langhantelrudern', 60)], 60 + i * 2),
    ]);
    expect(trend.single.$1, 'Rudern : Bankdrücken');
    expect((trend.single.$2.round(), trend.single.$3.round()), (75, 65));
  });
}
