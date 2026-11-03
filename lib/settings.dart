import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';
import 'sync.dart';
import 'units.dart';

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

  /// In-app browser tab on purpose: an installed GitHub app would grab github.com
  /// links and show a 404 for the app installation pages.
  Future<void> open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);

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

    // A tab of the home screen, so no Scaffold of its own.
    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Pause-Ende', style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          for (final (key, icon, title, subtitle) in const [
            ('rest.sound', Icons.volume_up_outlined, 'Ton', 'Signalton, wenn die Pause bei 0 ankommt'),
            ('rest.vibrate', Icons.vibration, 'Vibration', 'Kurz vibrieren, wenn die Pause bei 0 ankommt'),
          ])
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(icon),
              title: Text(title),
              subtitle: Text(subtitle),
              value: prefs.getBool(key) ?? true,
              onChanged: (v) async {
                await prefs.setBool(key, v);
                setState(() {});
              },
            ),
          const Divider(height: 32),
          Text('Serie', style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 4),
          Text('Trainings pro Woche, damit die Woche für deine Serie zählt', style: text.bodyMedium),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [for (var n = 1; n <= 7; n++) ButtonSegment(value: n, label: Text('$n×'))],
            selected: {weeklyGoal.value},
            onSelectionChanged: (v) async {
              weeklyGoal.value = v.single;
              await prefs.setInt('streak.perWeek', v.single);
              setState(() {});
            },
          ),
          const Divider(height: 32),
          Text('Einheit', style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 8),
          // null = automatic: lb in the US, Liberia and Myanmar, kg elsewhere (by the phone's region).
          SegmentedButton<String?>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: null,
                label: Text('Automatisch (${unitForRegion(WidgetsBinding.instance.platformDispatcher.locale.countryCode).name})'),
              ),
              const ButtonSegment(value: 'kg', label: Text('kg')),
              const ButtonSegment(value: 'lb', label: Text('lb')),
            ],
            selected: {prefs.getString('unit')},
            onSelectionChanged: (v) async {
              final choice = v.single;
              if (choice == null) {
                await prefs.remove('unit');
              } else {
                await prefs.setString('unit', choice);
              }
              unit.value = unitFromSetting(choice, WidgetsBinding.instance.platformDispatcher.locale.countryCode);
              setState(() {});
            },
          ),
          const SizedBox(height: 4),
          Text('Gespeichert wird immer in kg, Umrechnung nur für die Anzeige.',
              style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Divider(height: 32),
          Text('GitHub-Sync', style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              // GitHub's mobile site answers the install form with a 404; on desktop it works.
              Text(
                'Zeigt GitHub beim Installieren eine 404? Dann Schritt 2 am PC öffnen: '
                'github.com/apps/$githubAppSlug/installations/new',
                style: text.bodySmall,
              ),
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
    );
  }
}
