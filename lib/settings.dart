import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'language.dart';
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
        throw tr.syncNoFileYet(GitHubSync.path);
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr.syncRestored)));
        }
      case 'overwrite':
        final more = (theirs?['sessions'] as List?)?.length ?? 0;
        if (more > store.sessions.length &&
            !await confirm(context, tr.syncOverwriteMore(more, store.sessions.length))) {
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
          Text(tr.settingsTraining, style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          for (final (key, icon, title, subtitle, on) in [
            ('rest.sound', Icons.volume_up_outlined, tr.settingsSound, tr.settingsSoundHint, true),
            ('rest.vibrate', Icons.vibration, tr.settingsVibrate, tr.settingsVibrateHint, true),
            ('session.autoFinish', Icons.timer_off_outlined, tr.settingsAutoFinish, tr.settingsAutoFinishHint, true),
            ('session.keepScreenOn', Icons.light_mode_outlined, tr.settingsKeepScreenOn, tr.settingsKeepScreenOnHint, true),
            ('session.showWhenLocked', Icons.lock_open_outlined, tr.settingsShowWhenLocked, tr.settingsShowWhenLockedHint, true),
            ('session.askRir', Icons.battery_5_bar_outlined, tr.settingsAskRir, tr.settingsAskRirHint, false),
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
            title: Text(tr.settingsLeadIn),
            subtitle: Text(tr.settingsLeadInHint),
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
          Text(tr.settingsHome, style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          for (final (key, icon, title, subtitle) in [
            ('home.tasks', Icons.insights_outlined, tr.settingsTasks, tr.settingsTasksHint),
            ('home.insights', Icons.emoji_events_outlined, tr.settingsInsights, tr.settingsInsightsHint),
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
          Text(tr.settingsStreak, style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 4),
          Text(tr.settingsStreakHint, style: text.bodyMedium),
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
          Text(tr.settingsLanguage, style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 8),
          // null = the system's: German where it speaks German, English elsewhere.
          SegmentedButton<String?>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: null,
                label: Text(tr.settingsLanguageSystem(
                    languageName(localeFor(WidgetsBinding.instance.platformDispatcher.locale)))),
              ),
              for (final l in L10n.supportedLocales)
                ButtonSegment(value: l.languageCode, label: Text(languageName(l))),
            ],
            selected: {prefs.getString('language')},
            onSelectionChanged: (v) async {
              final choice = v.single;
              if (choice == null) {
                await prefs.remove('language');
              } else {
                await prefs.setString('language', choice);
              }
              language.value = languageFromSetting(choice);
            },
          ),
          const Divider(height: 32),
          Text(tr.settingsUnit, style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 8),
          // null = automatic: lb in the US, Liberia and Myanmar, kg elsewhere (by the phone's region).
          SegmentedButton<String?>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: null,
                label: Text(tr.settingsUnitAuto(unitForRegion(WidgetsBinding.instance.platformDispatcher.locale.countryCode).name)),
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
          Text(tr.settingsUnitHint,
              style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Divider(height: 32),
          Text(tr.settingsBarbell, style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.local_fire_department_outlined),
            title: Text(tr.settingsWarmup),
            subtitle: Text(tr.settingsWarmupHint),
            value: showWarmup,
            onChanged: (v) async {
              await prefs.setBool('session.warmup', v);
              setState(() {});
            },
          ),
          Text(tr.settingsBarPlatesHint, style: text.bodyMedium),
          const SizedBox(height: 8),
          // Kept per unit: a 20 kg bar isn't a 45 lb one.
          SegmentedButton<double>(
            showSelectedIcon: false,
            segments: [
              for (final b in barChoices[unit.value]!) ButtonSegment(value: b, label: Text(tr.settingsBar('${plateNum(b)} $unitLabel'))),
            ],
            selected: {barWeight},
            onSelectionChanged: (v) async {
              await prefs.setDouble('barbell.bar.${unit.value.name}', v.single);
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          Text(tr.settingsPlates, style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
          Text(tr.settingsData, style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.share_outlined),
            title: Text(tr.settingsExport),
            subtitle: Text(tr.settingsExportHint),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await export();
              messenger.showSnackBar(SnackBar(content: Text(tr.settingsExportDone)));
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_download_outlined),
            title: Text(tr.settingsRestore),
            subtitle: Text(sync.configured ? tr.settingsRestoreHint(sync.repo) : tr.settingsRestoreNoSync),
            enabled: sync.configured && !busy,
            onTap: resolve,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined),
            title: Text(tr.settingsPlanImport),
            subtitle: Text(tr.settingsPlanImportHint),
            onTap: () => openPlanImport(context),
          ),
          // CC-BY-SA asks for the source to be named, MIT for its notice to ship (on the licence page).
          InkWell(
            onTap: () => showLicensePage(context: context, applicationName: 'FerroLog'),
            child: Text(tr.settingsCredits,
                style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          const Divider(height: 32),
          Text(tr.syncTitle, style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 8),
          Text(tr.syncIntro),
          const SizedBox(height: 16),
          if (code != null) ...[
            Text(tr.syncEnterCode, style: text.bodyMedium),
            const SizedBox(height: 8),
            SelectableText(code.userCode, style: text.displaySmall, textAlign: TextAlign.center),
            TextButton(onPressed: () => open(code.verificationUri), child: Text(code.verificationUri)),
            Text(tr.syncThenBack, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ] else if (!sync.loggedIn)
            FilledButton.icon(
              icon: const Icon(Icons.login),
              label: Text(tr.syncLogin),
              onPressed: busy ? null : login,
            )
          else ...[
            Row(children: [
              const Icon(Icons.check_circle_outline),
              const SizedBox(width: 8),
              Expanded(child: Text(tr.syncConnected)),
              TextButton(
                onPressed: busy ? null : () => run(() async => sync.logout()),
                child: Text(tr.syncLogout),
              ),
            ]),
            if (repos != null && repos.isEmpty) ...[
              const SizedBox(height: 8),
              step(1, tr.syncStepRepo, tr.syncStepRepoHint,
                  done: false,
                  onTap: () => open('https://github.com/new?name=ferrolog-data&visibility=private'
                      '&description=${tr.syncRepoDescription}')),
              step(2, tr.syncStepAccess, tr.syncStepAccessHint,
                  done: false, onTap: () => open('https://github.com/apps/$githubAppSlug/installations/new')),
              Text(tr.syncFindsRepo),
              const SizedBox(height: 8),
              // GitHub's mobile site answers the install form with a 404; on desktop it works.
              Text(
                tr.sync404(githubAppSlug),
                style: text.bodySmall,
              ),
            ],
            if (repos != null && repos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(repos.length == 1 ? tr.syncRepo : tr.syncPickRepo, style: text.titleSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final r in repos)
                  ChoiceChip(label: Text(r), selected: sync.repo == r, onSelected: (_) => select(r)),
              ]),
              const SizedBox(height: 4),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(tr.syncAnotherRepo),
                onPressed: () => open('https://github.com/apps/$githubAppSlug/installations/new'),
              ),
              if (sync.configured)
                FilledButton.icon(
                  icon: const Icon(Icons.sync),
                  label: Text(tr.syncNow),
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
                    child: TextButton(onPressed: busy ? null : resolve, child: Text(tr.syncResolve)),
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
      last == null ? tr.trainingsCount(n) : tr.syncLastOn(tr.trainingsCount(n), dateLabel(last));

  @override
  Widget build(BuildContext context) {
    final remote = theirs?['sessions'] as List?;
    final dates = [for (final s in remote ?? const []) if (s case {'date': final String d}) DateTime.tryParse(d)].nonNulls;
    final last = dates.isEmpty ? null : dates.reduce((a, b) => a.isAfter(b) ? a : b);
    return AlertDialog(
      title: Text(tr.syncDialogTitle),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(remote == null ? tr.syncDialogUnreadable(problem ?? '') : tr.syncDialogRemote(_count(remote.length, last))),
        const SizedBox(height: 4),
        Text(tr.syncDialogLocal(_count(store.sessions.length, store.sessions.firstOrNull?.date))),
        const SizedBox(height: 12),
        Text(
          store.sessions.isEmpty
              ? tr.syncDialogRestoreAll
              : tr.syncDialogRestoreKeep,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr.cancel)),
        TextButton(onPressed: () => Navigator.pop(context, 'overwrite'), child: Text(tr.syncOverwrite)),
        FilledButton(
          onPressed: remote == null ? null : () => Navigator.pop(context, 'restore'),
          child: Text(tr.settingsRestore),
        ),
      ],
    );
  }
}
