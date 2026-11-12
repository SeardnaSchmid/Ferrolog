import 'dart:convert';

import 'package:ferrolog/model.dart';
import 'package:ferrolog/sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Session _session(String id, DateTime date, {String workout = 'a'}) => Session(
      id: id,
      workoutId: workout,
      workoutName: 'A',
      date: date,
      exercises: [ExerciseLog(name: 'Kniebeuge', weight: 100, targetReps: 5, reps: [5, 5, 5])],
    );

/// A file as another device would have pushed it.
Map<String, dynamic> _remote({List<Session> sessions = const [], List<Workout> workouts = const [], Map<String, dynamic>? muscles}) => {
      'app': 'ferrolog',
      'version': 1,
      'exportedAt': '2026-11-08T20:00:00.000',
      'instructions': 'export only, ignored',
      'derived': {'ignored': true},
      'workouts': [for (final w in workouts) w.toJson()],
      'sessions': [for (final s in sessions) s.toJson()],
      'muscles': ?muscles,
    };

void main() {
  late Store store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = Store(await SharedPreferences.getInstance());
  });

  test('replace takes plans, trainings and muscles and keeps the running training', () async {
    store.workouts = [Workout(id: 'old', name: 'Alt')];
    store.sessions = [_session('mine', DateTime(2026, 11, 10))];
    await store.saveActive(_session('running', DateTime(2026, 11, 12)));
    await store.importJson(
      _remote(
        sessions: [_session('s2', DateTime(2026, 11, 8)), _session('s1', DateTime(2026, 11, 6))],
        workouts: [Workout(id: 'a', name: 'A', exercises: [Exercise(name: 'Kniebeuge', weight: 102.5)])],
        muscles: {'Atemübung': {'primary': ['core']}},
      ),
      merge: false,
    );
    expect([for (final s in store.sessions) s.id], ['s2', 's1']);
    expect(store.workouts.single.exercises.single.weight, 102.5);
    expect(store.muscles.keys, ['Atemübung']);
    expect(store.active?.id, 'running');

    final reloaded = Store(await SharedPreferences.getInstance());
    expect(reloaded.sessions, hasLength(2), reason: 'saved');
    expect(reloaded.active?.id, 'running');
  });

  test('merge joins trainings by id (ours win) and plans by id (theirs win)', () async {
    final ours = _session('both', DateTime(2026, 11, 8))..note = 'ours';
    store.sessions = [_session('only here', DateTime(2026, 11, 10)), ours];
    store.workouts = [Workout(id: 'a', name: 'A alt'), Workout(id: 'local', name: 'Nur hier')];
    store.muscles = {'Curl': 'ours', 'Rudern': 'ours'};
    await store.importJson(
      _remote(
        sessions: [_session('both', DateTime(2026, 11, 8))..note = 'theirs', _session('only there', DateTime(2026, 11, 9))],
        workouts: [Workout(id: 'a', name: 'A neu')],
        muscles: {'Curl': 'theirs'},
      ),
      merge: true,
    );
    expect([for (final s in store.sessions) s.id], ['only here', 'only there', 'both'], reason: 'newest first');
    expect(store.sessions.last.note, 'ours');
    expect([for (final w in store.workouts) w.name], ['A neu', 'Nur hier']);
    expect(store.muscles, {'Curl': 'theirs', 'Rudern': 'ours'});
  });

  test('a foreign, newer or broken file is refused and changes nothing', () async {
    store.sessions = [_session('mine', DateTime(2026, 11, 10))];
    var saved = 0;
    store.onSaved = () => saved++;
    for (final (file, message) in [
      ({'app': 'other', 'version': 1, 'workouts': [], 'sessions': []}, 'keine FerroLog-Datei'),
      ({..._remote(), 'version': dataVersion + 1}, 'bitte die App aktualisieren'),
      ({'app': 'ferrolog', 'version': 1}, 'fehlen'),
      ({..._remote(), 'sessions': [{'id': 'x'}]}, 'beschädigt'),
      ('[]', 'keine FerroLog-Datei'),
    ]) {
      await expectLater(
        store.importJson(file, merge: false),
        throwsA(isA<FormatException>().having((e) => e.message.toLowerCase(), 'message', contains(message.toLowerCase()))),
      );
    }
    expect(store.sessions.single.id, 'mine');
    expect(saved, 0);
  });

  test('covers: a remote file holding nothing new', () {
    expect(store.covers(jsonEncode(_remote())), isFalse, reason: 'nothing here yet');
    store.sessions = [_session('s1', DateTime(2026, 11, 6)), _session('s2', DateTime(2026, 11, 8))];
    store.workouts = [Workout(id: 'a', name: 'A')];
    expect(store.covers(jsonEncode(_remote(sessions: [store.sessions.first], workouts: store.workouts))), isTrue);
    expect(store.covers(jsonEncode(_remote(sessions: [_session('s3', DateTime(2026, 11, 9))]))), isFalse);
    expect(store.covers(jsonEncode(_remote(workouts: [Workout(id: 'b', name: 'B')]))), isFalse);
    expect(store.covers('not json'), isFalse);
  });

  test('fresh install: nothing is pushed until restore, then the next save pushes', () async {
    SharedPreferences.setMockInitialValues({'sync.token': 't0k', 'sync.repo': 'me/data'});
    final prefs = await SharedPreferences.getInstance();
    store = Store(prefs);
    final history = [for (var i = 0; i < 100; i++) _session('s$i', DateTime(2026, 11, 8).subtract(Duration(days: 2 * i)))];
    var file = jsonEncode(_remote(sessions: history, workouts: [Workout(id: 'a', name: 'A')]));
    var fileSha = 'from the old phone';
    final puts = <Map<String, dynamic>>[];
    final client = MockClient((req) async {
      if (req.method == 'GET') {
        return req.headers['Accept'] == 'application/vnd.github.raw+json'
            ? http.Response.bytes(utf8.encode(file), 200)
            : http.Response(jsonEncode({'sha': fileSha}), 200);
      }
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      if (body['sha'] != fileSha) return http.Response('', 409);
      puts.add(body);
      file = utf8.decode(base64Decode(body['content']));
      fileSha = 'new${puts.length}';
      return http.Response(jsonEncode({'content': {'sha': fileSha}}), 200);
    });
    final sync = GitHubSync(prefs, client)..remoteCovered = store.covers;
    store.onSaved = () => sync.push(store.exportJson());

    await store.saveWorkout(Workout(name: 'Erstes Workout')); // the guard holds
    await pumpEventQueue();
    expect(puts, isEmpty);
    expect(sync.conflict.value, isTrue);

    final remote = (await sync.fetchRemote())!;
    await store.importJson(jsonDecode(remote.json), merge: store.sessions.isNotEmpty, beforeSave: () => sync.adopt(remote.sha));
    await pumpEventQueue();
    expect(store.sessions, hasLength(100));
    expect(store.workouts.single.id, 'a');
    expect(puts.single['sha'], 'from the old phone');
    expect(sync.conflict.value, isFalse);

    await store.saveWorkout(Workout(name: 'Neu'));
    await pumpEventQueue();
    expect(puts, hasLength(2));
    expect((jsonDecode(file)['sessions'] as List), hasLength(100));
  });
}
