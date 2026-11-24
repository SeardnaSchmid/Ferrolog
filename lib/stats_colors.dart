import 'package:flutter/material.dart';

extension StatsColors on ColorScheme {
  bool get _darkStats => brightness == Brightness.dark;

  Color get personalGoal => _darkStats ? const Color(0xFF89D6A3) : const Color(0xFF276749);
  Color get referenceGreen => _darkStats ? const Color(0xFF84BE9A) : const Color(0xFF35684D);
  Color get referenceAmber => _darkStats ? const Color(0xFFC4A67D) : const Color(0xFF785C35);
  Color get balanceBand => referenceGreen.withValues(alpha: .17);

  Color get volumeColor => _darkStats ? const Color(0xFFB1C9DD) : const Color(0xFF415C72);
}
