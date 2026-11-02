import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';
import 'sync.dart';

/// Guided GitHub setup: log in → create the data repo → give Ferrolog access → pick it.
/// The first two happen on github.com; repos are reloaded whenever the app comes back.
class SyncSettings extends StatefulWidget {
  const SyncSettings({super.key});

  @override
  State<SyncSettings> createState() => _SyncSettingsState();
}

class _SyncSettingsState extends State<SyncSettings> {
  late final AppLifecycleListener lifecycle = AppLifecycleListener(onResume: () {
    if (sync.loggedIn && pending == null) loadRepos();
  });
  DeviceCode? pending; // login in progress
  List<String>? repos; // null = not loaded yet
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    lifecycle;
    if (sync.loggedIn) loadRepos();
  }

  @override
  void dispose() {
    lifecycle.dispose();
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

  Future<void> open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  Future<void> login() => run(() async {
        final code = await sync.startLogin();
        setState(() => pending = code);
        await Clipboard.setData(ClipboardData(text: code.userCode));
        await open(code.verificationUri);
        try {
          await sync.finishLogin(code);
        } finally {
          pending = null;
        }
        await loadRepos();
      });

  Future<void> loadRepos() => run(() async {
        repos = await sync.repos();
        // Exactly one repo shared with Ferrolog: that's the one, start syncing right away.
        if (repos!.length == 1 && sync.repo != repos!.single) await select(repos!.single);
      });

  Future<void> select(String repo) async {
    await sync.selectRepo(repo);
    setState(() {});
    await sync.push(store.exportJson());
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final code = pending;
    final repos = this.repos;

    Widget step(int n, String title, String subtitle, {required bool done, VoidCallback? onTap}) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: done ? const Icon(Icons.check) : Text('$n')),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: onTap == null ? null : const Icon(Icons.open_in_new),
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('GitHub-Sync')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ferrolog speichert deine Trainingsdaten als ferrolog.json in einem privaten '
            'GitHub-Repo. Dort kann deine KI sie lesen. Ferrolog bekommt nur Zugriff auf '
            'diese eine Datei in dem Repo, das du freigibst.',
          ),
          const SizedBox(height: 16),
          if (code != null) ...[
            Text('Gib diesen Code auf GitHub ein (ist schon kopiert):', style: text.bodyMedium),
            const SizedBox(height: 8),
            SelectableText(code.userCode, style: text.displaySmall, textAlign: TextAlign.center),
            TextButton(onPressed: () => open(code.verificationUri), child: Text(code.verificationUri)),
            const Text('Danach einfach zurück in die App wechseln.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
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
            if (repos != null && repos.isEmpty) ...[
              const SizedBox(height: 8),
              step(1, 'Daten-Repo anlegen', 'Privates Repo „ferrolog-data“ auf GitHub erstellen',
                  done: false,
                  onTap: () => open('https://github.com/new?name=ferrolog-data&visibility=private'
                      '&description=Ferrolog+Trainingsdaten')),
              step(2, 'Ferrolog Zugriff geben', '„Only select repositories“ → ferrolog-data wählen',
                  done: false, onTap: () => open('https://github.com/apps/$githubAppSlug/installations/new')),
              const Text('Danach zurück in die App wechseln, Ferrolog findet das Repo dann selbst.'),
            ],
            if (repos != null && repos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(repos.length == 1 ? 'Repo' : 'Repo auswählen', style: text.titleSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final r in repos)
                  ChoiceChip(label: Text(r), selected: sync.repo == r, onSelected: (_) => select(r)),
              ]),
              const SizedBox(height: 4),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Weiteres Repo freigeben'),
                onPressed: () => open('https://github.com/apps/$githubAppSlug/installations/new'),
              ),
              if (sync.configured)
                FilledButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Jetzt synchronisieren'),
                  onPressed: busy ? null : () => run(() => sync.push(store.exportJson())),
                ),
            ],
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
