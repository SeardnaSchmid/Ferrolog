import 'dart:convert';

import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/settings.dart';
import 'package:ferrolog/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a conflict opens the dialog with both sides; restore brings the history back', (tester) async {
    SharedPreferences.setMockInitialValues({'sync.token': 't0k', 'sync.repo': 'me/data'});
    prefs = await SharedPreferences.getInstance();
    store = Store(prefs);
    var file = jsonEncode({
      'app': 'ferrolog',
      'version': 1,
      'workouts': [Workout(id: 'a', name: 'A').toJson()],
      'sessions': [
        for (final d in [8, 6, 4])
          Session(id: 's$d', workoutId: 'a', workoutName: 'A', date: DateTime(2026, 11, d), exercises: []).toJson(),
      ],
    });
    var fileSha = 'old phone';
    final puts = <String>[];
    sync = GitHubSync(prefs, MockClient((req) async {
      if (req.url.path == '/user/installations') return http.Response(jsonEncode({'installations': [{'id': 1}]}), 200);
      if (req.url.path.endsWith('/repositories')) {
        return http.Response(jsonEncode({'repositories': [{'full_name': 'me/data'}]}), 200);
      }
      if (req.method == 'GET') {
        return req.headers['Accept'] == 'application/vnd.github.raw+json'
            ? http.Response.bytes(utf8.encode(file), 200)
            : http.Response(jsonEncode({'sha': fileSha}), 200);
      }
      final body = jsonDecode(req.body);
      if (body['sha'] != fileSha) return http.Response('', 409);
      puts.add(body['sha']);
      fileSha = 'new';
      return http.Response(jsonEncode({'content': {'sha': fileSha}}), 200);
    }));
    store.onSaved = () => sync.push(store.exportJson());

    await sync.push(store.exportJson());
    expect(sync.conflict.value, isTrue);
    expect(puts, isEmpty);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SyncSettings())));
    await tester.pumpAndSettle();
    expect(find.text('Auf GitHub: 3 Trainings, letztes am 08.11.2026'), findsOneWidget);
    expect(find.text('Auf diesem Gerät: 0 Trainings'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Von GitHub wiederherstellen'));
    await tester.pumpAndSettle();
    expect([for (final s in store.sessions) s.id], ['s8', 's6', 's4']);
    expect(store.workouts.single.id, 'a');
    expect(puts, ['old phone'], reason: 'the save after the restore pushes without a conflict');
    expect(sync.conflict.value, isFalse);
    expect(find.text('Von GitHub wiederhergestellt'), findsOneWidget);

    // Edited elsewhere, with one training more than here: overwriting asks twice.
    final j = jsonDecode(file);
    (j['sessions'] as List).add(Session(id: 's2', workoutId: 'a', workoutName: 'A', date: DateTime(2026, 11, 2), exercises: []).toJson());
    file = jsonEncode(j);
    fileSha = 'by hand';
    await store.saveWorkout(Workout(name: 'Neu'));
    await tester.pumpAndSettle();
    expect(sync.conflict.value, isTrue);
    expect(puts, hasLength(1));

    final tile = find.widgetWithText(ListTile, 'Von GitHub wiederherstellen');
    await tester.pump(const Duration(seconds: 5)); // the snack bar goes
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(tile, 200);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('Auf GitHub: 4 Trainings, letztes am 08.11.2026'), findsOneWidget);
    await tester.tap(find.text('GitHub überschreiben'));
    await tester.pumpAndSettle();
    expect(find.textContaining('mehr Trainings (4) als hier (3)'), findsOneWidget);
    await tester.tap(find.text('Ja'));
    await tester.pumpAndSettle();
    expect(puts.last, 'by hand');
    expect(store.sessions, hasLength(3), reason: 'nothing taken from GitHub');
  });
}
