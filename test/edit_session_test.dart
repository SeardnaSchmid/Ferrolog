import 'package:ferrolog/edit_session.dart';
import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/recap.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two halves of the [i]th set tile: reps on top, weight below.
Finder reps(int i) => find.descendant(of: find.byType(SetTile).at(i), matching: find.byType(InkWell)).first;
Finder weight(int i) => find.descendant(of: find.byType(SetTile).at(i), matching: find.byType(InkWell)).last;

void main() {
  testWidgets('edit page round trip: a mistyped set fixed from the recap, the plan follows', (tester) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    unit.value = WeightUnit.kg;
    store = Store(prefs);
    final w = Workout(id: 'a', name: 'A', exercises: [Exercise(name: 'Kniebeuge', weight: 100, sets: 3, reps: 5)]);
    await store.saveWorkout(w);
    final s = Session.start(w);
    s.exercises.single.reps.setAll(0, [5, 5, 3]);
    await store.finishSession(s);
    expect(w.exercises.single.weight, 100);

    await tester.pumpWidget(MaterialApp(home: RecapPage(s)));
    await tester.tap(find.byTooltip('Training bearbeiten'));
    await tester.pumpAndSettle();
    expect(find.byType(EditSessionPage), findsOneWidget);
    expect(find.text('Die Plan-Gewichte werden neu berechnet.'), findsOneWidget);

    // Back without a change: no question.
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.byType(EditSessionPage), findsNothing);
    await tester.tap(find.byTooltip('Training bearbeiten'));
    await tester.pumpAndSettle();

    await tester.tap(reps(2));
    await tester.pumpAndSettle();
    expect(find.text('Satz 3 von 3 · Ziel 5'), findsOneWidget);
    await tester.tap(find.byTooltip('Mehr'));
    await tester.tap(find.byTooltip('Mehr'));
    await tester.pump();
    expect(find.text('5'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern').last);
    await tester.pumpAndSettle();
    expect(store.sessions.single.exercises.single.reps, [5, 5, 3], reason: 'not before Speichern');

    // A change and back: asks before throwing it away.
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.text('Änderungen verwerfen?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(find.byType(EditSessionPage), findsNothing);
    expect(store.sessions.single.exercises.single.reps, [5, 5, 5]);
    expect(w.exercises.single.weight, 102.5);
    expect(find.byType(RecapPage), findsOneWidget);

    // "Nicht gemacht" empties a set; the weight sheet changes this set only by default.
    await tester.tap(find.byTooltip('Training bearbeiten'));
    await tester.pumpAndSettle();
    await tester.tap(weight(0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '95');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern').last);
    await tester.pumpAndSettle();
    await tester.tap(reps(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nicht gemacht'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    final log = store.sessions.single.exercises.single;
    expect(log.weights, [95, 100, 100]);
    expect(log.reps, [5, null, 5]);
    expect(w.exercises.single.weight, 100, reason: 'a set left out holds the weight');
  });
}
