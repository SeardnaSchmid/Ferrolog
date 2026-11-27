import 'package:ferrolog/pulse_rest.dart';
import 'package:ferrolog/pulse_sensor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes both BLE heart rate formats and rejects absent contact', () {
    expect(heartRateFromMeasurement([0, 108]), 108);
    expect(heartRateFromMeasurement([0x07, 0x04, 0x01]), 260);
    expect(heartRateFromMeasurement([0x04, 108]), isNull);
    expect(heartRateFromMeasurement([0x06, 108]), 108);
    expect(heartRateFromMeasurement([0x01, 108]), isNull);
    expect(heartRateFromMeasurement([0, 0]), isNull);
    expect(heartRateFromMeasurement([]), isNull);
  });

  test('pulse release waits for the minimum and stays released', () {
    final rest = PulseRest();
    rest.update(elapsed: 29, minimum: 30, bpm: 105);
    expect(rest.pending, isTrue);
    expect(rest.endedAfter, isNull);
    rest.update(elapsed: 30, minimum: 30, bpm: 110);
    expect(rest.endAfter(30), 60);
    rest.update(elapsed: 35, minimum: 30, bpm: 109);
    expect(rest.endAfter(30), 35);
    rest.update(elapsed: 36, minimum: 30, bpm: 125);
    expect(rest.endAfter(30), 35);
  });

  test(
    'uses the time limit if the heart rate stays high or a tick is late',
    () {
      final rest = PulseRest();
      rest.update(elapsed: 0, minimum: 30, bpm: 140);
      rest.update(elapsed: 62, minimum: 30, bpm: 150);
      expect(rest.pending, isFalse);
      expect(rest.endAfter(30), 60);
    },
  );

  test('missing measurements fall back to the normal rest time', () {
    final earlyLoss = PulseRest();
    earlyLoss.update(elapsed: 0, minimum: 30, bpm: 140);
    earlyLoss.update(elapsed: 25, minimum: 30, bpm: null);
    expect(earlyLoss.pending, isFalse);
    expect(earlyLoss.endAfter(30), 30);
    earlyLoss.update(elapsed: 31, minimum: 30, bpm: 130);
    expect(earlyLoss.endAfter(30), 30);

    final lateLoss = PulseRest();
    lateLoss.update(elapsed: 0, minimum: 30, bpm: 140);
    lateLoss.update(elapsed: 35, minimum: 30, bpm: null);
    expect(lateLoss.pending, isFalse);
    expect(lateLoss.endAfter(30), 35);
  });
}
