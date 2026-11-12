import 'dart:convert';

import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/session.dart';
import 'package:ferrolog/timing.dart';
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

  testWidgets('the rest survives leaving the page and the app being killed, paused too', (tester) async {
    final w = Workout(name: 'Push A', exercises: [Exercise(name: 'Bankdrücken', weight: 60, sets: 3, reps: 5, restSeconds: 120)]);
    await store.saveWorkout(w);
    final s = Session.start(w);
    await store.saveActive(s);
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: SessionPage(s)));
    await tester.tap(find.text('–/5', findRichText: true).first);
    await tester.pump();
    expect(find.text('von 2:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // back to the home screen

    // Reopened 30 s later, after the app was killed: read back from the stored training.
    s.restStartedAt = s.restStartedAt!.subtract(const Duration(seconds: 30));
    await store.saveActive(s);
    final reloaded = (await Store.open()).active!;
    expect((reloaded.restSeconds, reloaded.restPausedAt), (120, null));
    store.active = reloaded; // the page closes when its training isn't the running one
    await tester.pumpWidget(MaterialApp(home: SessionPage(reloaded)));
    expect(find.text('1:30'), findsOneWidget);

    await tester.tap(find.byTooltip('Anhalten'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    final paused = (await Store.open()).active!;
    expect(paused.restPausedAt, isNotNull, reason: 'the pause is saved right away');
    store.active = paused;
    await tester.pumpWidget(MaterialApp(home: SessionPage(paused)));
    expect(find.text('ANGEHALTEN'), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    await store.finishSession(paused);
    expect((paused.restStartedAt, paused.restSeconds, paused.restPausedAt), (null, null, null));
    expect(jsonEncode(paused.toJson()), isNot(contains('rest')), reason: 'never in the history or the export');
  });

  test('rest fields: JSON round trip, omitted when unset', () {
    final w = Workout(name: 'Push A', exercises: [Exercise(name: 'Bankdrücken', weight: 60, sets: 3, reps: 5)]);
    final s = Session.start(w);
    expect(s.toJson().keys.where((k) => k.startsWith('rest')), isEmpty);
    expect(s.restLeft(DateTime.now()), isNull);
    final t = DateTime(2026, 11, 11, 18);
    s
      ..restStartedAt = t
      ..restSeconds = 90
      ..restPausedAt = t.add(const Duration(seconds: 20));
    final back = Session.fromJson(jsonDecode(jsonEncode(s.toJson())));
    expect((back.restStartedAt, back.restSeconds, back.restPausedAt), (t, 90, t.add(const Duration(seconds: 20))));
    expect(back.restLeft(t.add(const Duration(hours: 1))), 70, reason: 'paused: the clock stands');
    expect((back..restPausedAt = null).restLeft(t.add(const Duration(seconds: 100))), -10);
  });

  testWidgets('change the training: swap, add, sets, order; saved each time, the plan stays', (tester) async {
    final w = Workout(name: 'Pull', exercises: [
      Exercise(name: 'Rudern', weight: 50, sets: 3, reps: 8, restSeconds: 120),
      Exercise(name: 'Klimmzüge', weight: 0, sets: 3, reps: 6, restSeconds: 150),
    ]);
    await store.saveWorkout(w);
    final s = Session.start(w);
    await store.saveActive(s);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: SessionPage(s)));
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> menu(int card, String action) async {
      await tester.tap(find.byTooltip('Übung bearbeiten').at(card));
      await settle();
      await tester.tap(find.text(action));
      await settle();
    }

    Future<void> pick(String name) async {
      await tester.enterText(find.byType(TextField).first, name);
      await tester.pump();
      await tester.tap(find.text('Hinzufügen'));
      await settle();
    }

    /// "Bearbeiten" with another name: the editor opens with the exercise as it is.
    Future<void> rename(String name) async {
      await tester.enterText(find.byType(TextField).first, name);
      await tester.pump();
      await tester.tap(find.text('Übernehmen'));
      await settle();
    }

    List<String> names() => [for (final l in store.active!.exercises) '${l.name} ${l.reps.length}'];

    // Machine taken before the first set: swapped in place, with its own rest.
    await menu(0, 'Bearbeiten');
    expect(find.text('Automatische Anpassung · optional'), findsNothing, reason: 'plan only');
    expect(find.textContaining('Nur für dieses Training'), findsOneWidget);
    await rename('Kabelrudern');
    expect(names(), ['Kabelrudern 3', 'Klimmzüge 3']);
    expect(find.text('statt Rudern'), findsOneWidget);
    expect(s.exercises.first.replaces, 'Rudern');
    expect(s.exercises.first.weight, 50, reason: 'from the exercise it replaces');

    // Same name: a set more on the pull-ups; another exercise's name is refused.
    await menu(1, 'Bearbeiten');
    await tester.enterText(find.byType(TextField).first, 'Kabelrudern');
    await tester.pump();
    expect(find.textContaining('Steht schon in diesem Workout'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Klimmzüge');
    await tester.pump();
    await tester.tap(find.text('Satz').last); // dashed "+ Satz"
    await tester.pump();
    await tester.tap(find.text('Übernehmen'));
    await settle();
    expect(names(), ['Kabelrudern 3', 'Klimmzüge 4']);
    expect(s.exercises[1].replaces, isNull);

    // Order: pull-ups first.
    await menu(1, 'Nach oben');
    expect(names(), ['Klimmzüge 4', 'Kabelrudern 3']);

    // Added at the end; the same name again is refused.
    await tester.tap(find.text('Übung'));
    await settle();
    await pick('Facepulls');
    expect(names(), ['Klimmzüge 4', 'Kabelrudern 3', 'Facepulls 3']);
    expect(s.exercises.last.added, isTrue);
    await tester.tap(find.text('Übung'));
    await settle();
    await pick('Facepulls');
    expect(find.text('Schon im Training'), findsOneWidget);
    expect(names(), hasLength(3));

    // One set of pull-ups done, then the rest swapped: the done set stays, the new one follows.
    await tester.tap(find.text('–/6', findRichText: true).first);
    await tester.pump();
    await menu(0, 'Bearbeiten');
    await rename('Latziehen');
    expect(names(), ['Klimmzüge 1', 'Latziehen 3', 'Kabelrudern 3', 'Facepulls 3']);
    expect(s.exercises[0].reps, [6]);
    expect(s.exercises[1].replaces, 'Klimmzüge');

    // An added exercise can go again while nothing is logged; a planned one can't.
    await menu(3, 'Entfernen');
    expect(names(), hasLength(3));
    await tester.tap(find.byTooltip('Übung bearbeiten').at(1));
    await settle();
    expect(find.text('Entfernen'), findsNothing);
    await tester.tapAt(const Offset(10, 10)); // closes the menu
    await settle();

    // All of it survives a restart, and the time estimate still shows.
    expect([for (final l in (await Store.open()).active!.exercises) l.name], ['Klimmzüge', 'Latziehen', 'Kabelrudern']);
    expect(leftLabel(s, currentPace(), DateTime.now()), startsWith('noch ≈'), reason: 'the strip shows the rest now');
    expect((w.exercises.map((e) => '${e.name} ${e.sets}')), ['Rudern 3', 'Klimmzüge 3'], reason: 'the plan is untouched');
    await tester.pumpWidget(const SizedBox());
  });
}
