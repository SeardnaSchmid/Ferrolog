import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'language.dart';
import 'main.dart';
import 'edit.dart' show clock;
import 'model.dart';
import 'units.dart';

/// Android notifications, written by hand over the channel `ferrolog/notify` (see MainActivity.kt,
/// TrainingService.kt, ReminderReceiver.kt): the running training with its rest as a countdown, a
/// "rest over" alert while the app is away, and reminders when the weekly goal gets tight or the last
/// training is long ago. Everything here is computed in Dart; Android only shows and schedules it.
const _channel = MethodChannel('ferrolog/notify');

/// Settings, each on unless switched off.
const notifyTrainingKey = 'notify.training',
    notifyStreakKey = 'notify.streak',
    notifyBreakKey = 'notify.break';

bool _on(String key) => prefs.getBool(key) ?? true;

Future<T?> _call<T>(String method, [Object? args]) async {
  if (kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS) {
    return null;
  }
  try {
    return await _channel.invokeMethod<T>(method, args);
  } on MissingPluginException {
    return null; // tests
  } on PlatformException catch (e) {
    debugPrint('notify $method: $e');
    return null;
  }
}

/// Follows the store from now on: the training notification on every change, the reminders shortly
/// after the last one. Called once at start.
void initNotifications() {
  Timer? later;
  void changed() {
    syncTraining();
    later?.cancel();
    later = Timer(const Duration(seconds: 2), syncReminders);
  }

  store.addListener(changed);
  weeklyGoal.addListener(changed);
  language.addListener(changed);
  changed();
}

/// Asks Android 13+ for the permission to notify, once ever (or again from the settings, [force]).
Future<void> askNotifyPermission({bool force = false}) async {
  if (!force && (prefs.getBool('notify.asked') ?? false)) return;
  await prefs.setBool('notify.asked', true);
  await _call('askPermission');
}

String? _shownId;

/// Shows, updates or removes the notification of the running training: from its first logged set
/// until it ends (finished, discarded or finished automatically).
Future<void> syncTraining() async {
  final s = store.active;
  if (s == null || s.setsDone == 0 || !_on(notifyTrainingKey)) {
    if (_shownId == null) return;
    _shownId = null;
    await _call('trainingStop');
    return;
  }
  if (_shownId != s.id) {
    _shownId = s.id;
    await askNotifyPermission(); // the first set of the first training with notifications
  }
  await _call('training', trainingNotice(s, DateTime.now()));
}

/// The open set to do next: on the exercise of the set logged last while it has sets left, else the
/// first exercise with an open set. Null once everything is done.
({ExerciseLog log, int set})? nextSet(Session s) {
  ExerciseLog? last;
  DateTime? lastAt;
  for (final log in s.exercises) {
    for (final t in log.doneAt) {
      if (t != null && (lastAt == null || t.isAfter(lastAt))) {
        (last, lastAt) = (log, t);
      }
    }
  }
  for (final log in [?last, ...s.exercises]) {
    final i = log.reps.indexWhere((r) => r == null);
    if (i >= 0) return (log: log, set: i);
  }
  return null;
}

/// What the training notification shows: the next set as title ("Kniebeuge · Satz 3/5"), its weight
/// and reps, the workout as sub text, and the rest: when it ends (ms since epoch, for the system
/// countdown), or the seconds left while paused.
Map<String, Object?> trainingNotice(Session s, DateTime now) {
  final next = nextSet(s);
  String title, text;
  if (next == null) {
    title = tr.notifyAllDone;
    text = tr.notifyFinishHint;
  } else {
    final (:log, :set) = next;
    title = log.cardio
        ? log.name
        : tr.notifySetTitle(log.name, set + 1, log.reps.length);
    final target = log.targets[set], top = log.maxReps;
    final reps = log.cardio
        ? cardioLabel(target > 0 ? target : null, log.targetKm)
        : log.timed
        ? '$target${top != null && top > target ? '–$top' : ''} s'
        : '× $target${top != null && top > target ? '–$top' : ''}';
    final w = log.weights[set];
    text = log.cardio || w == 0
        ? reps.replaceFirst('× ', '')
        : '${weightLabel(w)} $reps';
  }
  final left = s.restLeft(now);
  final resting = left != null && left > 0;
  return {
    'title': title,
    'text': text,
    'sub': s.workoutName,
    'restEnd': resting && s.restPausedAt == null
        ? s.restStartedAt!
              .add(Duration(seconds: s.restSeconds ?? 0))
              .millisecondsSinceEpoch
        : null,
    'pausedText': resting && s.restPausedAt != null
        ? tr.notifyRestPaused(clock(left))
        : null,
    'overText': tr.notifyRestOver,
    'alertTitle': tr.notifyRestOver,
    'warningTitle': tr.notifyRestSoon,
    'alertText': next == null ? tr.notifyFinishHint : '$title · $text',
    'sound': prefs.getBool('rest.sound') ?? true,
    'vibrate': prefs.getBool('rest.vibrate') ?? true,
    'warning': prefs.getBool('rest.warning') ?? true,
    'channelName': tr.notifyChannelTraining,
    'alertChannelName': tr.notifyChannelRest,
    'alertSilentChannelName': tr.notifyChannelRestSilent,
  };
}

/// A reminder for later: Android shows it at [at] if the app hasn't replaced the list by then.
typedef Reminder = ({int id, DateTime at, String title, String text});

/// Hands the reminders to Android, which keeps them over a restart.
Future<void> syncReminders() async {
  final list = reminders(
    store.sessions,
    store.workouts,
    DateTime.now(),
    perWeek: weeklyGoal.value,
    streak: _on(notifyStreakKey),
    longBreak: _on(notifyBreakKey),
  );
  await _call('reminders', {
    'channelName': tr.notifyChannelReminders,
    'list': [
      for (final r in list)
        {
          'id': r.id,
          'at': r.at.millisecondsSinceEpoch,
          'title': r.title,
          'text': r.text,
        },
    ],
  });
}

/// The hour trainings usually start at: the median of the last 20, 17 without any.
int usualHour(List<Session> sessions) {
  final hours = [for (final s in sessions.take(20)) s.date.hour]..sort();
  return hours.isEmpty ? 17 : hours[hours.length ~/ 2];
}

/// Reminders from the trainings so far ([sessions] newest first), for the next three weeks; any
/// training reschedules them all. They come two hours before the usual training time, not before 8
/// and not after 19 o'clock.
/// - [streak]: on the last day the weekly goal can still be made, one training a day, as long as it
///   isn't made yet. Not in the week of the very first training, like the card at home.
/// - [longBreak]: 7 and 14 days after the last training, naming the workout trained longest ago.
List<Reminder> reminders(
  List<Session> sessions,
  List<Workout> workouts,
  DateTime now, {
  required int perWeek,
  bool streak = true,
  bool longBreak = true,
}) {
  if (sessions.isEmpty) return [];
  final hour = (usualHour(sessions) - 2).clamp(8, 19);
  DateTime at(DateTime day) => DateTime(day.year, day.month, day.day, hour);
  final result = <Reminder>[];
  final thisMonday = mondayOf(now);
  if (streak && sessions.last.date.isBefore(thisMonday)) {
    final weeks = weekStreak(
      sessions.map((s) => s.date),
      now,
      perWeek: perWeek,
    );
    for (var w = 0; w < 3; w++) {
      final monday = DateTime(
        thisMonday.year,
        thisMonday.month,
        thisMonday.day + 7 * w,
      );
      final done = w == 0
          ? sessions.where((s) => !s.date.isBefore(monday)).length
          : 0;
      final needed = perWeek - done;
      if (needed <= 0 || needed > 7) continue;
      // The day from which on it takes a training every day: Sunday for one, Saturday for two, …
      final day = at(
        DateTime(monday.year, monday.month, monday.day + 7 - needed),
      );
      if (!day.isAfter(now)) continue;
      result.add((
        id: 100 + w,
        at: day,
        title: w == 0 && weeks > 0
            ? tr.notifyStreakTitle(tr.weeksCount(weeks))
            : tr.weekTitle(needed),
        text: needed == 1
            ? tr.notifyStreakLastDay
            : tr.notifyStreakDays(needed),
      ));
    }
  }
  if (longBreak) {
    final last = sessions.first.date;
    final next = _longestAgo(sessions, workouts);
    for (final days in const [7, 14]) {
      final day = at(DateTime(last.year, last.month, last.day + days));
      if (!day.isAfter(now)) continue;
      result.add((
        id: 200 + days,
        at: day,
        title: tr.notifyBreakTitle(days),
        text: next == null ? tr.notifyBreakText : tr.notifyBreakNext(next),
      ));
    }
  }
  return result;
}

/// The workout whose last training is longest ago (never trained counts as longest).
String? _longestAgo(List<Session> sessions, List<Workout> workouts) {
  if (workouts.isEmpty) return null;
  DateTime? lastOf(Workout w) =>
      sessions.where((s) => s.workoutId == w.id).firstOrNull?.date;
  final sorted = [...workouts]
    ..sort((a, b) {
      final x = lastOf(a), y = lastOf(b);
      if (x == null || y == null) return x == null ? (y == null ? 0 : -1) : 1;
      return x.compareTo(y);
    });
  return sorted.first.name;
}
