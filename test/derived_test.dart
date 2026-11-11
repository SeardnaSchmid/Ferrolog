import 'dart:convert';

import 'package:ferrolog/derived.dart';
import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/sync.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('export: raw data plus prompt and statistics; a failing statistic keeps the data', () async {
    SharedPreferences.setMockInitialValues({});
    store = await Store.open();
    prefs = await SharedPreferences.getInstance();
    sync = GitHubSync(prefs);
    unit.value = WeightUnit.kg; // findings speak the shown unit; the test locale would pick lb
    final a = Workout(name: 'A', exercises: [
      Exercise(name: 'Bankdrücken', weight: 80, sets: 3, reps: 5),
      Exercise(name: 'Langhantelrudern', weight: 40, sets: 3, reps: 5),
      Exercise(name: 'Klimmzüge', weight: 0, sets: 3, reps: 5),
    ]);
    await store.saveWorkout(a);
    for (final reps in [5, 4]) {
      final s = Session.start(a);
      s.exercises[0].reps.setAll(0, [5, 5, reps]);
      s.exercises[1].reps.setAll(0, [5, 5, 5]);
      s.exercises[2].reps.setAll(0, [5, 4, reps]);
      await store.finishSession(s);
    }
    expect(jsonDecode(store.exportJson()).containsKey('derived'), isFalse, reason: 'only with the hook, as in main');

    store.exportExtras = analysisExtras;
    final j = jsonDecode(store.exportJson()) as Map<String, dynamic>;
    expect(j['sessions'], hasLength(2));
    expect(j.keys.take(5), ['app', 'version', 'exportedAt', 'units', 'instructions'], reason: 'instructions before the data');
    expect(j.keys.last, 'sessions', reason: 'the raw data at the end');
    expect(j['instructions'], allOf(contains('"derived"'), contains('"capabilities"'), contains('"planImport"')));
    expect((j['capabilities']['cannot'] as List).first, contains('Supersets'));
    final example = j['planImport']['example'] as Map<String, dynamic>;
    expect((example['app'], example['kind']), ('ferrolog', 'plan'));
    expect(Exercise.fromJson(example['workouts'][0]['exercises'][1]).timed, isTrue, reason: 'the example reads as a plan');
    final d = j['derived'] as Map<String, dynamic>;
    expect(d['about'], derivedFormat);
    expect(d['periods']['all']['trainings'], 2);
    final bench = (d['exercises'] as List).firstWhere((e) => e['name'] == 'Bankdrücken');
    expect((bench['trainings'], bench['bestWeight'], bench['next']), (2, 82.5, 82.5), reason: '80 done, so 82.5; missed a rep there');
    expect(d['setsPerMuscleWeek']['last28d']['Brust'], greaterThan(0));
    expect(d['setsPerMuscleWeek']['last90d'], d['setsPerMuscleWeek']['last28d'],
        reason: 'both trainings today: weeks since the first training, not the whole span');
    final pullUps = (d['exercises'] as List).firstWhere((e) => e['name'] == 'Klimmzüge');
    expect((pullUps['bodyweight'], pullUps['repsLast'], pullUps['repsBest'], pullUps.containsKey('e1rmNow')),
        (true, 13, 14, false));
    expect((d['balance28d'] as List).map((b) => b['pair']), contains('Brust ↔ Oberer Rücken'));
    expect(d.containsKey('tasks') || d.containsKey('facts'), isFalse, reason: 'replaced by findings');
    final found = d['findings'] as List;
    final record = found.singleWhere((f) => f['type'] == 'record');
    expect((record['kind'], record['title'], record['source']['view'], record['source']['exercise']),
        ('positive', 'Rekord: Bankdrücken 82,5 kg', 'exercise', 'Bankdrücken'));
    expect(analysisPrompt(const Locale('de', 'AT')), contains('Antworte auf Deutsch'));
    expect(analysisPrompt(const Locale('fr', 'FR')), allOf(startsWith('Here is'), contains('"planImport"'), contains('(fr-FR)')),
        reason: 'other systems get English, asking for an answer in their language');
    expect(store.toJson().containsKey('derived'), isFalse, reason: 'never stored, only exported');

    store.exportExtras = () => throw StateError('kaputt');
    final broken = jsonDecode(store.exportJson()) as Map<String, dynamic>;
    expect((broken['sessions'] as List).length, 2);
    expect(broken['derivedError'], contains('kaputt'));
  });
}
