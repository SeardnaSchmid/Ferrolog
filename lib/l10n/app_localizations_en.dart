// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FerroLog';

  @override
  String get cancel => 'Cancel';

  @override
  String trainingsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n workouts',
      one: '1 workout',
    );
    return '$_temp0';
  }

  @override
  String syncNoFileYet(Object path) {
    return 'There is no $path on GitHub yet.';
  }

  @override
  String get syncRestored => 'Restored from GitHub';

  @override
  String syncOverwriteMore(Object theirs, Object ours) {
    return 'GitHub holds more workouts ($theirs) than this device ($ours). Overwrite anyway? The old state stays only in the repo\'s Git history.';
  }

  @override
  String get settingsTraining => 'Workout';

  @override
  String get settingsSound => 'Sound';

  @override
  String get settingsSoundHint => 'Beep when the rest reaches 0';

  @override
  String get settingsVibrate => 'Vibration';

  @override
  String get settingsVibrateHint => 'Vibrate briefly when the rest reaches 0';

  @override
  String get settingsAutoFinish => 'Finish automatically';

  @override
  String get settingsAutoFinishHint =>
      'After 30 min without activity the workout ends at the last set';

  @override
  String get settingsKeepScreenOn => 'Keep screen on';

  @override
  String get settingsKeepScreenOnHint =>
      'The display stays on during a workout';

  @override
  String get settingsShowWhenLocked => 'Show over the lock screen';

  @override
  String get settingsShowWhenLockedHint =>
      'Check the rest during a workout without unlocking';

  @override
  String get settingsAskRir => 'Ask for reps in reserve';

  @override
  String get settingsAskRirHint =>
      'After the last set of an exercise: how many more reps could you have done? Helps with plateaus. Exercises in auto mode always ask';

  @override
  String get settingsLeadIn => 'Lead-in for timed exercises';

  @override
  String get settingsLeadInHint =>
      'Time to pick up the weights before the seconds count';

  @override
  String get settingsHome => 'Home screen';

  @override
  String get settingsTasks => 'Training hints';

  @override
  String get settingsTasksHint =>
      'When the statistics find something: skipped exercises, balance, plateau, weekly goal';

  @override
  String get settingsInsights => 'Achievements';

  @override
  String get settingsInsightsHint =>
      'Records, progress and milestones of the last workout';

  @override
  String get settingsStreak => 'Streak';

  @override
  String get settingsStreakHint =>
      'Workouts per week for the week to count towards your streak';

  @override
  String get settingsLanguage => 'Language';

  @override
  String settingsLanguageSystem(Object name) {
    return 'System ($name)';
  }

  @override
  String get settingsUnit => 'Unit';

  @override
  String settingsUnitAuto(Object unit) {
    return 'Automatic ($unit)';
  }

  @override
  String get settingsUnitHint =>
      'Always stored in kg, converted only for display.';

  @override
  String get settingsBarbell => 'Barbell';

  @override
  String get settingsWarmup => 'Show warm-up sets';

  @override
  String get settingsWarmupHint =>
      'Before the first set of a barbell exercise: empty bar, then 50, 70 and 85 %';

  @override
  String get settingsBarPlatesHint =>
      'Bar and plates for “per side” in the weight sheet and for the warm-up sets';

  @override
  String settingsBar(Object weight) {
    return 'Bar $weight';
  }

  @override
  String get settingsPlates => 'Plates';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsExport => 'Send to AI / export';

  @override
  String get settingsExportHint =>
      'All data as JSON, the analysis prompt goes to the clipboard';

  @override
  String get settingsExportDone =>
      'Prompt copied: paste it into the chat if it\'s missing';

  @override
  String get settingsRestore => 'Restore from GitHub';

  @override
  String settingsRestoreHint(Object repo) {
    return 'Get workouts and plans from $repo, after a reinstall or from another device';
  }

  @override
  String get settingsRestoreNoSync => 'Set up GitHub sync below first';

  @override
  String get settingsPlanImport => 'Take over a plan from AI';

  @override
  String get settingsPlanImportHint =>
      'Paste the JSON block from the chat, with a preview before saving';

  @override
  String get settingsCredits =>
      'Exercise muscles: wger.de (CC-BY-SA), free-exercise-db · Body map: react-native-body-highlighter (MIT) · Licenses';

  @override
  String get syncTitle => 'GitHub sync';

  @override
  String get syncIntro =>
      'FerroLog stores your training data as ferrolog.json in a private GitHub repo, where your AI can read it. FerroLog only gets access to this one file in the repo you share.';

  @override
  String get syncEnterCode => 'Enter this code on GitHub (already copied):';

  @override
  String get syncThenBack => 'Then simply switch back to the app.';

  @override
  String get syncLogin => 'Sign in with GitHub';

  @override
  String get syncConnected => 'Connected to GitHub';

  @override
  String get syncLogout => 'Sign out';

  @override
  String get syncStepRepo => 'Create a data repo';

  @override
  String get syncStepRepoHint =>
      'Create a private repo “ferrolog-data” on GitHub';

  @override
  String get syncRepoDescription => 'FerroLog+training+data';

  @override
  String get syncStepAccess => 'Give FerroLog access';

  @override
  String get syncStepAccessHint =>
      '“Only select repositories” → pick ferrolog-data';

  @override
  String get syncFindsRepo =>
      'Then switch back to the app, FerroLog finds the repo by itself.';

  @override
  String sync404(Object slug) {
    return 'GitHub shows a 404 while installing? Then open step 2 on a computer: github.com/apps/$slug/installations/new';
  }

  @override
  String get syncRepo => 'Repo';

  @override
  String get syncPickRepo => 'Choose a repo';

  @override
  String get syncAnotherRepo => 'Share another repo';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncResolve => 'Resolve conflict';

  @override
  String syncLastOn(Object count, Object date) {
    return '$count, last on $date';
  }

  @override
  String get syncDialogTitle => 'Data on GitHub';

  @override
  String syncDialogUnreadable(Object problem) {
    return 'On GitHub: unreadable. $problem';
  }

  @override
  String syncDialogRemote(Object count) {
    return 'On GitHub: $count';
  }

  @override
  String syncDialogLocal(Object count) {
    return 'On this device: $count';
  }

  @override
  String get syncDialogRestoreAll =>
      'Restoring gets workouts and plans from GitHub.';

  @override
  String get syncDialogRestoreKeep =>
      'Restoring gets workouts and plans from GitHub and keeps the workouts that are only here.';

  @override
  String get syncOverwrite => 'Overwrite GitHub';

  @override
  String get languageName => 'English';

  @override
  String get dateFormat => 'M/d/yyyy';

  @override
  String minutes(Object n) {
    return '$n min';
  }

  @override
  String get navWorkouts => 'Workouts';

  @override
  String get navStats => 'Statistics';

  @override
  String get navHistory => 'History';

  @override
  String get navSettings => 'Settings';

  @override
  String get noWorkoutsYet => 'No workouts yet. Create one.';

  @override
  String get workoutRunning => ' running · ';

  @override
  String get resume => 'Resume';

  @override
  String elapsedMinutes(Object n) {
    return '$n min';
  }

  @override
  String elapsedHours(Object time) {
    return '$time h';
  }

  @override
  String get restPaused => ' · rest paused';

  @override
  String restLeft(Object time) {
    return ' · rest $time';
  }

  @override
  String get workout => 'Workout';

  @override
  String get trainingRunning => 'Workout running';

  @override
  String runningSince(Object name) {
    return '$name · for ';
  }

  @override
  String get discardTraining => 'Discard workout';

  @override
  String get discardTrainingAsk =>
      'Discard the workout? Nothing will be saved.';

  @override
  String get resumeTraining => 'Resume workout';

  @override
  String comebackLighter(Object pct) {
    return '$pct % lighter to start after the break';
  }

  @override
  String get setMuscles =>
      'Set the muscles, else it\'s missing from the statistics';

  @override
  String lastDone(Object when) {
    return 'last $when';
  }

  @override
  String get edit => 'Edit';

  @override
  String get start => 'Start';

  @override
  String get running => 'RUNNING';

  @override
  String setsDone(Object done, Object total) {
    return '$done/$total sets';
  }

  @override
  String weeksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String streakTooltip(Object weeks, Object goal) {
    return 'Trained at least $goal× a week for $weeks in a row';
  }

  @override
  String get today => 'today';

  @override
  String get yesterday => 'yesterday';

  @override
  String daysAgo(Object n) {
    return '$n days ago';
  }

  @override
  String get noTrainingsYet => 'No workouts logged yet.';

  @override
  String streakGoal(Object goal) {
    return 'Goal: $goal× a week';
  }

  @override
  String streakWeeks(Object weeks, Object goal) {
    return '$weeks in a row · $goal× a week';
  }

  @override
  String streakWeekDone(Object done, Object goal) {
    return 'This week done ($done/$goal). Keep it up!';
  }

  @override
  String streakWeekOpen(Object done, Object goal, Object left) {
    return 'This week $done/$goal · $left to go';
  }

  @override
  String streakWeekOpenKeep(Object done, Object goal, Object left) {
    return 'This week $done/$goal · $left more to keep the streak';
  }

  @override
  String get todayButton => 'Today';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String trainingsInMonth(Object count, Object month) {
    return '$count in $month';
  }

  @override
  String get delete => 'Delete';

  @override
  String deleteTrainingAsk(Object date) {
    return 'Delete the workout of $date?';
  }

  @override
  String get deleteTrainingMovesPlan =>
      ' The plan weights go back to where they were before.';

  @override
  String get yes => 'Yes';

  @override
  String get secondsUnit => 's';

  @override
  String get progUp => 'done';

  @override
  String get progUp2 => 'lots in reserve, double step';

  @override
  String get progHalf => '2× at the limit, half a step';

  @override
  String get progLimit => 'at the limit, weight stays';

  @override
  String progBridgeTo(Object reps, Object to) {
    return 'next time $reps reps, more weight at $to';
  }

  @override
  String get progBridge => 'more reps first';

  @override
  String get progRange => 'all reps first';

  @override
  String get progMiss => 'missed';

  @override
  String get progReset => '2× missed, reps back down';

  @override
  String get progBadDay => 'bad day, doesn\'t count';

  @override
  String get progPain =>
      'Pain: weight stays. If it comes back, have the exercise checked.';

  @override
  String progDeload(Object fails) {
    return '$fails× missed, about −10 %, smaller steps';
  }

  @override
  String get progLighter => 'done lighter';

  @override
  String get progFewer => 'fewer sets';

  @override
  String get tagSleptBadly => 'Slept badly';

  @override
  String get tagWellRested => 'Well rested';

  @override
  String get tagSore => 'Sore muscles';

  @override
  String get tagPain => 'Pain';

  @override
  String get tagSick => 'Sick';

  @override
  String get tagStress => 'Stress';

  @override
  String get tagUnmotivated => 'Unmotivated';

  @override
  String get tagEnergetic => 'Full of energy';

  @override
  String get tagAteLittle => 'Ate little';

  @override
  String get tagAlcohol => 'Alcohol';

  @override
  String get tagCaffeine => 'Caffeine';

  @override
  String get tagLittleTime => 'Short on time';

  @override
  String get tagGymBusy => 'Gym busy';

  @override
  String get tagTravelling => 'Travelling';

  @override
  String get tagTechnique => 'Technique focus';

  @override
  String get fileNotFerrolog =>
      'This is not a FerroLog file (app \"ferrolog\" missing).';

  @override
  String get fileNoVersion => 'The file has no valid version.';

  @override
  String fileTooNew(Object version, Object known) {
    return 'The file has version $version, this app only knows up to $known. Please update the app.';
  }

  @override
  String get fileNoData => 'Workouts or trainings are missing from the file.';

  @override
  String fileBroken(Object error) {
    return 'The file is damaged: $error';
  }

  @override
  String get rirLimit => 'at the limit';

  @override
  String rirLeft(Object n) {
    return '$n left';
  }

  @override
  String get platesNotLoadable => 'Can\'t be loaded with your plates';

  @override
  String get platesBarOnly => 'Just the bar';

  @override
  String platesPerSide(Object plates) {
    return 'Per side: $plates';
  }

  @override
  String aboutMinutes(Object n) {
    return '≈ $n min';
  }

  @override
  String everySet(Object taken, Object time) {
    return '$taken · a set every $time min';
  }

  @override
  String get syncConflict =>
      'Conflict: the data on GitHub is newer or from elsewhere';

  @override
  String syncLoginFailed(Object code) {
    return 'GitHub sign-in failed (HTTP $code)';
  }

  @override
  String get syncNoClientId =>
      'githubClientId in lib/sync.dart is not set (see README).';

  @override
  String get syncCodeExpired => 'Code expired, please sign in again.';

  @override
  String get syncDenied => 'Sign-in denied.';

  @override
  String syncLoginError(Object error) {
    return 'GitHub sign-in: $error';
  }

  @override
  String syncDone(Object time) {
    return 'Synced $time';
  }

  @override
  String syncError(Object time, Object error) {
    return 'Error $time: $error';
  }

  @override
  String get syncExpired => 'Sign-in expired, please sign in again';

  @override
  String get syncNoWrite =>
      'No write access – does FerroLog have access to the repo?';

  @override
  String get syncNotFound =>
      'Repo not found – does FerroLog have access to it?';

  @override
  String get recapRecord => 'New record! 🏆';

  @override
  String get recapAllDone => 'All done! 💪';

  @override
  String recapBackoff(Object pct) {
    return '−$pct % after the break';
  }

  @override
  String get recapVolume => 'Volume';

  @override
  String get recapHeaviest => 'Heaviest';

  @override
  String get recapDuration => 'Duration';

  @override
  String get recapTitle => 'Summary';

  @override
  String get editTraining => 'Edit workout';

  @override
  String get recapNextWeight => '  Weight for next time';

  @override
  String get recapHowWasIt => 'How was it?';

  @override
  String get moodBad => 'Bad';

  @override
  String get moodOkay => 'Okay';

  @override
  String get moodGood => 'Good';

  @override
  String bodyWeight(Object unit) {
    return 'Body weight ($unit)';
  }

  @override
  String bodyWeightStale(Object days) {
    return 'Last entered $days days ago. Once a month keeps the statistics up to date.';
  }

  @override
  String get optional => 'Optional';

  @override
  String get bodyWeightSame => 'Same as last time? ± takes it over.';

  @override
  String get recapAddNote => 'Note: sleep, alcohol, stress …';

  @override
  String get recapCircumstances => 'Circumstances';

  @override
  String get recapNoteHint => 'Anything else? (optional)';

  @override
  String get done => 'Done';

  @override
  String get editDayHelp => 'Day of the workout';

  @override
  String get next => 'Next';

  @override
  String get editStartHelp => 'Start';

  @override
  String get ok => 'OK';

  @override
  String get discardChanges => 'Discard changes?';

  @override
  String editStartAt(Object date, Object time) {
    return '$date · start $time';
  }

  @override
  String cardioGoal(Object goal) {
    return 'Cardio · goal $goal';
  }

  @override
  String insteadOf(Object name) {
    return 'instead of $name';
  }

  @override
  String get notDone => 'Not done';

  @override
  String get rirQuestionShort => 'Reps left';

  @override
  String get save => 'Save';

  @override
  String get editReplans => 'The plan weights are recalculated.';

  @override
  String get editHistoryOnly =>
      'Older workouts only change the history and statistics, not the plan.';

  @override
  String get less => 'Less';

  @override
  String get more => 'More';

  @override
  String setOfGoal(Object n, Object total, Object goal) {
    return 'Set $n of $total · goal $goal';
  }

  @override
  String get cardWeekGoal => 'WEEKLY GOAL';

  @override
  String get cardSkipped => 'SKIPPED · LAST 4 WEEKS';

  @override
  String get cardBalance => 'BALANCE · LAST 28 DAYS';

  @override
  String get cardPlateau => 'PLATEAU';

  @override
  String get cardAllGood => 'All good';

  @override
  String get cardSeeStats => ' · see statistics';

  @override
  String get cardTitle => 'Your training';

  @override
  String get cardFromStats => 'from your statistics';

  @override
  String get cardWhyWhat => 'Why and what to do →';

  @override
  String get cardWhy => 'WHY';

  @override
  String get cardAdvice => 'RECOMMENDATION';

  @override
  String fixMoveUp(Object workout) {
    return 'Move up in $workout';
  }

  @override
  String fixDropSet(Object exercise) {
    return '1 set less $exercise';
  }

  @override
  String get fixInEditor => 'Adjust in the editor';

  @override
  String get later => 'Later';

  @override
  String get sourceBalance => 'See balance in the statistics';

  @override
  String get sourceWeeks => 'See weeks in the statistics';

  @override
  String sourceExercise(Object exercise) {
    return 'See $exercise in the statistics';
  }

  @override
  String get sourceHistory => 'See in the history';

  @override
  String fixMovedUp(Object exercise, Object workout) {
    return '$exercise moved up in $workout';
  }

  @override
  String setsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sets',
      one: '1 set',
    );
    return '$_temp0';
  }

  @override
  String fixDroppedSet(Object exercise, Object workout, Object sets) {
    return '$exercise in $workout: now $sets';
  }

  @override
  String get undo => 'Undo';

  @override
  String get finishTrainingFirst => 'Finish the running workout first';

  @override
  String get planTaken => 'Plan taken over';

  @override
  String fileUnreadable(Object error) {
    return 'The file couldn\'t be read: $error';
  }

  @override
  String get planPasteHint =>
      'Paste the JSON code block from the chat or open it as a file. You see every change before saving.';

  @override
  String get openFile => 'Open file (.json, .txt)';

  @override
  String get check => 'Check';

  @override
  String get changeNew => 'New';

  @override
  String get changeRemoved => 'Removed';

  @override
  String get changeChanged => 'Changed';

  @override
  String get changeSame => 'Unchanged';

  @override
  String get planFromAi => 'Plan from AI';

  @override
  String get planStale => 'You trained since the export';

  @override
  String planStaleHint(Object date) {
    return 'The plan is based on the state of $date. The weights may be outdated.';
  }

  @override
  String get planEmpty => 'The plan changes nothing in your workouts.';

  @override
  String planUnchanged(Object names) {
    return 'Unchanged: $names';
  }

  @override
  String get planKeepsTrainings =>
      'Your workouts stay as they are. After taking it over you can undo it once.';

  @override
  String get takeOver => 'Take over';

  @override
  String movedTo(Object n) {
    return 'Now in place $n';
  }

  @override
  String get front => 'Front';

  @override
  String get back => 'Back';

  @override
  String get muscleChest => 'Chest';

  @override
  String get muscleShoulders => 'Shoulders';

  @override
  String get muscleTriceps => 'Triceps';

  @override
  String get muscleBiceps => 'Biceps';

  @override
  String get muscleForearms => 'Forearms';

  @override
  String get muscleLats => 'Lats';

  @override
  String get muscleMiddleBack => 'Middle back';

  @override
  String get muscleLowerBack => 'Lower back';

  @override
  String get muscleTraps => 'Traps';

  @override
  String get muscleNeck => 'Neck';

  @override
  String get muscleAbdominals => 'Abs';

  @override
  String get muscleQuadriceps => 'Quads';

  @override
  String get muscleHamstrings => 'Hamstrings';

  @override
  String get muscleGlutes => 'Glutes';

  @override
  String get muscleCalves => 'Calves';

  @override
  String get muscleAdductors => 'Adductors';

  @override
  String get muscleAbductors => 'Abductors';

  @override
  String get groupChest => 'Chest';

  @override
  String get groupUpperBack => 'Upper back';

  @override
  String get groupShoulders => 'Shoulders';

  @override
  String get groupLats => 'Lats';

  @override
  String get groupFrontDelts => 'Front delts';

  @override
  String get groupRearDelts => 'Rear delts';

  @override
  String get groupQuads => 'Quads';

  @override
  String get groupHamstrings => 'Hamstrings';

  @override
  String get groupInternalRot => 'Internal rotation';

  @override
  String get groupExternalRot => 'External rotation';

  @override
  String get groupAbs => 'Abs';

  @override
  String get groupLowerBack => 'Lower back';

  @override
  String get objChest => 'the chest';

  @override
  String get objUpperBack => 'the upper back';

  @override
  String get objShoulders => 'the shoulders';

  @override
  String get objLats => 'the lats';

  @override
  String get objFrontDelts => 'the front delts';

  @override
  String get objRearDelts => 'the rear delts';

  @override
  String get objQuads => 'the quads';

  @override
  String get objHamstrings => 'the hamstrings';

  @override
  String get objInternalRot => 'internal rotation';

  @override
  String get objExternalRot => 'external rotation';

  @override
  String get objAbs => 'the abs';

  @override
  String get objLowerBack => 'the lower back';

  @override
  String get sidePush => 'pressing';

  @override
  String get sideRow => 'rowing';

  @override
  String get sideOverhead => 'overhead pressing';

  @override
  String get sidePullUps => 'pull-ups, pulldowns';

  @override
  String get sideFrontDelts => 'front delts';

  @override
  String get sideRearDelts => 'rear delts';

  @override
  String get sideQuads => 'quads';

  @override
  String get sideHamstrings => 'hamstrings';

  @override
  String get sideInternalRot => 'internal rotation';

  @override
  String get sideExternalRot => 'external rotation';

  @override
  String get sideAbs => 'abs';

  @override
  String get sideLowerBack => 'lower back';

  @override
  String get notePressHalf => 'presses count half';

  @override
  String get noteHingeSquatHalf => 'deadlifts and squats count half';

  @override
  String get ratioRowBench => 'Row : bench press';

  @override
  String get ratioHingeSquat => 'Deadlift : squat';

  @override
  String weekDaysLeft(Object n) {
    return '$n days left';
  }

  @override
  String get weekTomorrowLast => 'tomorrow is the last day';

  @override
  String get weekTodayLast => 'today is the last day';

  @override
  String weekTitle(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n more workouts this week',
      one: '1 more workout this week',
    );
    return '$_temp0';
  }

  @override
  String weekEvidence(Object done, Object goal, Object when) {
    return '$done of $goal done, $when';
  }

  @override
  String weekWhy(Object goal) {
    return 'Your weekly goal is $goal workouts.';
  }

  @override
  String get weekAdviceDays =>
      'One workout in the next few days keeps the streak.';

  @override
  String get weekAdviceTomorrow => 'One workout tomorrow keeps the streak.';

  @override
  String get weekAdviceToday => 'One workout today keeps the streak.';

  @override
  String get skippedEndAlways => ', each time as the last exercise';

  @override
  String get skippedEndMostly => ', mostly as the last exercise';

  @override
  String skippedConsequence(Object evidence) {
    return ' Effect on the balance: $evidence.';
  }

  @override
  String skippedTitle(Object name, Object n) {
    return '$name skipped $n×';
  }

  @override
  String skippedEvidence(Object end) {
    return 'In 4 weeks$end';
  }

  @override
  String skippedWhy(Object n, Object of, Object end, Object consequence) {
    return 'Left out entirely in $n of $of workouts$end.$consequence';
  }

  @override
  String skippedAdviceMove(Object name) {
    return 'Move $name before the accessories. Same volume, it just no longer falls off the end.';
  }

  @override
  String skippedAdvice(Object name) {
    return 'Plan $name earlier in the workout or take it out of the plan on purpose.';
  }

  @override
  String get remedyRearDelts => 'face pulls or reverse flyes';

  @override
  String get remedyAbs => 'plank or ab wheel';

  @override
  String get remedyNoteExternal =>
      ' Face pulls cover both: external rotation and rear delts. Plan them at the end of an upper-body workout.';

  @override
  String get remedyNoteRearDelts =>
      ' Face pulls cover both: rear delts and external rotation.';

  @override
  String balanceAdviceEarlier(Object side) {
    return 'Planned it\'s balanced, but sets get left out. Plan $side earlier in the workout.';
  }

  @override
  String balanceAdviceDrop(Object exercise, Object workout) {
    return 'One set less $exercise in $workout balances it, without more work.';
  }

  @override
  String balanceAdviceKeep(Object exercise) {
    return 'Main lifts stay as planned, don\'t skip $exercise and keep progressing.';
  }

  @override
  String balanceAdviceNothing(Object group) {
    return 'Nothing in the plan trains $group directly.';
  }

  @override
  String balanceAdviceSuggest(Object group, Object suggest, Object note) {
    return 'Nothing in the plan trains $group directly, for example $suggest.$note';
  }

  @override
  String balanceEvidence(
    Object ratio,
    Object a,
    Object aValue,
    Object b,
    Object bValue,
  ) {
    return '$ratio · $a $aValue : $b $bValue sets/week';
  }

  @override
  String balanceWhy(Object a, Object b, Object range, Object note) {
    return '$a against $b, guide $range. Counted are the sets done in the last 28 days$note.';
  }

  @override
  String balanceTitle(Object group) {
    return '$group falls short';
  }

  @override
  String guideFrom(Object pct) {
    return 'from $pct %';
  }

  @override
  String plateauDeloadAfter(Object n, Object fails) {
    return 'Automatic deload after $n misses in a row (so far $fails).';
  }

  @override
  String get plateauDeloadOff => 'Automatic deload is off.';

  @override
  String plateauTitle(Object name, Object weight) {
    return '$name stuck at $weight';
  }

  @override
  String plateauEvidence(Object n) {
    return '$n workouts without an increase';
  }

  @override
  String get plateauLighter =>
      'Did a set lighter last time, that holds the weight.';

  @override
  String plateauReserve(Object n) {
    return 'Last time $n more reps were left.';
  }

  @override
  String get plateauReserveMany => '4 or more';

  @override
  String get plateauLimit => 'The last 2 workouts at the limit, no rep left.';

  @override
  String get plateauAdviceTechnique =>
      'The weight isn\'t the limit: check technique, focus and enough rest, and push the sets. No deload needed.';

  @override
  String get plateauAdviceDeload =>
      'Twice at the limit: a deload of about 10 % helps, then build back up.';

  @override
  String get plateauAdviceHold =>
      'Hold the weight, mind clean technique and enough rest. If it doesn\'t work within 2 workouts, a deload can help.';

  @override
  String recordTitle(Object name, Object weight) {
    return 'Record: $name $weight';
  }

  @override
  String get recordEvidence => 'Heavier than ever before';

  @override
  String gainTitle(Object name, Object from, Object to) {
    return 'Progress: $name $from → $to';
  }

  @override
  String since(Object date) {
    return 'Since $date';
  }

  @override
  String milestoneTitle(Object n) {
    return 'Workout no. $n done';
  }

  @override
  String monthTitle(Object n) {
    return 'Record month: $n workouts';
  }

  @override
  String get monthEvidence => 'More than ever before';

  @override
  String get programFullBodyStrength => 'Full Body Strength';

  @override
  String get programFullBodyNote =>
      'Every workout the same, 1–3× a week, 48–72 h of recovery in between. Stick with it for 8–12 weeks.';

  @override
  String get programStrongLiftsNote => 'A and B alternating, 3× a week.';

  @override
  String get programPpl => 'Push/Pull/Legs';

  @override
  String get dayLegs => 'Legs';

  @override
  String get programUpperLower => 'Upper/Lower';

  @override
  String get dayUpper => 'Upper body';

  @override
  String get dayLower => 'Lower body';

  @override
  String get programFullBody => 'Full body';

  @override
  String get replaceExercisesAsk =>
      'Replace your changes to the exercise list?';

  @override
  String get newWorkout => 'New workout';

  @override
  String get editWorkout => 'Edit workout';

  @override
  String get deleteWorkout => 'Delete workout';

  @override
  String deleteWorkoutAsk(Object name) {
    return 'Delete “$name”? The history is kept.';
  }

  @override
  String get name => 'Name';

  @override
  String example(Object value) {
    return 'e.g. $value';
  }

  @override
  String get workoutA => 'Workout A';

  @override
  String fixedSteps(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n exercises progress in fixed steps',
      one: '1 exercise progresses in fixed steps',
    );
    return '$_temp0';
  }

  @override
  String get allAuto => 'All automatic';

  @override
  String get exercise => 'Exercise';

  @override
  String cardioLine(Object goal) {
    return 'Cardio · $goal';
  }

  @override
  String get auto => 'automatic';

  @override
  String onSuccess(Object weight) {
    return '+$weight on success';
  }

  @override
  String get removeExercise => 'Remove exercise';

  @override
  String get template => 'Template';

  @override
  String get custom => 'Custom';

  @override
  String get customHint => 'Add your exercises below with “+ Exercise”.';

  @override
  String transferAsk(Object from, Object to) {
    return 'Transfer the history from “$from” to “$to”?';
  }

  @override
  String transferHint(Object to, Object from) {
    return 'Transfer: statistics, records and workouts continue under “$to”, in other workouts too. New exercise: “$to” starts without history, “$from” stays in the history as it was.';
  }

  @override
  String get newExercise => 'New exercise';

  @override
  String get transfer => 'Transfer';

  @override
  String get set => 'Set';

  @override
  String setOf(Object n, Object total) {
    return 'Set $n of $total';
  }

  @override
  String get seconds => 'Seconds';

  @override
  String get secondsAtLeast => 'Seconds at least';

  @override
  String get reps => 'Reps';

  @override
  String get repsAtLeast => 'Reps at least';

  @override
  String weightIn(Object unit) {
    return 'Weight ($unit)';
  }

  @override
  String get assistHint =>
      'Below 0: assistance, e.g. on a pull-up machine. Progressing means less help, towards 0.';

  @override
  String get thisSet => 'This set';

  @override
  String get allSets => 'All sets';

  @override
  String get deleteSet => 'Delete set';

  @override
  String get close => 'Close';

  @override
  String get muscles => 'Muscles';

  @override
  String get unknownExercise =>
      'Unknown exercise: without muscles it\'s missing from the balance and the muscle map. Please tap what it trains.';

  @override
  String get musclesHint =>
      'Tap: main muscle ✓ → helps with ½ → off. For the statistics.';

  @override
  String get addExercise => 'Add exercise';

  @override
  String get editExercise => 'Edit exercise';

  @override
  String get add => 'Add';

  @override
  String get searchExercise => 'Search an exercise or type your own';

  @override
  String get duplicateExercise =>
      'Already in this workout. For more sets or other weights per set, edit the existing one.';

  @override
  String get noMatch => 'No match – your own name is used';

  @override
  String defaultsFrom(Object name) {
    return 'Defaults for $name filled in';
  }

  @override
  String get strength => 'Strength';

  @override
  String get cardio => 'Cardio';

  @override
  String get durationGoal => 'Duration';

  @override
  String get distance => 'Distance';

  @override
  String goalIn(Object unit) {
    return 'Goal ($unit)';
  }

  @override
  String get goalMinutes => 'Goal (min)';

  @override
  String get withWeight => 'With weight';

  @override
  String get withoutWeight => 'Without weight';

  @override
  String get time => 'Time';

  @override
  String get sets => 'Sets';

  @override
  String get tapSetToChange => 'Tap a set to change it';

  @override
  String get thisTrainingTap => 'This workout · tap to change';

  @override
  String get nextTrainingTap => 'Next workout · tap to change';

  @override
  String get timeRange => 'Time range';

  @override
  String get repRange => 'Rep range';

  @override
  String get rangeOffTime => 'Off · fixed time';

  @override
  String get rangeOffReps => 'Off · fixed reps';

  @override
  String rangeOnSeconds(Object sets, Object top) {
    return '$sets · weight only goes up when all sets reach $top s';
  }

  @override
  String rangeOnReps(Object sets, Object top) {
    return '$sets · weight only goes up when all sets reach $top reps';
  }

  @override
  String get upToSeconds => 'Up to seconds';

  @override
  String get upToReps => 'Up to reps';

  @override
  String get rest => 'Rest';

  @override
  String get minSecOrSec => 'min:s or s';

  @override
  String get afterMissedSet => 'After a missed set';

  @override
  String get sameAsAbove => 'Same as above';

  @override
  String get adjustWeight => 'Adjust weight';

  @override
  String get automatic => 'Automatic';

  @override
  String get fixed => 'Fixed';

  @override
  String get loadStep => 'Load step';

  @override
  String get increaseOnSuccess => 'Increase on success';

  @override
  String increaseOn(Object weight) {
    return '+$weight when all sets are done';
  }

  @override
  String get offWeightStays => 'Off · weight stays the same';

  @override
  String get decreaseOnMiss => 'Decrease on a miss';

  @override
  String decreaseOn(Object weight, Object n) {
    return '−$weight after $n× missed';
  }

  @override
  String get decreaseAfter => 'Decrease after misses in a row';

  @override
  String summaryCardio(Object name, Object goal) {
    return '$name: goal $goal. In the workout you start the stopwatch with a tap.';
  }

  @override
  String planNoWeight(Object sets) {
    return '$sets without weight';
  }

  @override
  String planWithWeight(Object sets, Object weight) {
    return '$sets with $weight';
  }

  @override
  String summaryTraining(Object name, Object plan) {
    return '$name: $plan. Only for this workout, the plan stays as it is.';
  }

  @override
  String summaryPlain(Object name, Object plan) {
    return '$name: $plan.';
  }

  @override
  String summaryAuto(Object name, Object plan) {
    return '$name: $plan. The weight adjusts automatically.';
  }

  @override
  String summaryUp(Object weight) {
    return 'On success +$weight.';
  }

  @override
  String summaryDown(Object n, Object weight) {
    return 'After $n× missed −$weight.';
  }

  @override
  String get summaryFixed => 'The weight isn\'t adjusted automatically.';

  @override
  String get autoRuleDone =>
      'Done: about 2.5 % more, double with 3 or more reps in reserve, at the limit it stays (the second time in a row half a step).';

  @override
  String get autoRuleBridge =>
      'If the step is too small to load, it goes via reps first.';

  @override
  String get autoRuleRange => 'Only once all sets are at the top of the range.';

  @override
  String autoRuleMiss(Object n) {
    return 'Missed: weight stays, after $n× in a row about −10 % and smaller steps afterwards, which grow again with reserve.';
  }

  @override
  String get autoRuleBadDay =>
      'Sick, slept badly, stress or ate little don\'t count (at most 2× in a row), after a 2-week break you start lighter. The reserve is asked after every exercise.';

  @override
  String autoNow(Object pct, Object step, Object source) {
    return 'Currently +$pct % per workout · load step $step ($source)';
  }

  @override
  String get sourcePlates => 'your plates';

  @override
  String get sourceLearned => 'from your weights';

  @override
  String get sourceGuess => 'starting value, learns along';

  @override
  String get sourceSet => 'set';

  @override
  String get own => 'Own';

  @override
  String leftAbout(Object about) {
    return '$about left';
  }

  @override
  String doneAround(Object time) {
    return 'done around $time';
  }

  @override
  String get alreadyInTraining => 'Already in the workout';

  @override
  String get kindStays => 'After the first set the kind stays as it is';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get remove => 'Remove';

  @override
  String get noSetsDiscard => 'No sets logged. Discard the workout?';

  @override
  String get notAllSetsFinish => 'Not all sets done. Finish anyway?';

  @override
  String get discard => 'Discard';

  @override
  String get finish => 'Finish';

  @override
  String get stripPickUp => 'PICK UP';

  @override
  String get stripHold => 'HOLD';

  @override
  String holdGoal(Object goal) {
    return 'Goal $goal s';
  }

  @override
  String get stop => 'Stop';

  @override
  String get pause => 'Pause';

  @override
  String get resumeRest => 'Resume';

  @override
  String get restart => 'Restart';

  @override
  String restOf(Object time) {
    return 'of $time';
  }

  @override
  String restGoal(Object time) {
    return 'Goal $time';
  }

  @override
  String get stripPaused => 'PAUSED';

  @override
  String get stripRest => 'REST';

  @override
  String get stripSoon => 'ALMOST';

  @override
  String get stripGo => 'GO';

  @override
  String get stripLate => 'OVER';

  @override
  String get rirQuestion => 'How many reps were left?';

  @override
  String restLine(Object time) {
    return 'Rest $time';
  }

  @override
  String get now => 'NOW';

  @override
  String warmup(Object sets) {
    return 'Warm-up: $sets';
  }

  @override
  String get startStopwatch => ' Start';

  @override
  String get enterDistance => 'Enter distance';

  @override
  String rangeDone(Object goal) {
    return '$goal done · heavier next time';
  }

  @override
  String rangeIncreaseAt(Object goal) {
    return 'Increase at $goal';
  }

  @override
  String rangeAllTop(Object goal) {
    return 'Increase at $goal · all at the top so far';
  }

  @override
  String rangeMissingReps(Object goal, Object n) {
    return 'Increase at $goal · $n reps to go';
  }

  @override
  String rangeMissingSeconds(Object goal, Object n) {
    return 'Increase at $goal · $n s to go';
  }

  @override
  String weightBetween(Object min, Object max) {
    return 'Weight between $min and $max';
  }

  @override
  String get applyTo => 'Apply to';

  @override
  String get openSets => 'Open sets';

  @override
  String get minutesUnit => 'min';

  @override
  String get distanceOptional => 'Distance (optional)';

  @override
  String hintsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hints',
      one: '1 hint',
    );
    return '$_temp0';
  }

  @override
  String pairsBalanced(Object ok, Object total) {
    return '  · $ok of $total balanced';
  }

  @override
  String get allPairsBalanced => 'All muscle pairs balanced';

  @override
  String get balanceScaleHint =>
      'The dot points to the side with more sets. In the light field it\'s balanced. Tap a pair for advice and numbers.';

  @override
  String get strengthTrend => 'Strength over time';

  @override
  String get trendUp => '↗ rising';

  @override
  String get trendDown => '↘ falling';

  @override
  String get trendFlat => '→ steady';

  @override
  String get strengthTrendHint =>
      'Ratio of the estimated 1RM over 90 days. Shows your development, not a comparison with literature values.';

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
    return '$a $aSets · $b $bSets sets per week$note. $group at $ratio, guide $range.';
  }

  @override
  String get balanced => '✓ Balanced';

  @override
  String verdictSlightly(Object strong, Object weak) {
    return '$strong trained slightly more than $weak';
  }

  @override
  String verdictClearly(Object strong, Object weak) {
    return '$strong trained clearly more than $weak';
  }

  @override
  String get balanceInfoTitle => 'Balance: what\'s behind it';

  @override
  String get infoProven => 'What\'s proven';

  @override
  String get infoProven1 =>
      'More sets per muscle and week bring more muscle growth, graded by under 5, 5–9 and 10+ sets [1].';

  @override
  String get infoProven2 =>
      'Counting helper muscles partly captures the volume more accurately: 5 sets of curls and 5 sets of rows make 7.5 biceps sets [2].';

  @override
  String get infoUncertain => 'What\'s uncertain';

  @override
  String get infoUncertain1 =>
      'Whether imbalances between pushing and pulling raise the risk of injury hasn\'t been studied.';

  @override
  String get infoUncertain2 =>
      'For the ratio of hamstrings to quads there is only very limited evidence as a risk factor [3].';

  @override
  String get infoUncertain3 =>
      'That\'s why FerroLog shows hints, not warnings.';

  @override
  String get infoGuides => 'Where the guide values come from';

  @override
  String get infoGuides1 =>
      'Push : pull 1:1 to 1:1.5 is a coaching recommendation, not a study value. Rules like 2:1 or 3:1 are rules of thumb [4].';

  @override
  String get infoGuides2 =>
      'Hamstrings from 60 % leans on lab measurements (H:Q > 0.6) [5]. They come from isokinetics and don\'t carry over directly to squats and deadlifts.';

  @override
  String get infoGuides3 =>
      'Recreational athletes press 1.5 to 2.7 times as much as they pull in tests [6].';

  @override
  String get infoGuides4 =>
      'At the shoulder, external rotation is 86–99 % of internal rotation in strength tests [7]. There is no study value for sets, the guide is set low on purpose.';

  @override
  String get infoGuides5 =>
      'For abs and lower back, studies disagree on which side is weaker with back pain [8, 9]. The guide is therefore wide and symmetrical.';

  @override
  String get infoMath => 'How FerroLog calculates';

  @override
  String get infoMath1 =>
      'Every exercise counts fully for its main group and half for helper muscles.';

  @override
  String get infoMath2 =>
      'Sets per week, averaged over the last 28 days, as a ratio per pair.';

  @override
  String get infoMath3 =>
      'Strength ratios (estimated 1RM) only as a trend, not against literature values.';

  @override
  String get infoMath4 => 'You can adjust all guide values.';

  @override
  String get infoScale => 'How to read the scale';

  @override
  String get infoScale1 =>
      'The dot points to the side that gets more sets. In the light field in the middle the pair is within its guide.';

  @override
  String get infoScale2 =>
      'The guide comes from training practice and is no medical limit. Helper muscles count half.';

  @override
  String get adjustGuides => 'Adjust guide values';

  @override
  String get sources => 'SOURCES';

  @override
  String get guides => 'Guide values';

  @override
  String get guidesHint =>
      'Right side relative to the left side, in percent of the sets.';

  @override
  String get resetDefaults => 'Reset to defaults';

  @override
  String get sourceShoulderNorms =>
      'Hand-held dynamometer norms, shoulder rotation';

  @override
  String get sourceTrunk => 'Trunk endurance flexion/extension (MMU)';

  @override
  String get piNoJson =>
      'No JSON found. Copy the whole code block from the chat.';

  @override
  String piBrokenJson(Object error) {
    return 'The JSON is incomplete or broken: $error';
  }

  @override
  String get piIsExport =>
      'This is an export with all data, not a plan. Take the JSON block from the AI\'s answer.';

  @override
  String get piNotPlan =>
      'This is not a FerroLog plan (app \"ferrolog\", kind \"plan\" missing).';

  @override
  String piVersion(Object v) {
    return 'This app doesn\'t know version $v.';
  }

  @override
  String get piNoWorkouts => 'The plan contains no workouts.';

  @override
  String piWorkoutNotObject(Object n) {
    return 'Workout $n is not an object.';
  }

  @override
  String piWorkoutTwice(Object id) {
    return 'Workout $id is in the plan twice.';
  }

  @override
  String piDeleteMissing(Object name) {
    return 'The workout to delete ($name) doesn\'t exist.';
  }

  @override
  String piWorkoutNoName(Object n) {
    return 'Workout $n has no name.';
  }

  @override
  String piNoExercises(Object name) {
    return '“$name” has no exercises.';
  }

  @override
  String piExerciseWhere(Object name, Object n) {
    return '“$name”, exercise $n';
  }

  @override
  String piExerciseTwice(Object name, Object exercise) {
    return '“$name” has “$exercise” twice. More sets or setWeights instead of a second exercise.';
  }

  @override
  String piNotObject(Object where) {
    return '$where is not an object.';
  }

  @override
  String piNoName(Object where) {
    return '$where has no name.';
  }

  @override
  String piQuoted(Object name) {
    return '“$name”';
  }

  @override
  String piNotInt(Object label, Object key) {
    return '$label: \"$key\" is missing or not a whole number.';
  }

  @override
  String piNoWeight(Object label) {
    return '$label: \"weight\" is missing.';
  }

  @override
  String piBadType(Object label, Object type) {
    return '$label: type \"$type\" doesn\'t exist.';
  }

  @override
  String piBadSets(Object label) {
    return '$label: sets or reps invalid.';
  }

  @override
  String piSetWeights(Object label, Object n) {
    return '$label: setWeights doesn\'t match $n sets.';
  }

  @override
  String piSetReps(Object label, Object n) {
    return '$label: setReps doesn\'t match $n sets.';
  }

  @override
  String piMaxReps(Object label) {
    return '$label: maxReps must be above reps.';
  }

  @override
  String piMinWeight(Object label, Object min) {
    return '$label: weight below $min kg.';
  }

  @override
  String piBadMuscle(Object label, Object muscle) {
    return '$label: muscle \"$muscle\" doesn\'t exist.';
  }

  @override
  String get aspectName => 'Name';

  @override
  String get aspectKind => 'Kind';

  @override
  String get aspectWeight => 'Weight';

  @override
  String get aspectIncrease => 'Increase';

  @override
  String get aspectDeload => 'Deload';

  @override
  String get off => 'off';

  @override
  String deloadAfter(Object weight, Object n) {
    return '−$weight after $n misses';
  }

  @override
  String restAfterMiss(Object s) {
    return 'after a miss $s s';
  }

  @override
  String get timedKind => 'timed';

  @override
  String get noWeightShort => 'without weight';

  @override
  String get days30 => '30 days';

  @override
  String get days90 => '90 days';

  @override
  String get year1 => '1 year';

  @override
  String get allTime => 'All';

  @override
  String get statsEmpty => 'Statistics come after the first workout.';

  @override
  String get noTrainingInPeriod => 'No workout in this period.';

  @override
  String get background => 'Background';

  @override
  String get strengthProgress => 'Strength progress';

  @override
  String get chartWeightHint =>
      'Working weight as the progression sets it; dips are deloads. ▲ = setback.';

  @override
  String get chartE1rmHint =>
      'Change of the estimated 1RM (from all sets) since the first workout in the period, the baseline. ▲ = setback: less done than last time or than once before at this weight.';

  @override
  String get exercises => 'Exercises';

  @override
  String get statusLast4Weeks => 'Status: last 4 weeks';

  @override
  String exercisesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n exercises',
      one: '1 exercise',
    );
    return '$_temp0';
  }

  @override
  String stuckCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n stuck',
      one: '1 stuck',
    );
    return '$_temp0';
  }

  @override
  String get perWeek => 'Per week';

  @override
  String goalWeeksHit(Object goal, Object hit, Object weeks) {
    return 'Goal $goal · $hit of $weeks weeks';
  }

  @override
  String get avgDuration => 'Ø duration';

  @override
  String volumeVsBefore(Object delta) {
    return '$delta % vs. the period before';
  }

  @override
  String get withRecord => 'With record';

  @override
  String xOfY(Object x, Object y) {
    return '$x of $y';
  }

  @override
  String get noNewBest => 'no new best weight';

  @override
  String get week => 'week';

  @override
  String get month => 'month';

  @override
  String get trainingsPerWeek => 'Workouts per week';

  @override
  String lineGoalWeek(Object goal) {
    return 'Line: goal $goal× a week';
  }

  @override
  String lineGoalMonth(Object goal) {
    return 'Average per month · line: goal $goal× a week';
  }

  @override
  String minutesPerTrainingAvg(Object per) {
    return 'Minutes per workout, average per $per · line: average in the period';
  }

  @override
  String tonnesPer(Object per) {
    return 'Tonnes per $per';
  }

  @override
  String kLbPer(Object per) {
    return 'Thousand lb per $per';
  }

  @override
  String get records => 'Records';

  @override
  String recordsPer(Object per) {
    return 'New best weights per $per, across all exercises';
  }

  @override
  String balanceDaysLabel(Object n) {
    return '$n days';
  }

  @override
  String get setsPerMuscle => 'Sets per muscle';

  @override
  String get perWeekLower => 'per week';

  @override
  String notTrained(Object names) {
    return 'Not trained: $names';
  }

  @override
  String musclesUnder10(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n muscles under 10 sets',
      one: '1 muscle under 10 sets',
    );
    return '$_temp0';
  }

  @override
  String get tapMuscle => 'Tap a muscle for its exercises';

  @override
  String get under5 => 'under 5';

  @override
  String get over20 => 'over 20';

  @override
  String get muscleBarsHint =>
      'Bars: sets per week. Band 10–20: the usual range for muscle growth. Orange: under 10.';

  @override
  String get musclesNote =>
      'Strength programs like 5×5 leave out muscles on purpose. Helper muscles count half.';

  @override
  String setsPerWeek(Object n) {
    return '$n sets per week';
  }

  @override
  String get noExerciseForMuscle =>
      'No exercise in the period trains this muscle.';

  @override
  String setsN(Object n) {
    return '$n sets';
  }

  @override
  String get cardioPerWeek => 'Cardio per week';

  @override
  String get minutesTitle => 'Minutes';

  @override
  String avgMinPerWeek(Object n) {
    return 'Ø $n min per week';
  }

  @override
  String lineCardioTotal(Object n, Object cardio) {
    return '$n · $cardio total';
  }

  @override
  String lineSets(Object n, Object sets) {
    return '$n · $sets';
  }

  @override
  String lineSetsUpTo(Object n, Object sets, Object weight) {
    return '$n · $sets · up to $weight';
  }

  @override
  String lineSetsLast(Object n, Object sets, Object weight) {
    return '$n · $sets · last $weight';
  }

  @override
  String lineVolume(Object n, Object volume) {
    return '$n · total $volume';
  }

  @override
  String get trendNew => 'new';

  @override
  String get trendRising => 'rising';

  @override
  String get trendSteady => 'steady';

  @override
  String get trendStuck => 'stuck';

  @override
  String mergeWith(Object name) {
    return 'Merge “$name” with';
  }

  @override
  String get noOtherExercise => 'No other exercise with history.';

  @override
  String mergeAsk(Object name, Object target) {
    return 'All workouts of “$name” will then be called “$target”, in the plans too. This can\'t be undone.';
  }

  @override
  String get mergeMenu => 'Merge with another exercise';

  @override
  String skippedOn(Object dates) {
    return 'Skipped on $dates';
  }

  @override
  String get weight => 'Weight';

  @override
  String bestE1rm(Object weight) {
    return 'Best 1RM $weight';
  }

  @override
  String measureWeightHint(Object unit) {
    return 'Working weight ($unit). ▲ = setback.';
  }

  @override
  String measureE1rmHint(Object unit) {
    return 'Estimated 1RM from all sets ($unit). ▲ = setback.';
  }

  @override
  String measureVolumeHint(Object unit) {
    return 'Volume: weight × reps ($unit). ▲ = setback.';
  }

  @override
  String get minutesPerTraining => 'Minutes per workout';

  @override
  String cardioTotal(Object minutes, Object trainings) {
    return 'Total: $minutes in $trainings';
  }
}
