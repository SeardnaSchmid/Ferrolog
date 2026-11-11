import 'package:flutter/foundation.dart';

/// Weights are always stored in kg; the unit only changes how they're shown and typed.
enum WeightUnit { kg, lb }

const lbPerKg = 2.20462262185;

/// lb where people lift in pounds (US, Liberia, Myanmar), kg everywhere else. Region, not
/// language: English speakers in the UK, Ireland or Australia lift in kg.
WeightUnit unitForRegion(String? countryCode) =>
    const {'US', 'LR', 'MM'}.contains(countryCode) ? WeightUnit.lb : WeightUnit.kg;

/// The unit in use; the app rebuilds when it changes. Set from the settings at startup.
final unit = ValueNotifier(unitForRegion(PlatformDispatcher.instance.locale.countryCode));

/// The stored setting ('kg', 'lb' or null = by region) turned into a unit.
WeightUnit unitFromSetting(String? setting, String? countryCode) =>
    WeightUnit.values.asNameMap()[setting] ?? unitForRegion(countryCode);

String get unitLabel => unit.value.name;

/// kg → displayed number, rounded to what makes sense for the unit (lb: 0.1, kg: 0.01).
double shown(double kg) => switch (unit.value) {
      WeightUnit.kg => (kg * 100).roundToDouble() / 100,
      WeightUnit.lb => (kg * lbPerKg * 10).roundToDouble() / 10,
    };

/// Displayed number → kg, unrounded so a typed 225 lb shows as 225 lb again.
double toKg(double value) => unit.value == WeightUnit.lb ? value / lbPerKg : value;

/// Weight without unit, German decimal comma: 82.5 kg → "82,5" (or "181,9" in lb). Assistance (a
/// machine taking weight off, e.g. for pull-ups) is negative: "−10".
String weightNum(double kg) {
  final v = shown(kg);
  return (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString()).replaceAll('.', ',').replaceAll('-', '−');
}

/// Weight with unit, e.g. "82,5 kg".

/// The lowest weight there is: this much assistance, in kg.
const minWeight = -200.0;
String weightLabel(double kg) => '${weightNum(kg)} $unitLabel';

/// Parses a typed weight ("102,5", "102.5", "−10" for assistance) in the current unit and returns kg.
double? parseWeight(String s) => switch (double.tryParse(s.trim().replaceAll(',', '.').replaceAll('−', '-'))) {
      final v? => toKg(v),
      null => null,
    };

const kmPerMile = 1.609344;

/// Distance unit: miles alongside lb, km otherwise.
String get distanceLabel => unit.value == WeightUnit.lb ? 'mi' : 'km';

/// km → shown number (km or mi), one decimal, German comma: 5.0 → "5", 5.25 → "5,3".
String distanceNum(double km) {
  final v = ((unit.value == WeightUnit.lb ? km / kmPerMile : km) * 10).roundToDouble() / 10;
  return (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString()).replaceAll('.', ',');
}

/// Typed distance in the shown unit → km; null if empty or invalid.
double? parseDistance(String s) => switch (double.tryParse(s.trim().replaceAll(',', '.'))) {
      final v? when v > 0 => unit.value == WeightUnit.lb ? v * kmPerMile : v,
      _ => null,
    };

/// "25 Min · 5,2 km" for planned or done cardio.
String cardioLabel(int? minutes, double? km) =>
    [if (minutes != null && minutes > 0) '$minutes Min', if (km != null) '${distanceNum(km)} $distanceLabel'].join(' · ');

/// Step for the −/+ buttons in the current unit: the plan's increment, but whole plate steps in lb
/// (2.5 kg → 5 lb, 1.25 kg → 2.5 lb, 5 kg → 10 lb).
double stepShown(double incrementKg) {
  if (incrementKg <= 0) return unit.value == WeightUnit.lb ? 5 : 2.5;
  if (unit.value == WeightUnit.kg) return incrementKg;
  return ((incrementKg * lbPerKg) / 2.5).round().clamp(1, 100) * 2.5;
}

/// Lifted volume: "850 kg", from a tonne on "7,2 t" (lb: "1.900 lb", "12,4k lb").
String volumeLabel(double kg) {
  final v = shown(kg);
  if (v < 1000) return '${v.round()} $unitLabel';
  final k = (v / 1000).toStringAsFixed(1).replaceAll('.', ',').replaceAll(RegExp(r',0$'), ''); // 10,0 t → 10 t
  return unit.value == WeightUnit.kg ? '$k t' : '${k}k lb';
}

/// "48 Min", "1:05 h".
String durationLabel(Duration d) =>
    d.inMinutes < 60 ? '${d.inMinutes} Min' : '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')} h';
