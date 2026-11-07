import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/session.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('logging a set at the bottom keeps its exercise above the rest timer', (tester) async {
    SharedPreferences.setMockInitialValues({});
    unit.value = WeightUnit.kg;
    store = await Store.open();
    final w = Workout(name: 'Lang', exercises: [
      for (final name in ['Kniebeuge', 'Bankdrücken', 'Rudern', 'Schulterdrücken', 'Kreuzheben'])
        Exercise(name: name, weight: 60, sets: 3, reps: 5),
    ]);
    await store.saveWorkout(w);
    final s = Session.start(w);
    await store.saveActive(s);
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: SessionPage(s)));
    await tester.pump();

    final last = find.text('Kreuzheben');
    await tester.scrollUntilVisible(last, 200);
    final screen = tester.view.physicalSize.height;
    // The last card's first set, close to the bottom edge.
    final tile = find.descendant(of: find.ancestor(of: last, matching: find.byType(Card)), matching: find.text('–/5', findRichText: true)).first;
    expect(tester.getRect(tile).bottom, greaterThan(screen - 200), reason: 'starts near the bottom');
    await tester.tap(tile);
    await tester.pump(); // rest timer appears
    await tester.pump(); // scroll animation starts
    await tester.pump(const Duration(milliseconds: 400));

    final card = tester.getRect(find.ancestor(of: last, matching: find.byType(Card)));
    final timer = tester.getRect(find.text('PAUSE · 2:00').first);
    expect(card.bottom, lessThanOrEqualTo(timer.top - 20), reason: 'the whole card stays above the timer');

    await tester.pumpWidget(const SizedBox());
  });
}
