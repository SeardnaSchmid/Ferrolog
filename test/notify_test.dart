import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/notify.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final a = Workout(
  name: 'A',
  exercises: [Exercise(name: 'Kniebeuge', weight: 100, sets: 3, reps: 5)],
);
final b = Workout(
  name: 'B',
  exercises: [Exercise(name: 'Kreuzheben', weight: 120, sets: 1, reps: 5)],
);

Session on(Workout w, DateTime date) => Session(
  workoutId: w.id,
  workoutName: w.name,
  date: date,
  exercises: [for (final e in w.exercises) ExerciseLog.fromPlan(e)],
);

String dump(List<Reminder> rs) =>
    [for (final r in rs) '${r.id} ${r.at} ${r.title} | ${r.text}'].join('\n');

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    unit.value = WeightUnit.kg;
    prefs = await SharedPreferences.getInstance();
  });

  group('reminders', () {
    // Monday 2026-11-16, trainings at 18:00 so far: reminders at 16:00.
    final now = DateTime(2026, 11, 16, 12);
    final history = [
      for (var d = 1; d <= 21; d += 2) on(a, DateTime(2026, 11, 16 - d, 18)),
    ];

    test(
      'weekly goal: on the last day it can be made, then the next weeks; long break after 7 and 14 days',
      () {
        final rs = reminders(history, [a, b], now, perWeek: 3);
        expect(dump(rs), '''
100 2026-11-20 16:00:00.000 Serie von 3 Wochen in Gefahr | Noch 3 Trainings in 3 Tagen: ab heute jeden Tag eins.
101 2026-11-27 16:00:00.000 Noch 3 Trainings diese Woche | Noch 3 Trainings in 3 Tagen: ab heute jeden Tag eins.
102 2026-12-04 16:00:00.000 Noch 3 Trainings diese Woche | Noch 3 Trainings in 3 Tagen: ab heute jeden Tag eins.
207 2026-11-22 16:00:00.000 Seit 7 Tagen kein Training | Als Nächstes: B
214 2026-11-29 16:00:00.000 Seit 14 Tagen kein Training | Als Nächstes: B''');
      },
    );

    test('goal made this week: no reminder this week; switched off: none', () {
      final done = [
        on(a, DateTime(2026, 11, 16, 8)),
        on(a, DateTime(2026, 11, 17, 8)),
        on(a, DateTime(2026, 11, 18, 8)),
        ...history,
      ];
      final rs = reminders(
        done,
        [a],
        DateTime(2026, 11, 18, 12),
        perWeek: 3,
        longBreak: false,
      );
      expect(rs.map((r) => r.id), [101, 102]);
      expect(
        reminders(
          history,
          [a],
          now,
          perWeek: 3,
          streak: false,
          longBreak: false,
        ),
        isEmpty,
      );
    });

    test('one left on Sunday, already past: nothing for this week', () {
      final rs = reminders(
        history,
        [a],
        DateTime(2026, 11, 22, 20),
        perWeek: 1,
        longBreak: false,
      );
      expect(rs.map((r) => r.id), [101, 102]);
    });

    test(
      'in the week of the very first training: no weekly goal yet; nothing trained: nothing',
      () {
        expect(
          reminders(
            [on(a, DateTime(2026, 11, 16, 9))],
            [a],
            now,
            perWeek: 3,
            longBreak: false,
          ),
          isEmpty,
        );
        expect(reminders([], [a], now, perWeek: 3), isEmpty);
      },
    );

    test(
      'reminder time: two hours before the usual start, between 8 and 19 o\'clock',
      () {
        expect(usualHour([]), 17);
        final early = [
          for (var d = 1; d <= 5; d++) on(a, DateTime(2026, 11, 16 - d, 6)),
        ];
        expect(
          reminders(early, [a], now, perWeek: 1, streak: false).first.at.hour,
          8,
        );
      },
    );
  });

  group('training notification', () {
    test(
      'the next set after the one logged last, its weight and reps; the rest as its end',
      () async {
        final s = on(a, DateTime(2026, 11, 16, 18));
        final now = DateTime(2026, 11, 16, 18, 10);
        s.exercises[0].reps[0] = 5;
        s.exercises[0].doneAt[0] = now;
        s.restStartedAt = now;
        s.restSeconds = 180;
        final n = trainingNotice(s, now);
        expect(n['title'], 'Kniebeuge · Satz 2/3');
        expect(n['text'], '100 kg × 5');
        expect(n['sub'], 'A');
        expect(
          n['restEnd'],
          now.add(const Duration(minutes: 3)).millisecondsSinceEpoch,
        );
        expect(n['pausedText'], isNull);
        expect(n['warning'], isTrue);
        await prefs.setBool('rest.warning', false);
        expect(trainingNotice(s, now)['warning'], isFalse);
        await prefs.remove('rest.warning');

        s.restPausedAt = now.add(const Duration(seconds: 40));
        final paused = trainingNotice(s, now.add(const Duration(minutes: 5)));
        expect(paused['restEnd'], isNull);
        expect(paused['pausedText'], 'Pause angehalten (2:20)');
      },
    );

    test('all done: asks to finish', () {
      final s = on(b, DateTime(2026, 11, 16, 18));
      s.exercises[0].reps[0] = 5;
      expect(nextSet(s), isNull);
      expect(
        trainingNotice(s, DateTime(2026, 11, 16, 19))['title'],
        'Alle Sätze geschafft',
      );
    });
  });
}
