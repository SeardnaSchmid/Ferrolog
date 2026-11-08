import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'body_map.dart';
import 'model.dart';
import 'muscles.dart';
import 'templates.dart';
import 'units.dart';

/// Edits a copy of a workout; nothing is stored until "Speichern".
class EditWorkout extends StatefulWidget {
  final Workout workout;
  const EditWorkout(this.workout, {super.key});

  @override
  State<EditWorkout> createState() => _EditWorkoutState();
}

class _EditWorkoutState extends State<EditWorkout> {
  Workout get w => widget.workout;
  late final bool isNew = !store.workouts.any((x) => x.id == w.id);
  late final nameField = TextEditingController(text: w.name);
  Program? program; // picked template; null = none yet or "Custom"
  Day? day;
  bool custom = false;
  bool changedByHand = false; // exercises edited since the template was applied
  String? autoName; // name the template set; replaced again as long as it wasn't typed over

  @override
  void dispose() {
    nameField.dispose();
    super.dispose();
  }

  /// Shows a template day's exercises right away (WYSIWYG). Asks first if the list was edited by hand.
  Future<void> applyDay(Program p, Day? d) async {
    if (changedByHand && w.exercises.isNotEmpty) {
      if (!await confirm(context, 'Deine Änderungen an der Übungsliste ersetzen?')) return;
    }
    setState(() {
      program = d == null ? null : p;
      day = d;
      custom = d == null;
      w.exercises = [
        for (final (name, sets, reps) in d?.exercises ?? const <(String, int, int)>[])
          knownExercise(name, sets: sets, reps: reps)..maxReps = d!.upTo[name],
      ];
      changedByHand = false;
      final next = d?.workoutName;
      if (nameField.text.trim().isEmpty || nameField.text == autoName) {
        nameField.text = next ?? '';
        w.name = nameField.text;
        autoName = next;
      }
    });
  }

  Future<void> editExercise([int? index]) async {
    final result = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ExerciseEditor(index == null ? null : w.exercises[index].copy()),
      ),
    );
    if (result == null) return;
    setState(() {
      index == null ? w.exercises.add(result) : w.exercises[index] = result;
      changedByHand = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Neues Workout' : 'Workout bearbeiten'),
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Workout löschen',
              onPressed: () async {
                if (!await confirm(context, '„${w.name}“ löschen? Der Verlauf bleibt erhalten.')) return;
                store.deleteWorkout(w);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: () {
                if (w.name.trim().isEmpty) w.name = 'Neues Workout';
                store.saveWorkout(w);
                Navigator.pop(context);
              },
              child: const Text('Speichern'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: nameField,
              autofocus: isNew,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'z. B. Workout A',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => w.name = v,
            ),
          ),
          // Templates only for new workouts, so an existing one isn't replaced by accident.
          if (isNew) templatePicker(context),
          Expanded(
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 24),
              footer: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: DashedAddButton('Übung', editExercise),
              ),
              onReorder: (from, to) => setState(() {
                changedByHand = true;
                if (to > from) to--;
                w.exercises.insert(to, w.exercises.removeAt(from));
              }),
              children: [
                for (final (i, e) in w.exercises.indexed)
                  ListTile(
                    key: ObjectKey(e),
                    title: Text(e.name),
                    subtitle: Text(e.cardio
                        ? 'Cardio · ${cardioLabel(e.reps, e.km)}'
                        : [
                            setsLabel(e.repsPerSet, e.maxReps),
                            if (!e.noWeight) weightLabel(e.weight),
                            if (e.up && !e.noWeight) '+${weightLabel(e.increment)} bei Erfolg',
                          ].join(' · ')),
                    onTap: () => editExercise(i),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Übung entfernen',
                          onPressed: () => setState(() {
                            w.exercises.remove(e);
                            changedByHand = true;
                          }),
                        ),
                        ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Program chips, and below them the program's days when it has more than one.
  Widget templatePicker(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final p = program;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Vorlage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.onSurfaceVariant)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final x in programs)
            ChoiceChip(
              showCheckmark: false,
              label: Text(x.name),
              selected: p == x,
              onSelected: (_) => applyDay(x, x.days.first),
            ),
          ChoiceChip(
            showCheckmark: false,
            avatar: const Icon(Icons.edit, size: 14),
            label: const Text('Custom'),
            selected: custom,
            onSelected: (_) => applyDay(programs.first, null),
          ),
        ]),
        if (p != null && p.days.length > 1) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.subdirectory_arrow_right, size: 18, color: c.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final d in p.days)
                  ChoiceChip(
                    showCheckmark: false,
                    label: Text(d.name),
                    selected: day == d,
                    onSelected: (_) => applyDay(p, d),
                  ),
              ]),
            ),
          ]),
        ],
        if (p?.note case final note?) ...[
          const SizedBox(height: 6),
          Text(note, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
        ],
        if (custom) ...[
          const SizedBox(height: 6),
          Text('Leg deine Übungen unten mit „+ Übung“ an.', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
        ],
      ]),
    );
  }
}

/// Full-screen add/edit of one exercise (design screen 07): search in German or English,
/// steppers for sets and reps, one weight or one per set, rest time and automatic adjustment.
/// Works on a copy; returns it on "Hinzufügen"/"Übernehmen", null on close.
class ExerciseEditor extends StatefulWidget {
  final Exercise? initial;
  const ExerciseEditor(this.initial, {super.key});

  @override
  State<ExerciseEditor> createState() => _ExerciseEditorState();
}

class _ExerciseEditorState extends State<ExerciseEditor> {
  late final Exercise e = widget.initial ?? Exercise(name: '');
  late final nameField = TextEditingController(text: e.name);
  late List<double> ws = List.of(e.noWeight ? List.filled(e.sets, 20.0) : e.weights); // kg, one per set
  late List<int> rs = List.of(e.repsPerSet); // reps, one per set
  late bool noWeight = e.noWeight;
  late int? maxReps = e.maxReps; // rep range top, null = fixed reps
  late bool byDistance = e.cardio && e.km != null; // cardio goal
  String? filledFrom; // catalogue/used exercise whose defaults were taken
  bool typed = false; // suggestions only once the name was typed, not for an opened exercise
  String? editing; // chip group with its "Eigene" input open: 'pause', 'inc' or 'dec'
  Muscles? muscles; // changed in this editor; null = follow the name
  final draft = TextEditingController();

  @override
  void dispose() {
    nameField.dispose();
    draft.dispose();
    super.dispose();
  }

  List<String> get knownNames => {
        ...exerciseCatalogue.keys,
        ...cardioCatalogue.keys,
        for (final w in store.workouts) ...w.exercises.map((e) => e.name),
        ...store.loggedExercises,
      }.toList()
        ..sort();

  List<String> get suggestions => typed ? searchExercises(e.name, knownNames).take(6).toList() : [];

  void pick(String name) {
    nameField.text = name;
    final x = knownExercise(name);
    setState(() {
      e
        ..name = name
        ..cardio = x.cardio
        ..timed = x.timed
        ..km = x.km
        ..sets = x.sets
        ..reps = x.reps
        ..weight = x.weight
        ..increment = x.increment
        ..up = x.up
        ..decrement = x.decrement
        ..down = x.down
        ..failsToDeload = x.failsToDeload
        ..restSeconds = x.restSeconds;
      noWeight = x.noWeight;
      ws = List.of(noWeight ? List.filled(x.sets, 20.0) : x.weights);
      rs = List.of(x.repsPerSet);
      maxReps = x.maxReps;
      byDistance = x.cardio && x.km != null;
      e.failRestSeconds = x.failRestSeconds;
      filledFrom = name;
    });
  }

  /// Weight steps: 2,5 kg (5 lb), snapped to that grid and never below 0.
  double get step => unit.value == WeightUnit.kg ? 2.5 : 5; // in the shown unit

  /// Distance goal ± 0,5 (km or mi), never below 0,5.
  double nudgedKm(int dir) {
    final perUnit = unit.value == WeightUnit.lb ? kmPerMile : 1.0;
    return max(.5, ((e.km ?? 5) / perUnit * 2).round() / 2 + dir * .5) * perUnit;
  }

  double nudged(double kg, int dir) =>
      toKg((((shown(kg) + dir * step) / step).round() * step).clamp(0, shown(1000)).toDouble());

  Exercise result() {
    e.name = e.name.trim();
    if (muscles case final m? when !e.cardio) setMuscles(e.name, m);
    if (e.cardio) {
      return e
        ..sets = 1
        ..setWeights = null
        ..setReps = null
        ..maxReps = null
        ..failRestSeconds = null
        ..weight = 0
        ..timed = false
        ..reps = byDistance ? 0 : max(1, e.reps)
        ..km = byDistance ? e.km ?? 5 : null
        ..up = false
        ..down = false;
    }
    e
      ..km = null
      ..sets = rs.length
      ..reps = rs.first
      ..setReps = rs.toSet().length == 1 ? null : List.of(rs)
      ..maxReps = maxReps == null ? null : max(maxReps!, rs.reduce(max))
      ..weight = noWeight ? 0 : ws.reduce(max)
      ..setWeights = noWeight || ws.toSet().length == 1 ? null : List.of(ws);
    if (noWeight) {
      e
        ..up = false
        ..down = false;
    }
    return e;
  }

  /// Sheet for one set: reps and weight, for this set or all sets; or delete it.
  Future<void> editSet(int i) async {
    var r = rs[i], w = ws[i], all = rs.toSet().length == 1 && ws.toSet().length == 1, delete = false;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(builder: (context, setSheet) {
        final c = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Text(e.name.trim().isEmpty ? 'Satz' : e.name.trim(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Text('Satz ${i + 1} von ${rs.length}', style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                // Typing doesn't rebuild the sheet, so the field keeps focus; ± swap in the new value.
                child: e.timed
                    ? BigStepper(maxReps == null ? 'Sekunden' : 'Sekunden mindestens', '$r', () => setSheet(() => r = max(5, (r - 1) ~/ 5 * 5)),
                        () => setSheet(() => r = min(600, r ~/ 5 * 5 + 5)),
                        onTyped: (v) => r = (int.tryParse(v) ?? r).clamp(1, 600))
                    : BigStepper(maxReps == null ? 'Wiederholungen' : 'Wdh. mindestens', '$r',
                        () => setSheet(() => r = max(1, r - 1)), () => setSheet(() => r = min(50, r + 1)),
                        onTyped: (v) => r = (int.tryParse(v) ?? r).clamp(1, 50)),
              ),
              if (!noWeight) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: BigStepper('Gewicht ($unitLabel)', weightNum(w), () => setSheet(() => w = nudged(w, -1)),
                      () => setSheet(() => w = nudged(w, 1)),
                      decimal: true,
                      onTyped: (v) => w = switch (parseWeight(v)) {
                            final kg? when kg >= 0 && kg <= 1000 => kg,
                            _ => w,
                          }),
                ),
              ],
            ]),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Dieser Satz')),
                ButtonSegment(value: true, label: Text('Alle Sätze')),
              ],
              selected: {all},
              onSelectionChanged: (v) => setSheet(() => all = v.single),
            ),
            const SizedBox(height: 20),
            Row(children: [
              if (rs.length > 1) ...[
                IconButton.outlined(
                  icon: Icon(Icons.delete_outline, color: c.error),
                  tooltip: 'Satz löschen',
                  onPressed: () {
                    delete = true;
                    Navigator.pop(context, true);
                  },
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Schließen'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Speichern'),
                ),
              ),
            ]),
          ]),
        );
      }),
    );
    if (saved != true) return;
    setState(() {
      if (delete) {
        rs.removeAt(i);
        ws.removeAt(i);
      } else if (all) {
        // Only what was changed goes to all sets, so a pyramid keeps its weights when only reps change.
        if (r != rs[i]) rs = List.filled(rs.length, r);
        if (w != ws[i]) ws = List.filled(ws.length, w);
      } else {
        rs[i] = r;
        ws[i] = w;
      }
      if (maxReps case final top?) maxReps = max(top, rs.reduce(max)); // the range top stays above every set
    });
  }

  /// Muscles as chips; a tap goes primary → secondary (counts half) → off.
  Widget musclePicker(BoxDecoration card, TextStyle muted) {
    final (p, s) = muscles ?? musclesOf(e.name) ?? (0, 0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Muskeln', style: TextStyle(fontWeight: FontWeight.w500)),
        // An own exercise nothing is known about: without muscles it's missing from the statistics.
        if (muscles == null && musclesOf(e.name) == null && e.name.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Unbekannte Übung: Ohne Muskeln fehlt sie in Balance und Muskelkarte. Bitte antippen, was sie trainiert.',
              style: muted.copyWith(color: Theme.of(context).colorScheme.tertiary, fontWeight: FontWeight.w500)),
        ],
        const SizedBox(height: 12),
        BodyMap((p, s), height: 180),
        const SizedBox(height: 14),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final g in Muscle.values) // ordered by body region
            FilterChip(
              label: Text(s & g.bit != 0 ? '${g.label} ½' : g.label),
              selected: (p | s) & g.bit != 0,
              showCheckmark: p & g.bit != 0,
              onSelected: (_) => setState(() => muscles = p & g.bit != 0
                  ? (p & ~g.bit, s | g.bit)
                  : s & g.bit != 0
                      ? (p, s & ~g.bit)
                      : (p | g.bit, s)),
            ),
        ]),
        const SizedBox(height: 8),
        Text('Antippen: Hauptmuskel ✓ → hilft mit ½ → aus. Für die Statistik.', style: muted),
      ]),
    );
  }

  /// A new set, copied from the last one.
  void addSet() => setState(() {
        if (rs.length >= 12) return;
        rs.add(rs.last);
        ws.add(ws.last);
      });

  /// Switches between strength and cardio with sensible starting values.
  void setCardio(bool cardio) => setState(() {
        if (cardio == e.cardio) return;
        e.cardio = cardio;
        if (cardio) {
          e
            ..reps = 30 // minutes
            ..km = null;
          byDistance = false;
        } else {
          e.up = true;
          rs = List.filled(3, 8);
          ws = List.filled(3, ws.isEmpty ? 20 : ws.first);
        }
      });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12, color: c.onSurfaceVariant);
    final isNew = widget.initial == null;
    final sugg = suggestions;
    final card = BoxDecoration(
      color: c.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.outlineVariant.withValues(alpha: .6)),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Schließen', onPressed: () => Navigator.pop(context)),
        title: Text(isNew ? 'Übung hinzufügen' : 'Übung bearbeiten'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: e.name.trim().isEmpty ? null : () => Navigator.pop(context, result()),
              child: Text(isNew ? 'Hinzufügen' : 'Speichern'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          TextField(
            controller: nameField,
            autofocus: isNew,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Übung suchen oder eigene eingeben',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: c.surfaceContainerHigh,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() {
              e.name = v;
              typed = true;
              filledFrom = null;
            }),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final n in sugg) ChoiceChip(showCheckmark: false, label: Text(n), selected: n == e.name, onSelected: (_) => pick(n)),
            if (typed && sugg.isEmpty && e.name.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Kein Treffer – eigener Name wird übernommen', style: muted),
              ),
          ]),
          if (filledFrom != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.auto_awesome, size: 14, color: c.primary),
              const SizedBox(width: 6),
              Flexible(child: Text('Standardwerte für $filledFrom übernommen', style: muted)),
            ]),
          ],
          const SizedBox(height: 18),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.fitness_center), label: Text('Kraft')),
              ButtonSegment(value: true, icon: Icon(Icons.directions_run), label: Text('Cardio')),
            ],
            selected: {e.cardio},
            onSelectionChanged: (v) => setCardio(v.single),
          ),
          const SizedBox(height: 18),
          if (e.cardio) ...[
            // One goal: how long or how far. What was actually done is logged in the training.
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, icon: Icon(Icons.timer_outlined), label: Text('Dauer')),
                ButtonSegment(value: true, icon: Icon(Icons.route_outlined), label: Text('Distanz')),
              ],
              selected: {byDistance},
              onSelectionChanged: (v) => setState(() {
                byDistance = v.single;
                if (byDistance) e.km ??= 5;
                if (!byDistance && e.reps <= 0) e.reps = 30;
              }),
            ),
            const SizedBox(height: 18),
            if (byDistance)
              BigStepper('Ziel ($distanceLabel)', distanceNum(e.km ?? 5), () => setState(() => e.km = nudgedKm(-1)),
                  () => setState(() => e.km = nudgedKm(1)),
                  decimal: true, onTyped: (v) => e.km = parseDistance(v) ?? e.km)
            else
              BigStepper('Ziel (Min)', '${max(1, e.reps)}', () => setState(() => e.reps = max(1, e.reps - 1)),
                  () => setState(() => e.reps = min(600, e.reps + 1)),
                  // Typing doesn't rebuild, so the field keeps focus; the steppers swap in the new value.
                  onTyped: (v) => e.reps = (int.tryParse(v) ?? e.reps).clamp(1, 600)),
          ] else ...[
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.fitness_center), label: Text('Mit Gewicht')),
              ButtonSegment(value: true, icon: Icon(Icons.accessibility_new), label: Text('Ohne Gewicht')),
            ],
            selected: {noWeight},
            onSelectionChanged: (v) => setState(() => noWeight = v.single),
          ),
          const SizedBox(height: 8),
          // Held or carried for a time (plank, farmer's walk): seconds instead of reps.
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.repeat), label: Text('Wiederholungen')),
              ButtonSegment(value: true, icon: Icon(Icons.timer_outlined), label: Text('Zeit')),
            ],
            selected: {e.timed},
            onSelectionChanged: (v) => setState(() {
              if (v.single == e.timed) return;
              e.timed = v.single;
              rs = List.filled(rs.length, e.timed ? 30 : 8);
              if (e.timed) maxReps = null;
            }),
          ),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Text('Sätze', style: TextStyle(fontWeight: FontWeight.w500))),
            Flexible(
              child: Text(isNew ? 'Satz antippen zum Ändern' : 'Nächstes Training · antippen zum Ändern',
                  textAlign: TextAlign.end, style: muted),
            ),
          ]),
          const SizedBox(height: 8),
          // Four tiles per row, like the sets in the training.
          LayoutBuilder(builder: (context, box) {
            final w = (box.maxWidth - 3 * 8) / 4;
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < rs.length; i++)
                _PlanTile(
                    width: w,
                    reps: rs[i],
                    maxReps: maxReps,
                    seconds: e.timed,
                    weight: noWeight ? null : ws[i],
                    onTap: () => editSet(i)),
              if (rs.length < 12) SizedBox(width: w, child: DashedAddButton('Satz', addSet, height: noWeight ? 56 : 94)),
            ]);
          }),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(e.timed ? 'Zeit-Spanne' : 'Wiederholungs-Spanne'),
            subtitle: Text(maxReps == null
                ? e.timed
                    ? 'Aus · feste Zeit'
                    : 'Aus · feste Wiederholungen'
                : '${setsLabel(rs, maxReps, seconds: e.timed)} · Gewicht steigt erst, wenn alle Sätze '
                    '$maxReps ${e.timed ? 's' : 'Wdh.'} schaffen'),
            value: maxReps != null,
            onChanged: (on) => setState(() => maxReps = on ? rangeTop(rs.reduce(max), seconds: e.timed) : null),
          ),
          if (maxReps case final top?)
            Row(children: [
              Expanded(child: Text(e.timed ? 'Bis Sekunden' : 'Bis Wiederholungen', style: TextStyle(color: c.onSurfaceVariant))),
              IconButton.filledTonal(
                icon: const Icon(Icons.remove, size: 20),
                onPressed: () => setState(() => maxReps = max(rs.reduce(max), top - (e.timed ? 5 : 1))),
              ),
              SizedBox(
                width: 36,
                child: Text('$top', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => setState(() => maxReps = e.timed ? min(600, top + 5) : min(50, top + 1)),
              ),
            ]),
          const SizedBox(height: 18),
          musclePicker(card, muted),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: card,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.timer_outlined, size: 20, color: c.onSurfaceVariant),
                const SizedBox(width: 10),
                const Expanded(child: Text('Pause', style: TextStyle(fontWeight: FontWeight.w500))),
                Text(clock(e.restSeconds), style: TextStyle(fontWeight: FontWeight.w500, color: c.primary)),
              ]),
              const SizedBox(height: 12),
              chips(
                key: 'pause',
                presets: const [30, 60, 90, 120, 180],
                current: e.restSeconds.toDouble(),
                label: (v) => clock(v.round()),
                set: (v) => e.restSeconds = v.round(),
                hint: 'z. B. 2:30',
                unitText: 'min:s oder s',
                parse: parseDuration,
              ),
              const SizedBox(height: 14),
              Text('Nach nicht geschafftem Satz', style: muted.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              chips(
                key: 'failpause',
                presets: const [0, 120, 180, 240, 300], // 0 = same as above
                current: (e.failRestSeconds ?? 0).toDouble(),
                label: (v) => v == 0 ? 'Wie oben' : clock(v.round()),
                set: (v) => e.failRestSeconds = v == 0 ? null : v.round(),
                hint: 'z. B. 4:00',
                unitText: 'min:s oder s',
                parse: parseDuration,
              ),
            ]),
          ),
          if (!noWeight) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: card,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Automatische Anpassung · optional',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.primary)),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.trending_up),
                title: const Text('Steigerung bei Erfolg'),
                subtitle: Text(e.up
                    ? '+${weightLabel(e.increment)}, wenn alle Sätze geschafft'
                    : 'Aus · Gewicht bleibt gleich'),
                value: e.up,
                onChanged: (on) => setState(() {
                  e.up = on;
                  if (editing == 'inc') editing = null;
                }),
              ),
              if (e.up) weightChips('inc', '+', e.increment, (kg) => e.increment = kg),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.trending_down),
                title: const Text('Senkung bei Misserfolg'),
                subtitle: Text(e.down
                    ? '−${weightLabel(e.decrement)} nach ${e.failsToDeload}× nicht geschafft'
                    : 'Aus · Gewicht bleibt gleich'),
                value: e.down,
                onChanged: (on) => setState(() {
                  e.down = on;
                  if (editing == 'dec') editing = null;
                }),
              ),
              if (e.down) ...[
                weightChips('dec', '−', e.decrement, (kg) => e.decrement = kg),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Text('Senken nach Fehlversuchen in Folge', style: TextStyle(color: c.onSurfaceVariant))),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove, size: 20),
                    onPressed: () => setState(() => e.failsToDeload = max(1, e.failsToDeload - 1)),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text('${e.failsToDeload}',
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: () => setState(() => e.failsToDeload = min(5, e.failsToDeload + 1)),
                  ),
                ]),
              ],
            ]),
          ),
          ],
          ],
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(summary, style: muted.copyWith(height: 1.45)),
          ),
        ],
      ),
    );
  }

  String get summary {
    final name = e.name.trim().isEmpty ? 'Neue Übung' : e.name.trim();
    if (e.cardio) {
      final goal = byDistance ? '${distanceNum(e.km ?? 5)} $distanceLabel' : '${e.reps} Min';
      return '$name: Ziel $goal. Im Training startest du die Stoppuhr mit einem Tipp.';
    }
    final plan = noWeight
        ? '${setsLabel(rs, maxReps)} ohne Gewicht'
        : ws.toSet().length == 1
            ? '${setsLabel(rs, maxReps)} mit ${weightLabel(ws.first)}'
            : [for (final (i, w) in ws.indexed) '${rs[i]}×${weightLabel(w)}'].join(', ');
    if (noWeight) return '$name: $plan.';
    return [
      '$name: $plan.',
      if (e.up) 'Bei Erfolg +${weightLabel(e.increment)}.',
      if (e.down) 'Nach ${e.failsToDeload}× Misserfolg −${weightLabel(e.decrement)}.',
      if (!e.up && !e.down) 'Gewicht wird nicht automatisch angepasst.',
    ].join(' ');
  }

  /// Plate-sized steps for increment/decrement chips, in the shown unit.
  Widget weightChips(String key, String sign, double kg, void Function(double kg) set) => chips(
        key: key,
        presets: unit.value == WeightUnit.kg ? const [0.25, 0.5, 1, 2.5, 5] : const [0.5, 1, 2.5, 5, 10],
        current: shown(kg),
        label: (v) => '$sign${weightNum(toKg(v))} $unitLabel',
        set: (v) => set(toKg(v)),
        hint: unit.value == WeightUnit.kg ? 'z. B. 1,25' : 'z. B. 7,5',
        unitText: unitLabel,
        prefix: sign,
        // Comma or point, at most 2 decimals, above 0.
        parse: (s) => switch (double.tryParse(s.trim().replaceAll(',', '.'))) {
          final v? when v > 0 => (v * 100).roundToDouble() / 100,
          _ => null,
        },
      );

  /// Preset chips plus "Eigene", which opens an input for any other value.
  Widget chips({
    required String key,
    required List<num> presets,
    required double current,
    required String Function(double) label,
    required void Function(double) set,
    required String hint,
    required String unitText,
    required double? Function(String) parse,
    String prefix = '',
  }) {
    final isPreset = presets.any((p) => p == current);
    final open = editing == key;
    void ok() => setState(() {
          if (parse(draft.text) case final v?) set(v);
          editing = null;
        });
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final p in presets)
          ChoiceChip(
            showCheckmark: false,
            label: Text(label(p.toDouble())),
            selected: p == current && !open,
            onSelected: (_) => setState(() {
              set(p.toDouble());
              editing = null;
            }),
          ),
        ChoiceChip(
          showCheckmark: false,
          avatar: const Icon(Icons.edit, size: 14),
          label: Text(isPreset ? 'Eigene' : label(current)),
          selected: !isPreset || open,
          onSelected: (_) => setState(() {
            editing = open ? null : key;
            draft.text = '';
          }),
        ),
      ]),
      if (open) ...[
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: draft,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                isDense: true,
                prefixText: prefix.isEmpty ? null : '$prefix ',
                suffixText: unitText,
                hintText: hint,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => ok(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: ok, child: const Text('OK')),
        ]),
      ],
    ]);
  }
}

/// An exercise as you'd set it up today: your settings from another workout if it's in one,
/// else catalogue defaults with your last logged weight. [sets]/[reps] override (templates).
Exercise knownExercise(String name, {int? sets, int? reps}) {
  final used = store.workouts.expand((w) => w.exercises).where((x) => x.name == name).firstOrNull;
  final Exercise e;
  if (used != null) {
    e = used.copy()..fails = 0;
  } else if (cardioCatalogue[name] case (final minutes, final km)) {
    return Exercise.cardio(name: name, minutes: minutes, km: km);
  } else {
    final d = exerciseCatalogue[name];
    e = Exercise(name: name, timed: timedExercises.contains(name));
    if (d != null) {
      e
        ..sets = d.$1
        ..reps = d.$2
        ..weight = d.$3
        ..increment = d.$4
        ..restSeconds = d.$5
        ..failRestSeconds = heavyLifts.contains(name) ? 120 : null
        // Accessories start with a range: the weight goes up once every set reaches its top.
        ..maxReps = heavyLifts.contains(name) ? null : rangeTop(d.$2, seconds: e.timed);
      if (unit.value == WeightUnit.lb) {
        // Catalogue values are kg; in lb start on round plates (50 kg → 110 lb, +2,5 kg → +5 lb).
        e
          ..weight = toKg((shown(e.weight) / 5).round() * 5.0)
          ..increment = toKg(stepShown(e.increment));
      }
    }
    if (store.historyOf(name).lastOrNull?.$2 case final logged?) e.weight = logged.weight;
  }
  if (sets != null && sets != e.sets) {
    e
      ..sets = sets
      ..setWeights = null // a different set count can't keep a per-set shape
      ..setReps = null;
  }
  if (reps != null) {
    e
      ..reps = reps
      ..setReps = null;
  }
  return e;
}

/// "2:30" → 150, "90" → 90 (seconds); null when not a positive duration.
double? parseDuration(String s) {
  s = s.trim();
  final parts = s.split(':');
  final secs = parts.length == 2
      ? (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0)
      : int.tryParse(s) ?? 0;
  return secs > 0 ? secs.toDouble() : null;
}

String clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// Big number with −/+ underneath, as in the design's sets/reps fields.
class BigStepper extends StatelessWidget {
  final String label, value;
  final VoidCallback onMinus, onPlus;

  /// Makes the value typeable: whole numbers, or with [decimal] a comma/point too.
  final void Function(String)? onTyped;
  final bool decimal;

  /// Shown greyed while [value] is empty, e.g. the last body weight.
  final String? hint;
  const BigStepper(this.label, this.value, this.onMinus, this.onPlus,
      {super.key, this.onTyped, this.decimal = false, this.hint});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    const style = TextStyle(fontSize: 28, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]);
    Widget button(IconData icon, VoidCallback onTap, BorderRadius radius) => Expanded(
          child: Material(
            color: c.surfaceContainerHigh,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: SizedBox(height: 44, child: Icon(icon, size: 22)),
            ),
          ),
        );
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.onSurfaceVariant)),
      const SizedBox(height: 6),
      Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16), bottom: Radius.circular(4)),
        ),
        child: switch (onTyped) {
          null => Text(value.isEmpty ? hint ?? '' : value,
              style: value.isEmpty ? style.copyWith(color: c.onSurfaceVariant.withValues(alpha: .45)) : style),
          final typed => TextFormField(
              key: ValueKey(value),
              initialValue: value,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
              style: style,
              decoration: InputDecoration.collapsed(
                  hintText: hint ?? '', hintStyle: style.copyWith(color: c.onSurfaceVariant.withValues(alpha: .45))),
              onChanged: typed,
            ),
        },
      ),
      const SizedBox(height: 2),
      Row(children: [
        button(Icons.remove, onMinus,
            const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4))),
        const SizedBox(width: 2),
        button(Icons.add, onPlus,
            const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4), bottomLeft: Radius.circular(4), bottomRight: Radius.circular(16))),
      ]),
    ]);
  }
}

/// A planned set in the editor: reps on top, weight below (none without weight). Tap to edit.
class _PlanTile extends StatelessWidget {
  final double width;
  final int reps;
  final int? maxReps;
  final bool seconds;
  final double? weight;
  final VoidCallback onTap;
  const _PlanTile(
      {required this.width,
      required this.reps,
      required this.maxReps,
      this.seconds = false,
      required this.weight,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final w = weight;
    const figures = [FontFeature.tabularFigures()];
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: c.surfaceContainer,
          child: InkWell(
            onTap: onTap,
            child: Column(children: [
              Container(
                height: 56,
                color: c.surfaceContainerHigh,
                alignment: Alignment.center,
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '$reps', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  if (maxReps case final top? when top > reps)
                    TextSpan(text: '–$top', style: TextStyle(fontSize: 16, color: c.onSurfaceVariant)),
                  if (seconds) TextSpan(text: ' s', style: TextStyle(fontSize: 16, color: c.onSurfaceVariant)),
                ]), style: const TextStyle(fontFeatures: figures)),
              ),
              if (w != null) ...[
                const SizedBox(height: 2),
                SizedBox(
                  height: 36,
                  child: Center(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: weightNum(w)),
                      TextSpan(text: ' $unitLabel', style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
                    ]), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, fontFeatures: figures)),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
