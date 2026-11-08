import 'package:flutter/material.dart';

import 'edit.dart';
import 'main.dart';
import 'model.dart';
import 'timing.dart';
import 'units.dart';

/// After a training (and from the history): the same card as in the history with next time's
/// weights, key figures, then mood, body weight and a note. Edits are saved when the page closes.
class RecapPage extends StatefulWidget {
  final Session session;
  const RecapPage(this.session, {super.key});

  @override
  State<RecapPage> createState() => _RecapPageState();
}

class _RecapPageState extends State<RecapPage> {
  Session get s => widget.session;
  late double? bodyWeight = s.bodyWeight;
  late final note = TextEditingController(text: s.note ?? '');
  late int? mood = s.mood;
  late final tags = {...s.tags};
  late bool noteOpen = s.tags.isNotEmpty || s.note != null;

  @override
  void dispose() {
    final text = note.text.trim();
    final tagList = [for (final t in noteTags.keys) if (tags.contains(t)) t];
    if (bodyWeight != s.bodyWeight ||
        (text.isEmpty ? null : text) != s.note ||
        mood != s.mood ||
        tagList.join('|') != s.tags.join('|')) {
      s.bodyWeight = bodyWeight;
      s.note = text.isEmpty ? null : text;
      s.mood = mood;
      s.tags = tagList;
      store.updateSession(s);
    }
    note.dispose();
    super.dispose();
  }

  /// The earlier training with a body weight entered, if any.
  Session? get lastWeighed => store.sessions.where((x) => x != s && x.bodyWeight != null).firstOrNull;

  /// Body weight entered on an earlier training.
  double? get lastWeight => lastWeighed?.bodyWeight;

  /// Days since the body weight was last entered, once that's over a month (only if it's tracked at all).
  int? get weightStale => switch (lastWeighed) {
        final x? when s.date.difference(x.date).inDays > 30 => s.date.difference(x.date).inDays,
        _ => null,
      };

  /// ±0.1 in the shown unit. The first tap starts from the last body weight entered.
  void nudge(int dir) => setState(() {
        final base = bodyWeight ?? lastWeight;
        bodyWeight = base == null
            ? toKg(unit.value == WeightUnit.kg ? 75 : 165)
            : bodyWeight == null
                ? base
                : toKg(((shown(base) * 10).round() + dir) / 10);
      });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final r = sessionRecap(s, store.sessions);
    final strength = s.exercises.where((e) => !e.cardio).toList();
    // What the progression did: only meaningful while this is the latest training of its workout.
    final plan = store.workouts.where((w) => w.id == s.workoutId).firstOrNull;
    final nextOf = plan != null && store.lastSessionOf(plan) == s
        ? {
            for (final l in strength)
              if (plan.exercises.where((e) => e.name == l.name && !e.noWeight).firstOrNull case final e?) l.name: (l, e.weight),
          }
        : const <String, (ExerciseLog, double)>{};
    final delta = switch (r.volumeBefore) {
      final b? when b > 0 => ((r.volume / b - 1) * 100).round(),
      _ => null,
    };
    final headline = r.records.isNotEmpty
        ? 'Neuer Rekord! 🏆'
        : r.succeeded == s.exercises.length
            ? 'Alles geschafft! 💪'
            : null;
    final records = {for (final (name, _) in r.records) name};
    final heaviest = strength.fold(0.0, (m, e) => e.setsDone > 0 && e.weight > m ? e.weight : m);
    final small = TextStyle(fontSize: 12, color: c.onSurfaceVariant);
    const title = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

    // Under each exercise's name: 🏆 for a record (the headline says so), then its weight next time
    // (explained once above the card, so long names stay short).
    Widget? detail(String name) {
      final record = records.contains(name);
      final next = nextOf[name];
      final time = timeTaken(s, name, perSet: true);
      if (!record && next == null && time == null) return null;
      final parts = <InlineSpan>[if (record) const TextSpan(text: '🏆 ')];
      if (next case (final l, final kg)) {
        final (icon, color) = kg > l.weight
            ? (Icons.arrow_upward, c.primary)
            : kg < l.weight
                ? (Icons.arrow_downward, c.tertiary)
                : (Icons.arrow_forward, c.onSurfaceVariant);
        parts.addAll([
          // Arrow and weight as one piece, so a line break never splits them.
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: color),
              Text(' ${weightLabel(kg)}', style: small.copyWith(color: color, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]);
      }
      // The time on a line of its own, so it never breaks in the middle.
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (parts.isNotEmpty) Text.rich(TextSpan(children: parts), style: small),
        if (time != null) Text(time, style: small),
      ]);
    }

    // One strip of key figures.
    Widget figure(String value, String label, [String? extra, Color? extraColor]) => Expanded(
          child: Column(children: [
            Text(value, maxLines: 1, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: label),
                if (extra != null) TextSpan(text: ' $extra', style: TextStyle(color: extraColor, fontWeight: FontWeight.w600)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
            ),
          ]),
        );
    final figures = [
      if (r.volume > 0) ...[
        figure(volumeLabel(r.volume), 'Volumen', delta == null ? null : '${delta >= 0 ? '+' : ''}$delta %',
            delta != null && delta < 0 ? c.tertiary : c.primary),
        figure(weightLabel(heaviest), 'Schwerster'),
      ],
      if (s.duration case final d? when d.inMinutes > 0) figure(durationLabel(d), 'Dauer'),
    ];

    // Big tap targets: a sweaty thumb right after training.
    Widget moodTile(int value, String emoji, String label) {
      final on = mood == value;
      return Expanded(
        child: Material(
          color: on ? c.primaryContainer : c.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: on ? c.primary : Colors.transparent, width: 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => mood = on ? null : value), // tap again to clear
            child: SizedBox(
              height: 76,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                        color: on ? c.onPrimaryContainer : c.onSurfaceVariant)),
              ]),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Zusammenfassung')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (headline != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Text(headline, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            ),
          if (nextOf.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
              child: Row(children: [
                for (final (icon, color) in [
                  (Icons.arrow_upward, c.primary),
                  (Icons.arrow_forward, c.onSurfaceVariant),
                  (Icons.arrow_downward, c.tertiary),
                ])
                  Icon(icon, size: 14, color: color),
                Text('  Gewicht fürs nächste Mal', style: small),
              ]),
            ),
          // The same card as in the history, so a training always looks the same.
          OverviewCard(
            title: s.workoutName,
            subtitle: dayLabel(s.date),
            rows: [for (final l in s.exercises) (l.name, l.weights, l.reps, l.targets, false, l.cardio ? l.km ?? l.targetKm : null, l.cardio)],
            detail: detail,
            perSet: true,
            timed: {for (final l in s.exercises) if (l.timed) l.name},
            actions: const [],
          ),
          if (figures.isNotEmpty) ...[
            const SizedBox(height: 5),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(children: figures)),
            ),
          ],
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Wie war’s?', style: title),
                const SizedBox(height: 10),
                Row(children: [
                  moodTile(1, '😣', 'Schlecht'),
                  const SizedBox(width: 8),
                  moodTile(2, '😐', 'Okay'),
                  const SizedBox(width: 8),
                  moodTile(3, '😄', 'Gut'),
                ]),
                const SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    width: 220,
                    // Last time's weight stays a grey placeholder until ± or typing takes it over.
                    child: BigStepper('Körpergewicht ($unitLabel)', bodyWeight == null ? '' : weightNum(bodyWeight!),
                        () => nudge(-1), () => nudge(1),
                        decimal: true,
                        hint: lastWeight == null ? null : weightNum(lastWeight!),
                        // Typing doesn't rebuild, so the field keeps focus; empty = not entered.
                        onTyped: (v) => bodyWeight = switch (parseWeight(v)) { final kg? when kg > 0 => kg, _ => null }),
                  ),
                ),
                if (bodyWeight == null) ...[
                  const SizedBox(height: 6),
                  if (weightStale case final days?)
                    Text('Zuletzt vor $days Tagen eingetragen. Einmal im Monat hält die Statistik aktuell.',
                        textAlign: TextAlign.center,
                        style: small.copyWith(color: c.tertiary, fontWeight: FontWeight.w600))
                  else
                    Text(lastWeight == null ? 'Optional' : 'Wie zuletzt? ± übernimmt den Wert.',
                        textAlign: TextAlign.center, style: small),
                ],
                const SizedBox(height: 12),
                if (!noteOpen)
                  Align(
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Notiz: Schlaf, Alkohol, Stress …'),
                      onPressed: () => setState(() => noteOpen = true),
                    ),
                  )
                else ...[
                  const Text('Umstände', style: title),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final MapEntry(key: tag, value: emoji) in noteTags.entries)
                      FilterChip(
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        label: Text('$emoji $tag'),
                        selected: tags.contains(tag),
                        onSelected: (on) => setState(() => on ? tags.add(tag) : tags.remove(tag)),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Sonst noch was? (optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
      // Always in reach, however long the list.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => Navigator.pop(context),
            child: const Text('Fertig'),
          ),
        ),
      ),
    );
  }
}
