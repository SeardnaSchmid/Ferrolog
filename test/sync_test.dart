import 'dart:convert';

import 'package:ferrolog/sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('creates, then overwrites with sha, and reports errors', () async {
    SharedPreferences.setMockInitialValues({});
    String? fileSha;
    String? stored;
    var fail = false;
    final puts = <Map<String, dynamic>>[];

    final client = MockClient((req) async {
      expect(req.url.path, '/repos/me/data/contents/ferrolog.json');
      expect(req.headers['Authorization'], 'Bearer t0k');
      if (fail) return http.Response('', 401);
      if (req.method == 'GET') {
        return fileSha == null ? http.Response('', 404) : http.Response(jsonEncode({'sha': fileSha}), 200);
      }
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      puts.add(body);
      if (body['sha'] != fileSha) return http.Response('', 409);
      stored = utf8.decode(base64Decode(body['content']));
      final created = fileSha == null;
      fileSha = 'sha${puts.length}';
      return http.Response(jsonEncode({'content': {'sha': fileSha}}), created ? 201 : 200);
    });

    final sync = GitHubSync(await SharedPreferences.getInstance(), client);
    await sync.push('{"a":1}'); // not configured -> no request
    expect(puts, isEmpty);

    await sync.selectRepo('me/data');
    await sync.push('{"a":1}'); // not logged in -> no request
    expect(puts, isEmpty);
    await (await SharedPreferences.getInstance()).setString('sync.token', 't0k');
    await sync.push('{"ä":1}');
    expect(stored, '{"ä":1}');
    expect(puts.single.containsKey('sha'), isFalse);

    await sync.push('{"ä":2}');
    expect(stored, '{"ä":2}');
    expect(puts.last['sha'], 'sha1');
    expect(sync.status.value, startsWith('Synchronisiert'));

    fail = true;
    await sync.push('{}');
    expect(sync.status.value, contains('neu anmelden'));
  });

  group('overwrite guard', () {
    late String? fileSha;
    late String content;
    late List<Map<String, dynamic>> puts;
    late List<http.Request> gets;
    late GitHubSync sync;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'sync.token': 't0k', 'sync.repo': 'me/data'});
      fileSha = 'elsewhere';
      content = '{"app":"ferrolog"}';
      puts = [];
      gets = [];
      final client = MockClient((req) async {
        if (req.method == 'GET') {
          gets.add(req);
          if (fileSha == null) return http.Response('', 404);
          if (req.headers['Accept'] == 'application/vnd.github.raw+json') return http.Response.bytes(utf8.encode(content), 200);
          return http.Response(jsonEncode({'sha': fileSha}), 200);
        }
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (body['sha'] != fileSha) return http.Response('', 409);
        puts.add(body);
        fileSha = 'mine${puts.length}';
        return http.Response(jsonEncode({'content': {'sha': fileSha}}), 200);
      });
      sync = GitHubSync(await SharedPreferences.getInstance(), client);
    });

    test('a foreign file is not overwritten until adopted', () async {
      await sync.push('{"a":1}');
      expect(puts, isEmpty);
      expect(sync.conflict.value, isTrue);
      expect(sync.status.value, 'Konflikt: Daten auf GitHub sind neuer oder fremd');

      gets.clear();
      await sync.push('{"a":2}');
      expect(gets, isEmpty, reason: 'paused while in conflict');

      await sync.adopt('elsewhere'); // "GitHub überschreiben"
      await sync.push('{"a":3}');
      expect(puts.single['sha'], 'elsewhere');
      expect(sync.lastSha, 'mine1');
      await sync.push('{"a":4}'); // this install pushed last: silent
      expect(puts, hasLength(2));

      fileSha = 'edited by hand';
      await sync.push('{"a":5}');
      expect(puts, hasLength(2));
      expect(sync.conflict.value, isTrue);
    });

    test('a missing file is created without asking', () async {
      fileSha = null;
      await sync.push('{"a":1}');
      expect(puts.single.containsKey('sha'), isFalse);
      expect(sync.conflict.value, isFalse);
    });

    test('without a known sha, a file holding nothing new is overwritten', () async {
      final seen = <String>[];
      sync.remoteCovered = (remote) {
        seen.add(remote);
        return true;
      };
      await sync.push('{"a":1}');
      expect(seen, [content]);
      expect(puts, hasLength(1));

      sync.remoteCovered = (_) => fail('only asked without a known sha');
      fileSha = 'elsewhere';
      await sync.push('{"a":2}');
      expect(sync.conflict.value, isTrue);
    });

    test('fetchRemote reads the raw file and its sha', () async {
      content = '{"app":"ferrolog","ä":1}';
      final remote = await sync.fetchRemote();
      expect(remote?.json, content);
      expect(remote?.sha, 'elsewhere');
      expect(gets.last.headers['Accept'], 'application/vnd.github.raw+json');
      expect(gets.last.headers['Authorization'], 'Bearer t0k');
      fileSha = null;
      expect(await sync.fetchRemote(), isNull);
    });

    test('logout and another repo forget the sha', () async {
      await sync.adopt('x');
      await sync.selectRepo('me/data');
      expect(sync.lastSha, 'x');
      await sync.selectRepo('me/other');
      expect(sync.lastSha, isNull);
      await sync.adopt('y');
      await sync.logout();
      expect(sync.lastSha, isNull);
    });
  });

  test('device flow login polls until the token arrives', () async {
    SharedPreferences.setMockInitialValues({});
    final answers = <Object>[
      {'error': 'authorization_pending'},
      http.ClientException('Failed host lookup'), // app in background

      {'error': 'slow_down', 'interval': 10},
      {'access_token': 'ghu_x'},
    ];
    final client = MockClient((req) async {
      expect(req.url.host, 'github.com');
      expect(req.bodyFields['grant_type'], 'urn:ietf:params:oauth:grant-type:device_code');
      expect(req.bodyFields['device_code'], 'dc');
      final a = answers.removeAt(0);
      if (a is Exception) throw a;
      return http.Response(jsonEncode(a), 200);
    });
    final sync = GitHubSync(await SharedPreferences.getInstance(), client);
    final waits = <int>[];
    await sync.finishLogin(
      (deviceCode: 'dc', userCode: 'ABCD-1234', verificationUri: 'https://github.com/login/device', interval: 5,
          expiresAt: DateTime.now().add(const Duration(minutes: 15))),
      wait: (s) {
        waits.add(s);
        return Duration.zero;
      },
    );
    expect(sync.token, 'ghu_x');
    expect(sync.loggedIn, isTrue);
    expect(waits, [5, 5, 5, 10]);
  });
}
