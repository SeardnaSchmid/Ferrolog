import 'package:flutter/material.dart';

import 'main.dart';

class SyncSettings extends StatefulWidget {
  const SyncSettings({super.key});

  @override
  State<SyncSettings> createState() => _SyncSettingsState();
}

class _SyncSettingsState extends State<SyncSettings> {
  late final repo = TextEditingController(text: sync.repo);
  late final branch = TextEditingController(text: sync.branch);
  late final path = TextEditingController(text: sync.path);
  late final token = TextEditingController(text: sync.token);
  bool busy = false;

  @override
  void dispose() {
    for (final c in [repo, branch, path, token]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> saveAndSync() async {
    setState(() => busy = true);
    await sync.configure(repo: repo.text, branch: branch.text, path: path.text, token: token.text);
    if (sync.configured) {
      await sync.push(store.exportJson());
    } else {
      sync.status.value = 'Repo (besitzer/name) und Token angeben.';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration field(String label, [String? hint]) =>
        InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder());
    return Scaffold(
      appBar: AppBar(title: const Text('GitHub-Sync')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Nach jedem Training und jeder Workout-Änderung wird ferrolog.json in dein '
            'GitHub-Repo geschrieben. Dort kann deine KI die Daten lesen.\n\n'
            'Token: GitHub → Settings → Developer settings → Fine-grained tokens. '
            'Nur dieses eine Repo freigeben, Berechtigung „Contents: Read and write“.',
          ),
          const SizedBox(height: 16),
          TextField(controller: repo, decoration: field('Repo', 'besitzer/ferrolog-data')),
          const SizedBox(height: 12),
          TextField(controller: branch, decoration: field('Branch')),
          const SizedBox(height: 12),
          TextField(controller: path, decoration: field('Datei im Repo')),
          const SizedBox(height: 12),
          TextField(controller: token, obscureText: true, autocorrect: false, decoration: field('Token')),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            label: const Text('Speichern & jetzt synchronisieren'),
            onPressed: busy ? null : saveAndSync,
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder(valueListenable: sync.status, builder: (_, s, _) => Text(s)),
        ],
      ),
    );
  }
}
