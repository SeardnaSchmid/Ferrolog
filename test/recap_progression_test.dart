import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/recap.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('recap compares the next plan with the plan before training', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    unit.value = WeightUnit.kg;
    store = Store(prefs);
    final w = Workout(id: 'recap', name: 'A', exercises: [
      Exercise(name: 'Squat', weight: 100, sets: 3, reps: 5, auto: true),
      Exercise(name: 'Pull-up', weight: -10, sets: 3, reps: 5, auto: true),
      Exercise(name: 'Face pull', weight: 10, sets: 3, reps: 12, auto: true, fails: 2),
    ]);
    await store.saveWorkout(w);
    final s = Session.start(w);
    s.exercises[0].reps.setAll(0, [5, 5, 5]);
    s.exercises[0].weights.setAll(0, [90, 90, 90]);
    s.exercises[0].rir = 2;
    s.exercises[1].reps.setAll(0, [5, 4, 4]);
    s.exercises[1].weights.setAll(0, [-10, -15, -20]);
    s.exercises[2].reps.setAll(0, [12, 12, 10]);
    await store.finishSession(s);
    await tester.pumpWidget(MaterialApp(home: RecapPage(s)));
    expect(w.exercises[2].weight, 7.5);
    expect(find.byIcon(Icons.arrow_forward), findsNWidgets(2), reason: 'lighter sets hold the previous plan');
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.textContaining('Heute leichter als geplant', findRichText: true), findsOneWidget);
    expect(find.textContaining('Unterstützung erhöht', findRichText: true), findsOneWidget);
    expect(find.textContaining('Nach 3 Trainings ohne Zielerreichung reduziert', findRichText: true), findsOneWidget);
    expect(find.text('2 Wdh. Reserve'), findsOneWidget);

    s.planBefore = null; // a training from before the plan or its decision was recorded
    for (final l in s.exercises) {
      l.decision = null;
    }
    await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: RecapPage(s)));
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
    expect(find.textContaining('3 Trainings in Folge Ziel nicht erreicht', findRichText: true), findsOneWidget);
  });

}
