import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/session.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('rest timer zones: orange from 30 s before the end to 30 s over, then red', () {
    expect([for (final left in [120, 31, 30, 1, 0, -29, -30, -90]) restZone(left, 120).name],
        ['rest', 'rest', 'soon', 'soon', 'soon', 'soon', 'late', 'late']);
    expect([for (final left in [45, 30, 15]) restZone(left, 60).name], ['rest', 'soon', 'soon']);
    expect([for (final left in [30, 16, 15]) restZone(left, 30).name], ['rest', 'rest', 'soon'], reason: 'short rest: last half');
  });

  test('rep range progress: what the increase takes, what the done sets still miss', () {
    ExerciseLog row(List<int?> reps, {bool timed = false}) =>
        ExerciseLog(name: 'Rudern', weight: 40, targetReps: timed ? 30 : 6, maxReps: timed ? 45 : 8, reps: reps, timed: timed);
    expect(rangeProgress(row([null, null, null])), 'Steigerung bei 3×8');
    expect(rangeProgress(row([6, 8, null])), 'Steigerung bei 3×8 · noch 2 Wdh.');
    expect(rangeProgress(row([8, 8, 8])), '3×8 geschafft · nächstes Mal schwerer');
    expect(rangeProgress(row([45, 40, null], timed: true)), 'Steigerung bei 3×45 s · noch 5 s');
    expect(rangeProgress(ExerciseLog(name: 'Kniebeuge', weight: 100, targetReps: 5, reps: [5])), isNull);
    expect((rangeTop(6), rangeTop(12), rangeTop(30, seconds: true), rangeTop(10, seconds: true)), (9, 15, 45, 15));
  });

  testWidgets('weight sheet applies to this set, open sets or all sets', (tester) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance(); // settings: screen on, rest signal
    unit.value = WeightUnit.kg; // the test locale is en-US, which would default to lb
    store = await Store.open();
    final w = Workout(name: 'Push A', exercises: [Exercise(name: 'Bankdrücken', weight: 60, sets: 3, reps: 5)]);
    await store.saveWorkout(w);
    final s = Session.start(w);
    final log = s.exercises.single;
    log.reps[0] = 5; // first set done, the other two open
    await store.saveActive(s); // the page closes when its training isn't the running one
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: SessionPage(s)));

    // Not pumpAndSettle: the pulsing live dot never settles.
    Future<void> settle() async {
      await tester.pump(); // starts route animations
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> edit(int set, String value, String scope, {bool save = true}) async {
      await tester.tap(find.text('60 kg').at(set)); // weight part of the set tile
      await settle();
      await tester.enterText(find.byType(TextField), value);
      await tester.tap(find.text(scope));
      await tester.pump();
      await tester.tap(find.text(save ? 'Speichern' : 'Schließen'));
      await settle();
    }

    await edit(1, '70', 'Dieser Satz', save: false);
    expect(log.weights, [60, 60, 60], reason: 'Schließen discards');

    await edit(2, '62,5', 'Dieser Satz');
    expect(log.weights, [60, 60, 62.5]);

    await edit(1, '65', 'Offene Sätze');
    expect(log.weights, [60, 65, 65], reason: 'the logged first set keeps its weight');

    await tester.tap(find.text('60 kg'));
    await settle();
    await tester.enterText(find.byType(TextField), '70');
    await tester.tap(find.text('Alle Sätze'));
    await tester.pump();
    await tester.tap(find.text('Speichern'));
    await settle();
    expect(log.weights, [70, 70, 70]);

    await tester.pumpWidget(const SizedBox()); // stops the page's timers
  });

  testWidgets('finishing opens the recap, and it stays open', (tester) async {
    unit.value = WeightUnit.kg; // store: set up by the test above (late final, once per file)
    final w = Workout(name: 'Push A', exercises: [Exercise(name: 'Bankdrücken', weight: 60, sets: 1, reps: 5)]);
    await store.saveWorkout(w);
    final s = Session.start(w)..exercises.single.reps[0] = 5;
    await store.saveActive(s);
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: SessionPage(s)));

    await tester.tap(find.text('Beenden'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1)); // the live page's ticker used to close it
    }
    expect(find.text('Alles geschafft! 💪'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a set logs its time; the page estimates what is left', (tester) async {
    // The store from the tests above; their trainings have no timestamps.
    final w = Workout(name: 'Push A', exercises: [
      Exercise(name: 'Bankdrücken', weight: 60, sets: 3, reps: 5, restSeconds: 120),
      Exercise(name: 'Plank', weight: 0, sets: 3, reps: 30, restSeconds: 60, timed: true),
    ]);
    await store.saveWorkout(w);
    final s = Session.start(w);
    await store.saveActive(s);
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: SessionPage(s)));
    await tester.pump();

    // Bench: 60 s + 3 warm-ups + 3 × 5 × 4.5 s + 2 × 120 s ≈ 9 Min; plank 30 s + 90 s + 120 s = 4 Min.
    expect(find.textContaining('≈ 9 Min'), findsOneWidget);
    expect(find.textContaining('≈ 4 Min'), findsOneWidget);
    expect(find.text('noch ≈ 13 Min'), findsOneWidget);
    expect(find.textContaining('fertig gegen'), findsOneWidget);

    await tester.tap(find.text('–/5', findRichText: true).first);
    await tester.pump();
    expect(s.exercises.first.doneAt.first, isNotNull);
    expect(find.textContaining('Sätze · ≈ 9 Min'), findsOneWidget, reason: 'two sets of bench left plus the plank, beside the rest');
    await tester.tap(find.text('5/5', findRichText: true).first); // fewer reps keep the time
    expect(s.exercises.first.doneAt.first, isNotNull);
  });

  testWidgets('timed set, hands-free: lead-in, then logged by itself at the target; a tap cancels or stops', (tester) async {
    await prefs.setInt('timed.leadIn', 1);
    final w = Workout(name: 'Carry', exercises: [
      Exercise(name: 'Farmers Walk', weight: 24, sets: 2, reps: 1, restSeconds: 90, timed: true),
    ]);
    await store.saveWorkout(w);
    final s = Session.start(w);
    final log = s.exercises.single;
    await store.saveActive(s);
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: SessionPage(s)));
    await tester.pump();
    expect(find.textContaining('2×1 s'), findsOneWidget);
    expect(find.text('24 kg', findRichText: true), findsNWidgets(2), reason: 'weight per set, as usual');

    // A tap starts the lead-in; another one cancels it, nothing logged.
    await tester.tap(find.text('–/1 s', findRichText: true).first);
    await tester.pump();
    expect(find.text('AUFNEHMEN'), findsOneWidget, reason: 'time to pick up the weights');
    expect(log.startedAt, isNotNull, reason: 'kept with the training, survives a restart');
    await tester.tap(find.byTooltip('Abbrechen'));
    await tester.pump();
    expect((log.reps.first, log.startedAt), (null, null));

    // Started again and left alone: go after the lead-in, logged at the target, then the rest.
    await tester.tap(find.text('–/1 s', findRichText: true).first);
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 2100)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect((log.reps.first, log.doneAt.first != null, log.startedAt), (1, true, null));
    expect(find.text('von 1:30'), findsOneWidget);

    // No lead-in and stopped right away: nothing held, nothing logged.
    await prefs.setInt('timed.leadIn', 0);
    await tester.tap(find.text('–/1 s', findRichText: true).first);
    await tester.pump();
    await tester.tap(find.byTooltip('Stopp'));
    await tester.pump();
    expect(log.reps.last, isNull);
    await prefs.remove('timed.leadIn');
  });

  testWidgets('the page shows over the lock screen while open, unless switched off', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('ferrolog/alert'), (call) async {
      if (call.method == 'showWhenLocked') calls.add('${call.arguments['on']}');
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('ferrolog/alert'), null));
    final w = Workout(name: 'Push A', exercises: [Exercise(name: 'Bankdrücken', weight: 60, sets: 3, reps: 5)]);
    await store.saveWorkout(w);
    final s = Session.start(w);
    await store.saveActive(s);

    await tester.pumpWidget(MaterialApp(home: SessionPage(s)));
    expect(calls, ['true']);
    await tester.pumpWidget(const SizedBox()); // leaving the page
    expect(calls, ['true', 'false']);

    await prefs.setBool('session.showWhenLocked', false);
    calls.clear();
    await tester.pumpWidget(MaterialApp(home: SessionPage(s)));
    expect(calls, isEmpty, reason: 'setting off: never switched on');
    await tester.pumpWidget(const SizedBox());
    expect(calls, ['false'], reason: 'switching off is harmless and covers a setting changed mid-training');
    await prefs.remove('session.showWhenLocked');
  });
}
