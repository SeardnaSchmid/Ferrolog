import 'dart:convert';

import 'package:ferrolog/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Store store;
  late Workout w;
  Exercise squat() => w.exercises.first;

  /// A squat training on [day] with [reps] at the planned weight.
  Future<Session> train(int day, List<int?> reps) async {
    final s = Session.start(w)..date = DateTime(2026, 11, day, 18);
    s.exercises.first.reps.setAll(0, reps);
    await store.finishSession(s, at: DateTime(2026, 11, day, 19));
    return s;
  }

  /// [s] as edited on the edit page: a copy with other reps, saved over it.
  Future<Session> correct(Session s, List<int?> reps) async {
    final edited = s.copy();
    edited.exercises.first.reps.setAll(0, reps);
    await store.replaceSession(edited);
    return edited;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Store.open();
    w = Workout(id: 'a', name: 'A', exercises: [
      Exercise(name: 'Kniebeuge', weight: 100, sets: 3, reps: 5, down: true, decrement: 10, failsToDeload: 2),
    ]);
    await store.saveWorkout(w);
  });

  test('finishing keeps the plan before on the newest training only', () async {
    final first = await train(2, [5, 5, 5]);
    expect(first.planBefore?['Kniebeuge'], (weight: 100.0, setWeights: null, fails: 0, auto: null));
    expect(squat().weight, 102.5);
    final second = await train(4, [5, 5, 3]);
    expect(first.planBefore, isNull, reason: 'handed over to the newer one');
    expect(second.planBefore?['Kniebeuge']?.weight, 102.5);
    expect((squat().weight, squat().fails), (102.5, 1));

    final reopened = Store(await SharedPreferences.getInstance());
    expect(reopened.sessions.first.planBefore, second.planBefore, reason: 'stored');
    expect(jsonDecode(store.exportJson())['sessions'].first.containsKey('planBefore'), isFalse, reason: 'not exported');
  });

  test('correcting the newest training recomputes the plan, and back again', () async {
    final s = await train(2, [5, 5, 3]);
    expect((squat().weight, squat().fails), (100.0, 1));
    final fixed = await correct(s, [5, 5, 5]);
    expect((squat().weight, squat().fails), (102.5, 0), reason: 'raised exactly once');
    await correct(fixed, [5, 5, 5]);
    expect(squat().weight, 102.5, reason: 'saving again changes nothing');
    await correct(fixed, [5, 5, 3]);
    expect((squat().weight, squat().fails), (100.0, 1));
    expect(Store(await SharedPreferences.getInstance()).workouts.single.exercises.single.weight, 100, reason: 'saved');
  });

  test('a deload undone by a correction', () async {
    await train(2, [5, 5, 3]);
    final s = await train(4, [5, 4, 3]); // second miss: deload by 10
    expect((squat().weight, squat().fails), (90.0, 0));
    await correct(s, [5, 5, 5]);
    expect((squat().weight, squat().fails), (102.5, 0));
  });

  test('deleting the newest training puts the plan back', () async {
    await train(2, [5, 5, 5]);
    final s = await train(4, [5, 5, 3]);
    expect((squat().weight, squat().fails), (102.5, 1));
    await store.deleteSession(s);
    expect((squat().weight, squat().fails), (102.5, 0));
    expect(store.sessions, hasLength(1));
  });

  test('an older training changes the history, not the plan', () async {
    final old = await train(2, [5, 5, 3]);
    await train(4, [5, 5, 5]);
    expect(squat().weight, 102.5);
    final fixed = await correct(old, [5, 5, 5]);
    expect(squat().weight, 102.5);
    expect(store.sessions.last.exercises.first.reps, [5, 5, 5]);
    expect(store.sessions.last, same(fixed));
    await store.deleteSession(fixed);
    expect(squat().weight, 102.5);
  });

  test('trainings from before the snapshot leave the plan alone', () async {
    final s = await train(2, [5, 5, 3]);
    s.planBefore = null; // as stored before WP4
    expect(store.movesPlan(s), isFalse);
    await correct(s, [5, 5, 5]);
    expect(squat().weight, 100);
    await store.deleteSession(s);
    expect(squat().weight, 100);
  });

  test('a new date re-sorts the history and moves the set times along', () async {
    await train(2, [5, 5, 5]);
    final s = await train(6, [5, 5, 5]);
    s.exercises.first.doneAt.setAll(0, [DateTime(2026, 11, 6, 18, 5), DateTime(2026, 11, 6, 18, 9), null]);
    final edited = s.copy()..shift(DateTime(2026, 11, 4, 17).difference(s.date));
    await store.replaceSession(edited);
    expect([for (final x in store.sessions) x.date.day], [4, 2]);
    expect(edited.date, DateTime(2026, 11, 4, 17));
    expect(edited.finishedAt, DateTime(2026, 11, 4, 18));
    expect(edited.exercises.first.doneAt, [DateTime(2026, 11, 4, 17, 5), DateTime(2026, 11, 4, 17, 9), null]);
    expect(squat().weight, 105, reason: 'still the newest: recomputed, the same');

    // Moved behind the other one: the plan stays, neither moves it any more.
    await store.replaceSession(edited.copy()..shift(const Duration(days: -3)));
    expect([for (final x in store.sessions) x.date.day], [2, 1]);
    expect(squat().weight, 105);
    expect(store.sessions.map(store.movesPlan), [false, false]);
  });

  test('a plan restructured since keeps that exercise as it is', () async {
    final s = await train(2, [5, 5, 5]);
    squat()
      ..sets = 2
      ..setWeights = [110, 100];
    await store.deleteSession(s);
    expect(squat().setWeights, [110, 100]);
  });
}
