import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';
import 'sync.dart';

class SyncSettings extends StatefulWidget {
  const SyncSettings({super.key});

  @override
  State<SyncSettings> createState() => _SyncSettingsState();
}

class _SyncSettingsState extends State<SyncSettings> {
  late final repo = TextEditingController(text: sync.repo);
  late final branch = TextEditingController(text: sync.branch);
  late final path = TextEditingController(text: sync.path);
  DeviceCode? pending; // login in progress
  List<String> repos = [];
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (sync.loggedIn) loadRepos();
  }

  @override
  void dispose() {
    for (final c in [repo, branch, path]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> login() => run(() async {
        final code = await sync.startLogin();
        setState(() => pending = code);
        await Clipboard.setData(ClipboardData(text: code.userCode));
        await launchUrl(Uri.parse(code.verificationUri), mode: LaunchMode.externalApplication);
        try {
          await sync.finishLogin(code);
        } finally {
          pending = null;
        }
        await loadRepos();
      });

  Future<void> loadRepos() => run(() async {
        repos = await sync.repos();
        if (repos.length == 1 && repo.text.isEmpty) repo.text = repos.single;
      });

  Future<void> saveAndSync() => run(() async {
        await sync.configure(repo: repo.text, branch: branch.text, path: path.text);
        if (!sync.configured) throw 'Repo auswählen (besitzer/name).';
        await sync.push(store.exportJson());
      });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    InputDecoration field(String label, [String? hint]) =>
        InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder());

    final code = pending;
    return Scaffold(
      appBar: AppBar(title: const Text('GitHub-Sync')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Nach jedem Training und jeder Workout-Änderung wird ferrolog.json in dein '
            'GitHub-Repo geschrieben. Dort kann deine KI die Daten lesen.',
          ),
          const SizedBox(height: 16),
          if (code != null) ...[
            Text('Gib diesen Code auf GitHub ein (ist schon kopiert):', style: text.bodyMedium),
            const SizedBox(height: 8),
            SelectableText(code.userCode, style: text.displaySmall, textAlign: TextAlign.center),
            TextButton(
              onPressed: () => launchUrl(Uri.parse(code.verificationUri), mode: LaunchMode.externalApplication),
              child: Text(code.verificationUri),
            ),
            const Center(child: CircularProgressIndicator()),
          ] else if (!sync.loggedIn)
            FilledButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Mit GitHub anmelden'),
              onPressed: busy ? null : login,
            )
          else ...[
            Row(children: [
              const Icon(Icons.check_circle_outline),
              const SizedBox(width: 8),
              const Expanded(child: Text('Mit GitHub verbunden')),
              TextButton(
                onPressed: busy ? null : () => run(() async => sync.logout()),
                child: const Text('Abmelden'),
              ),
            ]),
            const SizedBox(height: 12),
            if (repos.isNotEmpty)
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final r in repos)
                  ChoiceChip(
                    label: Text(r),
                    selected: repo.text == r,
                    onSelected: (_) => setState(() => repo.text = r),
                  ),
              ])
            else if (!busy)
              const Text('Keine Repos gefunden. Installiere die Ferrolog-App auf deinem Daten-Repo.'),
            const SizedBox(height: 12),
            TextField(controller: repo, decoration: field('Repo', 'besitzer/ferrolog-data')),
            const SizedBox(height: 12),
            TextField(controller: branch, decoration: field('Branch')),
            const SizedBox(height: 12),
            TextField(controller: path, decoration: field('Datei im Repo')),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('Speichern & jetzt synchronisieren'),
              onPressed: busy ? null : saveAndSync,
            ),
          ],
          const SizedBox(height: 16),
          if (busy && code == null) const LinearProgressIndicator(),
          if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ValueListenableBuilder(valueListenable: sync.status, builder: (_, s, _) => Text(s)),
        ],
      ),
    );
  }
}
