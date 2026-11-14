import 'language.dart';
import 'main.dart';
import 'units.dart';

/// Loading a barbell: the warm-up ramp before the work sets and the plates per side. The functions work
/// in the shown unit (kg or lb), as do the bar and the plates, which are set per unit in the settings.

/// Bars to choose from, the first is the default: a men's, a women's and a technique bar.
const barChoices = {WeightUnit.kg: [20.0, 15.0, 10.0], WeightUnit.lb: [45.0, 35.0, 15.0]};

/// Plates a gym usually has; all of them are available until some are switched off.
const plateChoices = {
  WeightUnit.kg: [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25, 0.5],
  WeightUnit.lb: [45.0, 35.0, 25.0, 10.0, 5.0, 2.5],
};

/// Warm-up sets on the training page: off unless switched on in the settings.
bool get showWarmup => prefs.getBool('session.warmup') ?? false;

/// The user's bar in the shown unit.
double get barWeight => prefs.getDouble('barbell.bar.${unit.value.name}') ?? barChoices[unit.value]!.first;

/// The user's plates in the shown unit, heaviest first.
List<double> get availablePlates => switch (prefs.getStringList('barbell.plates.${unit.value.name}')) {
      final list? => [for (final p in list) double.parse(p)]..sort((a, b) => b.compareTo(a)),
      null => plateChoices[unit.value]!,
    };

/// Warm-up before a work set of [work]: the empty bar × 8, then 50 % × 5, 70 % × 3 and 85 % × 1, rounded
/// to [step] (2,5 kg or 5 lb). A step is left out when it isn't above the one before or is within [near]
/// of the work weight, where it would just be another work set. Nothing when the work set is the bar.
List<(double, int)> warmupSets(double work, {double bar = 20, double step = 2.5, double near = 5}) {
  if (work <= bar) return const [];
  final sets = [(bar, 8)];
  for (final (share, reps) in const [(.5, 5), (.7, 3), (.85, 1)]) {
    final w = (work * share / step).round() * step;
    if (w > sets.last.$1 && work - w >= near) sets.add((w, reps));
  }
  return sets;
}

/// The plates on each side for [total] on a bar of [bar], heaviest first, as many of each as needed;
/// empty for the bare bar. Null when [plates] can't make it (below the bar, or a remainder left).
List<double>? platesPerSide(double total, {double bar = 20, required List<double> plates}) {
  var left = (total - bar) / 2;
  if (left < -1e-6) return null;
  final side = <double>[];
  for (final p in [...plates]..sort((a, b) => b.compareTo(a))) {
    while (left >= p - 1e-6) {
      side.add(p);
      left -= p;
    }
  }
  return left > 1e-6 ? null : side;
}

/// A shown weight as typed: "82,5", "2,5", "45".
String plateNum(double v) => decimal(v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');

/// The warm-up for a work set of [kg] with the user's bar, in the shown unit.
List<(double, int)> warmupFor(double kg) => warmupSets(shown(kg),
    bar: barWeight, step: unit.value == WeightUnit.lb ? 5 : 2.5, near: unit.value == WeightUnit.lb ? 10 : 5);

/// "Pro Seite: 25 + 10 + 2,5" for [kg] with the user's bar and plates.
String perSideLabel(double kg) => switch (platesPerSide(shown(kg), bar: barWeight, plates: availablePlates)) {
      null => tr.platesNotLoadable,
      [] => tr.platesBarOnly,
      final side => tr.platesPerSide(side.map(plateNum).join(' + ')),
    };
