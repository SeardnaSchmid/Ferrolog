import 'package:flutter/material.dart';

import 'edit.dart';
import 'main.dart';
import 'model.dart';
import 'units.dart';

/// After a training (and from the history): what was done, records, what changes next time,
/// plus body weight and a note. Edits are saved when the page closes.
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

  @override
  void dispose() {
    final text = note.text.trim();
    if (bodyWeight != s.bodyWeight || (text.isEmpty ? null : text) != s.note || mood != s.mood) {
      s.bodyWeight = bodyWeight;
      s.note = text.isEmpty ? null : text;
      s.mood = mood;
      store.updateSession(s);
    }
    note.dispose();
    super.dispose();
  }

  /// Body weight entered on an earlier training.
  double? get lastWeight => store.sessions.where((x) => x != s).map((x) => x.bodyWeight).nonNulls.firstOrNull;

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
    final next = plan != null && store.lastSessionOf(plan) == s
        ? [
            for (final l in strength)
              if (plan.exercises.where((e) => e.name == l.name && !e.noWeight).firstOrNull case final e?) (l, e.weight),
          ]
        : const <(ExerciseLog, double)>[];
    final delta = switch (r.volumeBefore) {
      final b? when b > 0 => ((r.volume / b - 1) * 100).round(),
      _ => null,
    };
    final (headline, emoji) = r.records.isNotEmpty
        ? ('Neuer Rekord!', '🏆')
        : r.succeeded == s.exercises.length
            ? ('Alles geschafft!', '💪')
            : ('Training gespeichert', '✅');

    // One strip of key figures instead of separate tiles.
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
    final heaviest = strength.fold(0.0, (m, e) => e.setsDone > 0 && e.weight > m ? e.weight : m);
    final records = {for (final (name, _) in r.records) name};
    final nextOf = {for (final (l, kg) in next) l.name: kg};
    final small = TextStyle(fontSize: 12, color: c.onSurfaceVariant);
    const title = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

    Widget arrow(ExerciseLog l) {
      final kg = nextOf[l.name];
      if (kg == null) return Text(l.weight > 0 ? weightLabel(l.weight) : '', style: const TextStyle(fontSize: 15));
      final (icon, color) = kg > l.weight
          ? (Icons.arrow_upward, c.primary)
          : kg < l.weight
              ? (Icons.arrow_downward, c.tertiary)
              : (Icons.arrow_forward, c.onSurfaceVariant);
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        Text(' ${weightLabel(kg)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
      ]);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Zusammenfassung')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$headline $emoji', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              Text(
                [s.workoutName, dayLabel(s.date), if (s.duration case final d? when d.inMinutes > 0) durationLabel(d)]
                    .join(' · '),
                style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
              ),
            ]),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(children: [
                figure('${r.setsDone}/${r.sets}', 'Sätze'),
                figure('${r.succeeded}/${s.exercises.length}', 'geschafft'),
                if (r.volume > 0) ...[
                  figure(volumeLabel(r.volume), 'Volumen', delta == null ? null : '${delta >= 0 ? '+' : ''}$delta %',
                      delta != null && delta < 0 ? c.tertiary : c.primary),
                  figure(weightLabel(heaviest), 'Schwerster'),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 10),
          // Every exercise in one list: 🏆 for a record, right what comes next time (or what was lifted).
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(children: [
                Row(children: [
                  const Expanded(child: Text('Übungen', style: title)),
                  Text(next.isEmpty ? 'Gewicht' : 'Nächstes Mal', style: small),
                ]),
                for (final l in s.exercises)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: l.name),
                            if (records.contains(l.name)) const TextSpan(text: ' 🏆'),
                            if (!l.succeeded) TextSpan(text: ' · ${l.setsDone}/${l.reps.length}', style: small),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      if (l.cardio)
                        Text(cardioLabel(l.reps.first, l.km), style: const TextStyle(fontSize: 15))
                      else
                        arrow(l),
                    ]),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Wie war’s?', style: title),
                const SizedBox(height: 10),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  emptySelectionAllowed: true, // tap again to clear
                  segments: const [
                    ButtonSegment(value: 1, label: Text('😣 Schlecht')),
                    ButtonSegment(value: 2, label: Text('😐 Okay')),
                    ButtonSegment(value: 3, label: Text('😄 Gut')),
                  ],
                  selected: {?mood},
                  onSelectionChanged: (v) => setState(() => mood = v.firstOrNull),
                ),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: BigStepper('Körpergewicht ($unitLabel)', bodyWeight == null ? '' : weightNum(bodyWeight!),
                        () => nudge(-1), () => nudge(1),
                        decimal: true,
                        // Typing doesn't rebuild, so the field keeps focus; empty = not entered.
                        onTyped: (v) => bodyWeight = switch (parseWeight(v)) { final kg? when kg > 0 => kg, _ => null }),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        switch (lastWeight) {
                          final kg? => 'Zuletzt ${weightLabel(kg)}.\n± startet dort.',
                          null => 'Optional. Wird im Verlauf angezeigt.',
                        },
                        style: small,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Notiz: Schlaf, Technik, Zwicken …',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
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
