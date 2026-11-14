// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class L10nDe extends L10n {
  L10nDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'FerroLog';

  @override
  String get cancel => 'Abbrechen';

  @override
  String trainingsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Trainings',
      one: '1 Training',
    );
    return '$_temp0';
  }

  @override
  String syncNoFileYet(Object path) {
    return 'Auf GitHub liegt noch keine $path.';
  }

  @override
  String get syncRestored => 'Von GitHub wiederhergestellt';

  @override
  String syncOverwriteMore(Object theirs, Object ours) {
    return 'Auf GitHub liegen mehr Trainings ($theirs) als hier ($ours). Wirklich überschreiben? Der alte Stand bleibt nur in der Git-Historie des Repos.';
  }

  @override
  String get settingsTraining => 'Training';

  @override
  String get settingsSound => 'Ton';

  @override
  String get settingsSoundHint => 'Signalton, wenn die Pause bei 0 ankommt';

  @override
  String get settingsVibrate => 'Vibration';

  @override
  String get settingsVibrateHint =>
      'Kurz vibrieren, wenn die Pause bei 0 ankommt';

  @override
  String get settingsAutoFinish => 'Automatisch beenden';

  @override
  String get settingsAutoFinishHint =>
      'Nach 30 Min ohne Aktivität endet das Training beim letzten Satz';

  @override
  String get settingsKeepScreenOn => 'Bildschirm anlassen';

  @override
  String get settingsKeepScreenOnHint =>
      'Während des Trainings geht das Display nicht aus';

  @override
  String get settingsShowWhenLocked => 'Über dem Sperrbildschirm zeigen';

  @override
  String get settingsShowWhenLockedHint =>
      'Während des Trainings ohne Entsperren auf die Pause schauen';

  @override
  String get settingsAskRir => 'Reserve abfragen';

  @override
  String get settingsAskRirHint =>
      'Nach dem letzten Satz einer Übung: Wie viele Wiederholungen gingen noch? Hilft bei Plateaus. Übungen im Auto-Modus fragen immer';

  @override
  String get settingsLeadIn => 'Vorlauf bei Zeitübungen';

  @override
  String get settingsLeadInHint =>
      'Zeit zum Aufnehmen der Gewichte, bevor die Sekunden zählen';

  @override
  String get settingsHome => 'Startseite';

  @override
  String get settingsTasks => 'Hinweise zum Training';

  @override
  String get settingsTasksHint =>
      'Wenn die Statistik etwas findet: Ausgelassenes, Balance, Plateau, Wochenziel';

  @override
  String get settingsInsights => 'Erfolge';

  @override
  String get settingsInsightsHint =>
      'Rekorde, Fortschritt und Meilensteine des letzten Trainings';

  @override
  String get settingsStreak => 'Serie';

  @override
  String get settingsStreakHint =>
      'Trainings pro Woche, damit die Woche für deine Serie zählt';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String settingsLanguageSystem(Object name) {
    return 'System ($name)';
  }

  @override
  String get settingsUnit => 'Einheit';

  @override
  String settingsUnitAuto(Object unit) {
    return 'Automatisch ($unit)';
  }

  @override
  String get settingsUnitHint =>
      'Gespeichert wird immer in kg, Umrechnung nur für die Anzeige.';

  @override
  String get settingsBarbell => 'Hantel';

  @override
  String get settingsWarmup => 'Aufwärmsätze zeigen';

  @override
  String get settingsWarmupHint =>
      'Vor dem ersten Satz einer Langhantel-Übung: leere Stange, dann 50, 70 und 85 %';

  @override
  String get settingsBarPlatesHint =>
      'Stange und Scheiben für „Pro Seite“ beim Gewicht und für die Aufwärmsätze';

  @override
  String settingsBar(Object weight) {
    return 'Stange $weight';
  }

  @override
  String get settingsPlates => 'Scheiben';

  @override
  String get settingsData => 'Daten';

  @override
  String get settingsExport => 'An KI senden / exportieren';

  @override
  String get settingsExportHint =>
      'Alle Daten als JSON, der Analyse-Prompt kommt in die Zwischenablage';

  @override
  String get settingsExportDone =>
      'Prompt kopiert: im Chat einfügen, falls er fehlt';

  @override
  String get settingsRestore => 'Von GitHub wiederherstellen';

  @override
  String settingsRestoreHint(Object repo) {
    return 'Trainings und Pläne aus $repo holen, nach einer Neuinstallation oder vom anderen Gerät';
  }

  @override
  String get settingsRestoreNoSync => 'Erst unten GitHub-Sync einrichten';

  @override
  String get settingsPlanImport => 'Plan von KI übernehmen';

  @override
  String get settingsPlanImportHint =>
      'JSON-Block aus dem Chat einfügen, mit Vorschau vor dem Speichern';

  @override
  String get settingsCredits =>
      'Muskeln der Übungen: wger.de (CC-BY-SA), free-exercise-db · Körperkarte: react-native-body-highlighter (MIT) · Lizenzen';

  @override
  String get syncTitle => 'GitHub-Sync';

  @override
  String get syncIntro =>
      'FerroLog speichert deine Trainingsdaten als ferrolog.json in einem privaten GitHub-Repo. Dort kann deine KI sie lesen. FerroLog bekommt nur Zugriff auf diese eine Datei in dem Repo, das du freigibst.';

  @override
  String get syncEnterCode =>
      'Gib diesen Code auf GitHub ein (ist schon kopiert):';

  @override
  String get syncThenBack => 'Danach einfach zurück in die App wechseln.';

  @override
  String get syncLogin => 'Mit GitHub anmelden';

  @override
  String get syncConnected => 'Mit GitHub verbunden';

  @override
  String get syncLogout => 'Abmelden';

  @override
  String get syncStepRepo => 'Daten-Repo anlegen';

  @override
  String get syncStepRepoHint =>
      'Privates Repo „ferrolog-data“ auf GitHub erstellen';

  @override
  String get syncRepoDescription => 'FerroLog+Trainingsdaten';

  @override
  String get syncStepAccess => 'FerroLog Zugriff geben';

  @override
  String get syncStepAccessHint =>
      '„Only select repositories“ → ferrolog-data wählen';

  @override
  String get syncFindsRepo =>
      'Danach zurück in die App wechseln, FerroLog findet das Repo dann selbst.';

  @override
  String sync404(Object slug) {
    return 'Zeigt GitHub beim Installieren eine 404? Dann Schritt 2 am PC öffnen: github.com/apps/$slug/installations/new';
  }

  @override
  String get syncRepo => 'Repo';

  @override
  String get syncPickRepo => 'Repo auswählen';

  @override
  String get syncAnotherRepo => 'Weiteres Repo freigeben';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get syncResolve => 'Konflikt lösen';

  @override
  String syncLastOn(Object count, Object date) {
    return '$count, letztes am $date';
  }

  @override
  String get syncDialogTitle => 'Daten auf GitHub';

  @override
  String syncDialogUnreadable(Object problem) {
    return 'Auf GitHub: nicht lesbar. $problem';
  }

  @override
  String syncDialogRemote(Object count) {
    return 'Auf GitHub: $count';
  }

  @override
  String syncDialogLocal(Object count) {
    return 'Auf diesem Gerät: $count';
  }

  @override
  String get syncDialogRestoreAll =>
      'Wiederherstellen holt Trainings und Pläne von GitHub.';

  @override
  String get syncDialogRestoreKeep =>
      'Wiederherstellen holt Trainings und Pläne von GitHub und behält die Trainings, die nur hier sind.';

  @override
  String get syncOverwrite => 'GitHub überschreiben';

  @override
  String get languageName => 'Deutsch';

  @override
  String get dateFormat => 'dd.MM.yyyy';

  @override
  String minutes(Object n) {
    return '$n Min';
  }

  @override
  String get navWorkouts => 'Workouts';

  @override
  String get navStats => 'Statistik';

  @override
  String get navHistory => 'Verlauf';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get noWorkoutsYet => 'Noch keine Workouts. Leg eins an.';

  @override
  String get workoutRunning => ' läuft · ';

  @override
  String get resume => 'Fortsetzen';

  @override
  String elapsedMinutes(Object n) {
    return '$n Min.';
  }

  @override
  String elapsedHours(Object time) {
    return '$time Std.';
  }

  @override
  String get restPaused => ' · Pause angehalten';

  @override
  String restLeft(Object time) {
    return ' · Pause $time';
  }

  @override
  String get workout => 'Workout';

  @override
  String get trainingRunning => 'Training läuft';

  @override
  String runningSince(Object name) {
    return '$name · seit ';
  }

  @override
  String get discardTraining => 'Training verwerfen';

  @override
  String get discardTrainingAsk =>
      'Training verwerfen? Nichts wird gespeichert.';

  @override
  String get resumeTraining => 'Training fortsetzen';

  @override
  String comebackLighter(Object pct) {
    return 'Nach der Pause $pct % leichter zum Einstieg';
  }

  @override
  String get setMuscles =>
      'Muskeln festlegen, sonst fehlt sie in der Statistik';

  @override
  String lastDone(Object when) {
    return 'zuletzt $when';
  }

  @override
  String get edit => 'Bearbeiten';

  @override
  String get start => 'Starten';

  @override
  String get running => 'LÄUFT';

  @override
  String setsDone(Object done, Object total) {
    return '$done/$total Sätze';
  }

  @override
  String weeksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Wochen',
      one: '1 Woche',
    );
    return '$_temp0';
  }

  @override
  String streakTooltip(Object weeks, Object goal) {
    return '$weeks in Folge mindestens $goal× trainiert';
  }

  @override
  String get today => 'heute';

  @override
  String get yesterday => 'gestern';

  @override
  String daysAgo(Object n) {
    return 'vor $n Tagen';
  }

  @override
  String get noTrainingsYet => 'Noch keine Trainings geloggt.';

  @override
  String streakGoal(Object goal) {
    return 'Ziel: $goal× pro Woche';
  }

  @override
  String streakWeeks(Object weeks, Object goal) {
    return '$weeks in Folge · $goal× pro Woche';
  }

  @override
  String streakWeekDone(Object done, Object goal) {
    return 'Diese Woche geschafft ($done/$goal). Weiter so!';
  }

  @override
  String streakWeekOpen(Object done, Object goal, Object left) {
    return 'Diese Woche $done/$goal · noch $left';
  }

  @override
  String streakWeekOpenKeep(Object done, Object goal, Object left) {
    return 'Diese Woche $done/$goal · noch $left, um die Serie zu halten';
  }

  @override
  String get todayButton => 'Heute';

  @override
  String get previousMonth => 'Voriger Monat';

  @override
  String get nextMonth => 'Nächster Monat';

  @override
  String trainingsInMonth(Object count, Object month) {
    return '$count im $month';
  }

  @override
  String get delete => 'Löschen';

  @override
  String deleteTrainingAsk(Object date) {
    return 'Training vom $date löschen?';
  }

  @override
  String get deleteTrainingMovesPlan =>
      ' Die Plan-Gewichte gehen auf den Stand davor zurück.';

  @override
  String get yes => 'Ja';

  @override
  String get secondsUnit => 's';

  @override
  String get progUp => 'geschafft';

  @override
  String get progUp2 => 'viel Reserve, doppelter Schritt';

  @override
  String get progHalf => '2× am Limit, halber Schritt';

  @override
  String get progLimit => 'am Limit, Gewicht bleibt';

  @override
  String progBridgeTo(Object reps, Object to) {
    return 'nächstes Mal $reps Wdh., bei $to mehr Gewicht';
  }

  @override
  String get progBridge => 'erst mehr Wiederholungen';

  @override
  String get progRange => 'erst alle Wiederholungen';

  @override
  String get progMiss => 'nicht geschafft';

  @override
  String get progReset => '2× nicht geschafft, Wiederholungen zurück';

  @override
  String get progBadDay => 'schlechter Tag, zählt nicht';

  @override
  String get progPain =>
      'Schmerzen: Gewicht bleibt. Kommt es wieder, lass die Übung prüfen.';

  @override
  String progDeload(Object fails) {
    return '$fails× nicht geschafft, etwa −10 %, kleinere Schritte';
  }

  @override
  String get progLighter => 'leichter gemacht';

  @override
  String get progFewer => 'weniger Sätze';

  @override
  String get tagSleptBadly => 'Schlecht geschlafen';

  @override
  String get tagWellRested => 'Gut erholt';

  @override
  String get tagSore => 'Muskelkater';

  @override
  String get tagPain => 'Schmerzen';

  @override
  String get tagSick => 'Krank';

  @override
  String get tagStress => 'Stress';

  @override
  String get tagUnmotivated => 'Unmotiviert';

  @override
  String get tagEnergetic => 'Voller Energie';

  @override
  String get tagAteLittle => 'Wenig gegessen';

  @override
  String get tagAlcohol => 'Alkohol';

  @override
  String get tagCaffeine => 'Koffein';

  @override
  String get tagLittleTime => 'Wenig Zeit';

  @override
  String get tagGymBusy => 'Studio voll';

  @override
  String get tagTravelling => 'Unterwegs';

  @override
  String get tagTechnique => 'Technik-Fokus';

  @override
  String get fileNotFerrolog =>
      'Das ist keine FerroLog-Datei (app \"ferrolog\" fehlt).';

  @override
  String get fileNoVersion => 'Die Datei hat keine gültige Version.';

  @override
  String fileTooNew(Object version, Object known) {
    return 'Die Datei hat Version $version, diese App kennt nur bis $known. Bitte die App aktualisieren.';
  }

  @override
  String get fileNoData => 'Workouts oder Trainings fehlen in der Datei.';

  @override
  String fileBroken(Object error) {
    return 'Die Datei ist beschädigt: $error';
  }

  @override
  String get rirLimit => 'am Limit';

  @override
  String rirLeft(Object n) {
    return 'noch $n übrig';
  }

  @override
  String get platesNotLoadable => 'Mit deinen Scheiben nicht ladbar';

  @override
  String get platesBarOnly => 'Nur die Stange';

  @override
  String platesPerSide(Object plates) {
    return 'Pro Seite: $plates';
  }

  @override
  String aboutMinutes(Object n) {
    return '≈ $n Min';
  }

  @override
  String everySet(Object taken, Object time) {
    return '$taken · alle $time Min ein Satz';
  }

  @override
  String get syncConflict => 'Konflikt: Daten auf GitHub sind neuer oder fremd';

  @override
  String syncLoginFailed(Object code) {
    return 'GitHub-Login fehlgeschlagen (HTTP $code)';
  }

  @override
  String get syncNoClientId =>
      'githubClientId in lib/sync.dart ist nicht gesetzt (siehe README).';

  @override
  String get syncCodeExpired => 'Code abgelaufen, bitte neu anmelden.';

  @override
  String get syncDenied => 'Anmeldung abgelehnt.';

  @override
  String syncLoginError(Object error) {
    return 'GitHub-Login: $error';
  }

  @override
  String syncDone(Object time) {
    return 'Synchronisiert $time';
  }

  @override
  String syncError(Object time, Object error) {
    return 'Fehler $time: $error';
  }

  @override
  String get syncExpired => 'Anmeldung abgelaufen, bitte neu anmelden';

  @override
  String get syncNoWrite =>
      'Keine Schreibrechte – hat FerroLog Zugriff auf das Repo?';

  @override
  String get syncNotFound =>
      'Repo nicht gefunden – hat FerroLog Zugriff darauf?';

  @override
  String get recapRecord => 'Neuer Rekord! 🏆';

  @override
  String get recapAllDone => 'Alles geschafft! 💪';

  @override
  String recapBackoff(Object pct) {
    return 'nach der Pause −$pct %';
  }

  @override
  String get recapVolume => 'Volumen';

  @override
  String get recapHeaviest => 'Schwerster';

  @override
  String get recapDuration => 'Dauer';

  @override
  String get recapTitle => 'Zusammenfassung';

  @override
  String get editTraining => 'Training bearbeiten';

  @override
  String get recapNextWeight => '  Gewicht fürs nächste Mal';

  @override
  String get recapHowWasIt => 'Wie war’s?';

  @override
  String get moodBad => 'Schlecht';

  @override
  String get moodOkay => 'Okay';

  @override
  String get moodGood => 'Gut';

  @override
  String bodyWeight(Object unit) {
    return 'Körpergewicht ($unit)';
  }

  @override
  String bodyWeightStale(Object days) {
    return 'Zuletzt vor $days Tagen eingetragen. Einmal im Monat hält die Statistik aktuell.';
  }

  @override
  String get optional => 'Optional';

  @override
  String get bodyWeightSame => 'Wie zuletzt? ± übernimmt den Wert.';

  @override
  String get recapAddNote => 'Notiz: Schlaf, Alkohol, Stress …';

  @override
  String get recapCircumstances => 'Umstände';

  @override
  String get recapNoteHint => 'Sonst noch was? (optional)';

  @override
  String get done => 'Fertig';

  @override
  String get editDayHelp => 'Tag des Trainings';

  @override
  String get next => 'Weiter';

  @override
  String get editStartHelp => 'Beginn';

  @override
  String get ok => 'OK';

  @override
  String get discardChanges => 'Änderungen verwerfen?';

  @override
  String editStartAt(Object date, Object time) {
    return '$date · Beginn $time';
  }

  @override
  String cardioGoal(Object goal) {
    return 'Cardio · Ziel $goal';
  }

  @override
  String insteadOf(Object name) {
    return 'statt $name';
  }

  @override
  String get notDone => 'Nicht gemacht';

  @override
  String get rirQuestionShort => 'Gingen noch';

  @override
  String get save => 'Speichern';

  @override
  String get editReplans => 'Die Plan-Gewichte werden neu berechnet.';

  @override
  String get editHistoryOnly =>
      'Ältere Trainings ändern nur Verlauf und Statistik, nicht den Plan.';

  @override
  String get less => 'Weniger';

  @override
  String get more => 'Mehr';

  @override
  String setOfGoal(Object n, Object total, Object goal) {
    return 'Satz $n von $total · Ziel $goal';
  }

  @override
  String get cardWeekGoal => 'WOCHENZIEL';

  @override
  String get cardSkipped => 'AUSGELASSEN · LETZTE 4 WOCHEN';

  @override
  String get cardBalance => 'BALANCE · LETZTE 28 TAGE';

  @override
  String get cardPlateau => 'PLATEAU';

  @override
  String get cardAllGood => 'Alles im Lot';

  @override
  String get cardSeeStats => ' · Statistik ansehen';

  @override
  String get cardTitle => 'Dein Training';

  @override
  String get cardFromStats => 'aus deiner Statistik';

  @override
  String get cardWhyWhat => 'Warum und was tun →';

  @override
  String get cardWhy => 'WARUM';

  @override
  String get cardAdvice => 'EMPFEHLUNG';

  @override
  String fixMoveUp(Object workout) {
    return 'In $workout vorziehen';
  }

  @override
  String fixDropSet(Object exercise) {
    return '1 Satz weniger $exercise';
  }

  @override
  String get fixInEditor => 'Im Editor anpassen';

  @override
  String get later => 'Später';

  @override
  String get sourceBalance => 'Balance in der Statistik ansehen';

  @override
  String get sourceWeeks => 'Wochen in der Statistik ansehen';

  @override
  String sourceExercise(Object exercise) {
    return '$exercise in der Statistik ansehen';
  }

  @override
  String get sourceHistory => 'Im Verlauf ansehen';

  @override
  String fixMovedUp(Object exercise, Object workout) {
    return '$exercise in $workout vorgezogen';
  }

  @override
  String setsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Sätze',
      one: '1 Satz',
    );
    return '$_temp0';
  }

  @override
  String fixDroppedSet(Object exercise, Object workout, Object sets) {
    return '$exercise in $workout: jetzt $sets';
  }

  @override
  String get undo => 'Rückgängig';

  @override
  String get finishTrainingFirst => 'Erst das laufende Training beenden';

  @override
  String get planTaken => 'Plan übernommen';

  @override
  String fileUnreadable(Object error) {
    return 'Die Datei ließ sich nicht lesen: $error';
  }

  @override
  String get planPasteHint =>
      'Füg den JSON-Codeblock aus dem Chat ein oder öffne ihn als Datei. Vor dem Speichern siehst du jede Änderung.';

  @override
  String get openFile => 'Datei öffnen (.json, .txt)';

  @override
  String get check => 'Prüfen';

  @override
  String get changeNew => 'Neu';

  @override
  String get changeRemoved => 'Fällt weg';

  @override
  String get changeChanged => 'Geändert';

  @override
  String get changeSame => 'Unverändert';

  @override
  String get planFromAi => 'Plan von KI';

  @override
  String get planStale => 'Seit dem Export hast du trainiert';

  @override
  String planStaleHint(Object date) {
    return 'Der Plan beruht auf dem Stand vom $date. Die Gewichte können veraltet sein.';
  }

  @override
  String get planEmpty => 'Der Plan ändert nichts an deinen Workouts.';

  @override
  String planUnchanged(Object names) {
    return 'Unverändert: $names';
  }

  @override
  String get planKeepsTrainings =>
      'Deine Trainings bleiben, wie sie sind. Nach dem Übernehmen kannst du es einmal rückgängig machen.';

  @override
  String get takeOver => 'Übernehmen';

  @override
  String movedTo(Object n) {
    return 'Jetzt an Platz $n';
  }

  @override
  String get front => 'Vorne';

  @override
  String get back => 'Hinten';

  @override
  String get muscleChest => 'Brust';

  @override
  String get muscleShoulders => 'Schultern';

  @override
  String get muscleTriceps => 'Trizeps';

  @override
  String get muscleBiceps => 'Bizeps';

  @override
  String get muscleForearms => 'Unterarme';

  @override
  String get muscleLats => 'Latissimus';

  @override
  String get muscleMiddleBack => 'Mittlerer Rücken';

  @override
  String get muscleLowerBack => 'Unterer Rücken';

  @override
  String get muscleTraps => 'Trapez';

  @override
  String get muscleNeck => 'Nacken';

  @override
  String get muscleAbdominals => 'Bauch';

  @override
  String get muscleQuadriceps => 'Quadrizeps';

  @override
  String get muscleHamstrings => 'Beinbeuger';

  @override
  String get muscleGlutes => 'Gesäß';

  @override
  String get muscleCalves => 'Waden';

  @override
  String get muscleAdductors => 'Adduktoren';

  @override
  String get muscleAbductors => 'Abduktoren';

  @override
  String get groupChest => 'Brust';

  @override
  String get groupUpperBack => 'Oberer Rücken';

  @override
  String get groupShoulders => 'Schultern';

  @override
  String get groupLats => 'Latissimus';

  @override
  String get groupFrontDelts => 'Vordere Schulter';

  @override
  String get groupRearDelts => 'Hintere Schulter';

  @override
  String get groupQuads => 'Quadrizeps';

  @override
  String get groupHamstrings => 'Hintere Oberschenkel';

  @override
  String get groupInternalRot => 'Innenrotation';

  @override
  String get groupExternalRot => 'Außenrotation';

  @override
  String get groupAbs => 'Bauch';

  @override
  String get groupLowerBack => 'Unterer Rücken';

  @override
  String get objChest => 'die Brust';

  @override
  String get objUpperBack => 'den oberen Rücken';

  @override
  String get objShoulders => 'die Schultern';

  @override
  String get objLats => 'den Latissimus';

  @override
  String get objFrontDelts => 'die vordere Schulter';

  @override
  String get objRearDelts => 'die hintere Schulter';

  @override
  String get objQuads => 'den Quadrizeps';

  @override
  String get objHamstrings => 'die hinteren Oberschenkel';

  @override
  String get objInternalRot => 'die Innenrotation';

  @override
  String get objExternalRot => 'die Außenrotation';

  @override
  String get objAbs => 'den Bauch';

  @override
  String get objLowerBack => 'den unteren Rücken';

  @override
  String get sidePush => 'Drücken';

  @override
  String get sideRow => 'Rudern';

  @override
  String get sideOverhead => 'Über Kopf drücken';

  @override
  String get sidePullUps => 'Klimmzüge, Latzug';

  @override
  String get sideFrontDelts => 'Vordere Schulter';

  @override
  String get sideRearDelts => 'hintere Schulter';

  @override
  String get sideQuads => 'Quadrizeps';

  @override
  String get sideHamstrings => 'hintere Oberschenkel';

  @override
  String get sideInternalRot => 'Innenrotation';

  @override
  String get sideExternalRot => 'Außenrotation';

  @override
  String get sideAbs => 'Bauch';

  @override
  String get sideLowerBack => 'unterer Rücken';

  @override
  String get notePressHalf => 'Drückübungen zählen halb';

  @override
  String get noteHingeSquatHalf => 'Kreuzheben und Kniebeuge zählen halb';

  @override
  String get ratioRowBench => 'Rudern : Bankdrücken';

  @override
  String get ratioHingeSquat => 'Kreuzheben : Kniebeuge';

  @override
  String weekDaysLeft(Object n) {
    return 'noch $n Tage';
  }

  @override
  String get weekTomorrowLast => 'morgen ist der letzte Tag';

  @override
  String get weekTodayLast => 'heute ist der letzte Tag';

  @override
  String weekTitle(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Noch $n Trainings diese Woche',
      one: 'Noch 1 Training diese Woche',
    );
    return '$_temp0';
  }

  @override
  String weekEvidence(Object done, Object goal, Object when) {
    return '$done von $goal geschafft, $when';
  }

  @override
  String weekWhy(Object goal) {
    return 'Dein Wochenziel sind $goal Trainings.';
  }

  @override
  String get weekAdviceDays =>
      'Mit einem Training in den nächsten Tagen bleibt die Serie.';

  @override
  String get weekAdviceTomorrow =>
      'Mit einem Training morgen bleibt die Serie.';

  @override
  String get weekAdviceToday => 'Mit einem Training heute bleibt die Serie.';

  @override
  String get skippedEndAlways => ', jedes Mal als letzte Übung';

  @override
  String get skippedEndMostly => ', meist als letzte Übung';

  @override
  String skippedConsequence(Object evidence) {
    return ' Folge für die Balance: $evidence.';
  }

  @override
  String skippedTitle(Object name, Object n) {
    return '$name $n× ausgelassen';
  }

  @override
  String skippedEvidence(Object end) {
    return 'In 4 Wochen$end';
  }

  @override
  String skippedWhy(Object n, Object of, Object end, Object consequence) {
    return 'In $n von $of Trainings komplett weggelassen$end.$consequence';
  }

  @override
  String skippedAdviceMove(Object name) {
    return '$name vor die Zusatzübungen ziehen. Gleiches Volumen, es fällt nur nicht mehr hinten runter.';
  }

  @override
  String skippedAdvice(Object name) {
    return '$name früher im Training einplanen oder bewusst aus dem Plan nehmen.';
  }

  @override
  String get remedyRearDelts => 'Face Pulls oder Reverse Flys';

  @override
  String get remedyAbs => 'Plank oder Ab Wheel';

  @override
  String get remedyNoteExternal =>
      ' Face Pulls decken beides ab: Außenrotation und hintere Schulter. Am Ende eines Oberkörper-Trainings einplanen.';

  @override
  String get remedyNoteRearDelts =>
      ' Face Pulls decken beides ab: hintere Schulter und Außenrotation.';

  @override
  String balanceAdviceEarlier(Object side) {
    return 'Geplant ist es ausgeglichen, aber Sätze fallen weg. $side früher im Training einplanen.';
  }

  @override
  String balanceAdviceDrop(Object exercise, Object workout) {
    return 'Ein Satz weniger $exercise in $workout gleicht aus, ohne mehr Arbeit.';
  }

  @override
  String balanceAdviceKeep(Object exercise) {
    return 'Grundübungen bleiben wie geplant, $exercise nicht auslassen und weiter steigern.';
  }

  @override
  String balanceAdviceNothing(Object group) {
    return 'Nichts im Plan trainiert $group direkt.';
  }

  @override
  String balanceAdviceSuggest(Object group, Object suggest, Object note) {
    return 'Nichts im Plan trainiert $group direkt, zum Beispiel $suggest.$note';
  }

  @override
  String balanceEvidence(
    Object ratio,
    Object a,
    Object aValue,
    Object b,
    Object bValue,
  ) {
    return '$ratio · $a $aValue : $b $bValue Sätze/Woche';
  }

  @override
  String balanceWhy(Object a, Object b, Object range, Object note) {
    return '$a gegen $b, Richtwert $range. Gezählt werden die gemachten Sätze der letzten 28 Tage$note.';
  }

  @override
  String balanceTitle(Object group) {
    return '$group kommt zu kurz';
  }

  @override
  String guideFrom(Object pct) {
    return 'ab $pct %';
  }

  @override
  String plateauDeloadAfter(Object n, Object fails) {
    return 'Automatischer Deload nach $n Fehlschlägen in Folge (bisher $fails).';
  }

  @override
  String get plateauDeloadOff => 'Automatischer Deload ist aus.';

  @override
  String plateauTitle(Object name, Object weight) {
    return '$name steht bei $weight';
  }

  @override
  String plateauEvidence(Object n) {
    return '$n Trainings ohne Steigerung';
  }

  @override
  String get plateauLighter =>
      'Zuletzt einen Satz leichter gemacht, das hält das Gewicht.';

  @override
  String plateauReserve(Object n) {
    return 'Zuletzt gingen noch $n Wiederholungen.';
  }

  @override
  String get plateauReserveMany => '4 oder mehr';

  @override
  String get plateauLimit =>
      'Die letzten 2 Trainings am Limit, keine Wiederholung mehr übrig.';

  @override
  String get plateauAdviceTechnique =>
      'Das Gewicht ist nicht die Grenze: Technik, Konzentration und genug Pause prüfen und die Sätze ausreizen. Ein Deload ist nicht nötig.';

  @override
  String get plateauAdviceDeload =>
      'Zweimal am Limit: ein Deload um etwa 10 % hilft, danach wieder aufbauen.';

  @override
  String get plateauAdviceHold =>
      'Gewicht halten, auf saubere Technik und genug Pause achten. Klappt es in 2 Trainings nicht, kann ein Deload helfen.';

  @override
  String recordTitle(Object name, Object weight) {
    return 'Rekord: $name $weight';
  }

  @override
  String get recordEvidence => 'Schwerer als je zuvor';

  @override
  String gainTitle(Object name, Object from, Object to) {
    return 'Fortschritt: $name $from → $to';
  }

  @override
  String since(Object date) {
    return 'Seit $date';
  }

  @override
  String milestoneTitle(Object n) {
    return '$n. Training geschafft';
  }

  @override
  String monthTitle(Object n) {
    return 'Rekordmonat: $n Trainings';
  }

  @override
  String get monthEvidence => 'So viele wie noch nie';

  @override
  String get programFullBodyStrength => 'Full Body Kraft';

  @override
  String get programFullBodyNote =>
      'Jedes Training gleich, 1–3× pro Woche, 48–72 h Erholung dazwischen. 8–12 Wochen dabei bleiben.';

  @override
  String get programStrongLiftsNote => 'A und B abwechselnd, 3× pro Woche.';

  @override
  String get programPpl => 'Push/Pull/Beine';

  @override
  String get dayLegs => 'Beine';

  @override
  String get programUpperLower => 'Ober/Unter';

  @override
  String get dayUpper => 'Oberkörper';

  @override
  String get dayLower => 'Unterkörper';

  @override
  String get programFullBody => 'Ganzkörper';

  @override
  String get replaceExercisesAsk =>
      'Deine Änderungen an der Übungsliste ersetzen?';

  @override
  String get newWorkout => 'Neues Workout';

  @override
  String get editWorkout => 'Workout bearbeiten';

  @override
  String get deleteWorkout => 'Workout löschen';

  @override
  String deleteWorkoutAsk(Object name) {
    return '„$name“ löschen? Der Verlauf bleibt erhalten.';
  }

  @override
  String get name => 'Name';

  @override
  String example(Object value) {
    return 'z. B. $value';
  }

  @override
  String get workoutA => 'Workout A';

  @override
  String fixedSteps(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Übungen steigern in festen Schritten',
      one: '1 Übung steigert in festen Schritten',
    );
    return '$_temp0';
  }

  @override
  String get allAuto => 'Alle automatisch';

  @override
  String get exercise => 'Übung';

  @override
  String cardioLine(Object goal) {
    return 'Cardio · $goal';
  }

  @override
  String get auto => 'automatisch';

  @override
  String onSuccess(Object weight) {
    return '+$weight bei Erfolg';
  }

  @override
  String get removeExercise => 'Übung entfernen';

  @override
  String get template => 'Vorlage';

  @override
  String get custom => 'Custom';

  @override
  String get customHint => 'Leg deine Übungen unten mit „+ Übung“ an.';

  @override
  String transferAsk(Object from, Object to) {
    return 'Verlauf von „$from“ auf „$to“ übertragen?';
  }

  @override
  String transferHint(Object to, Object from) {
    return 'Übertragen: Statistik, Rekorde und Trainings laufen unter „$to“ weiter, auch in anderen Workouts. Neue Übung: „$to“ beginnt ohne Verlauf, „$from“ bleibt im Verlauf, wie es war.';
  }

  @override
  String get newExercise => 'Neue Übung';

  @override
  String get transfer => 'Übertragen';

  @override
  String get set => 'Satz';

  @override
  String setOf(Object n, Object total) {
    return 'Satz $n von $total';
  }

  @override
  String get seconds => 'Sekunden';

  @override
  String get secondsAtLeast => 'Sekunden mindestens';

  @override
  String get reps => 'Wiederholungen';

  @override
  String get repsAtLeast => 'Wdh. mindestens';

  @override
  String weightIn(Object unit) {
    return 'Gewicht ($unit)';
  }

  @override
  String get assistHint =>
      'Unter 0: Unterstützung, z. B. am Klimmzug-Gerät. Steigern heißt weniger Hilfe, Richtung 0.';

  @override
  String get thisSet => 'Dieser Satz';

  @override
  String get allSets => 'Alle Sätze';

  @override
  String get deleteSet => 'Satz löschen';

  @override
  String get close => 'Schließen';

  @override
  String get muscles => 'Muskeln';

  @override
  String get unknownExercise =>
      'Unbekannte Übung: Ohne Muskeln fehlt sie in Balance und Muskelkarte. Bitte antippen, was sie trainiert.';

  @override
  String get musclesHint =>
      'Antippen: Hauptmuskel ✓ → hilft mit ½ → aus. Für die Statistik.';

  @override
  String get addExercise => 'Übung hinzufügen';

  @override
  String get editExercise => 'Übung bearbeiten';

  @override
  String get add => 'Hinzufügen';

  @override
  String get searchExercise => 'Übung suchen oder eigene eingeben';

  @override
  String get duplicateExercise =>
      'Steht schon in diesem Workout. Für mehr Sätze oder andere Gewichte pro Satz die vorhandene bearbeiten.';

  @override
  String get noMatch => 'Kein Treffer – eigener Name wird übernommen';

  @override
  String defaultsFrom(Object name) {
    return 'Standardwerte für $name übernommen';
  }

  @override
  String get strength => 'Kraft';

  @override
  String get cardio => 'Cardio';

  @override
  String get durationGoal => 'Dauer';

  @override
  String get distance => 'Distanz';

  @override
  String goalIn(Object unit) {
    return 'Ziel ($unit)';
  }

  @override
  String get goalMinutes => 'Ziel (Min)';

  @override
  String get withWeight => 'Mit Gewicht';

  @override
  String get withoutWeight => 'Ohne Gewicht';

  @override
  String get time => 'Zeit';

  @override
  String get sets => 'Sätze';

  @override
  String get tapSetToChange => 'Satz antippen zum Ändern';

  @override
  String get thisTrainingTap => 'Dieses Training · antippen zum Ändern';

  @override
  String get nextTrainingTap => 'Nächstes Training · antippen zum Ändern';

  @override
  String get timeRange => 'Zeit-Spanne';

  @override
  String get repRange => 'Wiederholungs-Spanne';

  @override
  String get rangeOffTime => 'Aus · feste Zeit';

  @override
  String get rangeOffReps => 'Aus · feste Wiederholungen';

  @override
  String rangeOnSeconds(Object sets, Object top) {
    return '$sets · Gewicht steigt erst, wenn alle Sätze $top s schaffen';
  }

  @override
  String rangeOnReps(Object sets, Object top) {
    return '$sets · Gewicht steigt erst, wenn alle Sätze $top Wdh. schaffen';
  }

  @override
  String get upToSeconds => 'Bis Sekunden';

  @override
  String get upToReps => 'Bis Wiederholungen';

  @override
  String get rest => 'Pause';

  @override
  String get minSecOrSec => 'min:s oder s';

  @override
  String get afterMissedSet => 'Nach nicht geschafftem Satz';

  @override
  String get sameAsAbove => 'Wie oben';

  @override
  String get adjustWeight => 'Gewicht anpassen';

  @override
  String get automatic => 'Automatisch';

  @override
  String get fixed => 'Fest';

  @override
  String get loadStep => 'Ladestufe';

  @override
  String get increaseOnSuccess => 'Steigerung bei Erfolg';

  @override
  String increaseOn(Object weight) {
    return '+$weight, wenn alle Sätze geschafft';
  }

  @override
  String get offWeightStays => 'Aus · Gewicht bleibt gleich';

  @override
  String get decreaseOnMiss => 'Senkung bei Misserfolg';

  @override
  String decreaseOn(Object weight, Object n) {
    return '−$weight nach $n× nicht geschafft';
  }

  @override
  String get decreaseAfter => 'Senken nach Fehlversuchen in Folge';

  @override
  String summaryCardio(Object name, Object goal) {
    return '$name: Ziel $goal. Im Training startest du die Stoppuhr mit einem Tipp.';
  }

  @override
  String planNoWeight(Object sets) {
    return '$sets ohne Gewicht';
  }

  @override
  String planWithWeight(Object sets, Object weight) {
    return '$sets mit $weight';
  }

  @override
  String summaryTraining(Object name, Object plan) {
    return '$name: $plan. Nur für dieses Training, der Plan bleibt, wie er ist.';
  }

  @override
  String summaryPlain(Object name, Object plan) {
    return '$name: $plan.';
  }

  @override
  String summaryAuto(Object name, Object plan) {
    return '$name: $plan. Gewicht passt sich automatisch an.';
  }

  @override
  String summaryUp(Object weight) {
    return 'Bei Erfolg +$weight.';
  }

  @override
  String summaryDown(Object n, Object weight) {
    return 'Nach $n× Misserfolg −$weight.';
  }

  @override
  String get summaryFixed => 'Gewicht wird nicht automatisch angepasst.';

  @override
  String get autoRuleDone =>
      'Geschafft: etwa 2,5 % mehr, mit 3 oder mehr Wiederholungen Reserve doppelt, am Limit bleibt es (beim zweiten Mal in Folge ein halber Schritt).';

  @override
  String get autoRuleBridge =>
      'Ist der Schritt zu klein zum Laden, geht es erst über Wiederholungen.';

  @override
  String get autoRuleRange => 'Erst wenn alle Sätze oben in der Spanne sind.';

  @override
  String autoRuleMiss(Object n) {
    return 'Nicht geschafft: Gewicht bleibt, nach $n× in Folge etwa −10 % und danach kleinere Schritte, die mit Reserve wieder wachsen.';
  }

  @override
  String get autoRuleBadDay =>
      'Krank, schlecht geschlafen, Stress oder wenig gegessen zählen nicht (höchstens 2× in Folge), nach 2 Wochen Pause geht es leichter los. Die Reserve wird nach jeder Übung abgefragt.';

  @override
  String autoNow(Object pct, Object step, Object source) {
    return 'Gerade +$pct % pro Training · Ladestufe $step ($source)';
  }

  @override
  String get sourcePlates => 'deine Scheiben';

  @override
  String get sourceLearned => 'aus deinen Gewichten';

  @override
  String get sourceGuess => 'Startwert, lernt mit';

  @override
  String get sourceSet => 'eingestellt';

  @override
  String get own => 'Eigene';

  @override
  String leftAbout(Object about) {
    return 'noch $about';
  }

  @override
  String doneAround(Object time) {
    return 'fertig gegen $time';
  }

  @override
  String get alreadyInTraining => 'Schon im Training';

  @override
  String get kindStays => 'Nach dem ersten Satz bleibt die Art, wie sie ist';

  @override
  String get moveUp => 'Nach oben';

  @override
  String get moveDown => 'Nach unten';

  @override
  String get remove => 'Entfernen';

  @override
  String get noSetsDiscard => 'Keine Sätze geloggt. Training verwerfen?';

  @override
  String get notAllSetsFinish => 'Nicht alle Sätze erledigt. Trotzdem beenden?';

  @override
  String get discard => 'Verwerfen';

  @override
  String get finish => 'Beenden';

  @override
  String get stripPickUp => 'AUFNEHMEN';

  @override
  String get stripHold => 'HALTEN';

  @override
  String holdGoal(Object goal) {
    return 'Ziel $goal s';
  }

  @override
  String get stop => 'Stopp';

  @override
  String get pause => 'Anhalten';

  @override
  String get resumeRest => 'Weiter';

  @override
  String get restart => 'Neu starten';

  @override
  String restOf(Object time) {
    return 'von $time';
  }

  @override
  String restGoal(Object time) {
    return 'Ziel $time';
  }

  @override
  String get stripPaused => 'ANGEHALTEN';

  @override
  String get stripRest => 'PAUSE';

  @override
  String get stripSoon => 'GLEICH WEITER';

  @override
  String get stripGo => 'LOS';

  @override
  String get stripLate => 'ÜBERZOGEN';

  @override
  String get rirQuestion => 'Wie viele gingen noch?';

  @override
  String restLine(Object time) {
    return 'Pause $time';
  }

  @override
  String get now => 'JETZT';

  @override
  String warmup(Object sets) {
    return 'Aufwärmen: $sets';
  }

  @override
  String get startStopwatch => ' Start';

  @override
  String get enterDistance => 'Distanz eintragen';

  @override
  String rangeDone(Object goal) {
    return '$goal geschafft · nächstes Mal schwerer';
  }

  @override
  String rangeIncreaseAt(Object goal) {
    return 'Steigerung bei $goal';
  }

  @override
  String rangeAllTop(Object goal) {
    return 'Steigerung bei $goal · bisher alle oben';
  }

  @override
  String rangeMissingReps(Object goal, Object n) {
    return 'Steigerung bei $goal · noch $n Wdh.';
  }

  @override
  String rangeMissingSeconds(Object goal, Object n) {
    return 'Steigerung bei $goal · noch $n s';
  }

  @override
  String weightBetween(Object min, Object max) {
    return 'Gewicht zwischen $min und $max';
  }

  @override
  String get applyTo => 'Übernehmen für';

  @override
  String get openSets => 'Offene Sätze';

  @override
  String get minutesUnit => 'Min';

  @override
  String get distanceOptional => 'Distanz (optional)';

  @override
  String hintsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Hinweise',
      one: '1 Hinweis',
    );
    return '$_temp0';
  }

  @override
  String pairsBalanced(Object ok, Object total) {
    return '  · $ok von $total ausgewogen';
  }

  @override
  String get allPairsBalanced => 'Alle Muskelpaare ausgewogen';

  @override
  String get balanceScaleHint =>
      'Der Punkt zeigt zur Seite mit mehr Sätzen. Im hellen Feld ist es ausgewogen. Tippe auf ein Paar für Empfehlung und Zahlen.';

  @override
  String get strengthTrend => 'Kraft im Verlauf';

  @override
  String get trendUp => '↗ steigt';

  @override
  String get trendDown => '↘ sinkt';

  @override
  String get trendFlat => '→ stabil';

  @override
  String get strengthTrendHint =>
      'Verhältnis aus dem geschätzten 1RM über 90 Tage. Zeigt deine Entwicklung, keinen Vergleich mit Literaturwerten.';

  @override
  String balanceDetail(
    Object a,
    Object aSets,
    Object b,
    Object bSets,
    Object note,
    Object group,
    Object ratio,
    Object range,
  ) {
    return '$a $aSets · $b $bSets Sätze pro Woche$note. $group bei $ratio, Richtwert $range.';
  }

  @override
  String get balanced => '✓ Ausgewogen';

  @override
  String verdictSlightly(Object strong, Object weak) {
    return '$strong etwas mehr trainiert als $weak';
  }

  @override
  String verdictClearly(Object strong, Object weak) {
    return '$strong deutlich mehr trainiert als $weak';
  }

  @override
  String get balanceInfoTitle => 'Balance: was dahintersteckt';

  @override
  String get infoProven => 'Was belegt ist';

  @override
  String get infoProven1 =>
      'Mehr Sätze pro Muskel und Woche bringen mehr Muskelwachstum, abgestuft nach unter 5, 5–9 und 10+ Sätzen [1].';

  @override
  String get infoProven2 =>
      'Hilfsmuskeln anteilig zu zählen bildet das Volumen genauer ab: 5 Sätze Curls und 5 Sätze Rudern ergeben 7,5 Bizeps-Sätze [2].';

  @override
  String get infoUncertain => 'Was unsicher ist';

  @override
  String get infoUncertain1 =>
      'Ob Ungleichgewichte zwischen Drücken und Ziehen das Verletzungsrisiko erhöhen, ist nicht untersucht.';

  @override
  String get infoUncertain2 =>
      'Für das Verhältnis Beinbeuger zu Quadrizeps gibt es nur sehr begrenzte Evidenz als Risikofaktor [3].';

  @override
  String get infoUncertain3 =>
      'Deshalb zeigt FerroLog Hinweise, keine Warnungen.';

  @override
  String get infoGuides => 'Woher die Richtwerte kommen';

  @override
  String get infoGuides1 =>
      'Drücken : Ziehen 1:1 bis 1:1,5 ist eine Trainerempfehlung, kein Studienwert. Regeln wie 2:1 oder 3:1 sind Faustregeln [4].';

  @override
  String get infoGuides2 =>
      'Beinbeuger ab 60 % lehnt sich an Labormessungen an (H:Q > 0,6) [5]. Die stammen aus der Isokinetik und lassen sich nicht direkt auf Kniebeuge und Kreuzheben übertragen.';

  @override
  String get infoGuides3 =>
      'Freizeitsportler drücken in Tests 1,5- bis 2,7-mal so viel, wie sie ziehen [6].';

  @override
  String get infoGuides4 =>
      'Bei der Schulter liegt die Außenrotation in Kraftmessungen bei 86–99 % der Innenrotation [7]. Für Sätze gibt es keinen Studienwert, der Richtwert ist bewusst niedrig angesetzt.';

  @override
  String get infoGuides5 =>
      'Bei Bauch und unterem Rücken widersprechen sich die Studien, welche Seite bei Rückenschmerzen schwächer ist [8, 9]. Der Richtwert ist deshalb breit und symmetrisch.';

  @override
  String get infoMath => 'Wie FerroLog rechnet';

  @override
  String get infoMath1 =>
      'Jede Übung zählt voll für ihre Hauptgruppe und halb für Hilfsmuskeln.';

  @override
  String get infoMath2 =>
      'Sätze pro Woche, gemittelt über die letzten 28 Tage, je Paar als Verhältnis.';

  @override
  String get infoMath3 =>
      'Kraftverhältnisse (geschätztes 1RM) nur als Verlauf, nicht gegen Literaturwerte.';

  @override
  String get infoMath4 => 'Alle Richtwerte kannst du anpassen.';

  @override
  String get infoScale => 'So liest du die Waage';

  @override
  String get infoScale1 =>
      'Der Punkt zeigt zur Seite, die mehr Sätze bekommt. Im hellen Feld in der Mitte liegt das Paar im Richtwert.';

  @override
  String get infoScale2 =>
      'Der Richtwert stammt aus der Trainingspraxis und ist keine medizinische Grenze. Hilfsmuskeln zählen halb.';

  @override
  String get adjustGuides => 'Richtwerte anpassen';

  @override
  String get sources => 'QUELLEN';

  @override
  String get guides => 'Richtwerte';

  @override
  String get guidesHint =>
      'Seite rechts im Verhältnis zur Seite links, in Prozent der Sätze.';

  @override
  String get resetDefaults => 'Auf Standard zurücksetzen';

  @override
  String get sourceShoulderNorms =>
      'Handdynamometer-Normwerte, Schulterrotation';

  @override
  String get sourceTrunk => 'Rumpf-Ausdauer Flexion/Extension (MMU)';

  @override
  String get piNoJson =>
      'Kein JSON gefunden. Kopier den ganzen Codeblock aus dem Chat.';

  @override
  String piBrokenJson(Object error) {
    return 'Das JSON ist unvollständig oder fehlerhaft: $error';
  }

  @override
  String get piIsExport =>
      'Das ist ein Export mit allen Daten, kein Plan. Nimm den JSON-Block aus der Antwort der KI.';

  @override
  String get piNotPlan =>
      'Das ist kein FerroLog-Plan (app \"ferrolog\", kind \"plan\" fehlt).';

  @override
  String piVersion(Object v) {
    return 'Version $v kennt diese App nicht.';
  }

  @override
  String get piNoWorkouts => 'Der Plan enthält keine Workouts.';

  @override
  String piWorkoutNotObject(Object n) {
    return 'Workout $n ist kein Objekt.';
  }

  @override
  String piWorkoutTwice(Object id) {
    return 'Workout $id steht zweimal im Plan.';
  }

  @override
  String piDeleteMissing(Object name) {
    return 'Das Workout zum Löschen ($name) gibt es nicht.';
  }

  @override
  String piWorkoutNoName(Object n) {
    return 'Workout $n hat keinen Namen.';
  }

  @override
  String piNoExercises(Object name) {
    return '„$name“ hat keine Übungen.';
  }

  @override
  String piExerciseWhere(Object name, Object n) {
    return '„$name“, Übung $n';
  }

  @override
  String piExerciseTwice(Object name, Object exercise) {
    return '„$name“ hat „$exercise“ zweimal. Mehr Sätze oder setWeights statt einer zweiten Übung.';
  }

  @override
  String piNotObject(Object where) {
    return '$where ist kein Objekt.';
  }

  @override
  String piNoName(Object where) {
    return '$where hat keinen Namen.';
  }

  @override
  String piQuoted(Object name) {
    return '„$name“';
  }

  @override
  String piNotInt(Object label, Object key) {
    return '$label: \"$key\" fehlt oder ist keine ganze Zahl.';
  }

  @override
  String piNoWeight(Object label) {
    return '$label: \"weight\" fehlt.';
  }

  @override
  String piBadType(Object label, Object type) {
    return '$label: Art \"$type\" gibt es nicht.';
  }

  @override
  String piBadSets(Object label) {
    return '$label: Sätze oder Wiederholungen ungültig.';
  }

  @override
  String piSetWeights(Object label, Object n) {
    return '$label: setWeights passt nicht zu $n Sätzen.';
  }

  @override
  String piSetReps(Object label, Object n) {
    return '$label: setReps passt nicht zu $n Sätzen.';
  }

  @override
  String piMaxReps(Object label) {
    return '$label: maxReps muss über reps liegen.';
  }

  @override
  String piMinWeight(Object label, Object min) {
    return '$label: Gewicht unter $min kg.';
  }

  @override
  String piBadMuscle(Object label, Object muscle) {
    return '$label: Muskel \"$muscle\" gibt es nicht.';
  }

  @override
  String get aspectName => 'Name';

  @override
  String get aspectKind => 'Art';

  @override
  String get aspectWeight => 'Gewicht';

  @override
  String get aspectIncrease => 'Steigerung';

  @override
  String get aspectDeload => 'Entlastung';

  @override
  String get off => 'aus';

  @override
  String deloadAfter(Object weight, Object n) {
    return '−$weight nach $n Fehlversuchen';
  }

  @override
  String restAfterMiss(Object s) {
    return 'nach Fehlversuch $s s';
  }

  @override
  String get timedKind => 'auf Zeit';

  @override
  String get noWeightShort => 'ohne Gewicht';

  @override
  String get days30 => '30 Tage';

  @override
  String get days90 => '90 Tage';

  @override
  String get year1 => '1 Jahr';

  @override
  String get allTime => 'Gesamt';

  @override
  String get statsEmpty => 'Statistiken gibt’s nach dem ersten Training.';

  @override
  String get noTrainingInPeriod => 'Kein Training in diesem Zeitraum.';

  @override
  String get background => 'Hintergrund';

  @override
  String get strengthProgress => 'Kraftentwicklung';

  @override
  String get chartWeightHint =>
      'Arbeitsgewicht, wie es die Progression vorgibt; Zacken nach unten sind Deloads. ▲ = Rückschritt.';

  @override
  String get chartE1rmHint =>
      'Veränderung des geschätzten 1RM (aus allen Sätzen) seit dem ersten Training im Zeitraum, der Baseline. ▲ = Rückschritt: weniger geschafft als zuletzt oder als schon einmal bei diesem Gewicht.';

  @override
  String get exercises => 'Übungen';

  @override
  String get statusLast4Weeks => 'Status: letzte 4 Wochen';

  @override
  String exercisesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Übungen',
      one: '1 Übung',
    );
    return '$_temp0';
  }

  @override
  String stuckCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hängen fest',
      one: '1 hängt fest',
    );
    return '$_temp0';
  }

  @override
  String get perWeek => 'Pro Woche';

  @override
  String goalWeeksHit(Object goal, Object hit, Object weeks) {
    return 'Ziel $goal · $hit von $weeks Wochen';
  }

  @override
  String get avgDuration => 'Ø Dauer';

  @override
  String volumeVsBefore(Object delta) {
    return '$delta % zum Zeitraum davor';
  }

  @override
  String get withRecord => 'Mit Rekord';

  @override
  String xOfY(Object x, Object y) {
    return '$x von $y';
  }

  @override
  String get noNewBest => 'kein neues Höchstgewicht';

  @override
  String get week => 'Woche';

  @override
  String get month => 'Monat';

  @override
  String get trainingsPerWeek => 'Trainings pro Woche';

  @override
  String lineGoalWeek(Object goal) {
    return 'Linie: Ziel $goal× pro Woche';
  }

  @override
  String lineGoalMonth(Object goal) {
    return 'Schnitt je Monat · Linie: Ziel $goal× pro Woche';
  }

  @override
  String minutesPerTrainingAvg(Object per) {
    return 'Minuten pro Training, Schnitt je $per · Linie: Schnitt im Zeitraum';
  }

  @override
  String tonnesPer(Object per) {
    return 'Tonnen je $per';
  }

  @override
  String kLbPer(Object per) {
    return 'Tausend lb je $per';
  }

  @override
  String get records => 'Rekorde';

  @override
  String recordsPer(Object per) {
    return 'Neue Höchstgewichte je $per, über alle Übungen';
  }

  @override
  String balanceDaysLabel(Object n) {
    return '$n Tage';
  }

  @override
  String get setsPerMuscle => 'Sätze je Muskel';

  @override
  String get perWeekLower => 'pro Woche';

  @override
  String notTrained(Object names) {
    return 'Nicht trainiert: $names';
  }

  @override
  String musclesUnder10(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Muskeln unter 10 Sätzen',
      one: '1 Muskel unter 10 Sätzen',
    );
    return '$_temp0';
  }

  @override
  String get tapMuscle => 'Tippe auf einen Muskel für seine Übungen';

  @override
  String get under5 => 'unter 5';

  @override
  String get over20 => 'über 20';

  @override
  String get muscleBarsHint =>
      'Balken: Sätze pro Woche. Band 10–20: der übliche Bereich für Muskelaufbau. Orange: unter 10.';

  @override
  String get musclesNote =>
      'Kraftprogramme wie 5×5 lassen bewusst Muskeln aus. Hilfsmuskeln zählen halb.';

  @override
  String setsPerWeek(Object n) {
    return '$n Sätze pro Woche';
  }

  @override
  String get noExerciseForMuscle =>
      'Keine Übung im Zeitraum trainiert diesen Muskel.';

  @override
  String setsN(Object n) {
    return '$n Sätze';
  }

  @override
  String get cardioPerWeek => 'Cardio pro Woche';

  @override
  String get minutesTitle => 'Minuten';

  @override
  String avgMinPerWeek(Object n) {
    return 'Ø $n Min pro Woche';
  }

  @override
  String lineCardioTotal(Object n, Object cardio) {
    return '$n · $cardio gesamt';
  }

  @override
  String lineSets(Object n, Object sets) {
    return '$n · $sets';
  }

  @override
  String lineSetsUpTo(Object n, Object sets, Object weight) {
    return '$n · $sets · bis $weight';
  }

  @override
  String lineSetsLast(Object n, Object sets, Object weight) {
    return '$n · $sets · zuletzt $weight';
  }

  @override
  String lineVolume(Object n, Object volume) {
    return '$n · Gesamt $volume';
  }

  @override
  String get trendNew => 'neu';

  @override
  String get trendRising => 'steigt';

  @override
  String get trendSteady => 'stabil';

  @override
  String get trendStuck => 'hängt fest';

  @override
  String mergeWith(Object name) {
    return '„$name“ zusammenführen mit';
  }

  @override
  String get noOtherExercise => 'Keine andere Übung mit Verlauf.';

  @override
  String mergeAsk(Object name, Object target) {
    return 'Alle Trainings von „$name“ heißen danach „$target“, auch in den Workouts. Das lässt sich nicht rückgängig machen.';
  }

  @override
  String get mergeMenu => 'Mit anderer Übung zusammenführen';

  @override
  String skippedOn(Object dates) {
    return 'Ausgelassen am $dates';
  }

  @override
  String get weight => 'Gewicht';

  @override
  String bestE1rm(Object weight) {
    return 'Bestes 1RM $weight';
  }

  @override
  String measureWeightHint(Object unit) {
    return 'Arbeitsgewicht ($unit). ▲ = Rückschritt.';
  }

  @override
  String measureE1rmHint(Object unit) {
    return 'Geschätztes 1RM aus allen Sätzen ($unit). ▲ = Rückschritt.';
  }

  @override
  String measureVolumeHint(Object unit) {
    return 'Volumen: Gewicht × Wiederholungen ($unit). ▲ = Rückschritt.';
  }

  @override
  String get minutesPerTraining => 'Minuten pro Training';

  @override
  String cardioTotal(Object minutes, Object trainings) {
    return 'Gesamt: $minutes in $trainings';
  }
}
