import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'loading.dart';
import 'main.dart';
import 'model.dart';
import 'plan_import_page.dart';
import 'sync.dart';
import 'units.dart';

/// Guided GitHub setup: log in → create the data repo → give FerroLog access → pick it.
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
    if (sync.conflict.value) WidgetsBinding.instance.addPostFrameCallback((_) => resolve());
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
        // Exactly one repo shared with FerroLog: that's the one, start syncing right away.
        if (repos!.length == 1 && sync.repo != repos!.single) await select(repos!.single);
      });

  /// The first push to a repo meets the guard: a file there that isn't ours waits for the user.
  Future<void> select(String repo) async {
    await sync.selectRepo(repo);
    setState(() {});
    await sync.push(store.exportJson());
    if (sync.conflict.value && mounted) await resolve();
  }

  /// Shows both sides in numbers and lets the user restore from GitHub or overwrite it.
  /// Only the network steps count as busy, not the time the dialog is open.
  Future<void> resolve() async {
    ({String json, String sha})? remote;
    await run(() async {
      remote = await sync.fetchRemote();
      if (remote == null) {
        sync.conflict.value = false; // gone meanwhile: the next push creates it
        throw 'Auf GitHub liegt noch keine ${GitHubSync.path}.';
      }
    });
    final sha = remote?.sha;
    if (sha == null || !mounted) return;
    Map<String, dynamic>? theirs;
    String? problem;
    try {
      theirs = migrate(jsonDecode(remote!.json));
    } on FormatException catch (e) {
      problem = e.message;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => _ResolveDialog(theirs: theirs, problem: problem),
    );
    if (!mounted) return;
    switch (choice) {
      case 'restore':
        await run(() => store.importJson(theirs, merge: store.sessions.isNotEmpty, beforeSave: () => sync.adopt(sha)));
        if (mounted && error == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Von GitHub wiederhergestellt')));
        }
      case 'overwrite':
        final more = (theirs?['sessions'] as List?)?.length ?? 0;
        if (more > store.sessions.length &&
            !await confirm(context, 'Auf GitHub liegen mehr Trainings ($more) als hier (${store.sessions.length}). '
                'Wirklich überschreiben? Der alte Stand bleibt nur in der Git-Historie des Repos.')) {
          return;
        }
        await run(() async {
          await sync.adopt(sha);
          await sync.push(store.exportJson());
        });
    }
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
          Text('Training', style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          for (final (key, icon, title, subtitle, on) in const [
            ('rest.sound', Icons.volume_up_outlined, 'Ton', 'Signalton, wenn die Pause bei 0 ankommt', true),
            ('rest.vibrate', Icons.vibration, 'Vibration', 'Kurz vibrieren, wenn die Pause bei 0 ankommt', true),
            ('session.autoFinish', Icons.timer_off_outlined, 'Automatisch beenden',
                'Nach 30 Min ohne Aktivität endet das Training beim letzten Satz', true),
            ('session.keepScreenOn', Icons.light_mode_outlined, 'Bildschirm anlassen',
                'Während des Trainings geht das Display nicht aus', true),
            ('session.showWhenLocked', Icons.lock_open_outlined, 'Über dem Sperrbildschirm zeigen',
                'Während des Trainings ohne Entsperren auf die Pause schauen', true),
            ('session.askRir', Icons.battery_5_bar_outlined, 'Reserve abfragen',
                'Nach dem letzten Satz einer Übung: Wie viele Wiederholungen gingen noch? Hilft bei Plateaus. '
                    'Übungen im Auto-Modus fragen immer', false),
          ])
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(icon),
              title: Text(title),
              subtitle: Text(subtitle),
              value: prefs.getBool(key) ?? on,
              onChanged: (v) async {
                await prefs.setBool(key, v);
                setState(() {});
              },
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.hourglass_top),
            title: const Text('Vorlauf bei Zeitübungen'),
            subtitle: const Text('Zeit zum Aufnehmen der Gewichte, bevor die Sekunden zählen'),
            trailing: DropdownButton<int>(
              value: prefs.getInt('timed.leadIn') ?? 10,
              items: [for (final n in const [0, 5, 10, 15]) DropdownMenuItem(value: n, child: Text('$n s'))],
              onChanged: (v) async {
                if (v == null) return;
                await prefs.setInt('timed.leadIn', v);
                setState(() {});
              },
            ),
          ),
          const Divider(height: 32),
          Text('Startseite', style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          for (final (key, icon, title, subtitle) in const [
            ('home.tasks', Icons.insights_outlined, 'Hinweise zum Training',
                'Wenn die Statistik etwas findet: Ausgelassenes, Balance, Plateau, Wochenziel'),
            ('home.insights', Icons.emoji_events_outlined, 'Erfolge', 'Rekorde, Fortschritt und Meilensteine des letzten Trainings'),
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
          Text('Hantel', style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.local_fire_department_outlined),
            title: const Text('Aufwärmsätze zeigen'),
            subtitle: const Text('Vor dem ersten Satz einer Langhantel-Übung: leere Stange, dann 50, 70 und 85 %'),
            value: showWarmup,
            onChanged: (v) async {
              await prefs.setBool('session.warmup', v);
              setState(() {});
            },
          ),
          Text('Stange und Scheiben für „Pro Seite“ beim Gewicht und für die Aufwärmsätze', style: text.bodyMedium),
          const SizedBox(height: 8),
          // Kept per unit: a 20 kg bar isn't a 45 lb one.
          SegmentedButton<double>(
            showSelectedIcon: false,
            segments: [
              for (final b in barChoices[unit.value]!) ButtonSegment(value: b, label: Text('Stange ${plateNum(b)} $unitLabel')),
            ],
            selected: {barWeight},
            onSelectionChanged: (v) async {
              await prefs.setDouble('barbell.bar.${unit.value.name}', v.single);
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          Text('Scheiben', style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in plateChoices[unit.value]!)
              FilterChip(
                label: Text(plateNum(p)),
                selected: availablePlates.contains(p),
                onSelected: (on) async {
                  final plates = {...availablePlates};
                  on ? plates.add(p) : plates.remove(p);
                  await prefs.setStringList('barbell.plates.${unit.value.name}', [for (final x in plates) '$x']);
                  setState(() {});
                },
              ),
          ]),
          const Divider(height: 32),
          Text('Daten', style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.share_outlined),
            title: const Text('An KI senden / exportieren'),
            subtitle: const Text('Alle Daten als JSON, der Analyse-Prompt kommt in die Zwischenablage'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await export();
              messenger.showSnackBar(const SnackBar(content: Text('Prompt kopiert: im Chat einfügen, falls er fehlt')));
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_download_outlined),
            title: const Text('Von GitHub wiederherstellen'),
            subtitle: Text(sync.configured
                ? 'Trainings und Pläne aus ${sync.repo} holen, nach einer Neuinstallation oder vom anderen Gerät'
                : 'Erst unten GitHub-Sync einrichten'),
            enabled: sync.configured && !busy,
            onTap: resolve,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined),
            title: const Text('Plan von KI übernehmen'),
            subtitle: const Text('JSON-Block aus dem Chat einfügen, mit Vorschau vor dem Speichern'),
            onTap: () => openPlanImport(context),
          ),
          // CC-BY-SA asks for the source to be named, MIT for its notice to ship (on the licence page).
          InkWell(
            onTap: () => showLicensePage(context: context, applicationName: 'FerroLog'),
            child: Text(
                'Muskeln der Übungen: wger.de (CC-BY-SA), free-exercise-db · '
                'Körperkarte: react-native-body-highlighter (MIT) · Lizenzen',
                style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          const Divider(height: 32),
          Text('GitHub-Sync', style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 8),
          const Text(
            'FerroLog speichert deine Trainingsdaten als ferrolog.json in einem privaten '
            'GitHub-Repo. Dort kann deine KI sie lesen. FerroLog bekommt nur Zugriff auf '
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
                      '&description=FerroLog+Trainingsdaten')),
              step(2, 'FerroLog Zugriff geben', '„Only select repositories“ → ferrolog-data wählen',
                  done: false, onTap: () => open('https://github.com/apps/$githubAppSlug/installations/new')),
              const Text('Danach zurück in die App wechseln, FerroLog findet das Repo dann selbst.'),
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
          ValueListenableBuilder(
            valueListenable: sync.conflict,
            builder: (_, c, _) => c
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: busy ? null : resolve, child: const Text('Konflikt lösen')),
                  )
                : const SizedBox.shrink(),
          ),
        ],
    );
  }
}

/// GitHub against this device, in numbers; pops 'restore', 'overwrite' or null.
class _ResolveDialog extends StatelessWidget {
  final Map<String, dynamic>? theirs;
  final String? problem;
  const _ResolveDialog({required this.theirs, required this.problem});

  static String _count(int n, DateTime? last) =>
      '$n ${n == 1 ? 'Training' : 'Trainings'}${last == null ? '' : ', letztes am ${dateLabel(last)}'}';

  @override
  Widget build(BuildContext context) {
    final remote = theirs?['sessions'] as List?;
    final dates = [for (final s in remote ?? const []) if (s case {'date': final String d}) DateTime.tryParse(d)].nonNulls;
    final last = dates.isEmpty ? null : dates.reduce((a, b) => a.isAfter(b) ? a : b);
    return AlertDialog(
      title: const Text('Daten auf GitHub'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(remote == null ? 'Auf GitHub: nicht lesbar. $problem' : 'Auf GitHub: ${_count(remote.length, last)}'),
        const SizedBox(height: 4),
        Text('Auf diesem Gerät: ${_count(store.sessions.length, store.sessions.firstOrNull?.date)}'),
        const SizedBox(height: 12),
        Text(
          store.sessions.isEmpty
              ? 'Wiederherstellen holt Trainings und Pläne von GitHub.'
              : 'Wiederherstellen holt Trainings und Pläne von GitHub und behält die Trainings, die nur hier sind.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        TextButton(onPressed: () => Navigator.pop(context, 'overwrite'), child: const Text('GitHub überschreiben')),
        FilledButton(
          onPressed: remote == null ? null : () => Navigator.pop(context, 'restore'),
          child: const Text('Von GitHub wiederherstellen'),
        ),
      ],
    );
  }
}
