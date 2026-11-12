import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/session.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The reps half of the [i]th set tile on the page.
Finder reps(int i) => find.descendant(of: find.byType(SetTile).at(i), matching: find.byType(InkWell)).first;

void main() {
  testWidgets('reps in reserve: asked on the card after the last set if switched on, never in the way', (tester) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    unit.value = WeightUnit.kg;
    store = await Store.open();
    final w = Workout(name: 'A', exercises: [
      Exercise(name: 'Bankdrücken', weight: 70, sets: 2, reps: 5),
      Exercise(name: 'Kniebeuge', weight: 100, sets: 2, reps: 5),
      Exercise(name: 'Unterstützte Klimmzüge', weight: -20, sets: 1, reps: 8),
    ]);
    await store.saveWorkout(w);
    final s = Session.start(w);
    await store.saveActive(s);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: SessionPage(s)));
    final bench = s.exercises[0];
    final question = find.text('Wie viele gingen noch?');

    // Off by default.
    await tester.tap(reps(0));
    await tester.tap(reps(1));
    await tester.pump();
    expect(bench.setsDone, 2);
    expect(question, findsNothing);

    // Switched on: not after the first set, after the last one.
    await prefs.setBool('session.askRir', true);
    for (var i = 0; i < 5; i++) {
      await tester.tap(reps(1)); // 5 → … → empty: undone
    }
    await tester.pump();
    expect(bench.setsDone, 1);
    await tester.tap(reps(1));
    await tester.pump();
    expect(question, findsOneWidget);
    expect(find.descendant(of: find.byType(Card).first, matching: question), findsOneWidget, reason: 'on its card');
    expect(find.byTooltip('Anhalten'), findsOneWidget, reason: 'the rest strip stays as it is');
    await tester.tap(find.text('2'));
    await tester.pump();
    expect(bench.rir, 2);
    expect(question, findsNothing);
    expect(find.text('noch 2 übrig'), findsOneWidget);
    expect(store.active!.exercises.first.rir, 2, reason: 'saved with the running training');

    // The last set undone takes the answer along.
    for (var i = 0; i < 5; i++) {
      await tester.tap(reps(1));
    }
    await tester.pump();
    expect(bench.rir, isNull);

    // Not answered yet: it waits through the rest, no hurry.
    await tester.tap(reps(1));
    await tester.pump();
    await tester.pump(const Duration(minutes: 2));
    expect(question, findsOneWidget);
    expect(bench.rir, isNull);

    // A set tapped while it asks: the set is logged, the question goes.
    await tester.tap(reps(2)); // first squat set
    await tester.pump();
    expect((s.exercises[1].setsDone, bench.rir), (1, null));
    expect(question, findsNothing);

    // Not for assistance.
    await tester.tap(reps(4));
    await tester.pump();
    expect(s.exercises[2].setsDone, 1);
    expect(question, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
