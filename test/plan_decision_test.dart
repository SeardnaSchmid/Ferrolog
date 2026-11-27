import 'dart:convert';

import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/recap.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Workout w;
  late Store st; // the app's [store] and [prefs] are final: set once, for the recap

  Future<void> open(List<Exercise> exercises) async {
    SharedPreferences.setMockInitialValues({});
    unit.value = WeightUnit.kg;
    st = Store(await SharedPreferences.getInstance());
    w = Workout(id: 'a', name: 'A', exercises: exercises);
    await st.saveWorkout(w);
  }

  /// A training on [day]: [reps] per exercise at the planned weights, [rir] after the last set.
  Future<Session> train(int day, List<List<int?>> reps, {List<int?>? rir, List<String> tags = const []}) async {
    final s = st.startSession(w, DateTime(2026, 11, day, 18))
      ..date = DateTime(2026, 11, day, 18)
      ..tags = tags;
    for (final (i, r) in reps.indexed) {
      s.exercises[i].reps.setAll(0, r);
      s.exercises[i].rir = rir?[i];
    }
    await st.finishSession(s, at: DateTime(2026, 11, day, 19));
    return s;
  }

  test('records the plan before, the step and its source, the outcome and the plan after', () async {
    await open([
      // The user's case: a 10 kg step on the exercise, 2,5 kg increments in the fixed mode.
      Exercise(name: 'Kniebeuge', weight: 130, sets: 3, reps: 5, loadStep: 10),
      Exercise(name: 'Bankdrücken', weight: 80, sets: 3, reps: 5),
      Exercise(name: 'Laufen', weight: 0, sets: 1, reps: 20, cardio: true),
    ]);
    final s = await train(24, [[5, 5, 5], [5, 5, 4], [20]]);
    final squat = s.exercises[0].decision!;
    expect((squat.before.weight, squat.before.sets, squat.before.reps), (130.0, 3, 5));
    expect((squat.step, squat.stepSource), (10.0, LoadSource.set));
    expect(squat.outcome, Progression.stepTooLarge, reason: '2,5 kg does not fit a 10 kg step');
    expect(squat.after.weight, 130.0);
    expect(s.exercises[0].progression, isNull, reason: 'progression stays the auto mode\'s');

    final bench = s.exercises[1].decision!;
    expect((bench.step, bench.stepSource), (2.5, LoadSource.guess));
    expect((bench.outcome, bench.after.weight, bench.after.fails), (Progression.miss, 80.0, 1));
    expect(s.exercises[2].decision, isNull, reason: 'cardio stays as planned');

    // Edited by hand later: the record still says what was decided then.
    w.exercises[0].weight = 132.5;
    await st.saveWorkout(w);
    final exported = jsonDecode(st.exportJson())['sessions'].first['exercises'][0]['decision'];
    expect(exported['before']['weight'], 130.0);
    expect(exported['after']['weight'], 130.0);
    expect((exported['loadStep'], exported['loadStepSource'], exported['outcome']), (10.0, 'set', 'stepTooLarge'));
    final reopened = Store(await SharedPreferences.getInstance()).sessions.first.exercises[0].decision!;
    expect(jsonEncode(reopened.toJson()), jsonEncode(squat.toJson()), reason: 'stored');
  });

  test('auto mode: held without a reserve, a rep added at the same weight, per-set targets kept', () async {
    await open([
      Exercise(name: 'Kniebeuge', weight: 100, sets: 3, reps: 5, auto: true),
      Exercise(name: 'Curls', weight: 10, sets: 3, reps: 6, auto: true, loadStep: 2.5),
      Exercise(name: 'Rudern', weight: 70, sets: 3, reps: 5, setWeights: [70, 70, 60], setReps: [5, 5, 8], auto: true),
    ]);
    final s = await train(24, [[5, 5, 5], [6, 6, 6], [5, 5, 8]], rir: [null, 2, 3]);
    final squat = s.exercises[0].decision!;
    expect((squat.outcome, squat.before.weight, squat.after.weight), (Progression.reserveNeeded, 100.0, 100.0));

    final curls = s.exercises[1].decision!;
    expect(curls.outcome, Progression.bridge);
    expect((curls.before.reps, curls.after.reps, curls.after.weight, curls.after.bridgeFrom), (6, 7, 10.0, 6));
    expect(progressionLabel(curls.outcome!, null, curls.after), 'Wiederholungsbrücke: Ziel 7, ursprünglich 6 Wdh.');

    final row = s.exercises[2].decision!;
    expect(row.before.setWeights, [70.0, 70.0, 60.0]);
    expect(row.before.setReps, [5, 5, 8]);
    expect(row.after.setWeights, w.exercises[2].setWeights);
    expect(row.after.setReps, w.exercises[2].setReps);
  });

  test('editing, replanning and deleting keep the record in step with the plan', () async {
    await open([Exercise(name: 'Kniebeuge', weight: 100, sets: 3, reps: 5, auto: true)]);
    final older = await train(20, [[5, 5, 5]], rir: [3]);
    expect((older.exercises[0].decision!.outcome, older.exercises[0].decision!.after.weight), (Progression.up, 102.5));
    final s = await train(24, [[5, 5, 5]], rir: [3]);
    expect(s.exercises[0].decision!.after.weight, 105.0);

    // Corrected to a miss: progression and record redone from the plan before.
    final edited = s.copy();
    edited.exercises[0].reps.setAll(0, [5, 5, 3]);
    await st.replaceSession(edited);
    final redone = st.sessions.first.exercises[0].decision!;
    expect((redone.before.weight, redone.outcome, redone.after.weight), (102.5, Progression.miss, 102.5));
    expect(older.exercises[0].decision!.after.weight, 102.5, reason: 'an older training keeps its record');

    // Pain tagged on the recap: the auto mode looks again.
    final latest = st.sessions.first..tags = [painTag];
    await st.updateSession(latest, replan: true);
    expect((latest.exercises[0].decision!.outcome, latest.exercises[0].decision!.after.fails), (Progression.pain, 0));

    await st.deleteSession(latest);
    expect(w.exercises[0].weight, 102.5);
    expect(st.sessions.single.exercises[0].decision!.after.weight, w.exercises[0].weight,
        reason: 'back to what the remaining newest training decided');
  });

  testWidgets('recap: next time line from the record, the step when opened', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open([Exercise(name: 'Kniebeuge', weight: 80, sets: 3, reps: 5, auto: true, loadStep: 2.5)]);
    store = st;
    prefs = await SharedPreferences.getInstance();
    final s = await train(24, [[5, 5, 5]]);
    // The plan edited later and an older training: the line still shows what was decided.
    w.exercises[0].weight = 90;
    await train(26, [[5, 5, 5]], rir: [2]);
    await tester.pumpWidget(MaterialApp(home: RecapPage(s)));
    expect(find.textContaining(RegExp(r'3×5\s+mit\s+80\s+kg'), findRichText: true), findsOneWidget);
    expect(find.textContaining('Wiederholungsreserve fehlt', findRichText: true), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(find.textContaining('Schritt:'), findsNothing);
    await tester.tap(find.textContaining('Nächstes Mal:', findRichText: true));
    await tester.pump();
    expect(find.text('Vorher: 3×5 mit 80 kg'), findsOneWidget);
    expect(find.text('Schritt: 2,5 kg · in der Übung festgelegt'), findsOneWidget);
  });
}
