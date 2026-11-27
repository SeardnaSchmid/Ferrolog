import 'dart:math';

const pulseRestThreshold = 110;

/// A rest can switch to pulse control only before the planned timer expires.
/// Once released, a later measurement cannot start the same rest again.
class PulseRest {
  bool pending = false;
  int? endedAfter;

  void update({required int elapsed, required int minimum, required int? bpm}) {
    if (endedAfter != null) return;
    if (elapsed < minimum) {
      pending = bpm != null;
      return;
    }
    if (!pending) return;
    if (elapsed >= minimum * 2 || bpm == null || bpm < pulseRestThreshold) {
      endedAfter = min(elapsed, minimum * 2);
      pending = false;
    }
  }

  int endAfter(int minimum) => endedAfter ?? (pending ? minimum * 2 : minimum);
}
