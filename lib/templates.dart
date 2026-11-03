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
  const Day(this.name, this.workoutName, this.exercises);
}

const programs = [
  Program('Starting Strength', [
    Day('A', 'Starting Strength A', [('Kniebeuge', 3, 5), ('Bankdrücken', 3, 5), ('Kreuzheben', 1, 5)]),
    Day('B', 'Starting Strength B', [('Kniebeuge', 3, 5), ('Schulterdrücken', 3, 5), ('Kreuzheben', 1, 5)]),
  ]),
  Program('StrongLifts 5×5', [
    Day('A', 'StrongLifts A', [('Kniebeuge', 5, 5), ('Bankdrücken', 5, 5), ('Langhantelrudern', 5, 5)]),
    Day('B', 'StrongLifts B', [('Kniebeuge', 5, 5), ('Schulterdrücken', 5, 5), ('Kreuzheben', 1, 5)]),
  ], note: 'A und B abwechselnd, 3× pro Woche.'),
  Program('5/3/1', [
    Day('Kniebeuge', '5/3/1 Kniebeuge', [('Kniebeuge', 3, 5), ('Beinbeuger', 3, 10), ('Ausfallschritte', 3, 10)]),
    Day('Bankdrücken', '5/3/1 Bankdrücken', [('Bankdrücken', 3, 5), ('Kurzhantelrudern', 3, 10), ('Dips', 3, 10)]),
    Day('Kreuzheben', '5/3/1 Kreuzheben', [('Kreuzheben', 3, 5), ('Klimmzüge', 3, 8), ('Beinpresse', 3, 10)]),
    Day('Schulterdrücken', '5/3/1 Schulterdrücken',
        [('Schulterdrücken', 3, 5), ('Latzug', 3, 10), ('Seitheben', 3, 15)]),
  ], note: 'Vereinfacht: Hauptübung 3×5 mit Steigerung bei Erfolg, ohne die Wochenwellen (5/3/1+, % vom Trainingsmax).'),
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
