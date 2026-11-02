import 'dart:convert';

import 'package:ferrolog/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('progressive overload and JSON round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.open();
    final w = Workout(name: 'A', exercises: [
      Exercise(name: 'Kniebeuge', weight: 100, sets: 2, reps: 5, increment: 2.5),
      Exercise(name: 'Bankdrücken', weight: 60, sets: 2, reps: 5, increment: 2.5),
    ]);
    await store.saveWorkout(w);

    final s = Session.start(w);
    s.exercises[0].reps.setAll(0, [5, 5]); // success -> +2.5
    s.exercises[1].reps.setAll(0, [5, 3]); // missed reps -> stays
    await store.finishSession(s);

    expect(w.exercises[0].weight, 102.5);
    expect(w.exercises[1].weight, 60);
    expect(store.lastSessionOf(w), s);
    expect(store.historyOf('Kniebeuge').single.$2.volume, 1000);

    final reopened = await Store.open();
    expect(reopened.workouts.single.exercises.first.weight, 102.5);
    expect(reopened.sessions.single.exercises[1].reps, [5, 3]);
    expect(jsonDecode(reopened.exportJson())['sessions'], hasLength(1));
  });
}
