import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'l10n/app_localizations.dart';

export 'l10n/app_localizations.dart';

/// The language picked in the settings; null = the system's. The app rebuilds when it changes.
final language = ValueNotifier<Locale?>(null);

/// German where the system speaks German, English everywhere else.
Locale localeFor(Locale system) => system.languageCode == 'de' ? const Locale('de') : const Locale('en');

/// The stored setting ('de', 'en' or null = system) turned into a locale.
Locale? languageFromSetting(String? setting) => setting == null ? null : localeFor(Locale(setting));

Locale get appLocale => language.value ?? localeFor(PlatformDispatcher.instance.locale);

final _texts = <Locale, L10n>{};

/// The texts in the app's language. Global like [unit], so the model, the findings and the formatters
/// need no BuildContext.
L10n get tr => _texts[appLocale] ??= lookupL10n(appLocale);

/// A number written with a point, in the app's language: "82.5" → "82,5" in German.
String decimal(String s) => appLocale.languageCode == 'de' ? s.replaceAll('.', ',') : s;

/// A language in its own words, for the picker: "Deutsch", "English".
String languageName(Locale l) => lookupL10n(l).languageName;
