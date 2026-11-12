import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Client ID of the FerroLog GitHub App (public, safe to commit). Setup in README.
const githubClientId = 'Iv23lidZNxih8vRT1Cab';

/// Slug of that app, for the install page `github.com/apps/<slug>/installations/new`.
const githubAppSlug = 'ferrolog-sync';

/// A pending device-flow login: show [userCode], let the user enter it at [verificationUri].
typedef DeviceCode = ({String deviceCode, String userCode, String verificationUri, int interval, DateTime expiresAt});

/// The file on GitHub is not the one this install pushed last: another device, a hand edit or an AI
/// changed it, or this is a fresh install. Pushing would overwrite it, so the user has to decide.
class SyncConflict implements Exception {
  final String sha;
  const SyncConflict(this.sha);

  @override
  String toString() => 'Konflikt: Daten auf GitHub sind neuer oder fremd';
}

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

  /// True after a push found a [SyncConflict]; pushes pause until the user restores or overwrites.
  final conflict = ValueNotifier(false);

  /// Asked only when this install has no [lastSha] yet (installs from before the guard): true if the
  /// remote file (raw JSON) holds nothing this device lacks, so pushing over it loses nothing.
  bool Function(String remote)? remoteCovered;

  GitHubSync(this._prefs, [http.Client? client]) : _client = client ?? http.Client() {
    status.value = _prefs.getString('sync.status') ?? '';
  }

  String get repo => _prefs.getString('sync.repo') ?? '';
  /// Fixed: the GitHub App's "Single file" permission only grants this one path.
  static const path = 'ferrolog.json';
  String get token => _prefs.getString('sync.token') ?? '';
  bool get loggedIn => token.isNotEmpty;
  bool get configured => RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(repo) && loggedIn;

  Future<void> selectRepo(String repo) async {
    if (repo != this.repo) await _forget();
    await _prefs.setString('sync.repo', repo);
  }

  /// Blob sha of the file as this install last wrote (or restored) it; a different sha on GitHub is a conflict.
  String? get lastSha => _prefs.getString('sync.lastSha');

  /// Takes the file with [sha] as ours: the next push overwrites it (after a restore, or "GitHub überschreiben").
  Future<void> adopt(String sha) async {
    await _prefs.setString('sync.lastSha', sha);
    conflict.value = false;
  }

  Future<void> _forget() async {
    await _prefs.remove('sync.lastSha');
    conflict.value = false;
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
      expiresAt: DateTime.now().add(Duration(seconds: j['expires_in'] as int)),
    );
  }

  /// Polls until the user confirmed the code in the browser, then stores the token.
  /// Network errors are retried: Android cuts background apps off the network
  /// while the user is in the browser entering the code.
  Future<void> finishLogin(DeviceCode code, {Duration Function(int seconds)? wait}) async {
    var interval = code.interval;
    while (true) {
      await Future.delayed((wait ?? (s) => Duration(seconds: s))(interval));
      if (DateTime.now().isAfter(code.expiresAt)) throw 'Code abgelaufen, bitte neu anmelden.';
      final Map<String, dynamic> j;
      try {
        j = await _oauth('oauth/access_token', {
          'device_code': code.deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        });
      } on http.ClientException {
        continue;
      }
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
    await _forget();
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
    if (!configured || conflict.value) return Future.value();
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
      } on SyncConflict catch (e) {
        conflict.value = true;
        _setStatus('$e');
        break;
      } catch (e) {
        _setStatus('Fehler ${_time(DateTime.now())}: $e');
      }
      next = _queued;
    }
    _running = null;
  }

  Uri get _url => Uri.https('api.github.com', '/repos/$repo/contents/$path');

  /// Blob sha of the file on GitHub, null when it doesn't exist yet.
  Future<String?> _remoteSha() async {
    final res = await _client.get(_url, headers: _headers);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw _error(res);
    return jsonDecode(res.body)['sha'];
  }

  /// The file on GitHub as it is, null when there is none. The raw media type has no 1 MB limit,
  /// unlike the JSON response with base64 content; the sha comes from a metadata request first.
  Future<({String json, String sha})?> fetchRemote() async {
    final sha = await _remoteSha();
    if (sha == null) return null;
    final res = await _client.get(_url, headers: {..._headers, 'Accept': 'application/vnd.github.raw+json'});
    if (res.statusCode != 200) throw _error(res);
    return (json: utf8.decode(res.bodyBytes), sha: sha);
  }

  Future<void> _put(String json) async {
    final headers = _headers;
    // The API needs the current file's sha to overwrite it; none means it doesn't exist yet.
    final sha = await _remoteSha();
    if (sha != null && sha != lastSha) {
      final covered = remoteCovered;
      if (lastSha != null || covered == null || !covered((await fetchRemote())?.json ?? '')) throw SyncConflict(sha);
    }

    final res = await _client.put(
      _url,
      headers: headers,
      body: jsonEncode({
        'message': 'FerroLog sync',
        'content': base64Encode(utf8.encode(json)),
        'sha': ?sha,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) throw _error(res);
    if (jsonDecode(res.body)['content']?['sha'] case final String written) await adopt(written);
  }

  static String _error(http.Response r) => switch (r.statusCode) {
        401 => 'Anmeldung abgelaufen, bitte neu anmelden',
        403 => 'Keine Schreibrechte – hat FerroLog Zugriff auf das Repo?',
        404 => 'Repo nicht gefunden – hat FerroLog Zugriff darauf?',
        _ => 'HTTP ${r.statusCode}',
      };

  void _setStatus(String s) {
    status.value = s;
    _prefs.setString('sync.status', s);
  }

  static String _time(DateTime d) =>
      '${d.day}.${d.month}. ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
