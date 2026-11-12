import 'dart:convert';

import 'package:ferrolog/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Session _training(String workout, DateTime date, List<ExerciseLog> logs) =>
    Session(workoutId: workout, workoutName: workout, date: date, exercises: logs);

ExerciseLog _log(String name, double weight, {String? replaces}) =>
    ExerciseLog(name: name, weight: weight, targetReps: 5, reps: [5, 5, 5], replaces: replaces);

void main() {
  late Store store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'tasks.snoozed': jsonEncode({
        'plateau:Bankdrücken': '2026-12-01T00:00:00.000',
        'record:Bankdrücken:2026-11-02T18:00:00.000': '2026-12-01T00:00:00.000',
        'skipped:Bankdrücken (Pause)': '2026-12-01T00:00:00.000',
        'week:2026-11-9': '2026-12-01T00:00:00.000',
      }),
    });
    store = await Store.open();
  });

  test('rename reaches plans, trainings, the running one, muscles and put-off findings', () async {
    store.workouts = [
      Workout(id: 'a', name: 'A', exercises: [Exercise(name: 'Bankdrücken'), Exercise(name: 'Kniebeuge')]),
      Workout(id: 'b', name: 'B', exercises: [Exercise(name: 'Bankdrücken')]),
    ];
    store.sessions = [
      _training('a', DateTime(2026, 11, 4), [_log('Kurzhantel-Bankdrücken', 24, replaces: 'Bankdrücken')])
        ..planBefore = {'Bankdrücken': (weight: 60, setWeights: null, fails: 1, auto: null)},
      _training('a', DateTime(2026, 11, 2), [_log('Bankdrücken', 57.5), _log('Kniebeuge', 100)]),
    ];
    store.muscles = {'bankdruecken': {'primary': ['chest']}};
    await store.saveActive(_training('b', DateTime(2026, 11, 6), [_log('Bankdrücken', 60)]));

    await store.renameExercise('Bankdrücken', 'Bankdrücken (Pause)');

    final reopened = Store(await SharedPreferences.getInstance());
    for (final s in [store, reopened]) {
      expect([for (final w in s.workouts) for (final e in w.exercises) e.name],
          ['Bankdrücken (Pause)', 'Kniebeuge', 'Bankdrücken (Pause)']);
      expect(s.sessions.first.exercises.single.replaces, 'Bankdrücken (Pause)');
      expect(s.sessions.first.planBefore?.keys, ['Bankdrücken (Pause)']);
      expect(s.sessions.last.exercises.map((e) => e.name), ['Bankdrücken (Pause)', 'Kniebeuge']);
      expect(s.sessions.last.exercises.first.weight, 57.5);
      expect(s.active?.exercises.single.name, 'Bankdrücken (Pause)');
      expect(s.muscles, {'Bankdrücken (Pause)': {'primary': ['chest']}});
      expect(s.historyOf('Bankdrücken'), isEmpty);
      expect(s.historyOf('Bankdrücken (Pause)'), hasLength(1));
    }
    expect(store.exportJson(), isNot(contains('"Bankdrücken"')));
    expect(jsonDecode((await SharedPreferences.getInstance()).getString('tasks.snoozed')!).keys, [
      'plateau:Bankdrücken (Pause)',
      'record:Bankdrücken (Pause):2026-11-02T18:00:00.000',
      'skipped:Bankdrücken (Pause)',
      'week:2026-11-9',
    ]);
  });

  test('merging two names: one history by date; a swap to itself is no swap; muscles of the target stay', () async {
    store.workouts = [Workout(id: 'a', name: 'A', exercises: [Exercise(name: 'Rudern')])];
    store.sessions = [
      _training('a', DateTime(2026, 11, 6), [_log('Langhantelrudern', 50, replaces: 'Rudern')]),
      _training('a', DateTime(2026, 11, 4), [_log('Rudern', 45)]),
      _training('a', DateTime(2026, 11, 2), [_log('Langhantelrudern', 42.5)]),
    ];
    store.muscles = {'Rudern': {'primary': ['back']}, 'Langhantelrudern': {'primary': ['lats']}};
    await store.renameExercise('Rudern', 'Langhantelrudern');
    expect([for (final (d, l) in store.historyOf('Langhantelrudern')) (d.day, l.weight)], [(2, 42.5), (4, 45.0), (6, 50.0)]);
    expect(store.sessions.first.exercises.single.replaces, isNull);
    expect(store.muscles, {'Langhantelrudern': {'primary': ['lats']}});
    expect(store.workouts.single.exercises.single.name, 'Langhantelrudern');
  });

  test('two names of one workout are not merged', () async {
    store.workouts = [Workout(id: 'a', name: 'A', exercises: [Exercise(name: 'Curls'), Exercise(name: 'Hammercurls')])];
    expect(store.shareAWorkout('Curls', 'Hammercurls'), isTrue);
    await expectLater(store.renameExercise('Curls', 'Hammercurls'), throwsStateError);
    expect(store.workouts.single.exercises.map((e) => e.name), ['Curls', 'Hammercurls']);
  });

  test('a name in the plan twice (older data): each entry gets its own result', () async {
    final w = Workout(id: 'a', name: 'A', exercises: [
      Exercise(name: 'Kniebeuge', weight: 100, sets: 1, reps: 5),
      Exercise(name: 'Kniebeuge', weight: 80, sets: 1, reps: 5),
    ]);
    await store.saveWorkout(w);
    final s = Session.start(w);
    s.exercises[0].reps[0] = 5; // heavy one done
    s.exercises[1].reps[0] = 3; // back-off missed
    await store.finishSession(s);
    expect(w.exercises.map((e) => (e.weight, e.fails)), [(102.5, 0), (80.0, 1)]);
    expect(planEntryOf(w, s.exercises, s.exercises[1]), same(w.exercises[1]));
  });
}
