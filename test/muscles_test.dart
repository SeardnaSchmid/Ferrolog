import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/muscles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('muscles: own choice, catalogue, databases, word parts; regions count secondary half', () async {
    SharedPreferences.setMockInitialValues({});
    store = await Store.open();
    expect(musclesOf('Kreuzheben')!.$1, Muscle.lowerBack.bit | Muscle.hamstrings.bit | Muscle.glutes.bit,
        reason: 'catalogue');
    expect(musclesOf('deadlift'), musclesOf('Kreuzheben'), reason: 'catalogue alias');
    expect(musclesIn(musclesOf('Frontkniebeuge')!.$1), contains(Muscle.quadriceps), reason: 'from the databases');
    expect(musclesOf('Barbell Shrug')!.$1 & Muscle.traps.bit, isNonZero, reason: 'free-exercise-db name');
    expect(musclesOf('Meine Spezial-Curls'), (Muscle.biceps.bit, 0), reason: 'word part');
    expect(musclesOf('Meditation'), isNull);

    final dips = (Muscle.chest.bit, Muscle.triceps.bit);
    await setMuscles('Dips', dips);
    expect(musclesOf('dips'), dips);
    final reopened = await Store.open();
    expect(reopened.muscles['Dips'], {'primary': ['chest'], 'secondary': ['triceps']}, reason: 'in the training data');
    await setMuscles('Dips', defaultMuscles('Dips')!); // back to the default: nothing stored
    expect(store.muscles, isEmpty);

    final s = Session(workoutId: 'w', workoutName: 'A', exercises: [
      ExerciseLog(name: 'Bankdrücken', weight: 60, targetReps: 5, reps: [5, 5, null]), // 2 sets
      ExerciseLog(name: 'Laufen', weight: 0, targetReps: 30, reps: [30], cardio: true),
    ]);
    final sets = setsPerMuscle([s]);
    expect(sets[MuscleGroup.chest], 2);
    expect(sets[MuscleGroup.arms], 1, reason: 'secondary (triceps): half');
    expect(sets[MuscleGroup.legs], 0, reason: 'cardio does not count');
  });
}
