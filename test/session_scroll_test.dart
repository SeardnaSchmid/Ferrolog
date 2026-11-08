import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/session.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('logging a set at the bottom keeps its exercise in view, the rest timer sits on top', (tester) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
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
    await tester.pump(); // rest line appears
    await tester.pump(); // scroll animation starts
    await tester.pump(const Duration(milliseconds: 400));

    final card = tester.getRect(find.ancestor(of: last, matching: find.byType(Card)));
    final timer = tester.getRect(find.textContaining('Pause 2:00 /', findRichText: true));
    expect(card.bottom, lessThanOrEqualTo(screen), reason: 'the whole card stays in view');
    expect(timer.bottom, lessThan(card.top), reason: 'the timer is in the strip above the list');
    expect(timer.top, lessThan(150), reason: 'right under the app bar, not at the bottom');

    await tester.pumpWidget(const SizedBox());
  });
}
