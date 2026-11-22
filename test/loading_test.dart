import 'package:ferrolog/loading.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(platesPerSide(80, plates: [20.0, 15.0]), [15, 15], reason: 'try smaller plates if the largest leaves a remainder');
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
