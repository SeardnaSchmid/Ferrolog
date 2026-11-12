import 'package:ferrolog/loading.dart';
import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/session.dart';
import 'package:ferrolog/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ferrolog/sync.dart';
import 'package:ferrolog/units.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('warm-up line on barbell lifts until the first set; plates per side in the weight sheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    unit.value = WeightUnit.kg;
    store = await Store.open();
    final w = Workout(name: 'A', exercises: [
      Exercise(name: 'Kniebeuge', weight: 100, sets: 3, reps: 5),
      Exercise(name: 'Bizepscurls', weight: 30, sets: 3, reps: 8),
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

    expect(find.textContaining('Aufwärmen'), findsNothing, reason: 'off until switched on');
    await prefs.setBool('session.warmup', true);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: SessionPage(s)));

    expect(find.text('Aufwärmen: 20×8 · 50×5 · 70×3 · 85×1'), findsOneWidget, reason: 'not for the curls');
    expect(find.byType(CheckboxListTile), findsNothing);
    await tester.tap(find.text('Aufwärmen: 20×8 · 50×5 · 70×3 · 85×1'));
    await tester.pump();
    expect(find.byType(CheckboxListTile), findsNWidgets(4));
    expect(find.text('Nur die Stange'), findsOneWidget);
    expect(find.text('Pro Seite: 15'), findsOneWidget);
    expect(find.text('Pro Seite: 25 + 5 + 2,5'), findsOneWidget); // 85 kg
    await tester.tap(find.text('50 kg × 5'));
    await tester.pump();
    expect(find.text('Aufwärmen: 20×8 · 50×5 · 70×3 · 85×1  ✓ 1/4'), findsOneWidget);
    expect(s.exercises.first.setsDone, 0, reason: 'warm-ups are not logged');

    // The weight sheet: plates for the typed weight, a hint when they don't add up.
    await tester.tap(find.text('100 kg').first);
    await settle();
    expect(find.text('Pro Seite: 25 + 15'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '101');
    await tester.pump();
    expect(find.text('Pro Seite: 25 + 15 + 0,5'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '100,3');
    await tester.pump();
    expect(find.text('Mit deinen Scheiben nicht ladbar'), findsOneWidget);
    await tester.tap(find.text('Schließen'));
    await settle();

    // First set logged: the warm-up is over.
    await tester.tap(find.descendant(of: find.byType(SetTile).first, matching: find.byType(InkWell)).first);
    await settle();
    expect(s.exercises.first.setsDone, 1);
    expect(find.textContaining('Aufwärmen'), findsNothing);
  });

  testWidgets('warm-up switch, bar and plates in the settings, per unit', (tester) async {
    await prefs.remove('session.warmup');
    unit.value = WeightUnit.kg;
    sync = GitHubSync(prefs);
    tester.view.physicalSize = const Size(500, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SyncSettings())));
    await tester.tap(find.text('Aufwärmsätze zeigen'));
    await tester.tap(find.text('Stange 15 kg'));
    await tester.tap(find.widgetWithText(FilterChip, '25'));
    await tester.pump();
    expect(prefs.getBool('session.warmup'), isTrue);
    expect(prefs.getDouble('barbell.bar.kg'), 15);
    expect(prefs.getStringList('barbell.plates.kg'), isNot(contains('25.0')));
    expect(warmupFor(100).first, (15.0, 8));
    expect(perSideLabel(100), 'Pro Seite: 20 + 20 + 2,5');
    unit.value = WeightUnit.lb; // the lb bar and plates are their own
    expect((barWeight, availablePlates.first), (45.0, 45.0));
  });
}
