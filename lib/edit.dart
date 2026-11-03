import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'model.dart';
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
          knownExercise(name, sets: sets, reps: reps),
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
          TextButton(
            onPressed: () {
              if (w.name.trim().isEmpty) w.name = 'Neues Workout';
              store.saveWorkout(w);
              Navigator.pop(context);
            },
            child: const Text('Speichern'),
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
                        : '${e.sets}×${e.reps} · ${weightLabel(e.weight)} · +${weightLabel(e.increment)} bei Erfolg'),
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
  late bool perSet = e.setWeights != null;
  late List<double> ws = List.of(e.weights); // kg, one per set
  String? filledFrom; // catalogue/used exercise whose defaults were taken
  bool typed = false; // suggestions only once the name was typed, not for an opened exercise
  String? editing; // chip group with its "Eigene" input open: 'pause', 'inc' or 'dec'
  final draft = TextEditingController();
  late double lastIncrement = e.increment > 0 ? e.increment : 2.5;
  late double lastDecrement = e.decrement > 0 ? e.decrement : 2.5;

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
        ..km = x.km
        ..sets = x.sets
        ..reps = x.reps
        ..weight = x.weight
        ..increment = x.increment
        ..decrement = x.decrement
        ..failsToDeload = x.failsToDeload
        ..restSeconds = x.restSeconds;
      perSet = x.setWeights != null;
      ws = List.of(x.weights);
      if (e.increment > 0) lastIncrement = e.increment;
      filledFrom = name;
    });
  }

  void setSets(int n) => setState(() {
        n = n.clamp(1, 10);
        ws = [for (var i = 0; i < n; i++) i < ws.length ? ws[i] : ws.last];
        e.sets = n;
      });

  /// Weight steps: 2,5 kg (5 lb), snapped to that grid and never below 0.
  double get step => unit.value == WeightUnit.kg ? 2.5 : 5; // in the shown unit

  double nudged(double kg, int dir) =>
      toKg((((shown(kg) + dir * step) / step).round() * step).clamp(0, shown(1000)).toDouble());

  Exercise result() {
    e.name = e.name.trim();
    if (e.cardio) {
      return e
        ..sets = 1
        ..setWeights = null
        ..weight = 0
        ..increment = 0
        ..decrement = 0;
    }
    return e
      ..km = null
      ..setWeights = perSet ? List.of(ws) : null
      ..weight = perSet ? ws.reduce(max) : ws.first;
  }

  /// Switches between strength and cardio with sensible starting values.
  void setCardio(bool cardio) => setState(() {
        if (cardio == e.cardio) return;
        e.cardio = cardio;
        if (cardio) {
          e
            ..reps = 30 // minutes
            ..km = null;
        } else {
          e
            ..sets = 3
            ..reps = 8
            ..increment = lastIncrement;
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
            Row(children: [
              Expanded(
                child: _BigStepper('Dauer (Min)', '${e.reps}', () => setState(() => e.reps = max(1, e.reps - 5)),
                    () => setState(() => e.reps = min(600, e.reps + 5))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(children: [
                  Text('Distanz (optional)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  // Same height as the duration stepper (56 + 2 + 44), number and unit centered together.
                  Container(
                    height: 102,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        IntrinsicWidth(
                          child: TextFormField(
                            key: ValueKey('km${e.name}'),
                            initialValue: switch (e.km) { final km? => distanceNum(km), null => '' },
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration.collapsed(hintText: '–'),
                            onChanged: (v) => setState(() => e.km = parseDistance(v)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(distanceLabel, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ]),
              ),
            ]),
          ] else ...[
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Gleiches Gewicht')),
              ButtonSegment(value: true, label: Text('Gewicht pro Satz')),
            ],
            selected: {perSet},
            onSelectionChanged: (v) => setState(() {
              perSet = v.single;
              if (!perSet) ws = List.filled(ws.length, ws.first);
            }),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _BigStepper('Sätze', '${e.sets}', () => setSets(e.sets - 1), () => setSets(e.sets + 1))),
            const SizedBox(width: 12),
            Expanded(
              child: _BigStepper('Wiederholungen', '${e.reps}', () => setState(() => e.reps = max(1, e.reps - 1)),
                  () => setState(() => e.reps = min(30, e.reps + 1))),
            ),
          ]),
          const SizedBox(height: 18),
          if (!perSet) ...[
            // In the plan this is what the next training starts with.
            Center(
              child: Text(isNew ? 'Startgewicht' : 'Gewicht nächstes Training',
                  style: muted.copyWith(fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 6),
            // Same grid as the sets/reps steppers above: −/+ as wide as their buttons.
            LayoutBuilder(builder: (context, box) {
              final button = (box.maxWidth - 16) / 4;
              return Row(children: [
                _StepButton(Icons.remove, button, left: true,
                    () => setState(() => ws = List.filled(ws.length, nudged(ws.first, -1)))),
                const SizedBox(width: 2),
                Expanded(
                  child: _WeightField(
                    key: ValueKey(ws.first),
                    kg: ws.first,
                    onChanged: (kg) => ws = List.filled(ws.length, kg),
                  ),
                ),
                const SizedBox(width: 2),
                _StepButton(Icons.add, button, left: false,
                    () => setState(() => ws = List.filled(ws.length, nudged(ws.first, 1)))),
              ]);
            }),
          ] else ...[
            Text(isNew ? 'Startgewicht pro Satz' : 'Gewicht pro Satz, nächstes Training',
                style: muted.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            for (var i = 0; i < ws.length; i++)
              Container(
                height: 52,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                decoration: card.copyWith(borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Text('Satz ${i + 1}', style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                  const Spacer(),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove, size: 20),
                    onPressed: () => setState(() => ws[i] = nudged(ws[i], -1)),
                  ),
                  SizedBox(
                    width: 84,
                    child: Text(weightLabel(ws[i]),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: () => setState(() => ws[i] = nudged(ws[i], 1)),
                  ),
                ]),
              ),
          ],
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
            ]),
          ),
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
                subtitle: Text(e.increment > 0
                    ? '+${weightLabel(e.increment)}, wenn alle Sätze geschafft'
                    : 'Aus · Gewicht bleibt gleich'),
                value: e.increment > 0,
                onChanged: (on) => setState(() {
                  if (e.increment > 0) lastIncrement = e.increment;
                  e.increment = on ? lastIncrement : 0;
                  if (editing == 'inc') editing = null;
                }),
              ),
              if (e.increment > 0) weightChips('inc', '+', e.increment, (kg) => e.increment = lastIncrement = kg),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.trending_down),
                title: const Text('Senkung bei Misserfolg'),
                subtitle: Text(e.decrement > 0
                    ? '−${weightLabel(e.decrement)} nach ${e.failsToDeload}× nicht geschafft'
                    : 'Aus · Gewicht bleibt gleich'),
                value: e.decrement > 0,
                onChanged: (on) => setState(() {
                  if (e.decrement > 0) lastDecrement = e.decrement;
                  e.decrement = on ? lastDecrement : 0;
                  if (editing == 'dec') editing = null;
                }),
              ),
              if (e.decrement > 0) ...[
                weightChips('dec', '−', e.decrement, (kg) => e.decrement = lastDecrement = kg),
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
    if (e.cardio) return '$name: ${cardioLabel(e.reps, e.km)}. Cardio wird nicht automatisch angepasst.';
    final plan = perSet
        ? ws.map((w) => '${e.reps}×${weightLabel(w)}').join(', ')
        : '${e.sets}×${e.reps} mit ${weightLabel(ws.first)}';
    return [
      '$name: $plan.',
      if (e.increment > 0) 'Bei Erfolg +${weightLabel(e.increment)}.',
      if (e.decrement > 0) 'Nach ${e.failsToDeload}× Misserfolg −${weightLabel(e.decrement)}.',
      if (e.increment <= 0 && e.decrement <= 0) 'Gewicht wird nicht automatisch angepasst.',
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
        // Comma or point, at most 2 decimals, above 0 (0 would mean off).
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
    e = Exercise(name: name);
    if (d != null) {
      e
        ..sets = d.$1
        ..reps = d.$2
        ..weight = d.$3
        ..increment = d.$4
        ..restSeconds = d.$5;
    }
    if (store.historyOf(name).lastOrNull?.$2 case final logged?) e.weight = logged.weight;
  }
  if (sets != null && sets != e.sets) {
    e
      ..sets = sets
      ..setWeights = null; // a different set count can't keep a per-set shape
  }
  if (reps != null) e.reps = reps;
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
class _BigStepper extends StatelessWidget {
  final String label, value;
  final VoidCallback onMinus, onPlus;
  const _BigStepper(this.label, this.value, this.onMinus, this.onPlus);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
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
        child: Text(value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
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

class _StepButton extends StatelessWidget {
  final IconData icon;
  final double width;
  final bool left; // outer corner rounded, inner ones square, as in the design
  final VoidCallback onTap;
  const _StepButton(this.icon, this.width, this.onTap, {required this.left});

  @override
  Widget build(BuildContext context) {
    const outer = Radius.circular(16), inner = Radius.circular(4);
    final radius = left
        ? const BorderRadius.horizontal(left: outer, right: inner)
        : const BorderRadius.horizontal(left: inner, right: outer);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: SizedBox(width: width, height: 60, child: Icon(icon)),
      ),
    );
  }
}

/// The weight as a typeable number in the shown unit; reports kg while typing.
class _WeightField extends StatelessWidget {
  final double kg;
  final void Function(double kg) onChanged;
  const _WeightField({super.key, required this.kg, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    const style = TextStyle(fontSize: 28, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]);
    // Number and unit centered together ("87,5 kg"), the field only as wide as what's typed.
    return Container(
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          IntrinsicWidth(
            child: TextFormField(
              initialValue: weightNum(kg),
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              style: style,
              decoration: const InputDecoration.collapsed(hintText: '0'),
              onChanged: (v) {
                if (parseWeight(v) case final kg? when kg >= 0 && kg <= 1000) onChanged(kg);
              },
            ),
          ),
          const SizedBox(width: 6),
          Text(unitLabel, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
        ],
      ),
    );
  }
}
