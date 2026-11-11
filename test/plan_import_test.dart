import 'dart:convert';

import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/muscles.dart';
import 'package:ferrolog/plan_import.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Workout a, b;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Store.open(); // late final: once for all tests
    unit.value = WeightUnit.kg;
  });

  setUp(() async {
    store.sessions.clear();
    a = Workout(id: 'a', name: 'Full Body', exercises: [
      Exercise(name: 'Kniebeuge', weight: 120, sets: 3, reps: 5, fails: 2),
      Exercise(name: 'Klimmzüge', weight: 0, sets: 3, reps: 5),
      Exercise(name: 'Langhantelrudern', weight: 40, sets: 3, reps: 6, maxReps: 8, restSeconds: 90, down: true),
      Exercise(name: 'Face Pulls', weight: 10, sets: 2, reps: 12),
    ]);
    b = Workout(id: 'b', name: 'Kurz', exercises: [Exercise(name: 'Bankdrücken', weight: 80, sets: 3, reps: 5)]);
    await store.replacePlans([a, b], muscles: {});
  });

  Map<String, dynamic> ex(String name, double weight, int sets, int reps, [Map<String, dynamic> more = const {}]) =>
      {'name': name, 'weight': weight, 'sets': sets, 'reps': reps, ...more};

  String plan(List<Map<String, dynamic>> workouts) => jsonEncode(
      {'app': 'ferrolog', 'kind': 'plan', 'version': 1, 'basedOn': '2026-11-11T08:00:00', 'summary': 'Test', 'workouts': workouts});

  test('a listed workout is replaced as a whole, the rest stays; fails and order carried over', () async {
    final p = parsePlanImport('Hier dein Plan:\n```json\n${plan([
          {
            'id': 'a',
            'name': 'Full Body',
            'exercises': [
              ex('Kniebeuge', 122.5, 3, 5, {'why': 'Zweimal sauber.'}),
              ex('Langhantelrudern', 40, 3, 6, {'maxReps': 8}),
              ex('Klimmzüge', 0, 3, 5, {'maxReps': 8, 'up': false}),
              ex('Plank', 0, 2, 45, {'type': 'timed', 'up': false}),
            ],
          },
        ])}\n```\nViel Erfolg!');
    expect(p.summary, 'Test');
    expect(p.workouts.map((w) => w.name), ['Full Body', 'Kurz'], reason: 'b not listed, so kept');
    final full = p.workouts.first;
    expect(full.id, 'a');
    expect(full.exercises.map((e) => e.name), ['Kniebeuge', 'Langhantelrudern', 'Klimmzüge', 'Plank']);
    expect(full.exercises.first.fails, 2, reason: 'the deload count survives');
    expect(full.exercises.first.increment, 2.5, reason: 'defaults where left out');
    expect((full.exercises[1].restSeconds, full.exercises[1].down), (90, true),
        reason: 'progression and rest left out stay as they were');
    expect(store.workouts.first.exercises.first.weight, 120, reason: 'nothing saved before taking it over');

    final d = p.diff.first;
    expect(d.change, Change.changed);
    String row(String name) => '${d.exercises.firstWhere((e) => e.name == name).change.name} '
        '${d.exercises.firstWhere((e) => e.name == name).details.join('; ')}';
    expect(row('Kniebeuge'), 'changed Gewicht: 120 kg → 122,5 kg');
    expect(d.exercises.first.why, 'Zweimal sauber.');
    expect(row('Klimmzüge'), 'changed Sätze: 3×5 → 3×5–8; Steigerung: +2,5 kg → aus');
    expect(d.exercises.firstWhere((e) => e.name == 'Klimmzüge').movedTo, 3);
    expect(d.exercises.firstWhere((e) => e.name == 'Langhantelrudern').movedTo, 2);
    expect(row('Plank'), 'added auf Zeit · 2×45 s · ohne Gewicht');
    expect(row('Face Pulls'), 'removed ');
    expect(p.diff.last.change, Change.same);

    final undo = await applyPlanImport(p);
    expect(store.workouts.first.exercises.map((e) => e.name), contains('Plank'));
    expect(jsonDecode(store.exportJson())['workouts'][0]['exercises'][0]['weight'], 122.5, reason: 'saved');
    await undo();
    expect(store.workouts.first.exercises.map((e) => (e.name, e.weight)).first, ('Kniebeuge', 120.0));
    expect(store.workouts.first.exercises, hasLength(4));
  });

  test('new and deleted workouts; muscles only for exercises the app does not know', () async {
    final p = parsePlanImport(plan([
      {'id': 'b', 'delete': true},
      {
        'name': 'Zusatz',
        'exercises': [
          ex('Atemübung XY', 0, 1, 60, {
            'type': 'timed',
            'muscles': {'primary': ['abdominals'], 'secondary': []},
          }),
          ex('Wadenheben', 40, 2, 12, {
            'maxReps': 15,
            'muscles': {'primary': ['chest'], 'secondary': []},
          }),
        ],
      },
    ]));
    expect(p.workouts.map((w) => w.name), ['Full Body', 'Zusatz']);
    expect((p.diff[0].change, p.diff[0].name), (Change.removed, 'Kurz'));
    expect(p.diff[1].change, Change.added);
    expect(p.diff[1].exercises.map((e) => e.change), [Change.added, Change.added]);
    expect(p.muscles.keys, ['Atemübung XY'], reason: 'calf raises are known, the AI does not override them');
    await applyPlanImport(p);
    expect(musclesOf('Atemübung XY'), (Muscle.abdominals.bit, 0));
  });

  test('broken answers are refused with a reason', () {
    void refused(String text, String reason) =>
        expect(() => parsePlanImport(text), throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(reason))));
    refused('Keine Ahnung', 'Kein JSON');
    refused('{"app": "ferrolog", "kind": "plan", "workouts": [', 'Kein JSON');
    refused('{"app": "ferrolog", "kind": "plan", "workouts": [}', 'fehlerhaft');
    refused('{"app": "other"}', 'kein FerroLog-Plan');
    refused(store.exportJson(), 'Export mit allen Daten');
    expect(parsePlanImport('\uFEFF${plan([{'id': 'b', 'name': 'Kurz', 'exercises': [ex('Bankdrücken', 80, 3, 5)]}])}').empty, isTrue,
        reason: 'a text file with a byte order mark reads too');
    refused(plan([]), 'keine Workouts');
    refused(plan([{'id': 'x', 'delete': true}]), 'gibt es nicht');
    refused(plan([{'name': 'A', 'exercises': [ex('Kniebeuge', 100, 3, 5, {'setReps': [5, 5]})]}]), 'setReps passt nicht zu 3');
    refused(plan([{'name': 'A', 'exercises': [{'name': 'Kniebeuge', 'weight': 100, 'sets': '3', 'reps': 5}]}]), '"sets"');
    refused(plan([{'name': 'A', 'exercises': [ex('Kniebeuge', 100, 3, 5, {'type': 'superset'})]}]), 'superset');
    refused(plan([{'name': 'A', 'exercises': [ex('X', 0, 3, 5, {'muscles': {'primary': ['core']}})]}]), 'Muskel "core"');
    refused(plan([{'id': 'a', 'name': 'A', 'exercises': [ex('X', 0, 3, 5)]}, {'id': 'a', 'delete': true}]), 'zweimal');
  });

  test('stale when trained after the export the AI read', () async {
    final p = parsePlanImport(plan([{'id': 'b', 'name': 'Kurz', 'exercises': [ex('Bankdrücken', 80, 3, 5)]}]));
    expect((p.stale, p.empty), (false, true), reason: 'same plan, no trainings yet');
    await store.finishSession(Session.start(b));
    expect(p.stale, isTrue);
  });
}
