import 'package:ferrolog/edit.dart';
import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Store.open();
    unit.value = WeightUnit.kg;
  });

  testWidgets('editor suggests in English too and fills catalogue defaults', (tester) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Exercise? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result =
              await Navigator.push<Exercise>(context, MaterialPageRoute(builder: (_) => const ExerciseEditor(null))),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'bench-press');
    await tester.pump();
    await tester.tap(find.text('Bankdrücken'));
    await tester.pump();
    expect(find.text('Standardwerte für Bankdrücken übernommen'), findsOneWidget);

    await tester.tap(find.text('Senkung bei Misserfolg'));
    await tester.pump();
    // First set tile → sheet: one plate step lighter, this set only.
    await tester.tap(find.text('50 kg', findRichText: true).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.remove).last); // the weight stepper
    await tester.tap(find.text('Dieser Satz'));
    await tester.pump();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satz').last); // dashed "+ Satz": copies the last set
    await tester.pump();
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();

    expect(result?.name, 'Bankdrücken');
    expect((result?.sets, result?.reps, result?.setReps), (4, 5, null));
    expect(result?.decrement, 2.5);
    expect(result?.setWeights, [47.5, 50, 50, 50], reason: 'catalogue weight 50 kg, first set −2,5, one set added');
    expect(result?.weight, 50);
    expect(result?.restSeconds, 180, reason: 'catalogue rest');
  });

  test('search matches German and English, ignoring case, dashes and umlauts', () {
    final names = exerciseCatalogue.keys;
    expect(searchExercises('bench press', names).first, 'Bankdrücken');
    expect(searchExercises('Bench-Press', names).first, 'Bankdrücken');
    expect(searchExercises('bankdruecken', names).first, 'Bankdrücken');
    expect(searchExercises('squat', names).first, 'Kniebeuge');
    expect(searchExercises('ohp', names), ['Schulterdrücken']);
    expect(searchExercises('', names), isEmpty);
    expect(searchExercises('treadmill', cardioCatalogue.keys), ['Laufband']);
    expect(searchExercises('rowing', cardioCatalogue.keys), ['Ergometer-Rudern']);
  });

  test('progression: up on success, down after N misses in a row', () {
    final e = Exercise(name: 'Kniebeuge', weight: 100, sets: 3, reps: 5, increment: 2.5, decrement: 10, down: true, failsToDeload: 2);
    ExerciseLog log(List<int?> reps) => ExerciseLog(name: 'Kniebeuge', weight: e.weight, targetReps: 5, reps: reps);
    e.applyResult(log([5, 5, 5]));
    expect(e.weight, 102.5);
    e.applyResult(log([5, 4, 3]));
    expect((e.weight, e.fails), (102.5, 1));
    e.applyResult(log([5, 3, 3]));
    expect((e.weight, e.fails), (92.5, 0), reason: 'second miss in a row deloads');

    final backOff = Exercise(name: 'Bankdrücken', sets: 3, reps: 5, setWeights: [80, 80, 70]);
    backOff.applyResult(ExerciseLog(name: 'Bankdrücken', weight: 0, targetReps: 5, reps: [5, 5, 5], weights: [80, 80, 70]));
    expect(backOff.setWeights, [82.5, 82.5, 72.5]);
    expect(backOff.weight, 82.5);
  });

  testWidgets('new workout: program chips show the day right away, switching days swaps the list', (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: EditWorkout(Workout(name: ''))));

    await tester.tap(find.text('Starting Strength'));
    await tester.pump();
    expect(find.text('Bankdrücken'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Starting Strength A'), findsOneWidget, reason: 'empty name gets filled');

    await tester.tap(find.text('B'));
    await tester.pump();
    expect(find.text('Bankdrücken'), findsNothing);
    expect(find.text('Schulterdrücken'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Starting Strength B'), findsOneWidget, reason: 'auto name follows the day');

    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    final saved = store.workouts.last;
    expect(saved.name, 'Starting Strength B');
    expect(saved.exercises.map((e) => '${e.name} ${e.sets}×${e.reps}'),
        ['Kniebeuge 3×5', 'Schulterdrücken 3×5', 'Kreuzheben 1×5']);
  });

  test('catalogue defaults start on round plates in lb', () {
    unit.value = WeightUnit.lb;
    addTearDown(() => unit.value = WeightUnit.kg);
    final e = knownExercise('Bankdrücken'); // 50 kg, +2,5 kg
    expect((weightNum(e.weight), weightNum(e.increment)), ('110', '5'));
  });

  testWidgets('timed exercises: seconds with or without weight', (tester) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Exercise? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result =
              await Navigator.push<Exercise>(context, MaterialPageRoute(builder: (_) => const ExerciseEditor(null))),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'farmer');
    await tester.pump();
    await tester.tap(find.text('Farmers Walk'));
    await tester.pump();
    expect(find.text('30 s', findRichText: true), findsNWidgets(3), reason: 'catalogue: 3 × 30 s');
    expect(find.text('Wiederholungs-Spanne'), findsNothing);

    // Seconds in steps of 5 for every set.
    await tester.tap(find.text('30 s', findRichText: true).first);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.widgetWithText(BigStepper, 'Sekunden'), matching: find.byIcon(Icons.add)));
    await tester.tap(find.text('Alle Sätze'));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();
    expect((result?.timed, result?.reps, result?.weight), (true, 35, 24.0));

    // Switching back to reps.
    final e = result!..timed = false;
    expect(Exercise.fromJson(e.toJson()).timed, isFalse);
  });
}

