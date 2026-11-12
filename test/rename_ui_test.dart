import 'package:ferrolog/edit.dart';
import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/stats.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Session _training(String name, int day) => Session(workoutId: 'a', workoutName: 'A', date: DateTime(2026, 11, day), exercises: [
      ExerciseLog(name: name, weight: 60, targetReps: 5, reps: [5, 5, 5]),
    ]);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = Store(prefs);
    unit.value = WeightUnit.kg;
  });

  testWidgets('renaming in the workout editor: no doubles, the history comes along', (tester) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    store.workouts = [Workout(id: 'a', name: 'A', exercises: [Exercise(name: 'Bankdrücken'), Exercise(name: 'Kniebeuge')])];
    store.sessions = [_training('Bankdrücken', 4), _training('Bankdrücken', 2)];

    await tester.pumpWidget(MaterialApp(home: EditWorkout(store.workouts.single.copy())));
    await tester.tap(find.text('Bankdrücken'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'kniebeuge');
    await tester.pump();
    expect(find.textContaining('Steht schon in diesem Workout'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Speichern')).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Bankdrücken (Pause)');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Verlauf von „Bankdrücken“ auf „Bankdrücken (Pause)“ übertragen?'), findsOneWidget);
    await tester.tap(find.text('Übertragen'));
    await tester.pumpAndSettle();
    expect(store.historyOf('Bankdrücken'), hasLength(2), reason: 'only on saving the workout');

    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(store.historyOf('Bankdrücken'), isEmpty);
    expect(store.historyOf('Bankdrücken (Pause)'), hasLength(2));
    expect(store.workouts.single.exercises.map((e) => e.name), ['Bankdrücken (Pause)', 'Kniebeuge']);
  });

  testWidgets('"Neue Übung" leaves the history where it was', (tester) async {
    store.workouts = [Workout(id: 'a', name: 'A', exercises: [Exercise(name: 'Curls')])];
    store.sessions = [_training('Curls', 2)];
    await tester.pumpWidget(MaterialApp(home: EditWorkout(store.workouts.single.copy())));
    await tester.tap(find.text('Curls'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Hammercurls');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neue Übung'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(store.historyOf('Curls'), hasLength(1));
    expect(store.workouts.single.exercises.single.name, 'Hammercurls');
  });

  testWidgets('merge from the exercise statistics', (tester) async {
    store.workouts = [Workout(id: 'a', name: 'A', exercises: [Exercise(name: 'Rudern')])];
    store.sessions = [_training('Rudern', 6), _training('Langhantelrudern', 2)];
    await tester.pumpWidget(const MaterialApp(home: ExerciseStats('Rudern')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mehr'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mit anderer Übung zusammenführen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SimpleDialogOption, 'Langhantelrudern'));
    await tester.pumpAndSettle();
    expect(find.textContaining('lässt sich nicht rückgängig machen'), findsOneWidget);
    await tester.tap(find.text('Ja'));
    await tester.pumpAndSettle();
    expect(store.historyOf('Langhantelrudern').map((h) => h.$1.day), [2, 6]);
    expect(store.workouts.single.exercises.single.name, 'Langhantelrudern');
    expect(find.widgetWithText(AppBar, 'Langhantelrudern'), findsOneWidget);
  });
}
