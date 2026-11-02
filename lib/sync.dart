import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Client ID of the Ferrolog GitHub App (public, safe to commit). Setup in README.
const githubClientId = 'Iv23lidZNxih8vRT1Cab';

/// A pending device-flow login: show [userCode], let the user enter it at [verificationUri].
typedef DeviceCode = ({String deviceCode, String userCode, String verificationUri, int interval});

/// Pushes the full export JSON to a file in a GitHub repo via the Contents API,
/// so an AI (or anything else) can read the training data from there.
/// Every push is a full snapshot, so a failed push is fixed by the next one.
/// Login is GitHub's device flow for a GitHub App, so the token only reaches
/// repos the app is installed on.
// ponytail: token sits in app-private prefs, not the keystore; it only reaches the
// app's installed repos. Move to flutter_secure_storage if that's not enough.
class GitHubSync {
  final SharedPreferences _prefs;
  final http.Client _client;
  final status = ValueNotifier<String>('');

  GitHubSync(this._prefs, [http.Client? client]) : _client = client ?? http.Client() {
    status.value = _prefs.getString('sync.status') ?? '';
  }

  String get repo => _prefs.getString('sync.repo') ?? '';
  String get branch => _prefs.getString('sync.branch') ?? 'main';
  /// Fixed: the GitHub App's "Single file" permission only grants this one path.
  static const path = 'ferrolog.json';
  String get token => _prefs.getString('sync.token') ?? '';
  bool get loggedIn => token.isNotEmpty;
  bool get configured => RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(repo) && loggedIn;

  Future<void> configure({required String repo, required String branch}) async {
    await _prefs.setString('sync.repo', repo.trim());
    await _prefs.setString('sync.branch', branch.trim().isEmpty ? 'main' : branch.trim());
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  Future<Map<String, dynamic>> _oauth(String endpoint, Map<String, String> body) async {
    final res = await _client.post(
      Uri.https('github.com', '/login/$endpoint'),
      headers: {'Accept': 'application/json'},
      body: {'client_id': githubClientId, ...body},
    );
    if (res.statusCode != 200) throw 'GitHub-Login fehlgeschlagen (HTTP ${res.statusCode})';
    return jsonDecode(res.body);
  }

  Future<DeviceCode> startLogin() async {
    if (githubClientId.isEmpty) throw 'githubClientId in lib/sync.dart ist nicht gesetzt (siehe README).';
    final j = await _oauth('device/code', {});
    return (
      deviceCode: j['device_code'] as String,
      userCode: j['user_code'] as String,
      verificationUri: j['verification_uri'] as String,
      interval: j['interval'] as int,
    );
  }

  /// Polls until the user confirmed the code in the browser, then stores the token.
  Future<void> finishLogin(DeviceCode code, {Duration Function(int seconds)? wait}) async {
    var interval = code.interval;
    while (true) {
      await Future.delayed((wait ?? (s) => Duration(seconds: s))(interval));
      final j = await _oauth('oauth/access_token', {
        'device_code': code.deviceCode,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
      });
      switch (j['error']) {
        case null:
          await _prefs.setString('sync.token', j['access_token']);
          return;
        case 'authorization_pending':
          continue;
        case 'slow_down':
          interval = j['interval'] ?? interval + 5;
        case 'expired_token':
          throw 'Code abgelaufen, bitte neu anmelden.';
        case 'access_denied':
          throw 'Anmeldung abgelehnt.';
        default:
          throw 'GitHub-Login: ${j['error_description'] ?? j['error']}';
      }
    }
  }

  Future<void> logout() async {
    await _prefs.remove('sync.token');
    _setStatus('');
  }

  /// "owner/name" of every repo the app is installed on and the user can access.
  Future<List<String>> repos() async {
    Future<Map<String, dynamic>> get(String path) async {
      final res = await _client.get(Uri.https('api.github.com', path), headers: _headers);
      if (res.statusCode != 200) throw _error(res);
      return jsonDecode(res.body);
    }

    final installs = await get('/user/installations');
    return [
      for (final i in installs['installations'])
        for (final r in (await get('/user/installations/${i['id']}/repositories'))['repositories'])
          r['full_name'] as String,
    ];
  }

  Future<void>? _running;
  String? _queued;

  /// Pushes [json]; if a push is already running, only the newest pending snapshot follows it.
  Future<void> push(String json) {
    if (!configured) return Future.value();
    if (_running != null) {
      _queued = json;
      return _running!;
    }
    return _running = _pushLoop(json);
  }

  Future<void> _pushLoop(String json) async {
    String? next = json;
    while (next != null) {
      _queued = null;
      try {
        await _put(next);
        _setStatus('Synchronisiert ${_time(DateTime.now())}');
      } catch (e) {
        _setStatus('Fehler ${_time(DateTime.now())}: $e');
      }
      next = _queued;
    }
    _running = null;
  }

  Future<void> _put(String json) async {
    final url = Uri.https('api.github.com', '/repos/$repo/contents/$path');
    final headers = _headers;
    // The API needs the current file's sha to overwrite it; 404 means it doesn't exist yet.
    final current = await _client.get(url.replace(queryParameters: {'ref': branch}), headers: headers);
    if (current.statusCode != 200 && current.statusCode != 404) throw _error(current);
    final sha = current.statusCode == 200 ? jsonDecode(current.body)['sha'] : null;

    final res = await _client.put(
      url,
      headers: headers,
      body: jsonEncode({
        'message': 'Ferrolog sync',
        'content': base64Encode(utf8.encode(json)),
        'branch': branch,
        'sha': ?sha,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) throw _error(res);
  }

  static String _error(http.Response r) => switch (r.statusCode) {
        401 => 'Anmeldung abgelaufen, bitte neu anmelden',
        403 => 'Keine Schreibrechte – App auf dem Repo installiert?',
        404 => 'Repo oder Branch nicht gefunden – App auf dem Repo installiert?',
        _ => 'HTTP ${r.statusCode}',
      };

  void _setStatus(String s) {
    status.value = s;
    _prefs.setString('sync.status', s);
  }

  static String _time(DateTime d) =>
      '${d.day}.${d.month}. ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
