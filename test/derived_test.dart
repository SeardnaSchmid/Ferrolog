import 'dart:convert';

import 'package:ferrolog/derived.dart';
import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('export: raw data plus prompt and statistics; a failing statistic keeps the data', () async {
    SharedPreferences.setMockInitialValues({});
    store = await Store.open();
    prefs = await SharedPreferences.getInstance();
    sync = GitHubSync(prefs);
    final a = Workout(name: 'A', exercises: [
      Exercise(name: 'Bankdrücken', weight: 80, sets: 3, reps: 5),
      Exercise(name: 'Langhantelrudern', weight: 40, sets: 3, reps: 5),
    ]);
    await store.saveWorkout(a);
    for (final reps in [5, 4]) {
      final s = Session.start(a);
      s.exercises[0].reps.setAll(0, [5, 5, reps]);
      s.exercises[1].reps.setAll(0, [5, 5, 5]);
      await store.finishSession(s);
    }
    expect(jsonDecode(store.exportJson()).containsKey('derived'), isFalse, reason: 'only with the hook, as in main');

    store.exportExtras = () => {'prompt': analysisPrompt, 'derived': derivedStats(DateTime.now())};
    final j = jsonDecode(store.exportJson()) as Map<String, dynamic>;
    expect(j['sessions'], hasLength(2));
    expect(j['prompt'], contains('"derived"'));
    final d = j['derived'] as Map<String, dynamic>;
    expect(d['about'], derivedFormat);
    expect(d['periods']['all']['trainings'], 2);
    final bench = (d['exercises'] as List).firstWhere((e) => e['name'] == 'Bankdrücken');
    expect((bench['trainings'], bench['bestWeight'], bench['next']), (2, 82.5, 82.5), reason: '80 done, so 82.5; missed a rep there');
    expect(d['setsPerMuscleWeek']['last28d']['Brust'], greaterThan(0));
    expect((d['balance90d'] as List).map((b) => b['pair']), contains('Brust ↔ oberer Rücken'));
    expect(d['tasks'], isA<List>(), reason: 'which ones depends on the day; see tasks_test');
    expect(store.toJson().containsKey('derived'), isFalse, reason: 'never stored, only exported');

    store.exportExtras = () => throw StateError('kaputt');
    final broken = jsonDecode(store.exportJson()) as Map<String, dynamic>;
    expect((broken['sessions'] as List).length, 2);
    expect(broken['derivedError'], contains('kaputt'));
  });
}
