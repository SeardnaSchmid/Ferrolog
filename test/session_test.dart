import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/session.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('weight sheet applies to this set, open sets or all sets', (tester) async {
    SharedPreferences.setMockInitialValues({});
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
}
