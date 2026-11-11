import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'plan_import.dart';

/// Settings → "Plan von KI übernehmen": paste the AI's JSON block (prefilled from the clipboard when it
/// looks like one) or open it as a file (.json, .txt, any text), check it, show what changes, and take it over with an undo.
Future<void> openPlanImport(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  if (store.active != null) {
    messenger.showSnackBar(const SnackBar(content: Text('Erst das laufende Training beenden')));
    return;
  }
  var clip = '';
  try {
    // A browser may ask for permission and never answer: then paste by hand.
    clip = (await Clipboard.getData(Clipboard.kTextPlain).timeout(const Duration(seconds: 2)))?.text ?? '';
  } catch (_) {}
  if (!context.mounted) return;
  final plan = await showDialog<PlanImport>(
    context: context,
    builder: (_) => _PasteDialog(clip.contains('"ferrolog"') ? clip : ''),
  );
  if (plan == null || !context.mounted) return;
  final undo = await Navigator.push<Future<void> Function()>(
    context,
    MaterialPageRoute(builder: (_) => PlanImportPage(plan)),
  );
  if (undo == null) return;
  messenger.showSnackBar(SnackBar(
    content: const Text('Plan übernommen'),
    duration: const Duration(seconds: 10),
    action: SnackBarAction(label: 'Rückgängig', onPressed: undo),
  ));
}

class _PasteDialog extends StatefulWidget {
  const _PasteDialog(this.initial);
  final String initial;

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  late final controller = TextEditingController(text: widget.initial);
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Any file: the AI's download may be .json, .txt or without an ending; what counts is the JSON inside.
  Future<void> open() async {
    try {
      final file = await FilePicker.pickFile();
      if (file == null) return;
      controller.text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    } catch (e) {
      setState(() => error = 'Die Datei ließ sich nicht lesen: $e');
      return;
    }
    if (mounted) check();
  }

  void check() {
    try {
      Navigator.pop(context, parsePlanImport(controller.text));
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Plan von KI übernehmen'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Füg den JSON-Codeblock aus dem Chat ein oder öffne ihn als Datei. Vor dem Speichern siehst '
                  'du jede Änderung.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 4,
                maxLines: 10,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: '{ "app": "ferrolog", "kind": "plan", … }',
                  errorText: error,
                  errorMaxLines: 5,
                ),
                onChanged: (_) => setState(() => error = null),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: open,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Datei öffnen (.json, .txt)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(onPressed: check, child: const Text('Prüfen')),
        ],
      );
}

/// What the plan changes, workout by workout; nothing is saved until "Übernehmen". Pops the undo.
class PlanImportPage extends StatelessWidget {
  const PlanImportPage(this.plan, {super.key});
  final PlanImport plan;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final changed = plan.diff.where((w) => w.change != Change.same);
    final same = plan.diff.where((w) => w.change == Change.same);
    final basedOn = plan.basedOn;

    (IconData, Color, String) look(Change ch) => switch (ch) {
          Change.added => (Icons.add_circle_outline, c.primary, 'Neu'),
          Change.removed => (Icons.remove_circle_outline, c.error, 'Fällt weg'),
          Change.changed => (Icons.edit_outlined, c.tertiary, 'Geändert'),
          Change.same => (Icons.check, c.onSurfaceVariant, 'Unverändert'),
        };

    return Scaffold(
      appBar: AppBar(title: const Text('Plan von KI')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (plan.summary.isNotEmpty) Text(plan.summary, style: text.titleMedium),
          if (plan.stale && basedOn != null) ...[
            const SizedBox(height: 12),
            Card(
              color: c.errorContainer,
              child: ListTile(
                leading: Icon(Icons.history, color: c.onErrorContainer),
                title: Text('Seit dem Export hast du trainiert',
                    style: TextStyle(color: c.onErrorContainer, fontWeight: FontWeight.w600)),
                subtitle: Text(
                    'Der Plan beruht auf dem Stand vom ${basedOn.day}.${basedOn.month}. Die Gewichte können veraltet sein.',
                    style: TextStyle(color: c.onErrorContainer)),
              ),
            ),
          ],
          if (plan.empty)
            const Padding(padding: EdgeInsets.only(top: 24), child: Text('Der Plan ändert nichts an deinen Workouts.')),
          for (final w in changed) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(w.name, style: text.titleMedium)),
                      Chip(
                        label: Text(look(w.change).$3),
                        avatar: Icon(look(w.change).$1, size: 18, color: look(w.change).$2),
                        visualDensity: VisualDensity.compact,
                      ),
                    ]),
                    for (final e in w.exercises)
                      if (w.change != Change.removed || e == w.exercises.first)
                        _ExerciseRow(e, look(e.change), removedWorkout: w.change == Change.removed, all: w.exercises),
                  ],
                ),
              ),
            ),
          ],
          if (same.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Unverändert: ${same.map((w) => w.name).join(', ')}',
                style: text.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
          ],
          const SizedBox(height: 16),
          Text('Deine Trainings bleiben, wie sie sind. Nach dem Übernehmen kannst du es einmal rückgängig machen.',
              style: text.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Übernehmen'),
            onPressed: plan.empty
                ? null
                : () async {
                    final undo = await applyPlanImport(plan);
                    if (context.mounted) Navigator.pop(context, undo);
                  },
          ),
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow(this.e, this.look, {required this.removedWorkout, required this.all});
  final ExerciseDiff e;
  final (IconData, Color, String) look;

  /// A deleted workout lists its exercises in one row.
  final bool removedWorkout;
  final List<ExerciseDiff> all;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final unchanged = e.change == Change.same;
    final lines = [
      if (e.movedTo case final n?) 'Jetzt an Platz $n',
      ...e.details,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(look.$1, size: 20, color: look.$2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(removedWorkout ? all.map((x) => x.name).join(', ') : e.name,
                    style: text.bodyLarge?.copyWith(
                      color: unchanged ? c.onSurfaceVariant : null,
                      decoration: e.change == Change.removed ? TextDecoration.lineThrough : null,
                    )),
                for (final l in lines) Text(l, style: text.bodyMedium),
                if (e.why case final why?)
                  Text(why, style: text.bodySmall?.copyWith(color: c.onSurfaceVariant, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
