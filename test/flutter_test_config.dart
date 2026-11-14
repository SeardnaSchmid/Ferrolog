import 'dart:async';

import 'package:ferrolog/language.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Runs before every test file: the tests expect the German texts, while the test locale is en-US.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  language.value = const Locale('de');
  await initializeDateFormatting();
  await testMain();
}
