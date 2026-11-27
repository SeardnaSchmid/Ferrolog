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
  String get settingsSoundHint =>
      'Countdown and a long beep when the rest reaches 0';

  @override
  String get settingsVibrate => 'Vibration';

  @override
  String get settingsVibrateHint =>
      'Vibrate with every beep, also without sound';

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
  String get progUp => 'goal reached';

  @override
  String get progUp2 => 'lots in reserve, double step';

  @override
  String get progHalf => '2× at the limit, half a step';

  @override
  String get progLimit => 'weight held';

  @override
  String get progBridge => 'more reps first';

  @override
  String get progRange => 'all reps first';

  @override
  String get progMiss => 'goal not reached in every set';

  @override
  String get progReset => '2× missed, reps back down';

  @override
  String get progBadDay => 'bad day, doesn\'t count';

  @override
  String get progPain =>
      'Pain: weight stays. If it comes back, have the exercise checked.';

  @override
  String progDeload(Object fails) {
    return 'Reduced after $fails workouts without reaching the goal';
  }

  @override
  String get progLighter => 'Lighter than planned today';

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
    return '$n reps in reserve';
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
  String get adjustWeight => 'Weight and progression';

  @override
  String get autoRangeTitle => 'Rep or time range';

  @override
  String get autoWeightTitle => 'Increase the weight';

  @override
  String get autoBridgeTitle => 'Add reps at the same weight';

  @override
  String get autoDeloadTitle => 'Reduce the weight';

  @override
  String get autoHelp => 'How Auto works';

  @override
  String get autoHintReps => 'Auto uses your reps in reserve.';

  @override
  String get autoHintTimed => 'Auto increases the weight in small steps.';

  @override
  String get automatic => 'Automatic';

  @override
  String get fixed => 'Fixed';

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
  String get autoRuleRange =>
      'Auto checks for an increase once every set reaches the top of the range.';

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
  String get stripWaitingForPulse => 'WAITING FOR HEART RATE';

  @override
  String simulatedPulse(int bpm) {
    return '$bpm bpm (sim.)';
  }

  @override
  String pulseRestTarget(int bpm) {
    return 'Below $bpm bpm or at 0:00';
  }

  @override
  String get pulseSensor => 'Connect heart rate sensor';

  @override
  String get pulseDisconnect => 'Disconnect heart rate sensor';

  @override
  String get pulseSearching => 'Searching for heart rate sensors…';

  @override
  String get pulseChooseSensor => 'Select your heart rate sensor.';

  @override
  String get pulseNoDevices =>
      'No sensor found. Enable heart rate broadcast on your sensor.';

  @override
  String get pulseScanFailed =>
      'Bluetooth scan failed. Check Bluetooth and app permissions.';

  @override
  String get pulseConnectFailed =>
      'Could not connect to the heart rate sensor.';

  @override
  String get pulseNoSignal => 'Heart rate: no signal';

  @override
  String livePulse(int bpm) {
    return '$bpm bpm';
  }

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
  String get startStopwatch => ' Start';

  @override
  String get enterDistance => 'Enter distance';

  @override
  String rangeGoalDone(String goal) {
    return '$goal done';
  }

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
      'In the shaded area the pair is balanced. Tap a pair for its history and details.';

  @override
  String get balanceHistory => 'Balance history';

  @override
  String balanceHistoryGuide(Object range) {
    return 'Target range · $range';
  }

  @override
  String balanceHistoryHint(Object days) {
    return 'Weekly snapshots of the previous $days days. Tap a point to see its ratio.';
  }

  @override
  String get balanceHistoryNoSets => 'No sets for either group';

  @override
  String balanceImbalance(Object group) {
    return 'Imbalance · $group below guide';
  }

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
  String get infoGuideRanges =>
      'FerroLog uses adjustable target ranges for the ratio of completed sets.';

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
      'The shaded band marks the target range. Outside the band, the dot points toward the side with more sets relative to the guide.';

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
  String musclesBelowReference(Object names) {
    return 'Under 10 sets per week · $names';
  }

  @override
  String get muscleBarsHint =>
      'Green marks the muscle growth reference range of 10–20 sets per week.';

  @override
  String get muscleVolumeInfoTitle => 'Why 10–20 sets?';

  @override
  String get muscleVolumeInfoEvidence =>
      'Research finds more muscle growth on average with more weekly sets, with diminishing returns at higher volumes. Fewer sets can still work. In one study with trained men, biceps thickness increased with nine sets per week.';

  @override
  String get muscleVolumeInfoRange =>
      '10–20 sets per muscle per week is a rough reference. A review suggested 12–20 sets for young, trained men, with different results by muscle group. The volume that suits you also depends on training experience, effort, and recovery.';

  @override
  String get muscleGoal => 'Personal weekly goal';

  @override
  String get muscleGoalInput => 'Sets per week';

  @override
  String get muscleGoalHelp => 'Leave blank to remove the goal.';

  @override
  String get muscleGoalInvalid => 'Enter a whole number greater than zero.';

  @override
  String muscleGoalValue(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sets',
      one: '1 set',
    );
    return 'Weekly goal · $_temp0';
  }

  @override
  String get muscleGoalReached => '✓ Weekly goal reached';

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
  String get trendDeclining => 'falling';

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

  @override
  String get notifyAllDone => 'All sets done';

  @override
  String get notifyFinishHint => 'Don\'t forget to finish the workout';

  @override
  String notifySetTitle(String name, int set, int sets) {
    return '$name · set $set/$sets';
  }

  @override
  String notifyRestPaused(String time) {
    return 'Rest paused ($time)';
  }

  @override
  String get notifyRestOver => 'Rest over';

  @override
  String get notifyRestSoon => '30 seconds of rest left';

  @override
  String get notifyChannelTraining => 'Running workout';

  @override
  String get notifyChannelRest => 'Rest over';

  @override
  String get notifyChannelReminders => 'Reminders';

  @override
  String notifyStreakTitle(String weeks) {
    return 'Streak of $weeks at risk';
  }

  @override
  String get notifyStreakLastDay =>
      'Today is the last day for your weekly goal.';

  @override
  String notifyStreakDays(int n) {
    return '$n workouts in $n days: one every day from today.';
  }

  @override
  String notifyBreakTitle(int days) {
    return 'No workout for $days days';
  }

  @override
  String get notifyBreakText => 'A short workout gets you back in.';

  @override
  String notifyBreakNext(String workout) {
    return 'Next up: $workout';
  }

  @override
  String get settingsNotify => 'Notifications';

  @override
  String get settingsNotifyTraining => 'Running workout';

  @override
  String get settingsNotifyTrainingHint =>
      'Next set and rest as a notification, a signal at the end of the rest even with the phone locked';

  @override
  String get settingsNotifyStreak => 'Weekly goal at risk';

  @override
  String get settingsNotifyStreakHint =>
      'Reminds you on the last day the weekly goal can still be made';

  @override
  String get settingsNotifyBreak => 'Long break';

  @override
  String get settingsNotifyBreakHint =>
      'Reminds you 7 and 14 days after the last workout';

  @override
  String get notifyChannelRestSilent => 'Rest over (no sound)';

  @override
  String get loadStep => 'Smallest weight step';

  @override
  String get loadStepHint =>
      'What is the smallest change to the total weight for this exercise? With 1.25 kg per side, enter 2.5 kg.';

  @override
  String loadStepSuggested(String step) {
    return 'Suggested: $step';
  }

  @override
  String fixedStepUnavailable(String step) {
    return 'Disabled options are unavailable with a weight step of $step.';
  }

  @override
  String fixedStepChoose(String step) {
    return 'Choose $step or a whole multiple of it.';
  }

  @override
  String progBridgeTarget(int reps, int base) {
    return 'Rep bridge: goal $reps, original goal $base reps';
  }

  @override
  String get progReserveNeeded => 'Weight held · reps in reserve not recorded';

  @override
  String get progStepTooLarge => 'Weight held · next step too large';

  @override
  String get autoRuleDone =>
      'Once you complete every set, Auto uses your reps in reserve from the last set to check whether the next weight fits your original goal. Without an answer, the weight stays the same.';

  @override
  String get autoRuleBridge =>
      'If the next step is too large and you had at least two reps left, Auto adds one rep per set, up to three above your original goal. Your original goal returns when the weight goes up.';

  @override
  String get autoRuleTimed =>
      'After meeting the time goal, the load increases one step if that step is no more than 2.5%.';

  @override
  String autoRuleMiss(Object n) {
    return 'After $n missed workouts in a row, weight drops by about 10% in available steps.';
  }

  @override
  String get settingsRestWarning => 'Countdown';

  @override
  String get settingsRestWarningHint =>
      'Double beep at 30 and 15 s, then 3, 2, 1; at 10 s in a timed set\'s lead-in';

  @override
  String get progSetLighter => 'Set weight reduced';

  @override
  String get progMoreAssistance => 'Assistance increased';

  @override
  String rirTimedLeft(Object n) {
    return '$n in reserve';
  }

  @override
  String get recapNextInline => 'Next time:';

  @override
  String progDeloadNoChange(Object fails) {
    return 'Goal not reached in $fails consecutive workouts';
  }

  @override
  String get recapPulse => 'Heart rate';

  @override
  String recapPulseSummary(int avg, int max) {
    return 'avg $avg · max $max bpm';
  }

  @override
  String get recapPulseRest => 'rest';

  @override
  String recapPulseAbove(int minutes, int bpm) {
    return '$minutes min above $bpm bpm';
  }

  @override
  String restAbout(String n) {
    return 'about $n min';
  }

  @override
  String restSuggest(
    int set,
    String short,
    int shortMet,
    int shortN,
    String long,
    int longMet,
    int longN,
    String time,
  ) {
    return 'Before set $set you reached the target $shortMet of $shortN times after $short, $longMet of $longN times after $long. Test $time next time?';
  }

  @override
  String get restTryOnce => 'Test once';

  @override
  String get restKeep => 'Keep as is';

  @override
  String restTrialPending(String time, int set) {
    return 'Next training: $time rest before set $set as a test';
  }

  @override
  String get restTrialCancel => 'Don\'t test';

  @override
  String restAdoptAsk(int worked, String time, int set) {
    return '$worked tests with $time before set $set worked. Keep it for good?';
  }

  @override
  String get restAdopt => 'Adopt';

  @override
  String get restAdoptNo => 'Don\'t adopt';

  @override
  String restNeedsVariety(int set) {
    return 'Set $set still needs trainings with rests of different lengths';
  }

  @override
  String get restBeforeSetRemove => 'Remove learned rest';

  @override
  String get restSmart => 'Smart';

  @override
  String get restFixed => 'Fixed';

  @override
  String get restSmartHelp => 'How smart rests work';

  @override
  String get restSmartHint =>
      'Learns from your set taps and suggests tests in the recap.';

  @override
  String get restRuleStartTitle => 'Starting values';

  @override
  String get restRuleStart =>
      'The times below apply until your trainings show otherwise. Each rest before a set learns on its own. The rest after a missed set stays as you set it.';

  @override
  String get restRuleMeasureTitle => 'Measured from your taps';

  @override
  String get restRuleMeasure =>
      'Rest = time between two set taps minus the estimated set duration. No extra tap needed. Breaks, other exercises in between and skipped sets don\'t count.';

  @override
  String get restRuleShorterTitle => 'Shorter';

  @override
  String get restRuleShorter =>
      'If you make the whole exercise several times with reps to spare, the recap suggests testing one rest shorter once. Never below 2:00 for heavy sets (up to 5 reps), else 1:00.';

  @override
  String get restRuleLongerTitle => 'Longer';

  @override
  String get restRuleLonger =>
      'If a set fails more often after short rests than after long ones, the recap suggests testing the longer rest, at most 5:00.';

  @override
  String get restRuleTestTitle => 'Test first, then adopt';

  @override
  String get restRuleTest =>
      'A test covers one training and one rest. The whole exercise counts: after two successful tests the app asks whether to keep the time.';

  @override
  String get restRuleStableTitle => 'New weight first';

  @override
  String get restRuleStable =>
      'When the weight goes up or a deload is due, the proven times apply first.';

  @override
  String get restPulse => 'Use heart rate';

  @override
  String get restPulseHint =>
      'With a heart rate sensor: extends the rest while your pulse is above 110, at most to double.';

  @override
  String restSuggestShorter(
    int set,
    int n,
    String rest,
    String time,
    String current,
  ) {
    return 'Before set $set you went on after $rest $n times and made the whole exercise. Test $time instead of $current once next time?';
  }

  @override
  String restSuggestTryShorter(int n, int set, String time, String current) {
    return '$n trainings in a row all made, with reps to spare. Test $time instead of $current before set $set once?';
  }

  @override
  String restTrialOutcome(
    int set,
    String rest,
    String usual,
    int done,
    int total,
  ) {
    return 'Test before set $set: $rest instead of $usual · $done of $total reps';
  }

  @override
  String get restTrialWorked =>
      'Worked: the whole exercise made, as many reps as usual.';

  @override
  String restTrialWorkedAfter(String context) {
    return 'Worked: the whole exercise made, as many reps as usual $context.';
  }

  @override
  String get restTrialFailed => 'Didn\'t work.';

  @override
  String restTrialNoComparison(String context) {
    return 'All made, but nothing to compare with $context yet. Doesn\'t count for keeping it.';
  }

  @override
  String get restTrialUnclear =>
      'All made, but what came before is unclear. Doesn\'t count for keeping it.';

  @override
  String restAfterSets(int sets, String name) {
    return 'after $sets sets of $name';
  }

  @override
  String get restNoPreload => 'without related sets before';

  @override
  String restStageAfter(String name) {
    return 'In trainings after $name:';
  }

  @override
  String get restStageFresh => 'In trainings without related sets before:';

  @override
  String get restNow => 'Now before each set';

  @override
  String get restNowHint =>
      '✦ learned from tests. Tap to go back to the starting value.';

  @override
  String get restStartValue => 'Starting value';

  @override
  String get restStartHint =>
      'Applies before every set until tests confirm a better rest.';

  @override
  String get restNowNone =>
      'Nothing learned yet: the starting value applies before every set.';

  @override
  String get restTileStart => 'Start';

  @override
  String get restPulseInfoTitle => 'Heart rate during the rest';

  @override
  String get restPulseInfo =>
      'Only with a connected heart rate sensor.\n\nThe planned rest is the minimum. If your pulse is still above 110 at the end, the rest keeps going until it drops below, at most to double the rest. If it drops below 110 earlier, the rest still ends at the planned time. Heart rate never shortens it.\n\nA rest only gets shorter through Smart: if you make a set reliably several times, the recap suggests testing a shorter rest.\n\nThe two are linked indirectly: Smart measures the rest you actually took. If the pulse often extends it and the sets go well afterwards, that can back a longer rest.\n\nWhy not shorter when your pulse drops fast? A low pulse doesn\'t mean your muscles have recovered. Especially for heavy sets, muscle recovery is what counts.\n\nWithout a sensor or a reading, the planned rest stays.';

  @override
  String restResetBody(int set, String learned, String start) {
    return 'Set $set goes back to the starting value $start instead of $learned.';
  }
}
