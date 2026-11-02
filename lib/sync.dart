import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Pushes the full export JSON to a file in a GitHub repo via the Contents API,
/// so an AI (or anything else) can read the training data from there.
/// Every push is a full snapshot, so a failed push is fixed by the next one.
// ponytail: token sits in app-private prefs, not the keystore. Use a fine-grained
// token limited to the one repo; move to flutter_secure_storage if that's not enough.
class GitHubSync {
  final SharedPreferences _prefs;
  final http.Client _client;
  final status = ValueNotifier<String>('');

  GitHubSync(this._prefs, [http.Client? client]) : _client = client ?? http.Client() {
    status.value = _prefs.getString('sync.status') ?? '';
  }

  String get repo => _prefs.getString('sync.repo') ?? '';
  String get branch => _prefs.getString('sync.branch') ?? 'main';
  String get path => _prefs.getString('sync.path') ?? 'ferrolog.json';
  String get token => _prefs.getString('sync.token') ?? '';
  bool get configured => RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(repo) && token.isNotEmpty;

  Future<void> configure({required String repo, required String branch, required String path, required String token}) async {
    await _prefs.setString('sync.repo', repo.trim());
    await _prefs.setString('sync.branch', branch.trim().isEmpty ? 'main' : branch.trim());
    await _prefs.setString('sync.path', path.trim().isEmpty ? 'ferrolog.json' : path.trim());
    await _prefs.setString('sync.token', token.trim());
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
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    };
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
        401 => 'Token ungültig',
        403 => 'Token hat keine Schreibrechte auf das Repo',
        404 => 'Repo oder Branch nicht gefunden',
        _ => 'HTTP ${r.statusCode}',
      };

  void _setStatus(String s) {
    status.value = s;
    _prefs.setString('sync.status', s);
  }

  static String _time(DateTime d) =>
      '${d.day}.${d.month}. ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
