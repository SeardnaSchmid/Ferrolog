import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In de, this message translates to:
  /// **'FerroLog'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @trainingsCount.
  ///
  /// In de, this message translates to:
  /// **'{n, plural, =1{1 Training} other{{n} Trainings}}'**
  String trainingsCount(int n);

  /// No description provided for @syncNoFileYet.
  ///
  /// In de, this message translates to:
  /// **'Auf GitHub liegt noch keine {path}.'**
  String syncNoFileYet(Object path);

  /// No description provided for @syncRestored.
  ///
  /// In de, this message translates to:
  /// **'Von GitHub wiederhergestellt'**
  String get syncRestored;

  /// No description provided for @syncOverwriteMore.
  ///
  /// In de, this message translates to:
  /// **'Auf GitHub liegen mehr Trainings ({theirs}) als hier ({ours}). Wirklich überschreiben? Der alte Stand bleibt nur in der Git-Historie des Repos.'**
  String syncOverwriteMore(Object theirs, Object ours);

  /// No description provided for @settingsTraining.
  ///
  /// In de, this message translates to:
  /// **'Training'**
  String get settingsTraining;

  /// No description provided for @settingsSound.
  ///
  /// In de, this message translates to:
  /// **'Ton'**
  String get settingsSound;

  /// No description provided for @settingsSoundHint.
  ///
  /// In de, this message translates to:
  /// **'Signalton, wenn die Pause bei 0 ankommt'**
  String get settingsSoundHint;

  /// No description provided for @settingsVibrate.
  ///
  /// In de, this message translates to:
  /// **'Vibration'**
  String get settingsVibrate;

  /// No description provided for @settingsVibrateHint.
  ///
  /// In de, this message translates to:
  /// **'Kurz vibrieren, wenn die Pause bei 0 ankommt'**
  String get settingsVibrateHint;

  /// No description provided for @settingsAutoFinish.
  ///
  /// In de, this message translates to:
  /// **'Automatisch beenden'**
  String get settingsAutoFinish;

  /// No description provided for @settingsAutoFinishHint.
  ///
  /// In de, this message translates to:
  /// **'Nach 30 Min ohne Aktivität endet das Training beim letzten Satz'**
  String get settingsAutoFinishHint;

  /// No description provided for @settingsKeepScreenOn.
  ///
  /// In de, this message translates to:
  /// **'Bildschirm anlassen'**
  String get settingsKeepScreenOn;

  /// No description provided for @settingsKeepScreenOnHint.
  ///
  /// In de, this message translates to:
  /// **'Während des Trainings geht das Display nicht aus'**
  String get settingsKeepScreenOnHint;

  /// No description provided for @settingsShowWhenLocked.
  ///
  /// In de, this message translates to:
  /// **'Über dem Sperrbildschirm zeigen'**
  String get settingsShowWhenLocked;

  /// No description provided for @settingsShowWhenLockedHint.
  ///
  /// In de, this message translates to:
  /// **'Während des Trainings ohne Entsperren auf die Pause schauen'**
  String get settingsShowWhenLockedHint;

  /// No description provided for @settingsAskRir.
  ///
  /// In de, this message translates to:
  /// **'Reserve abfragen'**
  String get settingsAskRir;

  /// No description provided for @settingsAskRirHint.
  ///
  /// In de, this message translates to:
  /// **'Nach dem letzten Satz einer Übung: Wie viele Wiederholungen gingen noch? Hilft bei Plateaus. Übungen im Auto-Modus fragen immer'**
  String get settingsAskRirHint;

  /// No description provided for @settingsLeadIn.
  ///
  /// In de, this message translates to:
  /// **'Vorlauf bei Zeitübungen'**
  String get settingsLeadIn;

  /// No description provided for @settingsLeadInHint.
  ///
  /// In de, this message translates to:
  /// **'Zeit zum Aufnehmen der Gewichte, bevor die Sekunden zählen'**
  String get settingsLeadInHint;

  /// No description provided for @settingsHome.
  ///
  /// In de, this message translates to:
  /// **'Startseite'**
  String get settingsHome;

  /// No description provided for @settingsTasks.
  ///
  /// In de, this message translates to:
  /// **'Hinweise zum Training'**
  String get settingsTasks;

  /// No description provided for @settingsTasksHint.
  ///
  /// In de, this message translates to:
  /// **'Wenn die Statistik etwas findet: Ausgelassenes, Balance, Plateau, Wochenziel'**
  String get settingsTasksHint;

  /// No description provided for @settingsInsights.
  ///
  /// In de, this message translates to:
  /// **'Erfolge'**
  String get settingsInsights;

  /// No description provided for @settingsInsightsHint.
  ///
  /// In de, this message translates to:
  /// **'Rekorde, Fortschritt und Meilensteine des letzten Trainings'**
  String get settingsInsightsHint;

  /// No description provided for @settingsStreak.
  ///
  /// In de, this message translates to:
  /// **'Serie'**
  String get settingsStreak;

  /// No description provided for @settingsStreakHint.
  ///
  /// In de, this message translates to:
  /// **'Trainings pro Woche, damit die Woche für deine Serie zählt'**
  String get settingsStreakHint;

  /// No description provided for @settingsLanguage.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In de, this message translates to:
  /// **'System ({name})'**
  String settingsLanguageSystem(Object name);

  /// No description provided for @settingsUnit.
  ///
  /// In de, this message translates to:
  /// **'Einheit'**
  String get settingsUnit;

  /// No description provided for @settingsUnitAuto.
  ///
  /// In de, this message translates to:
  /// **'Automatisch ({unit})'**
  String settingsUnitAuto(Object unit);

  /// No description provided for @settingsUnitHint.
  ///
  /// In de, this message translates to:
  /// **'Gespeichert wird immer in kg, Umrechnung nur für die Anzeige.'**
  String get settingsUnitHint;

  /// No description provided for @settingsBarbell.
  ///
  /// In de, this message translates to:
  /// **'Hantel'**
  String get settingsBarbell;

  /// No description provided for @settingsWarmup.
  ///
  /// In de, this message translates to:
  /// **'Aufwärmsätze zeigen'**
  String get settingsWarmup;

  /// No description provided for @settingsWarmupHint.
  ///
  /// In de, this message translates to:
  /// **'Vor dem ersten Satz einer Langhantel-Übung: leere Stange, dann 50, 70 und 85 %'**
  String get settingsWarmupHint;

  /// No description provided for @settingsBarPlatesHint.
  ///
  /// In de, this message translates to:
  /// **'Stange und Scheiben für „Pro Seite“ beim Gewicht und für die Aufwärmsätze'**
  String get settingsBarPlatesHint;

  /// No description provided for @settingsBar.
  ///
  /// In de, this message translates to:
  /// **'Stange {weight}'**
  String settingsBar(Object weight);

  /// No description provided for @settingsPlates.
  ///
  /// In de, this message translates to:
  /// **'Scheiben'**
  String get settingsPlates;

  /// No description provided for @settingsData.
  ///
  /// In de, this message translates to:
  /// **'Daten'**
  String get settingsData;

  /// No description provided for @settingsExport.
  ///
  /// In de, this message translates to:
  /// **'An KI senden / exportieren'**
  String get settingsExport;

  /// No description provided for @settingsExportHint.
  ///
  /// In de, this message translates to:
  /// **'Alle Daten als JSON, der Analyse-Prompt kommt in die Zwischenablage'**
  String get settingsExportHint;

  /// No description provided for @settingsExportDone.
  ///
  /// In de, this message translates to:
  /// **'Prompt kopiert: im Chat einfügen, falls er fehlt'**
  String get settingsExportDone;

  /// No description provided for @settingsRestore.
  ///
  /// In de, this message translates to:
  /// **'Von GitHub wiederherstellen'**
  String get settingsRestore;

  /// No description provided for @settingsRestoreHint.
  ///
  /// In de, this message translates to:
  /// **'Trainings und Pläne aus {repo} holen, nach einer Neuinstallation oder vom anderen Gerät'**
  String settingsRestoreHint(Object repo);

  /// No description provided for @settingsRestoreNoSync.
  ///
  /// In de, this message translates to:
  /// **'Erst unten GitHub-Sync einrichten'**
  String get settingsRestoreNoSync;

  /// No description provided for @settingsPlanImport.
  ///
  /// In de, this message translates to:
  /// **'Plan von KI übernehmen'**
  String get settingsPlanImport;

  /// No description provided for @settingsPlanImportHint.
  ///
  /// In de, this message translates to:
  /// **'JSON-Block aus dem Chat einfügen, mit Vorschau vor dem Speichern'**
  String get settingsPlanImportHint;

  /// No description provided for @settingsCredits.
  ///
  /// In de, this message translates to:
  /// **'Muskeln der Übungen: wger.de (CC-BY-SA), free-exercise-db · Körperkarte: react-native-body-highlighter (MIT) · Lizenzen'**
  String get settingsCredits;

  /// No description provided for @syncTitle.
  ///
  /// In de, this message translates to:
  /// **'GitHub-Sync'**
  String get syncTitle;

  /// No description provided for @syncIntro.
  ///
  /// In de, this message translates to:
  /// **'FerroLog speichert deine Trainingsdaten als ferrolog.json in einem privaten GitHub-Repo. Dort kann deine KI sie lesen. FerroLog bekommt nur Zugriff auf diese eine Datei in dem Repo, das du freigibst.'**
  String get syncIntro;

  /// No description provided for @syncEnterCode.
  ///
  /// In de, this message translates to:
  /// **'Gib diesen Code auf GitHub ein (ist schon kopiert):'**
  String get syncEnterCode;

  /// No description provided for @syncThenBack.
  ///
  /// In de, this message translates to:
  /// **'Danach einfach zurück in die App wechseln.'**
  String get syncThenBack;

  /// No description provided for @syncLogin.
  ///
  /// In de, this message translates to:
  /// **'Mit GitHub anmelden'**
  String get syncLogin;

  /// No description provided for @syncConnected.
  ///
  /// In de, this message translates to:
  /// **'Mit GitHub verbunden'**
  String get syncConnected;

  /// No description provided for @syncLogout.
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get syncLogout;

  /// No description provided for @syncStepRepo.
  ///
  /// In de, this message translates to:
  /// **'Daten-Repo anlegen'**
  String get syncStepRepo;

  /// No description provided for @syncStepRepoHint.
  ///
  /// In de, this message translates to:
  /// **'Privates Repo „ferrolog-data“ auf GitHub erstellen'**
  String get syncStepRepoHint;

  /// No description provided for @syncRepoDescription.
  ///
  /// In de, this message translates to:
  /// **'FerroLog+Trainingsdaten'**
  String get syncRepoDescription;

  /// No description provided for @syncStepAccess.
  ///
  /// In de, this message translates to:
  /// **'FerroLog Zugriff geben'**
  String get syncStepAccess;

  /// No description provided for @syncStepAccessHint.
  ///
  /// In de, this message translates to:
  /// **'„Only select repositories“ → ferrolog-data wählen'**
  String get syncStepAccessHint;

  /// No description provided for @syncFindsRepo.
  ///
  /// In de, this message translates to:
  /// **'Danach zurück in die App wechseln, FerroLog findet das Repo dann selbst.'**
  String get syncFindsRepo;

  /// No description provided for @sync404.
  ///
  /// In de, this message translates to:
  /// **'Zeigt GitHub beim Installieren eine 404? Dann Schritt 2 am PC öffnen: github.com/apps/{slug}/installations/new'**
  String sync404(Object slug);

  /// No description provided for @syncRepo.
  ///
  /// In de, this message translates to:
  /// **'Repo'**
  String get syncRepo;

  /// No description provided for @syncPickRepo.
  ///
  /// In de, this message translates to:
  /// **'Repo auswählen'**
  String get syncPickRepo;

  /// No description provided for @syncAnotherRepo.
  ///
  /// In de, this message translates to:
  /// **'Weiteres Repo freigeben'**
  String get syncAnotherRepo;

  /// No description provided for @syncNow.
  ///
  /// In de, this message translates to:
  /// **'Jetzt synchronisieren'**
  String get syncNow;

  /// No description provided for @syncResolve.
  ///
  /// In de, this message translates to:
  /// **'Konflikt lösen'**
  String get syncResolve;

  /// No description provided for @syncLastOn.
  ///
  /// In de, this message translates to:
  /// **'{count}, letztes am {date}'**
  String syncLastOn(Object count, Object date);

  /// No description provided for @syncDialogTitle.
  ///
  /// In de, this message translates to:
  /// **'Daten auf GitHub'**
  String get syncDialogTitle;

  /// No description provided for @syncDialogUnreadable.
  ///
  /// In de, this message translates to:
  /// **'Auf GitHub: nicht lesbar. {problem}'**
  String syncDialogUnreadable(Object problem);

  /// No description provided for @syncDialogRemote.
  ///
  /// In de, this message translates to:
  /// **'Auf GitHub: {count}'**
  String syncDialogRemote(Object count);

  /// No description provided for @syncDialogLocal.
  ///
  /// In de, this message translates to:
  /// **'Auf diesem Gerät: {count}'**
  String syncDialogLocal(Object count);

  /// No description provided for @syncDialogRestoreAll.
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellen holt Trainings und Pläne von GitHub.'**
  String get syncDialogRestoreAll;

  /// No description provided for @syncDialogRestoreKeep.
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellen holt Trainings und Pläne von GitHub und behält die Trainings, die nur hier sind.'**
  String get syncDialogRestoreKeep;

  /// No description provided for @syncOverwrite.
  ///
  /// In de, this message translates to:
  /// **'GitHub überschreiben'**
  String get syncOverwrite;

  /// No description provided for @languageName.
  ///
  /// In de, this message translates to:
  /// **'Deutsch'**
  String get languageName;

  /// No description provided for @dateFormat.
  ///
  /// In de, this message translates to:
  /// **'dd.MM.yyyy'**
  String get dateFormat;

  /// No description provided for @minutes.
  ///
  /// In de, this message translates to:
  /// **'{n} Min'**
  String minutes(Object n);

  /// No description provided for @navWorkouts.
  ///
  /// In de, this message translates to:
  /// **'Workouts'**
  String get navWorkouts;

  /// No description provided for @navStats.
  ///
  /// In de, this message translates to:
  /// **'Statistik'**
  String get navStats;

  /// No description provided for @navHistory.
  ///
  /// In de, this message translates to:
  /// **'Verlauf'**
  String get navHistory;

  /// No description provided for @navSettings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get navSettings;

  /// No description provided for @noWorkoutsYet.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Workouts. Leg eins an.'**
  String get noWorkoutsYet;

  /// No description provided for @workoutRunning.
  ///
  /// In de, this message translates to:
  /// **' läuft · '**
  String get workoutRunning;

  /// No description provided for @resume.
  ///
  /// In de, this message translates to:
  /// **'Fortsetzen'**
  String get resume;

  /// No description provided for @elapsedMinutes.
  ///
  /// In de, this message translates to:
  /// **'{n} Min.'**
  String elapsedMinutes(Object n);

  /// No description provided for @elapsedHours.
  ///
  /// In de, this message translates to:
  /// **'{time} Std.'**
  String elapsedHours(Object time);

  /// No description provided for @restPaused.
  ///
  /// In de, this message translates to:
  /// **' · Pause angehalten'**
  String get restPaused;

  /// No description provided for @restLeft.
  ///
  /// In de, this message translates to:
  /// **' · Pause {time}'**
  String restLeft(Object time);

  /// No description provided for @workout.
  ///
  /// In de, this message translates to:
  /// **'Workout'**
  String get workout;

  /// No description provided for @trainingRunning.
  ///
  /// In de, this message translates to:
  /// **'Training läuft'**
  String get trainingRunning;

  /// No description provided for @runningSince.
  ///
  /// In de, this message translates to:
  /// **'{name} · seit '**
  String runningSince(Object name);

  /// No description provided for @discardTraining.
  ///
  /// In de, this message translates to:
  /// **'Training verwerfen'**
  String get discardTraining;

  /// No description provided for @discardTrainingAsk.
  ///
  /// In de, this message translates to:
  /// **'Training verwerfen? Nichts wird gespeichert.'**
  String get discardTrainingAsk;

  /// No description provided for @resumeTraining.
  ///
  /// In de, this message translates to:
  /// **'Training fortsetzen'**
  String get resumeTraining;

  /// No description provided for @comebackLighter.
  ///
  /// In de, this message translates to:
  /// **'Nach der Pause {pct} % leichter zum Einstieg'**
  String comebackLighter(Object pct);

  /// No description provided for @setMuscles.
  ///
  /// In de, this message translates to:
  /// **'Muskeln festlegen, sonst fehlt sie in der Statistik'**
  String get setMuscles;

  /// No description provided for @lastDone.
  ///
  /// In de, this message translates to:
  /// **'zuletzt {when}'**
  String lastDone(Object when);

  /// No description provided for @edit.
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get edit;

  /// No description provided for @start.
  ///
  /// In de, this message translates to:
  /// **'Starten'**
  String get start;

  /// No description provided for @running.
  ///
  /// In de, this message translates to:
  /// **'LÄUFT'**
  String get running;

  /// No description provided for @setsDone.
  ///
  /// In de, this message translates to:
  /// **'{done}/{total} Sätze'**
  String setsDone(Object done, Object total);

  /// No description provided for @weeksCount.
  ///
  /// In de, this message translates to:
  /// **'{n, plural, =1{1 Woche} other{{n} Wochen}}'**
  String weeksCount(int n);

  /// No description provided for @streakTooltip.
  ///
  /// In de, this message translates to:
  /// **'{weeks} in Folge mindestens {goal}× trainiert'**
  String streakTooltip(Object weeks, Object goal);

  /// No description provided for @today.
  ///
  /// In de, this message translates to:
  /// **'heute'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In de, this message translates to:
  /// **'gestern'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In de, this message translates to:
  /// **'vor {n} Tagen'**
  String daysAgo(Object n);

  /// No description provided for @noTrainingsYet.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Trainings geloggt.'**
  String get noTrainingsYet;

  /// No description provided for @streakGoal.
  ///
  /// In de, this message translates to:
  /// **'Ziel: {goal}× pro Woche'**
  String streakGoal(Object goal);

  /// No description provided for @streakWeeks.
  ///
  /// In de, this message translates to:
  /// **'{weeks} in Folge · {goal}× pro Woche'**
  String streakWeeks(Object weeks, Object goal);

  /// No description provided for @streakWeekDone.
  ///
  /// In de, this message translates to:
  /// **'Diese Woche geschafft ({done}/{goal}). Weiter so!'**
  String streakWeekDone(Object done, Object goal);

  /// No description provided for @streakWeekOpen.
  ///
  /// In de, this message translates to:
  /// **'Diese Woche {done}/{goal} · noch {left}'**
  String streakWeekOpen(Object done, Object goal, Object left);

  /// No description provided for @streakWeekOpenKeep.
  ///
  /// In de, this message translates to:
  /// **'Diese Woche {done}/{goal} · noch {left}, um die Serie zu halten'**
  String streakWeekOpenKeep(Object done, Object goal, Object left);

  /// No description provided for @todayButton.
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get todayButton;

  /// No description provided for @previousMonth.
  ///
  /// In de, this message translates to:
  /// **'Voriger Monat'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In de, this message translates to:
  /// **'Nächster Monat'**
  String get nextMonth;

  /// No description provided for @trainingsInMonth.
  ///
  /// In de, this message translates to:
  /// **'{count} im {month}'**
  String trainingsInMonth(Object count, Object month);

  /// No description provided for @delete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get delete;

  /// No description provided for @deleteTrainingAsk.
  ///
  /// In de, this message translates to:
  /// **'Training vom {date} löschen?'**
  String deleteTrainingAsk(Object date);

  /// No description provided for @deleteTrainingMovesPlan.
  ///
  /// In de, this message translates to:
  /// **' Die Plan-Gewichte gehen auf den Stand davor zurück.'**
  String get deleteTrainingMovesPlan;

  /// No description provided for @yes.
  ///
  /// In de, this message translates to:
  /// **'Ja'**
  String get yes;

  /// No description provided for @secondsUnit.
  ///
  /// In de, this message translates to:
  /// **'s'**
  String get secondsUnit;

  /// No description provided for @progUp.
  ///
  /// In de, this message translates to:
  /// **'geschafft'**
  String get progUp;

  /// No description provided for @progUp2.
  ///
  /// In de, this message translates to:
  /// **'viel Reserve, doppelter Schritt'**
  String get progUp2;

  /// No description provided for @progHalf.
  ///
  /// In de, this message translates to:
  /// **'2× am Limit, halber Schritt'**
  String get progHalf;

  /// No description provided for @progLimit.
  ///
  /// In de, this message translates to:
  /// **'am Limit, Gewicht bleibt'**
  String get progLimit;

  /// No description provided for @progBridgeTo.
  ///
  /// In de, this message translates to:
  /// **'nächstes Mal {reps} Wdh., bei {to} mehr Gewicht'**
  String progBridgeTo(Object reps, Object to);

  /// No description provided for @progBridge.
  ///
  /// In de, this message translates to:
  /// **'erst mehr Wiederholungen'**
  String get progBridge;

  /// No description provided for @progRange.
  ///
  /// In de, this message translates to:
  /// **'erst alle Wiederholungen'**
  String get progRange;

  /// No description provided for @progMiss.
  ///
  /// In de, this message translates to:
  /// **'nicht geschafft'**
  String get progMiss;

  /// No description provided for @progReset.
  ///
  /// In de, this message translates to:
  /// **'2× nicht geschafft, Wiederholungen zurück'**
  String get progReset;

  /// No description provided for @progBadDay.
  ///
  /// In de, this message translates to:
  /// **'schlechter Tag, zählt nicht'**
  String get progBadDay;

  /// No description provided for @progPain.
  ///
  /// In de, this message translates to:
  /// **'Schmerzen: Gewicht bleibt. Kommt es wieder, lass die Übung prüfen.'**
  String get progPain;

  /// No description provided for @progDeload.
  ///
  /// In de, this message translates to:
  /// **'{fails}× nicht geschafft, etwa −10 %, kleinere Schritte'**
  String progDeload(Object fails);

  /// No description provided for @progLighter.
  ///
  /// In de, this message translates to:
  /// **'leichter gemacht'**
  String get progLighter;

  /// No description provided for @progFewer.
  ///
  /// In de, this message translates to:
  /// **'weniger Sätze'**
  String get progFewer;

  /// No description provided for @tagSleptBadly.
  ///
  /// In de, this message translates to:
  /// **'Schlecht geschlafen'**
  String get tagSleptBadly;

  /// No description provided for @tagWellRested.
  ///
  /// In de, this message translates to:
  /// **'Gut erholt'**
  String get tagWellRested;

  /// No description provided for @tagSore.
  ///
  /// In de, this message translates to:
  /// **'Muskelkater'**
  String get tagSore;

  /// No description provided for @tagPain.
  ///
  /// In de, this message translates to:
  /// **'Schmerzen'**
  String get tagPain;

  /// No description provided for @tagSick.
  ///
  /// In de, this message translates to:
  /// **'Krank'**
  String get tagSick;

  /// No description provided for @tagStress.
  ///
  /// In de, this message translates to:
  /// **'Stress'**
  String get tagStress;

  /// No description provided for @tagUnmotivated.
  ///
  /// In de, this message translates to:
  /// **'Unmotiviert'**
  String get tagUnmotivated;

  /// No description provided for @tagEnergetic.
  ///
  /// In de, this message translates to:
  /// **'Voller Energie'**
  String get tagEnergetic;

  /// No description provided for @tagAteLittle.
  ///
  /// In de, this message translates to:
  /// **'Wenig gegessen'**
  String get tagAteLittle;

  /// No description provided for @tagAlcohol.
  ///
  /// In de, this message translates to:
  /// **'Alkohol'**
  String get tagAlcohol;

  /// No description provided for @tagCaffeine.
  ///
  /// In de, this message translates to:
  /// **'Koffein'**
  String get tagCaffeine;

  /// No description provided for @tagLittleTime.
  ///
  /// In de, this message translates to:
  /// **'Wenig Zeit'**
  String get tagLittleTime;

  /// No description provided for @tagGymBusy.
  ///
  /// In de, this message translates to:
  /// **'Studio voll'**
  String get tagGymBusy;

  /// No description provided for @tagTravelling.
  ///
  /// In de, this message translates to:
  /// **'Unterwegs'**
  String get tagTravelling;

  /// No description provided for @tagTechnique.
  ///
  /// In de, this message translates to:
  /// **'Technik-Fokus'**
  String get tagTechnique;

  /// No description provided for @fileNotFerrolog.
  ///
  /// In de, this message translates to:
  /// **'Das ist keine FerroLog-Datei (app \"ferrolog\" fehlt).'**
  String get fileNotFerrolog;

  /// No description provided for @fileNoVersion.
  ///
  /// In de, this message translates to:
  /// **'Die Datei hat keine gültige Version.'**
  String get fileNoVersion;

  /// No description provided for @fileTooNew.
  ///
  /// In de, this message translates to:
  /// **'Die Datei hat Version {version}, diese App kennt nur bis {known}. Bitte die App aktualisieren.'**
  String fileTooNew(Object version, Object known);

  /// No description provided for @fileNoData.
  ///
  /// In de, this message translates to:
  /// **'Workouts oder Trainings fehlen in der Datei.'**
  String get fileNoData;

  /// No description provided for @fileBroken.
  ///
  /// In de, this message translates to:
  /// **'Die Datei ist beschädigt: {error}'**
  String fileBroken(Object error);

  /// No description provided for @rirLimit.
  ///
  /// In de, this message translates to:
  /// **'am Limit'**
  String get rirLimit;

  /// No description provided for @rirLeft.
  ///
  /// In de, this message translates to:
  /// **'noch {n} übrig'**
  String rirLeft(Object n);

  /// No description provided for @platesNotLoadable.
  ///
  /// In de, this message translates to:
  /// **'Mit deinen Scheiben nicht ladbar'**
  String get platesNotLoadable;

  /// No description provided for @platesBarOnly.
  ///
  /// In de, this message translates to:
  /// **'Nur die Stange'**
  String get platesBarOnly;

  /// No description provided for @platesPerSide.
  ///
  /// In de, this message translates to:
  /// **'Pro Seite: {plates}'**
  String platesPerSide(Object plates);

  /// No description provided for @aboutMinutes.
  ///
  /// In de, this message translates to:
  /// **'≈ {n} Min'**
  String aboutMinutes(Object n);

  /// No description provided for @everySet.
  ///
  /// In de, this message translates to:
  /// **'{taken} · alle {time} Min ein Satz'**
  String everySet(Object taken, Object time);

  /// No description provided for @syncConflict.
  ///
  /// In de, this message translates to:
  /// **'Konflikt: Daten auf GitHub sind neuer oder fremd'**
  String get syncConflict;

  /// No description provided for @syncLoginFailed.
  ///
  /// In de, this message translates to:
  /// **'GitHub-Login fehlgeschlagen (HTTP {code})'**
  String syncLoginFailed(Object code);

  /// No description provided for @syncNoClientId.
  ///
  /// In de, this message translates to:
  /// **'githubClientId in lib/sync.dart ist nicht gesetzt (siehe README).'**
  String get syncNoClientId;

  /// No description provided for @syncCodeExpired.
  ///
  /// In de, this message translates to:
  /// **'Code abgelaufen, bitte neu anmelden.'**
  String get syncCodeExpired;

  /// No description provided for @syncDenied.
  ///
  /// In de, this message translates to:
  /// **'Anmeldung abgelehnt.'**
  String get syncDenied;

  /// No description provided for @syncLoginError.
  ///
  /// In de, this message translates to:
  /// **'GitHub-Login: {error}'**
  String syncLoginError(Object error);

  /// No description provided for @syncDone.
  ///
  /// In de, this message translates to:
  /// **'Synchronisiert {time}'**
  String syncDone(Object time);

  /// No description provided for @syncError.
  ///
  /// In de, this message translates to:
  /// **'Fehler {time}: {error}'**
  String syncError(Object time, Object error);

  /// No description provided for @syncExpired.
  ///
  /// In de, this message translates to:
  /// **'Anmeldung abgelaufen, bitte neu anmelden'**
  String get syncExpired;

  /// No description provided for @syncNoWrite.
  ///
  /// In de, this message translates to:
  /// **'Keine Schreibrechte – hat FerroLog Zugriff auf das Repo?'**
  String get syncNoWrite;

  /// No description provided for @syncNotFound.
  ///
  /// In de, this message translates to:
  /// **'Repo nicht gefunden – hat FerroLog Zugriff darauf?'**
  String get syncNotFound;

  /// No description provided for @recapRecord.
  ///
  /// In de, this message translates to:
  /// **'Neuer Rekord! 🏆'**
  String get recapRecord;

  /// No description provided for @recapAllDone.
  ///
  /// In de, this message translates to:
  /// **'Alles geschafft! 💪'**
  String get recapAllDone;

  /// No description provided for @recapBackoff.
  ///
  /// In de, this message translates to:
  /// **'nach der Pause −{pct} %'**
  String recapBackoff(Object pct);

  /// No description provided for @recapVolume.
  ///
  /// In de, this message translates to:
  /// **'Volumen'**
  String get recapVolume;

  /// No description provided for @recapHeaviest.
  ///
  /// In de, this message translates to:
  /// **'Schwerster'**
  String get recapHeaviest;

  /// No description provided for @recapDuration.
  ///
  /// In de, this message translates to:
  /// **'Dauer'**
  String get recapDuration;

  /// No description provided for @recapTitle.
  ///
  /// In de, this message translates to:
  /// **'Zusammenfassung'**
  String get recapTitle;

  /// No description provided for @editTraining.
  ///
  /// In de, this message translates to:
  /// **'Training bearbeiten'**
  String get editTraining;

  /// No description provided for @recapNextWeight.
  ///
  /// In de, this message translates to:
  /// **'  Gewicht fürs nächste Mal'**
  String get recapNextWeight;

  /// No description provided for @recapHowWasIt.
  ///
  /// In de, this message translates to:
  /// **'Wie war’s?'**
  String get recapHowWasIt;

  /// No description provided for @moodBad.
  ///
  /// In de, this message translates to:
  /// **'Schlecht'**
  String get moodBad;

  /// No description provided for @moodOkay.
  ///
  /// In de, this message translates to:
  /// **'Okay'**
  String get moodOkay;

  /// No description provided for @moodGood.
  ///
  /// In de, this message translates to:
  /// **'Gut'**
  String get moodGood;

  /// No description provided for @bodyWeight.
  ///
  /// In de, this message translates to:
  /// **'Körpergewicht ({unit})'**
  String bodyWeight(Object unit);

  /// No description provided for @bodyWeightStale.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt vor {days} Tagen eingetragen. Einmal im Monat hält die Statistik aktuell.'**
  String bodyWeightStale(Object days);

  /// No description provided for @optional.
  ///
  /// In de, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @bodyWeightSame.
  ///
  /// In de, this message translates to:
  /// **'Wie zuletzt? ± übernimmt den Wert.'**
  String get bodyWeightSame;

  /// No description provided for @recapAddNote.
  ///
  /// In de, this message translates to:
  /// **'Notiz: Schlaf, Alkohol, Stress …'**
  String get recapAddNote;

  /// No description provided for @recapCircumstances.
  ///
  /// In de, this message translates to:
  /// **'Umstände'**
  String get recapCircumstances;

  /// No description provided for @recapNoteHint.
  ///
  /// In de, this message translates to:
  /// **'Sonst noch was? (optional)'**
  String get recapNoteHint;

  /// No description provided for @done.
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get done;

  /// No description provided for @editDayHelp.
  ///
  /// In de, this message translates to:
  /// **'Tag des Trainings'**
  String get editDayHelp;

  /// No description provided for @next.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get next;

  /// No description provided for @editStartHelp.
  ///
  /// In de, this message translates to:
  /// **'Beginn'**
  String get editStartHelp;

  /// No description provided for @ok.
  ///
  /// In de, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @discardChanges.
  ///
  /// In de, this message translates to:
  /// **'Änderungen verwerfen?'**
  String get discardChanges;

  /// No description provided for @editStartAt.
  ///
  /// In de, this message translates to:
  /// **'{date} · Beginn {time}'**
  String editStartAt(Object date, Object time);

  /// No description provided for @cardioGoal.
  ///
  /// In de, this message translates to:
  /// **'Cardio · Ziel {goal}'**
  String cardioGoal(Object goal);

  /// No description provided for @insteadOf.
  ///
  /// In de, this message translates to:
  /// **'statt {name}'**
  String insteadOf(Object name);

  /// No description provided for @notDone.
  ///
  /// In de, this message translates to:
  /// **'Nicht gemacht'**
  String get notDone;

  /// No description provided for @rirQuestionShort.
  ///
  /// In de, this message translates to:
  /// **'Gingen noch'**
  String get rirQuestionShort;

  /// No description provided for @save.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// No description provided for @editReplans.
  ///
  /// In de, this message translates to:
  /// **'Die Plan-Gewichte werden neu berechnet.'**
  String get editReplans;

  /// No description provided for @editHistoryOnly.
  ///
  /// In de, this message translates to:
  /// **'Ältere Trainings ändern nur Verlauf und Statistik, nicht den Plan.'**
  String get editHistoryOnly;

  /// No description provided for @less.
  ///
  /// In de, this message translates to:
  /// **'Weniger'**
  String get less;

  /// No description provided for @more.
  ///
  /// In de, this message translates to:
  /// **'Mehr'**
  String get more;

  /// No description provided for @setOfGoal.
  ///
  /// In de, this message translates to:
  /// **'Satz {n} von {total} · Ziel {goal}'**
  String setOfGoal(Object n, Object total, Object goal);

  /// No description provided for @cardWeekGoal.
  ///
  /// In de, this message translates to:
  /// **'WOCHENZIEL'**
  String get cardWeekGoal;

  /// No description provided for @cardSkipped.
  ///
  /// In de, this message translates to:
  /// **'AUSGELASSEN · LETZTE 4 WOCHEN'**
  String get cardSkipped;

  /// No description provided for @cardBalance.
  ///
  /// In de, this message translates to:
  /// **'BALANCE · LETZTE 28 TAGE'**
  String get cardBalance;

  /// No description provided for @cardPlateau.
  ///
  /// In de, this message translates to:
  /// **'PLATEAU'**
  String get cardPlateau;

  /// No description provided for @cardAllGood.
  ///
  /// In de, this message translates to:
  /// **'Alles im Lot'**
  String get cardAllGood;

  /// No description provided for @cardSeeStats.
  ///
  /// In de, this message translates to:
  /// **' · Statistik ansehen'**
  String get cardSeeStats;

  /// No description provided for @cardTitle.
  ///
  /// In de, this message translates to:
  /// **'Dein Training'**
  String get cardTitle;

  /// No description provided for @cardFromStats.
  ///
  /// In de, this message translates to:
  /// **'aus deiner Statistik'**
  String get cardFromStats;

  /// No description provided for @cardWhyWhat.
  ///
  /// In de, this message translates to:
  /// **'Warum und was tun →'**
  String get cardWhyWhat;

  /// No description provided for @cardWhy.
  ///
  /// In de, this message translates to:
  /// **'WARUM'**
  String get cardWhy;

  /// No description provided for @cardAdvice.
  ///
  /// In de, this message translates to:
  /// **'EMPFEHLUNG'**
  String get cardAdvice;

  /// No description provided for @fixMoveUp.
  ///
  /// In de, this message translates to:
  /// **'In {workout} vorziehen'**
  String fixMoveUp(Object workout);

  /// No description provided for @fixDropSet.
  ///
  /// In de, this message translates to:
  /// **'1 Satz weniger {exercise}'**
  String fixDropSet(Object exercise);

  /// No description provided for @fixInEditor.
  ///
  /// In de, this message translates to:
  /// **'Im Editor anpassen'**
  String get fixInEditor;

  /// No description provided for @later.
  ///
  /// In de, this message translates to:
  /// **'Später'**
  String get later;

  /// No description provided for @sourceBalance.
  ///
  /// In de, this message translates to:
  /// **'Balance in der Statistik ansehen'**
  String get sourceBalance;

  /// No description provided for @sourceWeeks.
  ///
  /// In de, this message translates to:
  /// **'Wochen in der Statistik ansehen'**
  String get sourceWeeks;

  /// No description provided for @sourceExercise.
  ///
  /// In de, this message translates to:
  /// **'{exercise} in der Statistik ansehen'**
  String sourceExercise(Object exercise);

  /// No description provided for @sourceHistory.
  ///
  /// In de, this message translates to:
  /// **'Im Verlauf ansehen'**
  String get sourceHistory;

  /// No description provided for @fixMovedUp.
  ///
  /// In de, this message translates to:
  /// **'{exercise} in {workout} vorgezogen'**
  String fixMovedUp(Object exercise, Object workout);

  /// No description provided for @setsCount.
  ///
  /// In de, this message translates to:
  /// **'{n, plural, =1{1 Satz} other{{n} Sätze}}'**
  String setsCount(int n);

  /// No description provided for @fixDroppedSet.
  ///
  /// In de, this message translates to:
  /// **'{exercise} in {workout}: jetzt {sets}'**
  String fixDroppedSet(Object exercise, Object workout, Object sets);

  /// No description provided for @undo.
  ///
  /// In de, this message translates to:
  /// **'Rückgängig'**
  String get undo;

  /// No description provided for @finishTrainingFirst.
  ///
  /// In de, this message translates to:
  /// **'Erst das laufende Training beenden'**
  String get finishTrainingFirst;

  /// No description provided for @planTaken.
  ///
  /// In de, this message translates to:
  /// **'Plan übernommen'**
  String get planTaken;

  /// No description provided for @fileUnreadable.
  ///
  /// In de, this message translates to:
  /// **'Die Datei ließ sich nicht lesen: {error}'**
  String fileUnreadable(Object error);

  /// No description provided for @planPasteHint.
  ///
  /// In de, this message translates to:
  /// **'Füg den JSON-Codeblock aus dem Chat ein oder öffne ihn als Datei. Vor dem Speichern siehst du jede Änderung.'**
  String get planPasteHint;

  /// No description provided for @openFile.
  ///
  /// In de, this message translates to:
  /// **'Datei öffnen (.json, .txt)'**
  String get openFile;

  /// No description provided for @check.
  ///
  /// In de, this message translates to:
  /// **'Prüfen'**
  String get check;

  /// No description provided for @changeNew.
  ///
  /// In de, this message translates to:
  /// **'Neu'**
  String get changeNew;

  /// No description provided for @changeRemoved.
  ///
  /// In de, this message translates to:
  /// **'Fällt weg'**
  String get changeRemoved;

  /// No description provided for @changeChanged.
  ///
  /// In de, this message translates to:
  /// **'Geändert'**
  String get changeChanged;

  /// No description provided for @changeSame.
  ///
  /// In de, this message translates to:
  /// **'Unverändert'**
  String get changeSame;

  /// No description provided for @planFromAi.
  ///
  /// In de, this message translates to:
  /// **'Plan von KI'**
  String get planFromAi;

  /// No description provided for @planStale.
  ///
  /// In de, this message translates to:
  /// **'Seit dem Export hast du trainiert'**
  String get planStale;

  /// No description provided for @planStaleHint.
  ///
  /// In de, this message translates to:
  /// **'Der Plan beruht auf dem Stand vom {date}. Die Gewichte können veraltet sein.'**
  String planStaleHint(Object date);

  /// No description provided for @planEmpty.
  ///
  /// In de, this message translates to:
  /// **'Der Plan ändert nichts an deinen Workouts.'**
  String get planEmpty;

  /// No description provided for @planUnchanged.
  ///
  /// In de, this message translates to:
  /// **'Unverändert: {names}'**
  String planUnchanged(Object names);

  /// No description provided for @planKeepsTrainings.
  ///
  /// In de, this message translates to:
  /// **'Deine Trainings bleiben, wie sie sind. Nach dem Übernehmen kannst du es einmal rückgängig machen.'**
  String get planKeepsTrainings;

  /// No description provided for @takeOver.
  ///
  /// In de, this message translates to:
  /// **'Übernehmen'**
  String get takeOver;

  /// No description provided for @movedTo.
  ///
  /// In de, this message translates to:
  /// **'Jetzt an Platz {n}'**
  String movedTo(Object n);

  /// No description provided for @front.
  ///
  /// In de, this message translates to:
  /// **'Vorne'**
  String get front;

  /// No description provided for @back.
  ///
  /// In de, this message translates to:
  /// **'Hinten'**
  String get back;

  /// No description provided for @muscleChest.
  ///
  /// In de, this message translates to:
  /// **'Brust'**
  String get muscleChest;

  /// No description provided for @muscleShoulders.
  ///
  /// In de, this message translates to:
  /// **'Schultern'**
  String get muscleShoulders;

  /// No description provided for @muscleTriceps.
  ///
  /// In de, this message translates to:
  /// **'Trizeps'**
  String get muscleTriceps;

  /// No description provided for @muscleBiceps.
  ///
  /// In de, this message translates to:
  /// **'Bizeps'**
  String get muscleBiceps;

  /// No description provided for @muscleForearms.
  ///
  /// In de, this message translates to:
  /// **'Unterarme'**
  String get muscleForearms;

  /// No description provided for @muscleLats.
  ///
  /// In de, this message translates to:
  /// **'Latissimus'**
  String get muscleLats;

  /// No description provided for @muscleMiddleBack.
  ///
  /// In de, this message translates to:
  /// **'Mittlerer Rücken'**
  String get muscleMiddleBack;

  /// No description provided for @muscleLowerBack.
  ///
  /// In de, this message translates to:
  /// **'Unterer Rücken'**
  String get muscleLowerBack;

  /// No description provided for @muscleTraps.
  ///
  /// In de, this message translates to:
  /// **'Trapez'**
  String get muscleTraps;

  /// No description provided for @muscleNeck.
  ///
  /// In de, this message translates to:
  /// **'Nacken'**
  String get muscleNeck;

  /// No description provided for @muscleAbdominals.
  ///
  /// In de, this message translates to:
  /// **'Bauch'**
  String get muscleAbdominals;

  /// No description provided for @muscleQuadriceps.
  ///
  /// In de, this message translates to:
  /// **'Quadrizeps'**
  String get muscleQuadriceps;

  /// No description provided for @muscleHamstrings.
  ///
  /// In de, this message translates to:
  /// **'Beinbeuger'**
  String get muscleHamstrings;

  /// No description provided for @muscleGlutes.
  ///
  /// In de, this message translates to:
  /// **'Gesäß'**
  String get muscleGlutes;

  /// No description provided for @muscleCalves.
  ///
  /// In de, this message translates to:
  /// **'Waden'**
  String get muscleCalves;

  /// No description provided for @muscleAdductors.
  ///
  /// In de, this message translates to:
  /// **'Adduktoren'**
  String get muscleAdductors;

  /// No description provided for @muscleAbductors.
  ///
  /// In de, this message translates to:
  /// **'Abduktoren'**
  String get muscleAbductors;

  /// No description provided for @groupChest.
  ///
  /// In de, this message translates to:
  /// **'Brust'**
  String get groupChest;

  /// No description provided for @groupUpperBack.
  ///
  /// In de, this message translates to:
  /// **'Oberer Rücken'**
  String get groupUpperBack;

  /// No description provided for @groupShoulders.
  ///
  /// In de, this message translates to:
  /// **'Schultern'**
  String get groupShoulders;

  /// No description provided for @groupLats.
  ///
  /// In de, this message translates to:
  /// **'Latissimus'**
  String get groupLats;

  /// No description provided for @groupFrontDelts.
  ///
  /// In de, this message translates to:
  /// **'Vordere Schulter'**
  String get groupFrontDelts;

  /// No description provided for @groupRearDelts.
  ///
  /// In de, this message translates to:
  /// **'Hintere Schulter'**
  String get groupRearDelts;

  /// No description provided for @groupQuads.
  ///
  /// In de, this message translates to:
  /// **'Quadrizeps'**
  String get groupQuads;

  /// No description provided for @groupHamstrings.
  ///
  /// In de, this message translates to:
  /// **'Hintere Oberschenkel'**
  String get groupHamstrings;

  /// No description provided for @groupInternalRot.
  ///
  /// In de, this message translates to:
  /// **'Innenrotation'**
  String get groupInternalRot;

  /// No description provided for @groupExternalRot.
  ///
  /// In de, this message translates to:
  /// **'Außenrotation'**
  String get groupExternalRot;

  /// No description provided for @groupAbs.
  ///
  /// In de, this message translates to:
  /// **'Bauch'**
  String get groupAbs;

  /// No description provided for @groupLowerBack.
  ///
  /// In de, this message translates to:
  /// **'Unterer Rücken'**
  String get groupLowerBack;

  /// No description provided for @objChest.
  ///
  /// In de, this message translates to:
  /// **'die Brust'**
  String get objChest;

  /// No description provided for @objUpperBack.
  ///
  /// In de, this message translates to:
  /// **'den oberen Rücken'**
  String get objUpperBack;

  /// No description provided for @objShoulders.
  ///
  /// In de, this message translates to:
  /// **'die Schultern'**
  String get objShoulders;

  /// No description provided for @objLats.
  ///
  /// In de, this message translates to:
  /// **'den Latissimus'**
  String get objLats;

  /// No description provided for @objFrontDelts.
  ///
  /// In de, this message translates to:
  /// **'die vordere Schulter'**
  String get objFrontDelts;

  /// No description provided for @objRearDelts.
  ///
  /// In de, this message translates to:
  /// **'die hintere Schulter'**
  String get objRearDelts;

  /// No description provided for @objQuads.
  ///
  /// In de, this message translates to:
  /// **'den Quadrizeps'**
  String get objQuads;

  /// No description provided for @objHamstrings.
  ///
  /// In de, this message translates to:
  /// **'die hinteren Oberschenkel'**
  String get objHamstrings;

  /// No description provided for @objInternalRot.
  ///
  /// In de, this message translates to:
  /// **'die Innenrotation'**
  String get objInternalRot;

  /// No description provided for @objExternalRot.
  ///
  /// In de, this message translates to:
  /// **'die Außenrotation'**
  String get objExternalRot;

  /// No description provided for @objAbs.
  ///
  /// In de, this message translates to:
  /// **'den Bauch'**
  String get objAbs;

  /// No description provided for @objLowerBack.
  ///
  /// In de, this message translates to:
  /// **'den unteren Rücken'**
  String get objLowerBack;

  /// No description provided for @sidePush.
  ///
  /// In de, this message translates to:
  /// **'Drücken'**
  String get sidePush;

  /// No description provided for @sideRow.
  ///
  /// In de, this message translates to:
  /// **'Rudern'**
  String get sideRow;

  /// No description provided for @sideOverhead.
  ///
  /// In de, this message translates to:
  /// **'Über Kopf drücken'**
  String get sideOverhead;

  /// No description provided for @sidePullUps.
  ///
  /// In de, this message translates to:
  /// **'Klimmzüge, Latzug'**
  String get sidePullUps;

  /// No description provided for @sideFrontDelts.
  ///
  /// In de, this message translates to:
  /// **'Vordere Schulter'**
  String get sideFrontDelts;

  /// No description provided for @sideRearDelts.
  ///
  /// In de, this message translates to:
  /// **'hintere Schulter'**
  String get sideRearDelts;

  /// No description provided for @sideQuads.
  ///
  /// In de, this message translates to:
  /// **'Quadrizeps'**
  String get sideQuads;

  /// No description provided for @sideHamstrings.
  ///
  /// In de, this message translates to:
  /// **'hintere Oberschenkel'**
  String get sideHamstrings;

  /// No description provided for @sideInternalRot.
  ///
  /// In de, this message translates to:
  /// **'Innenrotation'**
  String get sideInternalRot;

  /// No description provided for @sideExternalRot.
  ///
  /// In de, this message translates to:
  /// **'Außenrotation'**
  String get sideExternalRot;

  /// No description provided for @sideAbs.
  ///
  /// In de, this message translates to:
  /// **'Bauch'**
  String get sideAbs;

  /// No description provided for @sideLowerBack.
  ///
  /// In de, this message translates to:
  /// **'unterer Rücken'**
  String get sideLowerBack;

  /// No description provided for @notePressHalf.
  ///
  /// In de, this message translates to:
  /// **'Drückübungen zählen halb'**
  String get notePressHalf;

  /// No description provided for @noteHingeSquatHalf.
  ///
  /// In de, this message translates to:
  /// **'Kreuzheben und Kniebeuge zählen halb'**
  String get noteHingeSquatHalf;

  /// No description provided for @ratioRowBench.
  ///
  /// In de, this message translates to:
  /// **'Rudern : Bankdrücken'**
  String get ratioRowBench;

  /// No description provided for @ratioHingeSquat.
  ///
  /// In de, this message translates to:
  /// **'Kreuzheben : Kniebeuge'**
  String get ratioHingeSquat;

  /// No description provided for @weekDaysLeft.
  ///
  /// In de, this message translates to:
  /// **'noch {n} Tage'**
  String weekDaysLeft(Object n);

  /// No description provided for @weekTomorrowLast.
  ///
  /// In de, this message translates to:
  /// **'morgen ist der letzte Tag'**
  String get weekTomorrowLast;

  /// No description provided for @weekTodayLast.
  ///
  /// In de, this message translates to:
  /// **'heute ist der letzte Tag'**
  String get weekTodayLast;

  /// No description provided for @weekTitle.
  ///
  /// In de, this message translates to:
  /// **'{n, plural, =1{Noch 1 Training diese Woche} other{Noch {n} Trainings diese Woche}}'**
  String weekTitle(int n);

  /// No description provided for @weekEvidence.
  ///
  /// In de, this message translates to:
  /// **'{done} von {goal} geschafft, {when}'**
  String weekEvidence(Object done, Object goal, Object when);

  /// No description provided for @weekWhy.
  ///
  /// In de, this message translates to:
  /// **'Dein Wochenziel sind {goal} Trainings.'**
  String weekWhy(Object goal);

  /// No description provided for @weekAdviceDays.
  ///
  /// In de, this message translates to:
  /// **'Mit einem Training in den nächsten Tagen bleibt die Serie.'**
  String get weekAdviceDays;

  /// No description provided for @weekAdviceTomorrow.
  ///
  /// In de, this message translates to:
  /// **'Mit einem Training morgen bleibt die Serie.'**
  String get weekAdviceTomorrow;

  /// No description provided for @weekAdviceToday.
  ///
  /// In de, this message translates to:
  /// **'Mit einem Training heute bleibt die Serie.'**
  String get weekAdviceToday;

  /// No description provided for @skippedEndAlways.
  ///
  /// In de, this message translates to:
  /// **', jedes Mal als letzte Übung'**
  String get skippedEndAlways;

  /// No description provided for @skippedEndMostly.
  ///
  /// In de, this message translates to:
  /// **', meist als letzte Übung'**
  String get skippedEndMostly;

  /// No description provided for @skippedConsequence.
  ///
  /// In de, this message translates to:
  /// **' Folge für die Balance: {evidence}.'**
  String skippedConsequence(Object evidence);

  /// No description provided for @skippedTitle.
  ///
  /// In de, this message translates to:
  /// **'{name} {n}× ausgelassen'**
  String skippedTitle(Object name, Object n);

  /// No description provided for @skippedEvidence.
  ///
  /// In de, this message translates to:
  /// **'In 4 Wochen{end}'**
  String skippedEvidence(Object end);

  /// No description provided for @skippedWhy.
  ///
  /// In de, this message translates to:
  /// **'In {n} von {of} Trainings komplett weggelassen{end}.{consequence}'**
  String skippedWhy(Object n, Object of, Object end, Object consequence);

  /// No description provided for @skippedAdviceMove.
  ///
  /// In de, this message translates to:
  /// **'{name} vor die Zusatzübungen ziehen. Gleiches Volumen, es fällt nur nicht mehr hinten runter.'**
  String skippedAdviceMove(Object name);

  /// No description provided for @skippedAdvice.
  ///
  /// In de, this message translates to:
  /// **'{name} früher im Training einplanen oder bewusst aus dem Plan nehmen.'**
  String skippedAdvice(Object name);

  /// No description provided for @remedyRearDelts.
  ///
  /// In de, this message translates to:
  /// **'Face Pulls oder Reverse Flys'**
  String get remedyRearDelts;

  /// No description provided for @remedyAbs.
  ///
  /// In de, this message translates to:
  /// **'Plank oder Ab Wheel'**
  String get remedyAbs;

  /// No description provided for @remedyNoteExternal.
  ///
  /// In de, this message translates to:
  /// **' Face Pulls decken beides ab: Außenrotation und hintere Schulter. Am Ende eines Oberkörper-Trainings einplanen.'**
  String get remedyNoteExternal;

  /// No description provided for @remedyNoteRearDelts.
  ///
  /// In de, this message translates to:
  /// **' Face Pulls decken beides ab: hintere Schulter und Außenrotation.'**
  String get remedyNoteRearDelts;

  /// No description provided for @balanceAdviceEarlier.
  ///
  /// In de, this message translates to:
  /// **'Geplant ist es ausgeglichen, aber Sätze fallen weg. {side} früher im Training einplanen.'**
  String balanceAdviceEarlier(Object side);

  /// No description provided for @balanceAdviceDrop.
  ///
  /// In de, this message translates to:
  /// **'Ein Satz weniger {exercise} in {workout} gleicht aus, ohne mehr Arbeit.'**
  String balanceAdviceDrop(Object exercise, Object workout);

  /// No description provided for @balanceAdviceKeep.
  ///
  /// In de, this message translates to:
  /// **'Grundübungen bleiben wie geplant, {exercise} nicht auslassen und weiter steigern.'**
  String balanceAdviceKeep(Object exercise);

  /// No description provided for @balanceAdviceNothing.
  ///
  /// In de, this message translates to:
  /// **'Nichts im Plan trainiert {group} direkt.'**
  String balanceAdviceNothing(Object group);

  /// No description provided for @balanceAdviceSuggest.
  ///
  /// In de, this message translates to:
  /// **'Nichts im Plan trainiert {group} direkt, zum Beispiel {suggest}.{note}'**
  String balanceAdviceSuggest(Object group, Object suggest, Object note);

  /// No description provided for @balanceEvidence.
  ///
  /// In de, this message translates to:
  /// **'{ratio} · {a} {aValue} : {b} {bValue} Sätze/Woche'**
  String balanceEvidence(
    Object ratio,
    Object a,
    Object aValue,
    Object b,
    Object bValue,
  );

  /// No description provided for @balanceWhy.
  ///
  /// In de, this message translates to:
  /// **'{a} gegen {b}, Richtwert {range}. Gezählt werden die gemachten Sätze der letzten 28 Tage{note}.'**
  String balanceWhy(Object a, Object b, Object range, Object note);

  /// No description provided for @balanceTitle.
  ///
  /// In de, this message translates to:
  /// **'{group} kommt zu kurz'**
  String balanceTitle(Object group);

  /// No description provided for @guideFrom.
  ///
  /// In de, this message translates to:
  /// **'ab {pct} %'**
  String guideFrom(Object pct);

  /// No description provided for @plateauDeloadAfter.
  ///
  /// In de, this message translates to:
  /// **'Automatischer Deload nach {n} Fehlschlägen in Folge (bisher {fails}).'**
  String plateauDeloadAfter(Object n, Object fails);

  /// No description provided for @plateauDeloadOff.
  ///
  /// In de, this message translates to:
  /// **'Automatischer Deload ist aus.'**
  String get plateauDeloadOff;

  /// No description provided for @plateauTitle.
  ///
  /// In de, this message translates to:
  /// **'{name} steht bei {weight}'**
  String plateauTitle(Object name, Object weight);

  /// No description provided for @plateauEvidence.
  ///
  /// In de, this message translates to:
  /// **'{n} Trainings ohne Steigerung'**
  String plateauEvidence(Object n);

  /// No description provided for @plateauLighter.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt einen Satz leichter gemacht, das hält das Gewicht.'**
  String get plateauLighter;

  /// No description provided for @plateauReserve.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt gingen noch {n} Wiederholungen.'**
  String plateauReserve(Object n);

  /// No description provided for @plateauReserveMany.
  ///
  /// In de, this message translates to:
  /// **'4 oder mehr'**
  String get plateauReserveMany;

  /// No description provided for @plateauLimit.
  ///
  /// In de, this message translates to:
  /// **'Die letzten 2 Trainings am Limit, keine Wiederholung mehr übrig.'**
  String get plateauLimit;

  /// No description provided for @plateauAdviceTechnique.
  ///
  /// In de, this message translates to:
  /// **'Das Gewicht ist nicht die Grenze: Technik, Konzentration und genug Pause prüfen und die Sätze ausreizen. Ein Deload ist nicht nötig.'**
  String get plateauAdviceTechnique;

  /// No description provided for @plateauAdviceDeload.
  ///
  /// In de, this message translates to:
  /// **'Zweimal am Limit: ein Deload um etwa 10 % hilft, danach wieder aufbauen.'**
  String get plateauAdviceDeload;

  /// No description provided for @plateauAdviceHold.
  ///
  /// In de, this message translates to:
  /// **'Gewicht halten, auf saubere Technik und genug Pause achten. Klappt es in 2 Trainings nicht, kann ein Deload helfen.'**
  String get plateauAdviceHold;

  /// No description provided for @recordTitle.
  ///
  /// In de, this message translates to:
  /// **'Rekord: {name} {weight}'**
  String recordTitle(Object name, Object weight);

  /// No description provided for @recordEvidence.
  ///
  /// In de, this message translates to:
  /// **'Schwerer als je zuvor'**
  String get recordEvidence;

  /// No description provided for @gainTitle.
  ///
  /// In de, this message translates to:
  /// **'Fortschritt: {name} {from} → {to}'**
  String gainTitle(Object name, Object from, Object to);

  /// No description provided for @since.
  ///
  /// In de, this message translates to:
  /// **'Seit {date}'**
  String since(Object date);

  /// No description provided for @milestoneTitle.
  ///
  /// In de, this message translates to:
  /// **'{n}. Training geschafft'**
  String milestoneTitle(Object n);

  /// No description provided for @monthTitle.
  ///
  /// In de, this message translates to:
  /// **'Rekordmonat: {n} Trainings'**
  String monthTitle(Object n);

  /// No description provided for @monthEvidence.
  ///
  /// In de, this message translates to:
  /// **'So viele wie noch nie'**
  String get monthEvidence;

  /// No description provided for @programFullBodyStrength.
  ///
  /// In de, this message translates to:
  /// **'Full Body Kraft'**
  String get programFullBodyStrength;

  /// No description provided for @programFullBodyNote.
  ///
  /// In de, this message translates to:
  /// **'Jedes Training gleich, 1–3× pro Woche, 48–72 h Erholung dazwischen. 8–12 Wochen dabei bleiben.'**
  String get programFullBodyNote;

  /// No description provided for @programStrongLiftsNote.
  ///
  /// In de, this message translates to:
  /// **'A und B abwechselnd, 3× pro Woche.'**
  String get programStrongLiftsNote;

  /// No description provided for @programPpl.
  ///
  /// In de, this message translates to:
  /// **'Push/Pull/Beine'**
  String get programPpl;

  /// No description provided for @dayLegs.
  ///
  /// In de, this message translates to:
  /// **'Beine'**
  String get dayLegs;

  /// No description provided for @programUpperLower.
  ///
  /// In de, this message translates to:
  /// **'Ober/Unter'**
  String get programUpperLower;

  /// No description provided for @dayUpper.
  ///
  /// In de, this message translates to:
  /// **'Oberkörper'**
  String get dayUpper;

  /// No description provided for @dayLower.
  ///
  /// In de, this message translates to:
  /// **'Unterkörper'**
  String get dayLower;

  /// No description provided for @programFullBody.
  ///
  /// In de, this message translates to:
  /// **'Ganzkörper'**
  String get programFullBody;

  /// No description provided for @replaceExercisesAsk.
  ///
  /// In de, this message translates to:
  /// **'Deine Änderungen an der Übungsliste ersetzen?'**
  String get replaceExercisesAsk;

  /// No description provided for @newWorkout.
  ///
  /// In de, this message translates to:
  /// **'Neues Workout'**
  String get newWorkout;

  /// No description provided for @editWorkout.
  ///
  /// In de, this message translates to:
  /// **'Workout bearbeiten'**
  String get editWorkout;

  /// No description provided for @deleteWorkout.
  ///
  /// In de, this message translates to:
  /// **'Workout löschen'**
  String get deleteWorkout;

  /// No description provided for @deleteWorkoutAsk.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ löschen? Der Verlauf bleibt erhalten.'**
  String deleteWorkoutAsk(Object name);

  /// No description provided for @name.
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @example.
  ///
  /// In de, this message translates to:
  /// **'z. B. {value}'**
  String example(Object value);

  /// No description provided for @workoutA.
  ///
  /// In de, this message translates to:
  /// **'Workout A'**
  String get workoutA;

  /// No description provided for @fixedSteps.
  ///
  /// In de, this message translates to:
  /// **'{n, plural, =1{1 Übung steigert in festen Schritten} other{{n} Übungen steigern in festen Schritten}}'**
  String fixedSteps(int n);

  /// No description provided for @allAuto.
  ///
  /// In de, this message translates to:
  /// **'Alle automatisch'**
  String get allAuto;

  /// No description provided for @exercise.
  ///
  /// In de, this message translates to:
  /// **'Übung'**
  String get exercise;

  /// No description provided for @cardioLine.
  ///
  /// In de, this message translates to:
  /// **'Cardio · {goal}'**
  String cardioLine(Object goal);

  /// No description provided for @auto.
  ///
  /// In de, this message translates to:
  /// **'automatisch'**
  String get auto;

  /// No description provided for @onSuccess.
  ///
  /// In de, this message translates to:
  /// **'+{weight} bei Erfolg'**
  String onSuccess(Object weight);

  /// No description provided for @removeExercise.
  ///
  /// In de, this message translates to:
  /// **'Übung entfernen'**
  String get removeExercise;

  /// No description provided for @template.
  ///
  /// In de, this message translates to:
  /// **'Vorlage'**
  String get template;

  /// No description provided for @custom.
  ///
  /// In de, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @customHint.
  ///
  /// In de, this message translates to:
  /// **'Leg deine Übungen unten mit „+ Übung“ an.'**
  String get customHint;

  /// No description provided for @transferAsk.
  ///
  /// In de, this message translates to:
  /// **'Verlauf von „{from}“ auf „{to}“ übertragen?'**
  String transferAsk(Object from, Object to);

  /// No description provided for @transferHint.
  ///
  /// In de, this message translates to:
  /// **'Übertragen: Statistik, Rekorde und Trainings laufen unter „{to}“ weiter, auch in anderen Workouts. Neue Übung: „{to}“ beginnt ohne Verlauf, „{from}“ bleibt im Verlauf, wie es war.'**
  String transferHint(Object to, Object from);

  /// No description provided for @newExercise.
  ///
  /// In de, this message translates to:
  /// **'Neue Übung'**
  String get newExercise;

  /// No description provided for @transfer.
  ///
  /// In de, this message translates to:
  /// **'Übertragen'**
  String get transfer;

  /// No description provided for @set.
  ///
  /// In de, this message translates to:
  /// **'Satz'**
  String get set;

  /// No description provided for @setOf.
  ///
  /// In de, this message translates to:
  /// **'Satz {n} von {total}'**
  String setOf(Object n, Object total);

  /// No description provided for @seconds.
  ///
  /// In de, this message translates to:
  /// **'Sekunden'**
  String get seconds;

  /// No description provided for @secondsAtLeast.
  ///
  /// In de, this message translates to:
  /// **'Sekunden mindestens'**
  String get secondsAtLeast;

  /// No description provided for @reps.
  ///
  /// In de, this message translates to:
  /// **'Wiederholungen'**
  String get reps;

  /// No description provided for @repsAtLeast.
  ///
  /// In de, this message translates to:
  /// **'Wdh. mindestens'**
  String get repsAtLeast;

  /// No description provided for @weightIn.
  ///
  /// In de, this message translates to:
  /// **'Gewicht ({unit})'**
  String weightIn(Object unit);

  /// No description provided for @assistHint.
  ///
  /// In de, this message translates to:
  /// **'Unter 0: Unterstützung, z. B. am Klimmzug-Gerät. Steigern heißt weniger Hilfe, Richtung 0.'**
  String get assistHint;

  /// No description provided for @thisSet.
  ///
  /// In de, this message translates to:
  /// **'Dieser Satz'**
  String get thisSet;

  /// No description provided for @allSets.
  ///
  /// In de, this message translates to:
  /// **'Alle Sätze'**
  String get allSets;

  /// No description provided for @deleteSet.
  ///
  /// In de, this message translates to:
  /// **'Satz löschen'**
  String get deleteSet;

  /// No description provided for @close.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get close;

  /// No description provided for @muscles.
  ///
  /// In de, this message translates to:
  /// **'Muskeln'**
  String get muscles;

  /// No description provided for @unknownExercise.
  ///
  /// In de, this message translates to:
  /// **'Unbekannte Übung: Ohne Muskeln fehlt sie in Balance und Muskelkarte. Bitte antippen, was sie trainiert.'**
  String get unknownExercise;

  /// No description provided for @musclesHint.
  ///
  /// In de, this message translates to:
  /// **'Antippen: Hauptmuskel ✓ → hilft mit ½ → aus. Für die Statistik.'**
  String get musclesHint;

  /// No description provided for @addExercise.
  ///
  /// In de, this message translates to:
  /// **'Übung hinzufügen'**
  String get addExercise;

  /// No description provided for @editExercise.
  ///
  /// In de, this message translates to:
  /// **'Übung bearbeiten'**
  String get editExercise;

  /// No description provided for @add.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get add;

  /// No description provided for @searchExercise.
  ///
  /// In de, this message translates to:
  /// **'Übung suchen oder eigene eingeben'**
  String get searchExercise;

  /// No description provided for @duplicateExercise.
  ///
  /// In de, this message translates to:
  /// **'Steht schon in diesem Workout. Für mehr Sätze oder andere Gewichte pro Satz die vorhandene bearbeiten.'**
  String get duplicateExercise;

  /// No description provided for @noMatch.
  ///
  /// In de, this message translates to:
  /// **'Kein Treffer – eigener Name wird übernommen'**
  String get noMatch;

  /// No description provided for @defaultsFrom.
  ///
  /// In de, this message translates to:
  /// **'Standardwerte für {name} übernommen'**
  String defaultsFrom(Object name);

  /// No description provided for @strength.
  ///
  /// In de, this message translates to:
  /// **'Kraft'**
  String get strength;

  /// No description provided for @cardio.
  ///
  /// In de, this message translates to:
  /// **'Cardio'**
  String get cardio;

  /// No description provided for @durationGoal.
  ///
  /// In de, this message translates to:
  /// **'Dauer'**
  String get durationGoal;

  /// No description provided for @distance.
  ///
  /// In de, this message translates to:
  /// **'Distanz'**
  String get distance;

  /// No description provided for @goalIn.
  ///
  /// In de, this message translates to:
  /// **'Ziel ({unit})'**
  String goalIn(Object unit);

  /// No description provided for @goalMinutes.
  ///
  /// In de, this message translates to:
  /// **'Ziel (Min)'**
  String get goalMinutes;

  /// No description provided for @withWeight.
  ///
  /// In de, this message translates to:
  /// **'Mit Gewicht'**
  String get withWeight;

  /// No description provided for @withoutWeight.
  ///
  /// In de, this message translates to:
  /// **'Ohne Gewicht'**
  String get withoutWeight;

  /// No description provided for @time.
  ///
  /// In de, this message translates to:
  /// **'Zeit'**
  String get time;

  /// No description provided for @sets.
  ///
  /// In de, this message translates to:
  /// **'Sätze'**
  String get sets;

  /// No description provided for @tapSetToChange.
  ///
  /// In de, this message translates to:
  /// **'Satz antippen zum Ändern'**
  String get tapSetToChange;

  /// No description provided for @thisTrainingTap.
  ///
  /// In de, this message translates to:
  /// **'Dieses Training · antippen zum Ändern'**
  String get thisTrainingTap;

  /// No description provided for @nextTrainingTap.
  ///
  /// In de, this message translates to:
  /// **'Nächstes Training · antippen zum Ändern'**
  String get nextTrainingTap;

  /// No description provided for @timeRange.
  ///
  /// In de, this message translates to:
  /// **'Zeit-Spanne'**
  String get timeRange;

  /// No description provided for @repRange.
  ///
  /// In de, this message translates to:
  /// **'Wiederholungs-Spanne'**
  String get repRange;

  /// No description provided for @rangeOffTime.
  ///
  /// In de, this message translates to:
  /// **'Aus · feste Zeit'**
  String get rangeOffTime;

  /// No description provided for @rangeOffReps.
  ///
  /// In de, this message translates to:
  /// **'Aus · feste Wiederholungen'**
  String get rangeOffReps;

  /// No description provided for @rangeOnSeconds.
  ///
  /// In de, this message translates to:
  /// **'{sets} · Gewicht steigt erst, wenn alle Sätze {top} s schaffen'**
  String rangeOnSeconds(Object sets, Object top);

  /// No description provided for @rangeOnReps.
  ///
  /// In de, this message translates to:
  /// **'{sets} · Gewicht steigt erst, wenn alle Sätze {top} Wdh. schaffen'**
  String rangeOnReps(Object sets, Object top);

  /// No description provided for @upToSeconds.
  ///
  /// In de, this message translates to:
  /// **'Bis Sekunden'**
  String get upToSeconds;

  /// No description provided for @upToReps.
  ///
  /// In de, this message translates to:
  /// **'Bis Wiederholungen'**
  String get upToReps;

  /// No description provided for @rest.
  ///
  /// In de, this message translates to:
  /// **'Pause'**
  String get rest;

  /// No description provided for @minSecOrSec.
  ///
  /// In de, this message translates to:
  /// **'min:s oder s'**
  String get minSecOrSec;

  /// No description provided for @afterMissedSet.
  ///
  /// In de, this message translates to:
  /// **'Nach nicht geschafftem Satz'**
  String get afterMissedSet;

  /// No description provided for @sameAsAbove.
  ///
  /// In de, this message translates to:
  /// **'Wie oben'**
  String get sameAsAbove;

  /// No description provided for @adjustWeight.
  ///
  /// In de, this message translates to:
  /// **'Gewicht anpassen'**
  String get adjustWeight;

  /// No description provided for @automatic.
  ///
  /// In de, this message translates to:
  /// **'Automatisch'**
  String get automatic;

  /// No description provided for @fixed.
  ///
  /// In de, this message translates to:
  /// **'Fest'**
  String get fixed;

  /// No description provided for @loadStep.
  ///
  /// In de, this message translates to:
  /// **'Ladestufe'**
  String get loadStep;

  /// No description provided for @increaseOnSuccess.
  ///
  /// In de, this message translates to:
  /// **'Steigerung bei Erfolg'**
  String get increaseOnSuccess;

  /// No description provided for @increaseOn.
  ///
  /// In de, this message translates to:
  /// **'+{weight}, wenn alle Sätze geschafft'**
  String increaseOn(Object weight);

  /// No description provided for @offWeightStays.
  ///
  /// In de, this message translates to:
  /// **'Aus · Gewicht bleibt gleich'**
  String get offWeightStays;

  /// No description provided for @decreaseOnMiss.
  ///
  /// In de, this message translates to:
  /// **'Senkung bei Misserfolg'**
  String get decreaseOnMiss;

  /// No description provided for @decreaseOn.
  ///
  /// In de, this message translates to:
  /// **'−{weight} nach {n}× nicht geschafft'**
  String decreaseOn(Object weight, Object n);

  /// No description provided for @decreaseAfter.
  ///
  /// In de, this message translates to:
  /// **'Senken nach Fehlversuchen in Folge'**
  String get decreaseAfter;

  /// No description provided for @summaryCardio.
  ///
  /// In de, this message translates to:
  /// **'{name}: Ziel {goal}. Im Training startest du die Stoppuhr mit einem Tipp.'**
  String summaryCardio(Object name, Object goal);

  /// No description provided for @planNoWeight.
  ///
  /// In de, this message translates to:
  /// **'{sets} ohne Gewicht'**
  String planNoWeight(Object sets);

  /// No description provided for @planWithWeight.
  ///
  /// In de, this message translates to:
  /// **'{sets} mit {weight}'**
  String planWithWeight(Object sets, Object weight);

  /// No description provided for @summaryTraining.
  ///
  /// In de, this message translates to:
  /// **'{name}: {plan}. Nur für dieses Training, der Plan bleibt, wie er ist.'**
  String summaryTraining(Object name, Object plan);

  /// No description provided for @summaryPlain.
  ///
  /// In de, this message translates to:
  /// **'{name}: {plan}.'**
  String summaryPlain(Object name, Object plan);

  /// No description provided for @summaryAuto.
  ///
  /// In de, this message translates to:
  /// **'{name}: {plan}. Gewicht passt sich automatisch an.'**
  String summaryAuto(Object name, Object plan);

  /// No description provided for @summaryUp.
  ///
  /// In de, this message translates to:
  /// **'Bei Erfolg +{weight}.'**
  String summaryUp(Object weight);

  /// No description provided for @summaryDown.
  ///
  /// In de, this message translates to:
  /// **'Nach {n}× Misserfolg −{weight}.'**
  String summaryDown(Object n, Object weight);

  /// No description provided for @summaryFixed.
  ///
  /// In de, this message translates to:
  /// **'Gewicht wird nicht automatisch angepasst.'**
  String get summaryFixed;

  /// No description provided for @autoRuleDone.
  ///
  /// In de, this message translates to:
  /// **'Geschafft: etwa 2,5 % mehr, mit 3 oder mehr Wiederholungen Reserve doppelt, am Limit bleibt es (beim zweiten Mal in Folge ein halber Schritt).'**
  String get autoRuleDone;

  /// No description provided for @autoRuleBridge.
  ///
  /// In de, this message translates to:
  /// **'Ist der Schritt zu klein zum Laden, geht es erst über Wiederholungen.'**
  String get autoRuleBridge;

  /// No description provided for @autoRuleRange.
  ///
  /// In de, this message translates to:
  /// **'Erst wenn alle Sätze oben in der Spanne sind.'**
  String get autoRuleRange;

  /// No description provided for @autoRuleMiss.
  ///
  /// In de, this message translates to:
  /// **'Nicht geschafft: Gewicht bleibt, nach {n}× in Folge etwa −10 % und danach kleinere Schritte, die mit Reserve wieder wachsen.'**
  String autoRuleMiss(Object n);

  /// No description provided for @autoRuleBadDay.
  ///
  /// In de, this message translates to:
  /// **'Krank, schlecht geschlafen, Stress oder wenig gegessen zählen nicht (höchstens 2× in Folge), nach 2 Wochen Pause geht es leichter los. Die Reserve wird nach jeder Übung abgefragt.'**
  String get autoRuleBadDay;

  /// No description provided for @autoNow.
  ///
  /// In de, this message translates to:
  /// **'Gerade +{pct} % pro Training · Ladestufe {step} ({source})'**
  String autoNow(Object pct, Object step, Object source);

  /// No description provided for @sourcePlates.
  ///
  /// In de, this message translates to:
  /// **'deine Scheiben'**
  String get sourcePlates;

  /// No description provided for @sourceLearned.
  ///
  /// In de, this message translates to:
  /// **'aus deinen Gewichten'**
  String get sourceLearned;

  /// No description provided for @sourceGuess.
  ///
  /// In de, this message translates to:
  /// **'Startwert, lernt mit'**
  String get sourceGuess;

  /// No description provided for @sourceSet.
  ///
  /// In de, this message translates to:
  /// **'eingestellt'**
  String get sourceSet;

  /// No description provided for @own.
  ///
  /// In de, this message translates to:
  /// **'Eigene'**
  String get own;

  /// No description provided for @leftAbout.
  ///
  /// In de, this message translates to:
  /// **'noch {about}'**
  String leftAbout(Object about);

  /// No description provided for @doneAround.
  ///
  /// In de, this message translates to:
  /// **'fertig gegen {time}'**
  String doneAround(Object time);

  /// No description provided for @alreadyInTraining.
  ///
  /// In de, this message translates to:
  /// **'Schon im Training'**
  String get alreadyInTraining;

  /// No description provided for @kindStays.
  ///
  /// In de, this message translates to:
  /// **'Nach dem ersten Satz bleibt die Art, wie sie ist'**
  String get kindStays;

  /// No description provided for @moveUp.
  ///
  /// In de, this message translates to:
  /// **'Nach oben'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In de, this message translates to:
  /// **'Nach unten'**
  String get moveDown;

  /// No description provided for @remove.
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get remove;

  /// No description provided for @noSetsDiscard.
  ///
  /// In de, this message translates to:
  /// **'Keine Sätze geloggt. Training verwerfen?'**
  String get noSetsDiscard;

  /// No description provided for @notAllSetsFinish.
  ///
  /// In de, this message translates to:
  /// **'Nicht alle Sätze erledigt. Trotzdem beenden?'**
  String get notAllSetsFinish;

  /// No description provided for @discard.
  ///
  /// In de, this message translates to:
  /// **'Verwerfen'**
  String get discard;

  /// No description provided for @finish.
  ///
  /// In de, this message translates to:
  /// **'Beenden'**
  String get finish;

  /// No description provided for @stripPickUp.
  ///
  /// In de, this message translates to:
  /// **'AUFNEHMEN'**
  String get stripPickUp;

  /// No description provided for @stripHold.
  ///
  /// In de, this message translates to:
  /// **'HALTEN'**
  String get stripHold;

  /// No description provided for @holdGoal.
  ///
  /// In de, this message translates to:
  /// **'Ziel {goal} s'**
  String holdGoal(Object goal);

  /// No description provided for @stop.
  ///
  /// In de, this message translates to:
  /// **'Stopp'**
  String get stop;

  /// No description provided for @pause.
  ///
  /// In de, this message translates to:
  /// **'Anhalten'**
  String get pause;

  /// No description provided for @resumeRest.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get resumeRest;

  /// No description provided for @restart.
  ///
  /// In de, this message translates to:
  /// **'Neu starten'**
  String get restart;

  /// No description provided for @restOf.
  ///
  /// In de, this message translates to:
  /// **'von {time}'**
  String restOf(Object time);

  /// No description provided for @restGoal.
  ///
  /// In de, this message translates to:
  /// **'Ziel {time}'**
  String restGoal(Object time);

  /// No description provided for @stripPaused.
  ///
  /// In de, this message translates to:
  /// **'ANGEHALTEN'**
  String get stripPaused;

  /// No description provided for @stripRest.
  ///
  /// In de, this message translates to:
  /// **'PAUSE'**
  String get stripRest;

  /// No description provided for @stripSoon.
  ///
  /// In de, this message translates to:
  /// **'GLEICH WEITER'**
  String get stripSoon;

  /// No description provided for @stripGo.
  ///
  /// In de, this message translates to:
  /// **'LOS'**
  String get stripGo;

  /// No description provided for @stripLate.
  ///
  /// In de, this message translates to:
  /// **'ÜBERZOGEN'**
  String get stripLate;

  /// No description provided for @rirQuestion.
  ///
  /// In de, this message translates to:
  /// **'Wie viele gingen noch?'**
  String get rirQuestion;

  /// No description provided for @restLine.
  ///
  /// In de, this message translates to:
  /// **'Pause {time}'**
  String restLine(Object time);

  /// No description provided for @now.
  ///
  /// In de, this message translates to:
  /// **'JETZT'**
  String get now;

  /// No description provided for @warmup.
  ///
  /// In de, this message translates to:
  /// **'Aufwärmen: {sets}'**
  String warmup(Object sets);

  /// No description provided for @startStopwatch.
  ///
  /// In de, this message translates to:
  /// **' Start'**
  String get startStopwatch;

  /// No description provided for @enterDistance.
  ///
  /// In de, this message translates to:
  /// **'Distanz eintragen'**
  String get enterDistance;

  /// No description provided for @rangeDone.
  ///
  /// In de, this message translates to:
  /// **'{goal} geschafft · nächstes Mal schwerer'**
  String rangeDone(Object goal);

  /// No description provided for @rangeIncreaseAt.
  ///
  /// In de, this message translates to:
  /// **'Steigerung bei {goal}'**
  String rangeIncreaseAt(Object goal);

  /// No description provided for @rangeAllTop.
  ///
  /// In de, this message translates to:
  /// **'Steigerung bei {goal} · bisher alle oben'**
  String rangeAllTop(Object goal);

  /// No description provided for @rangeMissingReps.
  ///
  /// In de, this message translates to:
  /// **'Steigerung bei {goal} · noch {n} Wdh.'**
  String rangeMissingReps(Object goal, Object n);

  /// No description provided for @rangeMissingSeconds.
  ///
  /// In de, this message translates to:
  /// **'Steigerung bei {goal} · noch {n} s'**
  String rangeMissingSeconds(Object goal, Object n);

  /// No description provided for @weightBetween.
  ///
  /// In de, this message translates to:
  /// **'Gewicht zwischen {min} und {max}'**
  String weightBetween(Object min, Object max);

  /// No description provided for @applyTo.
  ///
  /// In de, this message translates to:
  /// **'Übernehmen für'**
  String get applyTo;

  /// No description provided for @openSets.
  ///
  /// In de, this message translates to:
  /// **'Offene Sätze'**
  String get openSets;

  /// No description provided for @minutesUnit.
  ///
  /// In de, this message translates to:
  /// **'Min'**
  String get minutesUnit;

  /// No description provided for @distanceOptional.
  ///
  /// In de, this message translates to:
  /// **'Distanz (optional)'**
  String get distanceOptional;

  /// No description provided for @hintsCount.
  ///
  /// In de, this message translates to:
  /// **'{n, plural, =1{1 Hinweis} other{{n} Hinweise}}'**
  String hintsCount(int n);

  /// No description provided for @pairsBalanced.
  ///
  /// In de, this message translates to:
  /// **'  · {ok} von {total} ausgewogen'**
  String pairsBalanced(Object ok, Object total);

  /// No description provided for @allPairsBalanced.
  ///
  /// In de, this message translates to:
  /// **'Alle Muskelpaare ausgewogen'**
  String get allPairsBalanced;

  /// No description provided for @balanceScaleHint.
  ///
  /// In de, this message translates to:
  /// **'Der Punkt zeigt zur Seite mit mehr Sätzen. Im hellen Feld ist es ausgewogen. Tippe auf ein Paar für Empfehlung und Zahlen.'**
  String get balanceScaleHint;

  /// No description provided for @strengthTrend.
  ///
  /// In de, this message translates to:
  /// **'Kraft im Verlauf'**
  String get strengthTrend;

  /// No description provided for @trendUp.
  ///
  /// In de, this message translates to:
  /// **'↗ steigt'**
  String get trendUp;

  /// No description provided for @trendDown.
  ///
  /// In de, this message translates to:
  /// **'↘ sinkt'**
  String get trendDown;

  /// No description provided for @trendFlat.
  ///
  /// In de, this message translates to:
  /// **'→ stabil'**
  String get trendFlat;

  /// No description provided for @strengthTrendHint.
  ///
  /// In de, this message translates to:
  /// **'Verhältnis aus dem geschätzten 1RM über 90 Tage. Zeigt deine Entwicklung, keinen Vergleich mit Literaturwerten.'**
  String get strengthTrendHint;

  /// No description provided for @balanceDetail.
  ///
  /// In de, this message translates to:
  /// **'{a} {aSets} · {b} {bSets} Sätze pro Woche{note}. {group} bei {ratio}, Richtwert {range}.'**
  String balanceDetail(
    Object a,
    Object aSets,
    Object b,
    Object bSets,
    Object note,
    Object group,
    Object ratio,
    Object range,
  );

  /// No description provided for @balanced.
  ///
  /// In de, this message translates to:
  /// **'✓ Ausgewogen'**
  String get balanced;

  /// No description provided for @verdictSlightly.
  ///
  /// In de, this message translates to:
  /// **'{strong} etwas mehr trainiert als {weak}'**
  String verdictSlightly(Object strong, Object weak);

  /// No description provided for @verdictClearly.
  ///
  /// In de, this message translates to:
  /// **'{strong} deutlich mehr trainiert als {weak}'**
  String verdictClearly(Object strong, Object weak);

  /// No description provided for @balanceInfoTitle.
  ///
  /// In de, this message translates to:
  /// **'Balance: was dahintersteckt'**
  String get balanceInfoTitle;

  /// No description provided for @infoProven.
  ///
  /// In de, this message translates to:
  /// **'Was belegt ist'**
  String get infoProven;

  /// No description provided for @infoProven1.
  ///
  /// In de, this message translates to:
  /// **'Mehr Sätze pro Muskel und Woche bringen mehr Muskelwachstum, abgestuft nach unter 5, 5–9 und 10+ Sätzen [1].'**
  String get infoProven1;

  /// No description provided for @infoProven2.
  ///
  /// In de, this message translates to:
  /// **'Hilfsmuskeln anteilig zu zählen bildet das Volumen genauer ab: 5 Sätze Curls und 5 Sätze Rudern ergeben 7,5 Bizeps-Sätze [2].'**
  String get infoProven2;

  /// No description provided for @infoUncertain.
  ///
  /// In de, this message translates to:
  /// **'Was unsicher ist'**
  String get infoUncertain;

  /// No description provided for @infoUncertain1.
  ///
  /// In de, this message translates to:
  /// **'Ob Ungleichgewichte zwischen Drücken und Ziehen das Verletzungsrisiko erhöhen, ist nicht untersucht.'**
  String get infoUncertain1;

  /// No description provided for @infoUncertain2.
  ///
  /// In de, this message translates to:
  /// **'Für das Verhältnis Beinbeuger zu Quadrizeps gibt es nur sehr begrenzte Evidenz als Risikofaktor [3].'**
  String get infoUncertain2;

  /// No description provided for @infoUncertain3.
  ///
  /// In de, this message translates to:
  /// **'Deshalb zeigt FerroLog Hinweise, keine Warnungen.'**
  String get infoUncertain3;

  /// No description provided for @infoGuides.
  ///
  /// In de, this message translates to:
  /// **'Woher die Richtwerte kommen'**
  String get infoGuides;

  /// No description provided for @infoGuides1.
  ///
  /// In de, this message translates to:
  /// **'Drücken : Ziehen 1:1 bis 1:1,5 ist eine Trainerempfehlung, kein Studienwert. Regeln wie 2:1 oder 3:1 sind Faustregeln [4].'**
  String get infoGuides1;

  /// No description provided for @infoGuides2.
  ///
  /// In de, this message translates to:
  /// **'Beinbeuger ab 60 % lehnt sich an Labormessungen an (H:Q > 0,6) [5]. Die stammen aus der Isokinetik und lassen sich nicht direkt auf Kniebeuge und Kreuzheben übertragen.'**
  String get infoGuides2;

  /// No description provided for @infoGuides3.
  ///
  /// In de, this message translates to:
  /// **'Freizeitsportler drücken in Tests 1,5- bis 2,7-mal so viel, wie sie ziehen [6].'**
  String get infoGuides3;

  /// No description provided for @infoGuides4.
  ///
  /// In de, this message translates to:
  /// **'Bei der Schulter liegt die Außenrotation in Kraftmessungen bei 86–99 % der Innenrotation [7]. Für Sätze gibt es keinen Studienwert, der Richtwert ist bewusst niedrig angesetzt.'**
  String get infoGuides4;

  /// No description provided for @infoGuides5.
  ///
  /// In de, this message translates to:
  /// **'Bei Bauch und unterem Rücken widersprechen sich die Studien, welche Seite bei Rückenschmerzen schwächer ist [8, 9]. Der Richtwert ist deshalb breit und symmetrisch.'**
  String get infoGuides5;

  /// No description provided for @infoMath.
  ///
  /// In de, this message translates to:
  /// **'Wie FerroLog rechnet'**
  String get infoMath;

  /// No description provided for @infoMath1.
  ///
  /// In de, this message translates to:
  /// **'Jede Übung zählt voll für ihre Hauptgruppe und halb für Hilfsmuskeln.'**
  String get infoMath1;

  /// No description provided for @infoMath2.
  ///
  /// In de, this message translates to:
  /// **'Sätze pro Woche, gemittelt über die letzten 28 Tage, je Paar als Verhältnis.'**
  String get infoMath2;

  /// No description provided for @infoMath3.
  ///
  /// In de, this message translates to:
  /// **'Kraftverhältnisse (geschätztes 1RM) nur als Verlauf, nicht gegen Literaturwerte.'**
  String get infoMath3;

  /// No description provided for @infoMath4.
  ///
  /// In de, this message translates to:
  /// **'Alle Richtwerte kannst du anpassen.'**
  String get infoMath4;

  /// No description provided for @infoScale.
  ///
  /// In de, this message translates to:
  /// **'So liest du die Waage'**
  String get infoScale;

  /// No description provided for @infoScale1.
  ///
  /// In de, this message translates to:
  /// **'Der Punkt zeigt zur Seite, die mehr Sätze bekommt. Im hellen Feld in der Mitte liegt das Paar im Richtwert.'**
  String get infoScale1;

  /// No description provided for @infoScale2.
  ///
  /// In de, this message translates to:
  /// **'Der Richtwert stammt aus der Trainingspraxis und ist keine medizinische Grenze. Hilfsmuskeln zählen halb.'**
  String get infoScale2;

  /// No description provided for @adjustGuides.
  ///
  /// In de, this message translates to:
  /// **'Richtwerte anpassen'**
  String get adjustGuides;

  /// No description provided for @sources.
  ///
  /// In de, this message translates to:
  /// **'QUELLEN'**
  String get sources;

  /// No description provided for @guides.
  ///
  /// In de, this message translates to:
  /// **'Richtwerte'**
  String get guides;

  /// No description provided for @guidesHint.
  ///
  /// In de, this message translates to:
  /// **'Seite rechts im Verhältnis zur Seite links, in Prozent der Sätze.'**
  String get guidesHint;

  /// No description provided for @resetDefaults.
  ///
  /// In de, this message translates to:
  /// **'Auf Standard zurücksetzen'**
  String get resetDefaults;

  /// No description provided for @sourceShoulderNorms.
  ///
  /// In de, this message translates to:
  /// **'Handdynamometer-Normwerte, Schulterrotation'**
  String get sourceShoulderNorms;

  /// No description provided for @sourceTrunk.
  ///
  /// In de, this message translates to:
  /// **'Rumpf-Ausdauer Flexion/Extension (MMU)'**
  String get sourceTrunk;

  /// No description provided for @piNoJson.
  ///
  /// In de, this message translates to:
  /// **'Kein JSON gefunden. Kopier den ganzen Codeblock aus dem Chat.'**
  String get piNoJson;

  /// No description provided for @piBrokenJson.
  ///
  /// In de, this message translates to:
  /// **'Das JSON ist unvollständig oder fehlerhaft: {error}'**
  String piBrokenJson(Object error);

  /// No description provided for @piIsExport.
  ///
  /// In de, this message translates to:
  /// **'Das ist ein Export mit allen Daten, kein Plan. Nimm den JSON-Block aus der Antwort der KI.'**
  String get piIsExport;

  /// No description provided for @piNotPlan.
  ///
  /// In de, this message translates to:
  /// **'Das ist kein FerroLog-Plan (app \"ferrolog\", kind \"plan\" fehlt).'**
  String get piNotPlan;

  /// No description provided for @piVersion.
  ///
  /// In de, this message translates to:
  /// **'Version {v} kennt diese App nicht.'**
  String piVersion(Object v);

  /// No description provided for @piNoWorkouts.
  ///
  /// In de, this message translates to:
  /// **'Der Plan enthält keine Workouts.'**
  String get piNoWorkouts;

  /// No description provided for @piWorkoutNotObject.
  ///
  /// In de, this message translates to:
  /// **'Workout {n} ist kein Objekt.'**
  String piWorkoutNotObject(Object n);

  /// No description provided for @piWorkoutTwice.
  ///
  /// In de, this message translates to:
  /// **'Workout {id} steht zweimal im Plan.'**
  String piWorkoutTwice(Object id);

  /// No description provided for @piDeleteMissing.
  ///
  /// In de, this message translates to:
  /// **'Das Workout zum Löschen ({name}) gibt es nicht.'**
  String piDeleteMissing(Object name);

  /// No description provided for @piWorkoutNoName.
  ///
  /// In de, this message translates to:
  /// **'Workout {n} hat keinen Namen.'**
  String piWorkoutNoName(Object n);

  /// No description provided for @piNoExercises.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ hat keine Übungen.'**
  String piNoExercises(Object name);

  /// No description provided for @piExerciseWhere.
  ///
  /// In de, this message translates to:
  /// **'„{name}“, Übung {n}'**
  String piExerciseWhere(Object name, Object n);

  /// No description provided for @piExerciseTwice.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ hat „{exercise}“ zweimal. Mehr Sätze oder setWeights statt einer zweiten Übung.'**
  String piExerciseTwice(Object name, Object exercise);

  /// No description provided for @piNotObject.
  ///
  /// In de, this message translates to:
  /// **'{where} ist kein Objekt.'**
  String piNotObject(Object where);

  /// No description provided for @piNoName.
  ///
  /// In de, this message translates to:
  /// **'{where} hat keinen Namen.'**
  String piNoName(Object where);

  /// No description provided for @piQuoted.
  ///
  /// In de, this message translates to:
  /// **'„{name}“'**
  String piQuoted(Object name);

  /// No description provided for @piNotInt.
  ///
  /// In de, this message translates to:
  /// **'{label}: \"{key}\" fehlt oder ist keine ganze Zahl.'**
  String piNotInt(Object label, Object key);

  /// No description provided for @piNoWeight.
  ///
  /// In de, this message translates to:
  /// **'{label}: \"weight\" fehlt.'**
  String piNoWeight(Object label);

  /// No description provided for @piBadType.
  ///
  /// In de, this message translates to:
  /// **'{label}: Art \"{type}\" gibt es nicht.'**
  String piBadType(Object label, Object type);

  /// No description provided for @piBadSets.
  ///
  /// In de, this message translates to:
  /// **'{label}: Sätze oder Wiederholungen ungültig.'**
  String piBadSets(Object label);

  /// No description provided for @piSetWeights.
  ///
  /// In de, this message translates to:
  /// **'{label}: setWeights passt nicht zu {n} Sätzen.'**
  String piSetWeights(Object label, Object n);

  /// No description provided for @piSetReps.
  ///
  /// In de, this message translates to:
  /// **'{label}: setReps passt nicht zu {n} Sätzen.'**
  String piSetReps(Object label, Object n);

  /// No description provided for @piMaxReps.
  ///
  /// In de, this message translates to:
  /// **'{label}: maxReps muss über reps liegen.'**
  String piMaxReps(Object label);

  /// No description provided for @piMinWeight.
  ///
  /// In de, this message translates to:
  /// **'{label}: Gewicht unter {min} kg.'**
  String piMinWeight(Object label, Object min);

  /// No description provided for @piBadMuscle.
  ///
  /// In de, this message translates to:
  /// **'{label}: Muskel \"{muscle}\" gibt es nicht.'**
  String piBadMuscle(Object label, Object muscle);

  /// No description provided for @aspectName.
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get aspectName;

  /// No description provided for @aspectKind.
  ///
  /// In de, this message translates to:
  /// **'Art'**
  String get aspectKind;

  /// No description provided for @aspectWeight.
  ///
  /// In de, this message translates to:
  /// **'Gewicht'**
  String get aspectWeight;

  /// No description provided for @aspectIncrease.
  ///
  /// In de, this message translates to:
  /// **'Steigerung'**
  String get aspectIncrease;

  /// No description provided for @aspectDeload.
  ///
  /// In de, this message translates to:
  /// **'Entlastung'**
  String get aspectDeload;

  /// No description provided for @off.
  ///
  /// In de, this message translates to:
  /// **'aus'**
  String get off;

  /// No description provided for @deloadAfter.
  ///
  /// In de, this message translates to:
  /// **'−{weight} nach {n} Fehlversuchen'**
  String deloadAfter(Object weight, Object n);

  /// No description provided for @restAfterMiss.
  ///
  /// In de, this message translates to:
  /// **'nach Fehlversuch {s} s'**
  String restAfterMiss(Object s);

  /// No description provided for @timedKind.
  ///
  /// In de, this message translates to:
  /// **'auf Zeit'**
  String get timedKind;

  /// No description provided for @noWeightShort.
  ///
  /// In de, this message translates to:
  /// **'ohne Gewicht'**
  String get noWeightShort;

  /// No description provided for @days30.
  ///
  /// In de, this message translates to:
  /// **'30 Tage'**
  String get days30;

  /// No description provided for @days90.
  ///
  /// In de, this message translates to:
  /// **'90 Tage'**
  String get days90;

  /// No description provided for @year1.
  ///
  /// In de, this message translates to:
  /// **'1 Jahr'**
  String get year1;

  /// No description provided for @allTime.
  ///
  /// In de, this message translates to:
  /// **'Gesamt'**
  String get allTime;

  /// No description provided for @statsEmpty.
  ///
  /// In de, this message translates to:
  /// **'Statistiken gibt’s nach dem ersten Training.'**
  String get statsEmpty;

  /// No description provided for @noTrainingInPeriod.
  ///
  /// In de, this message translates to:
  /// **'Kein Training in diesem Zeitraum.'**
  String get noTrainingInPeriod;

  /// No description provided for @background.
  ///
  /// In de, this message translates to:
  /// **'Hintergrund'**
  String get background;

  /// No description provided for @strengthProgress.
  ///
  /// In de, this message translates to:
  /// **'Kraftentwicklung'**
  String get strengthProgress;

  /// No description provided for @chartWeightHint.
  ///
  /// In de, this message translates to:
  /// **'Arbeitsgewicht, wie es die Progression vorgibt; Zacken nach unten sind Deloads. ▲ = Rückschritt.'**
  String get chartWeightHint;

  /// No description provided for @chartE1rmHint.
  ///
  /// In de, this message translates to:
  /// **'Veränderung des geschätzten 1RM (aus allen Sätzen) seit dem ersten Training im Zeitraum, der Baseline. ▲ = Rückschritt: weniger geschafft als zuletzt oder als schon einmal bei diesem Gewicht.'**
  String get chartE1rmHint;

  /// No description provided for @exercises.
  ///
  /// In de, this message translates to:
  /// **'Übungen'**
  String get exercises;

  /// No description provided for @statusLast4Weeks.
  ///
  /// In de, this message translates to:
  /// **'Status: letzte 4 Wochen'**
  String get statusLast4Weeks;

  /// No description provided for @exercisesCount.
  ///
  /// In de, this message translates to:
  /// **'{n, plural, =1{1 Übung} other{{n} Übungen}}'**
  String exercisesCount(int n);

  /// No description provided for @stuckCount.
  ///
  /// In de, this message translates to:
  /// **'{n, plural, =1{1 hängt fest} other{{n} hängen fest}}'**
  String stuckCount(int n);

  /// No description provided for @perWeek.
  ///
  /// In de, this message translates to:
  /// **'Pro Woche'**
  String get perWeek;

  /// No description provided for @goalWeeksHit.
  ///
  /// In de, this message translates to:
  /// **'Ziel {goal} · {hit} von {weeks} Wochen'**
  String goalWeeksHit(Object goal, Object hit, Object weeks);

  /// No description provided for @avgDuration.
  ///
  /// In de, this message translates to:
  /// **'Ø Dauer'**
  String get avgDuration;

  /// No description provided for @volumeVsBefore.
  ///
  /// In de, this message translates to:
  /// **'{delta} % zum Zeitraum davor'**
  String volumeVsBefore(Object delta);

  /// No description provided for @withRecord.
  ///
  /// In de, this message translates to:
  /// **'Mit Rekord'**
  String get withRecord;

  /// No description provided for @xOfY.
  ///
  /// In de, this message translates to:
  /// **'{x} von {y}'**
  String xOfY(Object x, Object y);

  /// No description provided for @noNewBest.
  ///
  /// In de, this message translates to:
  /// **'kein neues Höchstgewicht'**
  String get noNewBest;

  /// No description provided for @week.
  ///
  /// In de, this message translates to:
  /// **'Woche'**
  String get week;

  /// No description provided for @month.
  ///
  /// In de, this message translates to:
  /// **'Monat'**
  String get month;

  /// No description provided for @trainingsPerWeek.
  ///
  /// In de, this message translates to:
  /// **'Trainings pro Woche'**
  String get trainingsPerWeek;

  /// No description provided for @lineGoalWeek.
  ///
  /// In de, this message translates to:
  /// **'Linie: Ziel {goal}× pro Woche'**
  String lineGoalWeek(Object goal);

  /// No description provided for @lineGoalMonth.
  ///
  /// In de, this message translates to:
  /// **'Schnitt je Monat · Linie: Ziel {goal}× pro Woche'**
  String lineGoalMonth(Object goal);

  /// No description provided for @minutesPerTrainingAvg.
  ///
  /// In de, this message translates to:
  /// **'Minuten pro Training, Schnitt je {per} · Linie: Schnitt im Zeitraum'**
  String minutesPerTrainingAvg(Object per);

  /// No description provided for @tonnesPer.
  ///
  /// In de, this message translates to:
  /// **'Tonnen je {per}'**
  String tonnesPer(Object per);

  /// No description provided for @kLbPer.
  ///
  /// In de, this message translates to:
  /// **'Tausend lb je {per}'**
  String kLbPer(Object per);

  /// No description provided for @records.
  ///
  /// In de, this message translates to:
  /// **'Rekorde'**
  String get records;

  /// No description provided for @recordsPer.
  ///
  /// In de, this message translates to:
  /// **'Neue Höchstgewichte je {per}, über alle Übungen'**
  String recordsPer(Object per);

  /// No description provided for @balanceDaysLabel.
  ///
  /// In de, this message translates to:
  /// **'{n} Tage'**
  String balanceDaysLabel(Object n);

  /// No description provided for @setsPerMuscle.
  ///
  /// In de, this message translates to:
  /// **'Sätze je Muskel'**
  String get setsPerMuscle;

  /// No description provided for @perWeekLower.
  ///
  /// In de, this message translates to:
  /// **'pro Woche'**
  String get perWeekLower;

  /// No description provided for @notTrained.
  ///
  /// In de, this message translates to:
  /// **'Nicht trainiert: {names}'**
  String notTrained(Object names);

  /// No description provided for @musclesUnder10.
  ///
  /// In de, this message translates to:
  /// **'{n, plural, =1{1 Muskel unter 10 Sätzen} other{{n} Muskeln unter 10 Sätzen}}'**
  String musclesUnder10(int n);

  /// No description provided for @tapMuscle.
  ///
  /// In de, this message translates to:
  /// **'Tippe auf einen Muskel für seine Übungen'**
  String get tapMuscle;

  /// No description provided for @under5.
  ///
  /// In de, this message translates to:
  /// **'unter 5'**
  String get under5;

  /// No description provided for @over20.
  ///
  /// In de, this message translates to:
  /// **'über 20'**
  String get over20;

  /// No description provided for @muscleBarsHint.
  ///
  /// In de, this message translates to:
  /// **'Balken: Sätze pro Woche. Band 10–20: der übliche Bereich für Muskelaufbau. Orange: unter 10.'**
  String get muscleBarsHint;

  /// No description provided for @musclesNote.
  ///
  /// In de, this message translates to:
  /// **'Kraftprogramme wie 5×5 lassen bewusst Muskeln aus. Hilfsmuskeln zählen halb.'**
  String get musclesNote;

  /// No description provided for @setsPerWeek.
  ///
  /// In de, this message translates to:
  /// **'{n} Sätze pro Woche'**
  String setsPerWeek(Object n);

  /// No description provided for @noExerciseForMuscle.
  ///
  /// In de, this message translates to:
  /// **'Keine Übung im Zeitraum trainiert diesen Muskel.'**
  String get noExerciseForMuscle;

  /// No description provided for @setsN.
  ///
  /// In de, this message translates to:
  /// **'{n} Sätze'**
  String setsN(Object n);

  /// No description provided for @cardioPerWeek.
  ///
  /// In de, this message translates to:
  /// **'Cardio pro Woche'**
  String get cardioPerWeek;

  /// No description provided for @minutesTitle.
  ///
  /// In de, this message translates to:
  /// **'Minuten'**
  String get minutesTitle;

  /// No description provided for @avgMinPerWeek.
  ///
  /// In de, this message translates to:
  /// **'Ø {n} Min pro Woche'**
  String avgMinPerWeek(Object n);

  /// No description provided for @lineCardioTotal.
  ///
  /// In de, this message translates to:
  /// **'{n} · {cardio} gesamt'**
  String lineCardioTotal(Object n, Object cardio);

  /// No description provided for @lineSets.
  ///
  /// In de, this message translates to:
  /// **'{n} · {sets}'**
  String lineSets(Object n, Object sets);

  /// No description provided for @lineSetsUpTo.
  ///
  /// In de, this message translates to:
  /// **'{n} · {sets} · bis {weight}'**
  String lineSetsUpTo(Object n, Object sets, Object weight);

  /// No description provided for @lineSetsLast.
  ///
  /// In de, this message translates to:
  /// **'{n} · {sets} · zuletzt {weight}'**
  String lineSetsLast(Object n, Object sets, Object weight);

  /// No description provided for @lineVolume.
  ///
  /// In de, this message translates to:
  /// **'{n} · Gesamt {volume}'**
  String lineVolume(Object n, Object volume);

  /// No description provided for @trendNew.
  ///
  /// In de, this message translates to:
  /// **'neu'**
  String get trendNew;

  /// No description provided for @trendRising.
  ///
  /// In de, this message translates to:
  /// **'steigt'**
  String get trendRising;

  /// No description provided for @trendSteady.
  ///
  /// In de, this message translates to:
  /// **'stabil'**
  String get trendSteady;

  /// No description provided for @trendStuck.
  ///
  /// In de, this message translates to:
  /// **'hängt fest'**
  String get trendStuck;

  /// No description provided for @mergeWith.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ zusammenführen mit'**
  String mergeWith(Object name);

  /// No description provided for @noOtherExercise.
  ///
  /// In de, this message translates to:
  /// **'Keine andere Übung mit Verlauf.'**
  String get noOtherExercise;

  /// No description provided for @mergeAsk.
  ///
  /// In de, this message translates to:
  /// **'Alle Trainings von „{name}“ heißen danach „{target}“, auch in den Workouts. Das lässt sich nicht rückgängig machen.'**
  String mergeAsk(Object name, Object target);

  /// No description provided for @mergeMenu.
  ///
  /// In de, this message translates to:
  /// **'Mit anderer Übung zusammenführen'**
  String get mergeMenu;

  /// No description provided for @skippedOn.
  ///
  /// In de, this message translates to:
  /// **'Ausgelassen am {dates}'**
  String skippedOn(Object dates);

  /// No description provided for @weight.
  ///
  /// In de, this message translates to:
  /// **'Gewicht'**
  String get weight;

  /// No description provided for @bestE1rm.
  ///
  /// In de, this message translates to:
  /// **'Bestes 1RM {weight}'**
  String bestE1rm(Object weight);

  /// No description provided for @measureWeightHint.
  ///
  /// In de, this message translates to:
  /// **'Arbeitsgewicht ({unit}). ▲ = Rückschritt.'**
  String measureWeightHint(Object unit);

  /// No description provided for @measureE1rmHint.
  ///
  /// In de, this message translates to:
  /// **'Geschätztes 1RM aus allen Sätzen ({unit}). ▲ = Rückschritt.'**
  String measureE1rmHint(Object unit);

  /// No description provided for @measureVolumeHint.
  ///
  /// In de, this message translates to:
  /// **'Volumen: Gewicht × Wiederholungen ({unit}). ▲ = Rückschritt.'**
  String measureVolumeHint(Object unit);

  /// No description provided for @minutesPerTraining.
  ///
  /// In de, this message translates to:
  /// **'Minuten pro Training'**
  String get minutesPerTraining;

  /// No description provided for @cardioTotal.
  ///
  /// In de, this message translates to:
  /// **'Gesamt: {minutes} in {trainings}'**
  String cardioTotal(Object minutes, Object trainings);
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return L10nDe();
    case 'en':
      return L10nEn();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
