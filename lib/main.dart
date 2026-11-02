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

const analysisPrompt = 'Hier sind meine Trainingsdaten aus Ferrolog (JSON, Format steht im Feld "format"). '
    'Analysiere bitte meinen Fortschritt: Welche Übungen laufen gut, wo stagniere ich (Plateaus, '
    'verpasste Wiederholungen), wie sieht Trainingsfrequenz und Volumen aus? '
    'Gib mir konkrete Vorschläge für die nächsten Wochen.';

String kg(double w) => '${w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toString()} kg';

class Ferrolog extends StatelessWidget {
  const Ferrolog({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) {
      // Design "FerroLog Final": Material 3 roles from seed #426372.
      // Tertiary (partial sets, rest over) is the design's orange, not the seed's derived hue.
      final light = b == Brightness.light;
      final c = ColorScheme.fromSeed(seedColor: const Color(0xFF426372), brightness: b).copyWith(
        tertiary: Color(light ? 0xFF8B5000 : 0xFFFFB876),
        onTertiary: Color(light ? 0xFFFFFFFF : 0xFF4A2800),
        tertiaryContainer: Color(light ? 0xFFFFDCC0 : 0xFF6A3C00),
        onTertiaryContainer: Color(light ? 0xFF2D1600 : 0xFFFFDCC0),
      );
      return ThemeData(
        colorScheme: c,
        scaffoldBackgroundColor: c.surface,
        appBarTheme: AppBarTheme(backgroundColor: c.surface, scrolledUnderElevation: 0),
        cardTheme: CardThemeData(
          elevation: 0,
          color: c.surfaceContainerLow,
          margin: const EdgeInsets.symmetric(vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: c.outlineVariant.withValues(alpha: .6)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: c.surfaceContainer,
          indicatorColor: c.secondaryContainer,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: c.primaryContainer,
          foregroundColor: c.onPrimaryContainer,
        ),
      );
    }

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

  /// Shares all data plus a ready-made prompt, e.g. straight into the Claude app.
  Future<void> export() async {
    final name = 'ferrolog-${DateTime.now().toIso8601String().substring(0, 10)}.json';
    final file = XFile.fromData(utf8.encode(store.exportJson()), mimeType: 'application/json', name: name);
    await SharePlus.instance.share(ShareParams(
      files: [file],
      fileNameOverrides: [name],
      text: analysisPrompt,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: tab == 0 ? const Logo() : Text(const ['Workouts', 'Verlauf', 'Statistik'][tab]),
          actions: [
            IconButton(icon: const Icon(Icons.share_outlined), tooltip: 'An KI senden / exportieren', onPressed: export),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'GitHub-Sync',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncSettings())),
            ),
          ],
        ),
        // Not const: const widgets are skipped on rebuild, so store changes wouldn't show.
        body: [WorkoutList(), HistoryList(), StatsPage()][tab],
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
            NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Statistik'),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Training läuft'),
              subtitle: Text('${active.workoutName} · seit ${DateTime.now().difference(active.date).inMinutes} Min.'),
              trailing: FilledButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionPage(active))),
                child: const Text('Fortsetzen'),
              ),
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
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text(workout.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500))),
                if (last != null) Text(ago(last.date), style: muted),
              ],
            ),
            const SizedBox(height: 6),
            for (final e in workout.exercises) _exercise(e, last, scheme, muted),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  child: const Text('Bearbeiten'),
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

  /// Plan plus last result as mini set tiles; a chip with the new weight when the last run fully succeeded
  /// (the store has already added the increment to the plan by then).
  Widget _exercise(Exercise e, Session? last, ColorScheme scheme, TextStyle muted) {
    final log = last?.exercises.where((l) => l.name == e.name).firstOrNull;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(e.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              Text('${e.sets}×${e.reps}', style: muted),
              if (log != null && log.succeeded && e.increment > 0) ...[
                const SizedBox(width: 8),
                Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(11)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.arrow_upward, size: 13, color: scheme.onSecondaryContainer),
                    Text(kg(e.weight),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: scheme.onSecondaryContainer)),
                  ]),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in log?.reps ?? List<int?>.filled(e.sets, null))
                SizedBox(
                  width: 44,
                  child: SetTile(
                    reps: r,
                    target: log?.targetReps ?? e.reps,
                    weight: kgNum(log?.weight ?? e.weight),
                    small: true,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A set as a two-part tile: reps on top (open / done / partial colors), weight below.
class SetTile extends StatelessWidget {
  final int? reps;
  final int target;
  final String weight;
  final bool small;
  final bool selected;
  final VoidCallback? onTapReps, onTapWeight;
  const SetTile({
    super.key,
    required this.reps,
    required this.target,
    required this.weight,
    this.small = false,
    this.selected = false,
    this.onTapReps,
    this.onTapWeight,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final r = reps;
    final (bg, fg) = r == null
        ? (c.surfaceContainerHigh, c.outline)
        : r >= target
            ? (c.primary, c.onPrimary)
            : (c.tertiaryContainer, c.onTertiaryContainer);
    final radius = BorderRadius.circular(small ? 8 : 14);
    final top = small
        ? Text(r == null ? '$target' : '$r', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg))
        : Text.rich(
            TextSpan(children: [
              TextSpan(text: r?.toString() ?? '–', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              TextSpan(
                text: '/$target',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: fg.withValues(alpha: .7)),
              ),
            ]),
            style: TextStyle(color: fg),
          );
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: selected ? Border.all(color: c.primary, width: 2) : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          children: [
            Material(
              color: bg,
              child: InkWell(
                onTap: onTapReps,
                child: SizedBox(height: small ? 22 : 56, child: Center(child: top)),
              ),
            ),
            SizedBox(height: small ? 1 : 2),
            Material(
              color: small || selected ? (selected ? c.secondaryContainer : c.surfaceContainerHigh) : c.surfaceContainer,
              child: InkWell(
                onTap: onTapWeight,
                child: SizedBox(
                  height: small ? 18 : 36,
                  child: Center(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: weight),
                        if (!small) TextSpan(text: ' kg', style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
                      ]),
                      style: TextStyle(
                        fontSize: small ? 10.5 : 15,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: small ? c.onSurfaceVariant : c.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ferrolog wordmark: a ring in a rounded square, "log" in primary.
class Logo extends StatelessWidget {
  const Logo({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(8)),
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.primaryContainer, width: 3.5)),
        ),
      ),
      const SizedBox(width: 9),
      Text.rich(
        TextSpan(children: [const TextSpan(text: 'ferro'), TextSpan(text: 'log', style: TextStyle(color: c.primary))]),
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, letterSpacing: -.4, color: c.onSurface),
      ),
    ]);
  }
}

/// Weight without unit, German decimal comma: 82.5 → "82,5".
String kgNum(double w) => (w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toString()).replaceAll('.', ',');

String dateLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String ago(DateTime d) {
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  return switch (days) { <= 0 => 'heute', 1 => 'gestern', _ => 'vor $days Tagen' };
}

class HistoryList extends StatelessWidget {
  const HistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    if (store.sessions.isEmpty) return const Center(child: Text('Noch keine Trainings geloggt.'));
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      children: [
        for (final s in store.sessions)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 8, 10),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.workoutName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        Text(dateLabel(s.date), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ]),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: scheme.onSurfaceVariant),
                      tooltip: 'Löschen',
                      onPressed: () async {
                        final ok = await confirm(context, 'Training vom ${dateLabel(s.date)} löschen?');
                        if (ok) store.deleteSession(s);
                      },
                    ),
                  ]),
                  for (final e in s.exercises)
                    SizedBox(
                      height: 26,
                      child: Row(children: [
                        Expanded(child: Text(e.name, style: const TextStyle(fontSize: 13))),
                        SizedBox(
                          width: 64,
                          child: Text(kg(e.weight).replaceAll('.', ','),
                              textAlign: TextAlign.end,
                              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                        ),
                        SizedBox(
                          width: 66,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: e.succeeded
                                ? Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(Icons.check, size: 18, color: scheme.primary),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                    decoration: BoxDecoration(
                                        color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
                                    child: Text(e.reps.map((r) => r ?? '–').join('/'),
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: scheme.onTertiaryContainer)),
                                  ),
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
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
