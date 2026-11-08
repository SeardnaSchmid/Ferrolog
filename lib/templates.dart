/// Workout templates for "new workout": a program with one or more days, each day a list of
/// (catalogue exercise, sets, reps). Weights come from your own data or the catalogue.
class Program {
  final String name;

  /// Shown under the chips, e.g. what was simplified.
  final String? note;
  final List<Day> days;
  const Program(this.name, this.days, {this.note});
}

class Day {
  final String name;

  /// Workout name when picked, e.g. "Starting Strength A".
  final String workoutName;
  final List<(String, int, int)> exercises;

  /// Rep ranges: exercise → top of the range (the reps above are the bottom).
  final Map<String, int> upTo;
  const Day(this.name, this.workoutName, this.exercises, {this.upTo = const {}});
}

const programs = [
  // Every training the same, so one, two or three trainings a week still train everything.
  Program('Full Body Kraft', [
    Day('Full Body', 'Full Body', [
      ('Kniebeuge', 3, 5),
      ('Bankdrücken', 3, 5),
      ('Kreuzheben', 1, 3),
      ('Schulterdrücken', 2, 5),
      ('Langhantelrudern', 3, 6),
      ('Klimmzüge', 3, 5),
      ('Face Pulls', 2, 12),
      ('Farmers Walk', 3, 30), // 20–30 m, about 30 s
    ], upTo: {'Kreuzheben': 5, 'Langhantelrudern': 8, 'Klimmzüge': 8, 'Face Pulls': 15, 'Farmers Walk': 45}),
  ], note: 'Jedes Training gleich, 1–3× pro Woche, 48–72 h Erholung dazwischen. 8–12 Wochen dabei bleiben.'),
  Program('Starting Strength', [
    Day('A', 'Starting Strength A', [('Kniebeuge', 3, 5), ('Bankdrücken', 3, 5), ('Kreuzheben', 1, 5)]),
    Day('B', 'Starting Strength B', [('Kniebeuge', 3, 5), ('Schulterdrücken', 3, 5), ('Kreuzheben', 1, 5)]),
  ]),
  Program('StrongLifts 5×5', [
    Day('A', 'StrongLifts A', [('Kniebeuge', 5, 5), ('Bankdrücken', 5, 5), ('Langhantelrudern', 5, 5)]),
    Day('B', 'StrongLifts B', [('Kniebeuge', 5, 5), ('Schulterdrücken', 5, 5), ('Kreuzheben', 1, 5)]),
  ], note: 'A und B abwechselnd, 3× pro Woche.'),
  Program('Push/Pull/Beine', [
    Day('Push', 'Push', [
      ('Bankdrücken', 3, 8),
      ('Schulterdrücken', 3, 8),
      ('Seitheben', 3, 15),
      ('Trizepsdrücken am Kabel', 3, 12),
    ]),
    Day('Pull', 'Pull', [('Klimmzüge', 3, 8), ('Langhantelrudern', 3, 8), ('Face Pulls', 3, 15), ('Bizepscurls', 3, 10)]),
    Day('Beine', 'Beine', [
      ('Kniebeuge', 3, 8),
      ('Rumänisches Kreuzheben', 3, 8),
      ('Beinpresse', 3, 10),
      ('Wadenheben', 3, 15),
    ]),
  ]),
  Program('Ober/Unter', [
    Day('Oberkörper', 'Oberkörper', [
      ('Bankdrücken', 3, 8),
      ('Langhantelrudern', 3, 8),
      ('Schulterdrücken', 3, 8),
      ('Latzug', 3, 10),
      ('Bizepscurls', 3, 10),
    ]),
    Day('Unterkörper', 'Unterkörper', [
      ('Kniebeuge', 3, 8),
      ('Rumänisches Kreuzheben', 3, 8),
      ('Ausfallschritte', 3, 10),
      ('Beinbeuger', 3, 12),
      ('Wadenheben', 3, 15),
    ]),
  ]),
  Program('Ganzkörper', [
    Day('Ganzkörper', 'Ganzkörper', [
      ('Kniebeuge', 3, 8),
      ('Bankdrücken', 3, 8),
      ('Langhantelrudern', 3, 8),
      ('Schulterdrücken', 3, 8),
      ('Rumänisches Kreuzheben', 3, 8),
    ]),
  ]),
];
