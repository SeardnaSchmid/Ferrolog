import 'package:ferrolog/loading.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('warm-up: bar, then 50/70/85 %, rounded; steps too close dropped', () {
    expect(warmupSets(100), [(20.0, 8), (50.0, 5), (70.0, 3), (85.0, 1)]);
    expect(warmupSets(137.5), [(20.0, 8), (70.0, 5), (97.5, 3), (117.5, 1)]);
    expect(warmupSets(60), [(20.0, 8), (30.0, 5), (42.5, 3), (50.0, 1)]);
    expect(warmupSets(40), [(20.0, 8), (27.5, 3), (35.0, 1)], reason: '50 % is 20, not above the bar');
    expect(warmupSets(31), [(20.0, 8), (22.5, 3)], reason: '85 % is 27,5, within 5 kg of the work set');
    expect(warmupSets(25), [(20.0, 8)]);
    expect(warmupSets(20), isEmpty);
    expect(warmupSets(15), isEmpty);
    expect(warmupSets(0), isEmpty);
    expect(warmupSets(-10), isEmpty, reason: 'assistance');
    expect(warmupSets(80, bar: 15), [(15.0, 8), (40.0, 5), (55.0, 3), (67.5, 1)]);
  });

  test('warm-up in lb: 45 lb bar, 5 lb steps', () {
    expect(warmupSets(225, bar: 45, step: 5, near: 10), [(45.0, 8), (115.0, 5), (160.0, 3), (190.0, 1)]);
    expect(warmupSets(95, bar: 45, step: 5, near: 10), [(45.0, 8), (50.0, 5), (65.0, 3), (80.0, 1)]);
    expect(warmupSets(50, bar: 45, step: 5, near: 10), [(45.0, 8)]);
  });

  const kg = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25, 0.5];
  test('plates per side in kg', () {
    expect(platesPerSide(100, plates: kg), [25, 15]);
    expect(platesPerSide(142.5, plates: kg), [25, 25, 10, 1.25]);
    expect(platesPerSide(61, plates: kg), [20, 0.5]);
    expect(platesPerSide(20, plates: kg), isEmpty);
    expect(platesPerSide(17.5, plates: kg), isNull, reason: 'below the bar');
    expect(platesPerSide(60.3, plates: kg), isNull, reason: 'no 0,15 kg plates');
    expect(platesPerSide(100, plates: [20.0, 10.0, 5.0]), [20, 20]);
    expect(platesPerSide(82.5, plates: [20.0, 10.0, 5.0]), isNull);
    expect(platesPerSide(70, bar: 15, plates: kg), [25, 2.5]);
  });

  test('plates per side in lb', () {
    const lb = [45.0, 35.0, 25.0, 10.0, 5.0, 2.5];
    expect(platesPerSide(225, bar: 45, plates: lb), [45, 45]);
    expect(platesPerSide(185, bar: 45, plates: lb), [45, 25]);
    expect(platesPerSide(140, bar: 45, plates: lb), [45, 2.5]);
    expect(platesPerSide(142, bar: 45, plates: lb), isNull);
    expect(platesPerSide(45, bar: 45, plates: lb), isEmpty);
  });

  test('numbers as typed', () {
    expect([2.5, 45.0, 1.25].map(plateNum), ['2,5', '45', '1,25']);
  });
}
