import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'edit.dart';
import 'model.dart';
import 'session.dart';
import 'settings.dart';
import 'stats.dart';
import 'sync.dart';

late final Store store;
late final GitHubSync sync;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  store = await Store.open();
  sync = GitHubSync(await SharedPreferences.getInstance());
  store.onSaved = sync.push;
  runApp(const Ferrolog());
}

String kg(double w) => '${w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toString()} kg';

class Ferrolog extends StatelessWidget {
  const Ferrolog({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) =>
        ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: b));
    return MaterialApp(
      title: 'Ferrolog',
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;

  Future<void> export() async {
    final file = XFile.fromData(
      utf8.encode(store.exportJson()),
      mimeType: 'application/json',
      name: 'ferrolog.json',
    );
    await SharePlus.instance.share(ShareParams(files: [file], fileNameOverrides: ['ferrolog.json']));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(const ['Workouts', 'Verlauf', 'Statistik'][tab]),
          actions: [
            IconButton(icon: const Icon(Icons.ios_share), tooltip: 'Daten exportieren', onPressed: export),
            IconButton(
              icon: const Icon(Icons.cloud_sync_outlined),
              tooltip: 'GitHub-Sync',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncSettings())),
            ),
          ],
        ),
        body: [const WorkoutList(), const HistoryList(), const StatsPage()][tab],
        floatingActionButton: tab == 0
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: const Text('Workout'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditWorkout(Workout(name: 'Neues Workout'))),
                ),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Workouts'),
            NavigationDestination(icon: Icon(Icons.history), label: 'Verlauf'),
            NavigationDestination(icon: Icon(Icons.show_chart), label: 'Statistik'),
          ],
        ),
      ),
    );
  }
}

class WorkoutList extends StatelessWidget {
  const WorkoutList({super.key});

  @override
  Widget build(BuildContext context) {
    final active = store.active;
    if (store.workouts.isEmpty && active == null) {
      return const Center(child: Text('Noch keine Workouts. Leg eins an.'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      children: [
        if (active != null)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.play_circle),
              title: Text('${active.workoutName} läuft'),
              subtitle: const Text('Antippen zum Fortsetzen'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionPage(active))),
            ),
          ),
        for (final w in store.workouts) WorkoutCard(w),
      ],
    );
  }
}

class WorkoutCard extends StatelessWidget {
  final Workout workout;
  const WorkoutCard(this.workout, {super.key});

  @override
  Widget build(BuildContext context) {
    final last = store.lastSessionOf(workout);
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workout.name, style: text.titleLarge),
            if (last != null)
              Text('Zuletzt: ${dateLabel(last.date)}', style: text.bodySmall),
            const SizedBox(height: 8),
            for (final e in workout.exercises)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(e.name)),
                    Text('${e.sets}×${e.reps} · ${kg(e.weight)}'),
                    SizedBox(width: 56, child: Text(lastSets(last, e), textAlign: TextAlign.end, style: text.bodySmall)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Bearbeiten'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditWorkout(workout.copy())),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Starten'),
                  onPressed: workout.exercises.isEmpty
                      ? null
                      : () {
                          // Persist before opening, so a killed app can resume it.
                          final session = Session.start(workout);
                          store.saveActive(session);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => SessionPage(session)));
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Last time: "✓" if every set hit the target, else the reps done, e.g. "5/5/3".
  static String lastSets(Session? last, Exercise e) {
    final log = last?.exercises.where((l) => l.name == e.name).firstOrNull;
    if (log == null) return '';
    return log.succeeded ? '✓' : log.reps.map((r) => r ?? '–').join('/');
  }
}

String dateLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

class HistoryList extends StatelessWidget {
  const HistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    if (store.sessions.isEmpty) return const Center(child: Text('Noch keine Trainings geloggt.'));
    return ListView(
      children: [
        for (final s in store.sessions)
          ListTile(
            title: Text(s.workoutName),
            subtitle: Text([
              dateLabel(s.date),
              for (final e in s.exercises)
                '${e.name}: ${kg(e.weight)} × ${e.reps.map((r) => r ?? '–').join('/')}',
            ].join('\n')),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Löschen',
              onPressed: () async {
                final ok = await confirm(context, 'Training vom ${dateLabel(s.date)} löschen?');
                if (ok) store.deleteSession(s);
              },
            ),
          ),
      ],
    );
  }
}

Future<bool> confirm(BuildContext context, String question) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(question),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ja')),
        ],
      ),
    ) ??
    false;
