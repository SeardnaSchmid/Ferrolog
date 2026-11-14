import 'dart:convert';
import 'dart:io';

import 'package:ferrolog/edit.dart';
import 'package:ferrolog/language.dart';
import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/templates.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = await Store.open();
    unit.value = WeightUnit.kg;
  });
  tearDown(() => language.value = const Locale('de')); // the other tests expect German

  test('both ARB files hold the same keys', () {
    Set<String> keys(String l) =>
        (jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync()) as Map<String, dynamic>)
            .keys
            .where((k) => !k.startsWith('@'))
            .toSet();
    expect(keys('en'), keys('de'));
  });

  test('the system language picks German or English, the setting wins', () {
    expect(localeFor(const Locale('de', 'AT')), const Locale('de'));
    expect(localeFor(const Locale('fr')), const Locale('en'));
    expect(languageFromSetting(null), isNull);
    expect(languageFromSetting('en'), const Locale('en'));
  });

  test('numbers, dates and labels follow the language', () {
    final d = DateTime(2026, 11, 2);
    expect(weightLabel(82.5), '82,5 kg');
    expect(dateLabel(d), '02.11.2026');
    expect(tagLabel('Krank'), 'Krank');

    language.value = const Locale('en');
    expect(weightLabel(82.5), '82.5 kg');
    expect(volumeLabel(7240), '7.2 t');
    expect(dateLabel(d), '11/2/2026');
    expect(dayLabel(d), 'Monday, November 2');
    expect(durationLabel(const Duration(minutes: 48)), '48 min');
    expect(tagLabel('Krank'), 'Sick');
    expect(tagLabel('Eigener Tag'), 'Eigener Tag', reason: 'unknown tags stay as stored');
    expect(rirLabel(0), 'at the limit');
    expect(progressionLabel(Progression.miss), 'missed');
    expect(tr.trainingsCount(1), '1 workout');
    expect(tr.trainingsCount(3), '3 workouts');
  });

  test('catalogue exercises in English: shown, found and set up like the German ones', () {
    language.value = const Locale('en');
    expect(exerciseLabel('Bankdrücken'), 'Bench Press');
    expect(exerciseLabel('Plank'), 'Plank');
    expect(catalogueName('Bench Press'), 'Bankdrücken');
    expect(catalogueName('bench-press'), 'Bankdrücken');
    expect(catalogueName('My own lift'), 'My own lift');
    expect(searchExercises('bench', [exerciseLabel('Bankdrücken'), 'Squat']).first, 'Bench Press');

    final squat = knownExercise('Squat');
    expect(squat.weight, knownExercise('Kniebeuge').weight, reason: 'catalogue defaults found by the English name');
    expect(squat.failRestSeconds, 120, reason: 'a heavy lift in English too');
    expect(knownExercise('Side Plank').timed, isTrue);

    final day = programs.firstWhere((p) => p.name == 'StrongLifts 5×5').days.first;
    expect(day.workoutName, 'StrongLifts A');
    expect(programs.map((p) => p.name), contains('Push/Pull/Legs'));
  });

  test('the export prompt follows a language picked in the app', () {
    language.value = const Locale('en');
    expect(analysisPrompt(), startsWith('Here is my training data'));
    language.value = const Locale('de');
    expect(analysisPrompt(), startsWith('Hier sind meine Trainingsdaten'));
  });

  testWidgets('home screen in English', (tester) async {
    language.value = const Locale('en');
    await store.saveWorkout(Workout(name: 'Push A', exercises: [Exercise(name: 'Bench Press')]));
    await tester.pumpWidget(const MaterialApp(home: Home()));
    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Starten'), findsNothing);
  });
}
