import 'dart:convert';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'edit.dart';
import 'model.dart';
import 'recap.dart';
import 'session.dart';
import 'settings.dart';
import 'stats.dart';
import 'sync.dart';
import 'units.dart';

late final Store store;
late final GitHubSync sync;
late final SharedPreferences prefs;

/// Trainings per week the streak asks for; set in the settings.
final weeklyGoal = ValueNotifier(3);

/// Selected bottom tab; finishing a training switches back to the workouts.
final homeTab = ValueNotifier(0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  store = await Store.open();
  prefs = await SharedPreferences.getInstance();
  weeklyGoal.value = prefs.getInt('streak.perWeek') ?? 3;
  unit.value = unitFromSetting(prefs.getString('unit'), WidgetsBinding.instance.platformDispatcher.locale.countryCode);
  sync = GitHubSync(prefs);
  store.onSaved = sync.push;
  await store.autoFinish();
  runApp(const Ferrolog());
}

const analysisPrompt = 'Hier sind meine Trainingsdaten aus FerroLog (JSON, Format steht im Feld "format"). '
    'Analysiere bitte meinen Fortschritt: Welche Übungen laufen gut, wo stagniere ich (Plateaus, '
    'verpasste Wiederholungen), wie sieht Trainingsfrequenz und Volumen aus? '
    'Gib mir konkrete Vorschläge für die nächsten Wochen.';

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
      title: 'FerroLog',
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
  int get tab => homeTab.value;
  set tab(int i) => homeTab.value = i;

  /// Back in the app after a long break: a training left running ends on its own.
  late final lifecycle = AppLifecycleListener(onResume: store.autoFinish);

  @override
  void initState() {
    super.initState();
    lifecycle; // start listening
  }

  @override
  void dispose() {
    lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // Settings (unit, weekly goal) change what every tab shows.
      listenable: Listenable.merge([store, unit, weeklyGoal, homeTab]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Logo(),
          actions: [
            Streak(
              weekStreak(store.sessions.map((s) => s.date), DateTime.now(), perWeek: weeklyGoal.value),
              onTap: () => tab = 2, // history highlights the streak weeks
            ),
          ],
        ),
        // Not const: const widgets are skipped on rebuild, so store changes wouldn't show.
        body: [WorkoutList(), StatsPage(), HistoryList(), SyncSettings()][tab],
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The workouts tab shows the running training as its first card; elsewhere this bar.
            if (store.active case final active? when tab != 0) ActiveBar(active),
            NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => tab = i,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Workouts'),
                NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Statistik'),
                NavigationDestination(icon: Icon(Icons.history), label: 'Verlauf'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Einstellungen'),
              ],
            ),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Noch keine Workouts. Leg eins an.'),
            SizedBox(height: 16),
            AddWorkoutButton(),
          ]),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        if (active != null) ...[
          ActiveTrainingCard(active, key: ValueKey(active.id)),
          const SizedBox(height: 12),
        ],
        if (active == null) ...[const InsightCard(), const SizedBox(height: 4)],
        if (store.workouts.isNotEmpty) const SectionHeader('Workouts', ''),
        for (final w in store.workouts) WorkoutCard(w),
        const SizedBox(height: 8),
        const AddWorkoutButton(),
      ],
    );
  }
}

/// Slim "training running" bar above the navigation, for tabs other than Workouts.
class ActiveBar extends StatelessWidget {
  final Session session;
  const ActiveBar(this.session, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.primaryContainer,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionPage(session))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: Row(children: [
            const LiveDot(),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: session.workoutName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const TextSpan(text: ' läuft · '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Elapsed(session.date, style: TextStyle(color: c.onPrimaryContainer)),
                  ),
                ]),
                style: TextStyle(color: c.onPrimaryContainer),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionPage(session))),
              child: const Text('Fortsetzen'),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Pulsing dot that marks something as live.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: .35, end: 1.0).animate(pulse),
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
        ),
      );
}

/// Time since [start] as "18 Min." or "1:05 Std.", refreshed every few seconds.
class Elapsed extends StatelessWidget {
  final DateTime start;
  final TextStyle? style;
  const Elapsed(this.start, {super.key, this.style});

  @override
  Widget build(BuildContext context) => StreamBuilder(
        stream: Stream.periodic(const Duration(seconds: 5)),
        builder: (context, _) {
          final m = DateTime.now().difference(start).inMinutes;
          return Text(m < 60 ? '$m Min.' : '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')} Std.', style: style);
        },
      );
}

/// Dashed "+ Workout" button at the end of the workout list.
class AddWorkoutButton extends StatelessWidget {
  const AddWorkoutButton({super.key});

  @override
  Widget build(BuildContext context) => DashedAddButton(
        'Workout',
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditWorkout(Workout(name: '')))),
      );
}

/// Inline "+ label" button with a dashed outline, placed at the end of a list.
class DashedAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double height;
  const DashedAddButton(this.label, this.onTap, {super.key, this.height = 44});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _DashedBorder(c.outline),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: height,
          // Wraps the label under the icon when narrow (the "+ Satz" tile).
          child: Center(
            child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
              Icon(Icons.add, color: c.primary),
              Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.primary)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  final Color color;
  _DashedBorder(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)).deflate(.75));
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

/// The running training on the overview: a compact banner that expands into the full card on tap.
class ActiveTrainingCard extends StatefulWidget {
  final Session session;
  const ActiveTrainingCard(this.session, {super.key});

  @override
  State<ActiveTrainingCard> createState() => _ActiveTrainingCardState();
}

class _ActiveTrainingCardState extends State<ActiveTrainingCard> {
  bool expanded = false;

  void resume() => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionPage(widget.session)));

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final c = Theme.of(context).colorScheme;
    final Widget child;
    if (!expanded) {
      child = Material(
        key: const ValueKey('collapsed'),
        color: c.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => expanded = true),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(children: [
              Icon(Icons.timer_outlined, color: c.onPrimaryContainer),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Training läuft',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.onPrimaryContainer)),
                    Icon(Icons.expand_more, size: 18, color: c.onPrimaryContainer.withValues(alpha: .7)),
                  ]),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '${s.workoutName} · seit '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Elapsed(s.date, style: TextStyle(fontSize: 13, color: c.onPrimaryContainer)),
                      ),
                    ]),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.onPrimaryContainer),
                  ),
                ]),
              ),
              FilledButton(onPressed: resume, child: const Text('Fortsetzen')),
            ]),
          ),
        ),
      );
    } else {
      child = OverviewCard(
        key: const ValueKey('expanded'),
        title: s.workoutName,
        live: s,
        rows: [for (final l in s.exercises) (l.name, l.weights, l.reps, l.targets, false, l.cardio ? l.km ?? l.targetKm : null, l.cardio)],
        onTap: () => setState(() => expanded = false), // tap anywhere to collapse
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Training verwerfen',
            onPressed: () async {
              if (await confirm(context, 'Training verwerfen? Nichts wird gespeichert.')) store.saveActive(null);
            },
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Training fortsetzen'),
            onPressed: resume,
          ),
        ],
      );
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(duration: const Duration(milliseconds: 150), child: child),
    );
  }
}

/// Top of the workouts tab: little facts about recent training, one at a time, swipe for the next.
class InsightCard extends StatefulWidget {
  const InsightCard({super.key});

  @override
  State<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<InsightCard> {
  int page = 0;

  static const icons = {
    Fact.record: Icons.local_fire_department,
    Fact.streak: Icons.check_circle_outline,
    Fact.gain: Icons.trending_up,
    Fact.close: Icons.flag_outlined,
    Fact.milestone: Icons.emoji_events_outlined,
    Fact.week: Icons.calendar_today_outlined,
    Fact.stall: Icons.landscape_outlined,
    Fact.pause: Icons.bedtime_outlined,
    Fact.tonnage: Icons.fitness_center,
  };

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final facts = homeFacts(store.sessions, store.workouts, DateTime.now(), perWeek: weeklyGoal.value);
    if (facts.isEmpty) return const SizedBox();
    final current = page.clamp(0, facts.length - 1);
    return Card(
      // A light tint sets it apart from the workout cards below, softer than the running training.
      color: Color.alphaBlend(c.primaryContainer.withValues(alpha: .25), c.surfaceContainerLow),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide.none),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
        child: Column(children: [
          SizedBox(
            height: 38, // two lines of text
            child: PageView(
              // Mouse drags too, so it swipes in the browser as well.
              scrollBehavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
              onPageChanged: (i) => setState(() => page = i),
              children: [
                for (final (kind, text) in facts)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      Icon(icons[kind], size: 20, color: kind == Fact.record ? c.tertiary : c.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(text,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, height: 1.25)),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
          if (facts.length > 1) ...[
            const SizedBox(height: 2),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < facts.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == current ? 14 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: i == current ? c.primary : c.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title, trailing;
  const SectionHeader(this.title, this.trailing, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        Text(trailing, style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    ),
  );
}

class WorkoutCard extends StatelessWidget {
  final Workout workout;
  const WorkoutCard(this.workout, {super.key});

  @override
  Widget build(BuildContext context) {
    final last = store.lastSessionOf(workout);
    return OverviewCard(
      title: workout.name,
      subtitle: last == null ? null : 'zuletzt ${ago(last.date)}',
      rows: [
        for (final e in workout.exercises)
          // Weight went up when last time every set hit the target (the store already added the increment).
          (e.name, e.weights, List<int?>.filled(e.sets, null), e.repsPerSet, _improved(last, e), e.km, e.cardio),
      ],
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Bearbeiten',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditWorkout(workout.copy()))),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Starten'),
          // Starting another training would replace the running one.
          onPressed: workout.exercises.isEmpty || store.active != null
              ? null
              : () {
                  // Persist before opening, so a killed app can resume it.
                  final session = Session.start(workout);
                  store.saveActive(session);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SessionPage(session)));
                },
        ),
      ],
    );
  }

  static bool _improved(Session? last, Exercise e) {
    final log = last?.exercises.where((l) => l.name == e.name).firstOrNull;
    return log != null && log.succeeded && e.weight > log.weight;
  }
}

/// A workout as compact rows: exercise name left, weight and joined rep pills right.
class OverviewCard extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// (name, weight per set, reps done or null per set, target reps per set, weight went up, km, cardio).
  /// Cardio rows have one "set" whose reps are minutes; they show "25 Min · 5 km" instead of weights.
  /// A weight of 0 is shown as reps only.
  final List<(String, List<double>, List<int?>, List<int>, bool, double?, bool)> rows;
  final List<Widget> actions;

  /// The running training, if this card shows it: highlighted, with elapsed time and progress.
  final Session? live;

  /// Tap anywhere on the card (buttons inside keep their own taps).
  final VoidCallback? onTap;

  /// Small text left of the actions, e.g. mood, body weight and note of a past training.
  final String? footer;

  /// Extra line under an exercise's row, e.g. its weight next time on the recap.
  final Widget? Function(String name)? detail;

  /// A done training: every set as a small tile, reps over weight, below the exercise's name.
  final bool perSet;
  const OverviewCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.rows,
    required this.actions,
    this.live,
    this.onTap,
    this.footer,
    this.detail,
    this.perSet = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final line = BorderSide(color: c.outlineVariant.withValues(alpha: .6));
    final live = this.live;
    final done = live?.exercises.fold(0, (n, e) => n + e.setsDone) ?? 0;
    final total = live?.exercises.fold(0, (n, e) => n + e.reps.length) ?? 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: live == null ? null : Color.alphaBlend(c.primaryContainer.withValues(alpha: .45), c.surfaceContainerLow),
      shape: live == null
          ? null
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.primary, width: 2)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (live != null) ...[
                Row(children: [
                  const LiveDot(),
                  const SizedBox(width: 8),
                  Text('LÄUFT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: c.primary)),
                  Text(' · ', style: TextStyle(color: c.onSurfaceVariant)),
                  Elapsed(live.date, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                  const Spacer(),
                  Text('$done/$total Sätze', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.onSurface)),
                  if (onTap != null) Icon(Icons.expand_less, size: 20, color: c.onSurfaceVariant),
                ]),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                  backgroundColor: c.surface,
                ),
                const SizedBox(height: 10),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  ),
                  if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 4),
              for (final (name, weights, reps, targets, up, km, cardio) in rows)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(border: Border(bottom: line)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (perSet && !cardio)
                    // Name (and detail) left, wrapping if long; sets always right, in two rows when there are many.
                    LayoutBuilder(builder: (context, box) {
                      return Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: const TextStyle(fontSize: 16)),
                            if (detail?.call(name) case final d?) ...[const SizedBox(height: 2), d],
                          ]),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: box.maxWidth * .7),
                          child: Wrap(alignment: WrapAlignment.end, spacing: 3, runSpacing: 3, children: [
                            for (final (i, r) in reps.indexed) MiniSetTile(r, targets[i], weights[i]),
                          ]),
                        ),
                      ]);
                    })
                  else
                  Row(
                    children: [
                      Expanded(
                        child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
                      ),
                      if (cardio)
                        CardioPill(reps.first, targets.first, km)
                      else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final (i, (weight, sets)) in groupByWeight(weights).indexed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (up && i == 0) Icon(Icons.arrow_upward, size: 16, color: c.primary),
                                  if (weight > 0) Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(text: weightNum(weight)),
                                        TextSpan(
                                          text: ' $unitLabel',
                                          style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: up ? c.primary : c.onSurfaceVariant,
                                      fontWeight: up ? FontWeight.w600 : FontWeight.w400,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  RepPills([for (final j in sets) reps[j]], [for (final j in sets) targets[j]]),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (!perSet || cardio) ?detail?.call(name),
                  ]),
                ),
              if (footer != null || actions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Text(footer ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                ),
                ...actions,
              ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Cardio in a card row: "25 Min · 5 km", colored like a set pill (open / done / short).
class CardioPill extends StatelessWidget {
  final int? minutes;
  final int target;
  final double? km;
  const CardioPill(this.minutes, this.target, this.km, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final m = minutes;
    final (bg, fg) = m == null
        ? (c.surface, c.onSurface)
        : m >= target
            ? (c.primary, c.onPrimary)
            : (c.tertiaryContainer, c.onTertiaryContainer);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.directions_run, size: 16, color: fg),
        const SizedBox(width: 6),
        Text(cardioLabel(m ?? target, km),
            style: TextStyle(fontSize: 14, fontWeight: m == null ? FontWeight.w400 : FontWeight.w600, color: fg)),
      ]),
    );
  }
}

/// Consecutive sets with the same weight, as set indexes, e.g. 72.5: [0, 1], 70: [2].
List<(double, List<int>)> groupByWeight(List<double> weights) {
  final groups = <(double, List<int>)>[];
  for (final (i, w) in weights.indexed) {
    if (groups.isEmpty || groups.last.$1 != w) groups.add((w, []));
    groups.last.$2.add(i);
  }
  return groups;
}

/// A set on a done training's card: reps on top, colored like a [RepPills] pill, weight below.
class MiniSetTile extends StatelessWidget {
  final int? reps;
  final int target;
  final double weight;
  const MiniSetTile(this.reps, this.target, this.weight, {super.key});

  static const double width = 40;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final r = reps;
    final (bg, fg) = r == null
        ? (c.surface, c.onSurfaceVariant)
        : r >= target
            ? (c.primary, c.onPrimary)
            : (c.tertiaryContainer, c.onTertiaryContainer);
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: width,
        child: Column(children: [
          Container(
            height: 30,
            color: bg,
            alignment: Alignment.center,
            child: Text(r?.toString() ?? '–',
                style: TextStyle(fontSize: 15, fontWeight: r == null ? FontWeight.w400 : FontWeight.w600, color: fg)),
          ),
          if (weight > 0) ...[
            const SizedBox(height: 1),
            Container(
              height: 18,
              color: c.surfaceContainerHigh,
              alignment: Alignment.center,
              child: Text(weightNum(weight),
                  style: TextStyle(fontSize: 11, color: c.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Sets as a joined row of pills: open sets show the target, logged ones their reps.
class RepPills extends StatelessWidget {
  final List<int?> reps;
  final List<int> targets;
  const RepPills(this.reps, this.targets, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, r) in reps.indexed)
            if (targets[i] case final target) ...[
            if (i > 0) const SizedBox(width: 2),
            Container(
              constraints: const BoxConstraints(minWidth: 30),
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              color: r == null ? c.surface : (r >= target ? c.primary : c.tertiaryContainer),
              child: Text(
                '${r ?? target}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: r == null ? FontWeight.w400 : FontWeight.w600,
                  color: r == null ? c.onSurface : (r >= target ? c.onPrimary : c.onTertiaryContainer),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A set as a two-part tile: reps on top (open / done / partial colors), weight below.
class SetTile extends StatelessWidget {
  final int? reps;
  final int target;

  /// Top of a rep range: shows "/5–8".
  final int? targetMax;
  final String weight;
  final bool selected;

  /// After the target ("/30 Min") and after the bottom value (default: the weight unit).
  final String repsUnit;
  final String? weightUnit;
  final VoidCallback? onTapReps, onTapWeight;
  const SetTile({
    super.key,
    required this.reps,
    required this.target,
    this.targetMax,
    required this.weight,
    this.repsUnit = '',
    this.weightUnit,
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
    final radius = BorderRadius.circular(14);
    final top = Text.rich(
            TextSpan(children: [
              TextSpan(text: r?.toString() ?? '–', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              TextSpan(
                text: '/$target${targetMax != null && targetMax! > target ? '–$targetMax' : ''}$repsUnit',
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
                child: SizedBox(height: 56, child: Center(child: top)),
              ),
            ),
            SizedBox(height: 2),
            Material(
              color: selected ? c.secondaryContainer : c.surfaceContainer,
              child: InkWell(
                onTap: onTapWeight,
                child: SizedBox(
                  height: 36,
                  child: Center(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: weight),
                        if (weightUnit != '')
                          TextSpan(text: ' ${weightUnit ?? unitLabel}', style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
                      ]),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: c.onSurface,
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

/// Flame badge with the number of weeks trained in a row.
class Streak extends StatelessWidget {
  final int weeks;
  final VoidCallback? onTap;
  const Streak(this.weeks, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final active = weeks > 0;
    return Tooltip(
      message: '${weeks == 1 ? '1 Woche' : '$weeks Wochen'} in Folge mindestens ${weeklyGoal.value}× trainiert',
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Material(
          color: active ? c.tertiaryContainer : c.surfaceContainerHigh,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Container(
              height: 36,
              padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.local_fire_department, size: 22, color: active ? c.tertiary : c.outline),
                const SizedBox(width: 2),
                Text('$weeks',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: active ? c.onTertiaryContainer : c.onSurfaceVariant)),
              ]),
            ),
          ),
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
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(8)),
        child: CustomPaint(painter: _PlatePainter(plate: c.primaryContainer, cut: c.primary)),
      ),
      const SizedBox(width: 9),
      Text.rich(
        TextSpan(children: [const TextSpan(text: 'Ferro'), TextSpan(text: 'Log', style: TextStyle(color: c.primary))]),
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, letterSpacing: -.4, color: c.onSurface),
      ),
    ]);
  }
}

/// Tri-grip weight plate, same geometry as the app icon (72-unit view of the 108dp grid, centre 36).
class _PlatePainter extends CustomPainter {
  const _PlatePainter({required this.plate, required this.cut});
  final Color plate, cut;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 72, c = size.center(Offset.zero);
    canvas.drawCircle(c, 24 * u, Paint()..color = plate);
    final slot = Paint()
      ..color = cut
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 * u
      ..strokeCap = StrokeCap.round;
    for (final a in [-90, 30, 150]) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: 16 * u), (a - 32) * pi / 180, 64 * pi / 180, false, slot);
    }
    canvas.drawCircle(c, 6 * u, Paint()..color = cut);
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.plate != plate || old.cut != cut;
}

String dateLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// "Montag, 2. November"
String dayLabel(DateTime d) =>
    '${const ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'][d.weekday - 1]}, '
    '${d.day}. ${const ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'][d.month - 1]}';

String ago(DateTime d) {
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  return switch (days) { <= 0 => 'heute', 1 => 'gestern', _ => 'vor $days Tagen' };
}

const _months = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

/// Month calendar with training days marked; below it the month's (or the tapped day's) trainings.
class HistoryList extends StatefulWidget {
  const HistoryList({super.key});

  @override
  State<HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<HistoryList> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? day;

  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    if (store.sessions.isEmpty) return const Center(child: Text('Noch keine Trainings geloggt.'));
    final c = Theme.of(context).colorScheme;
    final inMonth = store.sessions.where((s) => s.date.year == month.year && s.date.month == month.month).toList();
    final shown = day == null ? inMonth : inMonth.where((s) => sameDay(s.date, day!)).toList();
    final first = month.subtract(Duration(days: month.weekday - 1)); // Monday on or before the 1st
    final today = DateTime.now();
    final goal = weeklyGoal.value;
    final streak = streakWeeks(store.sessions.map((s) => s.date), today, perWeek: goal);
    final thisWeek = store.sessions.where((s) => mondayOf(s.date) == mondayOf(today)).length;

    Widget cell(DateTime d) {
      // Days of the neighbouring months show their trainings too (dimmed), so a streak week
      // spanning two months doesn't look empty.
      final count = store.sessions.where((s) => sameDay(s.date, d)).length;
      final other = d.month != month.month;
      var (bg, fg) = count == 0
          ? (Colors.transparent, other ? c.outlineVariant : c.onSurfaceVariant)
          : count == 1
              ? (c.secondaryContainer, c.onSecondaryContainer)
              : (c.primary, c.onPrimary);
      if (other && count > 0) (bg, fg) = (bg.withValues(alpha: .45), fg.withValues(alpha: .7));
      final selected = day != null && sameDay(d, day!);
      return Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: selected || sameDay(d, today)
                ? BorderSide(color: selected ? c.primary : c.onSurface, width: selected ? 2.5 : 1.5)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: count == 0
                ? null
                : () => setState(() {
                      if (other) month = DateTime(d.year, d.month); // jump to that month, day selected
                      day = selected ? null : d;
                    }),
            child: SizedBox(
              height: 44,
              child: Center(
                child: Text('${d.day}',
                    style: TextStyle(
                        fontSize: 17, color: fg, fontWeight: count > 0 ? FontWeight.w600 : FontWeight.w400)),
              ),
            ),
          ),
        ),
      );
    }

    void go(int delta) => setState(() {
          month = DateTime(month.year, month.month + delta);
          day = null;
        });

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [
        if (streak.isNotEmpty || thisWeek > 0)
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(color: c.tertiaryContainer, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(Icons.local_fire_department, color: c.tertiary, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    streak.isEmpty
                        ? 'Ziel: $goal× pro Woche'
                        : '${streak.length} ${streak.length == 1 ? 'Woche' : 'Wochen'} in Folge · $goal× pro Woche',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.onTertiaryContainer),
                  ),
                  Text(
                    thisWeek >= goal
                        ? 'Diese Woche geschafft ($thisWeek/$goal). Weiter so!'
                        : 'Diese Woche $thisWeek/$goal · noch ${goal - thisWeek} '
                            '${goal - thisWeek == 1 ? 'Training' : 'Trainings'}'
                            '${streak.isEmpty ? '' : ', um die Serie zu halten'}',
                    style: TextStyle(fontSize: 13, color: c.onTertiaryContainer.withValues(alpha: .8)),
                  ),
                ]),
              ),
            ]),
          ),
        Row(children: [
          const SizedBox(width: 6),
          Expanded(
            child: Text('${_months[month.month - 1]}${month.year == today.year ? '' : ' ${month.year}'}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          ),
          // Back to the current month; hidden while it's already shown.
          if (month.year != today.year || month.month != today.month || day != null)
            TextButton(
              onPressed: () => setState(() {
                month = DateTime(today.year, today.month);
                day = null;
              }),
              child: const Text('Heute'),
            ),
          IconButton.filledTonal(icon: const Icon(Icons.chevron_left), tooltip: 'Voriger Monat', onPressed: () => go(-1)),
          IconButton.filledTonal(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Nächster Monat',
            onPressed: month.year == today.year && month.month == today.month ? null : () => go(1),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (final w in const ['M', 'D', 'M', 'D', 'F', 'S', 'S'])
            Expanded(
              child: Center(child: Text(w, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant))),
            ),
        ]),
        const SizedBox(height: 4),
        for (var week = 0; week < 6; week++)
          if (first.add(Duration(days: week * 7)).month == month.month || week == 0)
            // Weeks of the current streak get an orange band.
            Container(
              decoration: streak.contains(DateTime(first.year, first.month, first.day + week * 7))
                  ? BoxDecoration(
                      color: c.tertiaryContainer.withValues(alpha: .6), borderRadius: BorderRadius.circular(17))
                  : null,
              child: Row(children: [
                for (var i = 0; i < 7; i++)
                  // DateTime(…, day + n) rather than add(), so DST switches don't shift the date.
                  Expanded(child: cell(DateTime(first.year, first.month, first.day + week * 7 + i))),
              ]),
            ),
        SectionHeader(
          day == null
              ? '${inMonth.length} ${inMonth.length == 1 ? 'Training' : 'Trainings'} im ${_months[month.month - 1]}'
              : dayLabel(day!),
          '',
        ),
        for (final s in shown)
          OverviewCard(
            title: s.workoutName,
            subtitle: dayLabel(s.date),
            rows: [for (final l in s.exercises) (l.name, l.weights, l.reps, l.targets, false, l.cardio ? l.km ?? l.targetKm : null, l.cardio)],
            perSet: true,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecapPage(s))),
            footer: [
              if (s.mood case final m?) const ['😣', '😐', '😄'][m - 1],
              if (s.bodyWeight case final kg?) weightLabel(kg),
              for (final t in s.tags) '${noteTags[t] ?? ''} $t'.trim(),
              if (s.note case final n?) '„$n“',
            ].join(' · '),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Löschen',
                onPressed: () async {
                  final ok = await confirm(context, 'Training vom ${dateLabel(s.date)} löschen?');
                  if (ok) store.deleteSession(s);
                },
              ),
            ],
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
