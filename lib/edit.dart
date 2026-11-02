import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'model.dart';

/// Edits a copy of a workout; nothing is stored until "Speichern".
class EditWorkout extends StatefulWidget {
  final Workout workout;
  const EditWorkout(this.workout, {super.key});

  @override
  State<EditWorkout> createState() => _EditWorkoutState();
}

class _EditWorkoutState extends State<EditWorkout> {
  Workout get w => widget.workout;
  bool get isNew => !store.workouts.any((x) => x.id == w.id);

  Future<void> editExercise([int? index]) async {
    final result = await showDialog<Exercise>(
      context: context,
      builder: (_) => ExerciseDialog(index == null ? null : w.exercises[index].copy()),
    );
    if (result == null) return;
    setState(() => index == null ? w.exercises.add(result) : w.exercises[index] = result);
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
              store.saveWorkout(w);
              Navigator.pop(context);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Übung'),
        onPressed: editExercise,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              initialValue: w.name,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              onChanged: (v) => w.name = v,
            ),
          ),
          Expanded(
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 88),
              onReorder: (from, to) => setState(() {
                if (to > from) to--;
                w.exercises.insert(to, w.exercises.removeAt(from));
              }),
              children: [
                for (final (i, e) in w.exercises.indexed)
                  ListTile(
                    key: ObjectKey(e),
                    title: Text(e.name),
                    subtitle: Text('${e.sets}×${e.reps} · ${kg(e.weight)} · +${kg(e.increment)} bei Erfolg'),
                    onTap: () => editExercise(i),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Übung entfernen',
                          onPressed: () => setState(() => w.exercises.remove(e)),
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
}

/// Add/edit one exercise. Typing a name suggests from the catalogue and from
/// everything already used; picking one fills in defaults and the last used weight.
class ExerciseDialog extends StatefulWidget {
  final Exercise? initial;
  const ExerciseDialog(this.initial, {super.key});

  @override
  State<ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<ExerciseDialog> {
  late final Exercise e = widget.initial ?? Exercise(name: '');
  late final nameField = TextEditingController(text: e.name);
  // Rebuilt with a new key whenever a suggestion fills in the numbers.
  int fillGeneration = 0;

  @override
  void dispose() {
    nameField.dispose();
    super.dispose();
  }

  /// Up to 8 known exercises matching what's typed; hidden once the name matches exactly.
  List<String> get suggestions {
    final q = e.name.toLowerCase();
    if (q.isEmpty || knownNames.any((n) => n.toLowerCase() == q)) return [];
    return knownNames.where((n) => n.toLowerCase().contains(q)).take(8).toList();
  }

  List<String> get knownNames => {
        ...exerciseCatalogue.keys,
        for (final w in store.workouts) ...w.exercises.map((e) => e.name),
        ...store.loggedExercises,
      }.toList()
        ..sort();

  void pick(String name) {
    setState(() {
      e.name = name;
      final defaults = exerciseCatalogue[name];
      if (defaults != null) {
        e
          ..sets = defaults.$1
          ..reps = defaults.$2
          ..increment = defaults.$3;
      }
      // Already in another workout? Take its settings, else the last logged weight.
      final used = store.workouts.expand((w) => w.exercises).where((x) => x.name == name).firstOrNull;
      final logged = store.historyOf(name).lastOrNull?.$2;
      if (used != null) {
        e
          ..sets = used.sets
          ..reps = used.reps
          ..increment = used.increment
          ..weight = used.weight
          ..restSeconds = used.restSeconds;
      } else if (logged != null) {
        e.weight = logged.weight;
      }
      fillGeneration++;
    });
  }

  Widget number(String label, num value, void Function(String) onChanged, {bool decimal = false}) => Expanded(
        child: TextFormField(
          key: ValueKey('$label$fillGeneration'),
          initialValue: decimal ? value.toString() : value.toStringAsFixed(0),
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
          onChanged: onChanged,
        ),
      );

  double? parse(String s) => double.tryParse(s.replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Übung hinzufügen' : 'Übung bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 400), // keeps the dialog from jumping as chips come and go
            TextField(
              controller: nameField,
              autofocus: widget.initial == null,
              decoration: const InputDecoration(
                labelText: 'Übung',
                hintText: 'z. B. Kniebeuge',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => e.name = v.trim()),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final n in suggestions)
                    ActionChip(
                      label: Text(n),
                      onPressed: () {
                        nameField.text = n;
                        pick(n);
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(children: [
              number('Sätze', e.sets, (v) => e.sets = int.tryParse(v) ?? e.sets),
              const SizedBox(width: 8),
              number('Wdh.', e.reps, (v) => e.reps = int.tryParse(v) ?? e.reps),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              number('Gewicht (kg)', e.weight, (v) => e.weight = parse(v) ?? e.weight, decimal: true),
              const SizedBox(width: 8),
              number('+ bei Erfolg', e.increment, (v) => e.increment = parse(v) ?? e.increment, decimal: true),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              number('Pause (s)', e.restSeconds, (v) => e.restSeconds = int.tryParse(v) ?? e.restSeconds),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            if (e.name.isEmpty || e.sets < 1 || e.reps < 1) return;
            Navigator.pop(context, e);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
