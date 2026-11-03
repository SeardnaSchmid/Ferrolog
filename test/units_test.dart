import 'package:ferrolog/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default unit follows the region, not the language', () {
    expect(unitForRegion('US'), WeightUnit.lb);
    expect(unitForRegion('GB'), WeightUnit.kg);
    expect(unitForRegion('DE'), WeightUnit.kg);
    expect(unitForRegion(null), WeightUnit.kg);
    expect(unitFromSetting('kg', 'US'), WeightUnit.kg);
    expect(unitFromSetting(null, 'US'), WeightUnit.lb);
  });

  test('lb: typed values come back unchanged, steps are plate-sized', () {
    unit.value = WeightUnit.lb;
    addTearDown(() => unit.value = WeightUnit.kg);
    final kg = parseWeight('225')!;
    expect(kg, closeTo(102.06, .01));
    expect(weightNum(kg), '225');
    expect(weightNum(kg + parseWeight('5')!), '230'); // progression in lb stays round
    expect(weightLabel(60), '132,3 lb');
    expect(stepShown(2.5), 5);
    expect(stepShown(1.25), 2.5);
    expect(stepShown(5), 10);
  });

  test('kg: comma decimals', () {
    unit.value = WeightUnit.kg;
    expect(parseWeight('82,5'), 82.5);
    expect(weightLabel(82.5), '82,5 kg');
    expect(stepShown(1.25), 1.25);
  });
}
