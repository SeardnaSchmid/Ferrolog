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
        expect(req.url.queryParameters['ref'], 'main');
        return fileSha == null ? http.Response('', 404) : http.Response(jsonEncode({'sha': fileSha}), 200);
      }
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      puts.add(body);
      if (body['sha'] != fileSha) return http.Response('', 409);
      stored = utf8.decode(base64Decode(body['content']));
      final created = fileSha == null;
      fileSha = 'sha${puts.length}';
      return http.Response('{}', created ? 201 : 200);
    });

    final sync = GitHubSync(await SharedPreferences.getInstance(), client);
    await sync.push('{"a":1}'); // not configured -> no request
    expect(puts, isEmpty);

    await sync.configure(repo: 'me/data', branch: '');
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

  test('device flow login polls until the token arrives', () async {
    SharedPreferences.setMockInitialValues({});
    final answers = [
      {'error': 'authorization_pending'},
      {'error': 'slow_down', 'interval': 10},
      {'access_token': 'ghu_x'},
    ];
    final client = MockClient((req) async {
      expect(req.url.host, 'github.com');
      expect(req.bodyFields['grant_type'], 'urn:ietf:params:oauth:grant-type:device_code');
      expect(req.bodyFields['device_code'], 'dc');
      return http.Response(jsonEncode(answers.removeAt(0)), 200);
    });
    final sync = GitHubSync(await SharedPreferences.getInstance(), client);
    final waits = <int>[];
    await sync.finishLogin(
      (deviceCode: 'dc', userCode: 'ABCD-1234', verificationUri: 'https://github.com/login/device', interval: 5),
      wait: (s) {
        waits.add(s);
        return Duration.zero;
      },
    );
    expect(sync.token, 'ghu_x');
    expect(sync.loggedIn, isTrue);
    expect(waits, [5, 5, 10]);
  });
}
