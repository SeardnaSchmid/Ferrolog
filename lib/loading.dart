import 'language.dart';
import 'units.dart';

/// Plates per side for a barbell. The calculator works in the shown unit.

/// Bars to choose from, the first is the default: a men's, a women's and a technique bar.
const barChoices = {WeightUnit.kg: [20.0, 15.0, 10.0], WeightUnit.lb: [45.0, 35.0, 15.0]};

/// Plates a gym usually has; all of them are available until some are switched off.
const plateChoices = {
  WeightUnit.kg: [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25, 0.5],
  WeightUnit.lb: [45.0, 35.0, 25.0, 10.0, 5.0, 2.5],
};

class BarbellSetup {
  final double bar;
  final List<double> plates;

  BarbellSetup(this.bar, Iterable<double> plates)
      : plates = List.unmodifiable(plates.where((p) => p.isFinite && p > 0).toSet());

  factory BarbellSetup.defaults(WeightUnit unit) => BarbellSetup(barChoices[unit]!.first, plateChoices[unit]!);

  Map<String, dynamic> toJson() => {'bar': bar, 'plates': plates};

  factory BarbellSetup.fromJson(Map<String, dynamic> j) {
    final bar = (j['bar'] as num).toDouble();
    if (!bar.isFinite || bar <= 0) throw const FormatException('Invalid bar weight');
    return BarbellSetup(bar, (j['plates'] as List).map((p) => (p as num).toDouble()));
  }
}

Map<WeightUnit, BarbellSetup> barbellSetupsFromJson(Map<String, dynamic>? j) => {
      for (final u in WeightUnit.values)
        if (j?[u.name] case final Map<String, dynamic> setup) u: BarbellSetup.fromJson(setup),
    };

Map<String, dynamic> barbellSetupsToJson(Map<WeightUnit, BarbellSetup> setups) =>
    setups.map((u, setup) => MapEntry(u.name, setup.toJson()));

/// The plates on each side for [total] on a bar of [bar], heaviest first, as many of each as needed;
/// empty for the bare bar. Null when [plates] can't make it (below the bar, or a remainder left).
List<double>? platesPerSide(double total, {double bar = 20, required List<double> plates}) {
  final sizes = [...plates.where((p) => p.isFinite && p > 1e-6)]..sort((a, b) => b.compareTo(a));
  final failed = <(int, int)>{};
  List<double>? load(int i, double left) {
    if (left.abs() < 1e-6) return [];
    if (left < 0 || i == sizes.length) return null;
    if (!failed.add((i, (left * 1e6).round()))) return null;
    final p = sizes[i];
    for (var count = ((left + 1e-6) / p).floor(); count >= 0; count--) {
      if (load(i + 1, left - count * p) case final rest?) {
        return [...List.filled(count, p), ...rest];
      }
    }
    return null;
  }
  return load(0, (total - bar) / 2);
}

/// A shown weight as typed: "82,5", "2,5", "45".
String plateNum(double v) => decimal(v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');

/// "Pro Seite: 25 + 10 + 2,5" for [kg] with this exercise's bar and plates.
String perSideLabel(double kg, BarbellSetup setup) => switch (platesPerSide(shown(kg), bar: setup.bar, plates: setup.plates)) {
      null => tr.platesNotLoadable,
      [] => tr.platesBarOnly,
      final side => tr.platesPerSide(side.map(plateNum).join(' + ')),
    };
