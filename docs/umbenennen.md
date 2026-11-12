# Übungen umbenennen und zusammenführen

Stand der Umsetzung (WP5 der Improvement-Spec). Wird bei jedem Schritt fortgeschrieben.

- Code: [lib/model.dart](../lib/model.dart) (`Store.renameExercise`, `shareAWorkout`, `planEntryOf`), [lib/edit.dart](../lib/edit.dart) (`transferHistory`, `ExerciseEditor.taken`, Umbenennen beim Speichern in `EditWorkout`), [lib/main.dart](../lib/main.dart) (`editExerciseIn`), [lib/stats.dart](../lib/stats.dart) (Menü „Mit anderer Übung zusammenführen“), [lib/session.dart](../lib/session.dart) (`planOf`), [lib/plan_import.dart](../lib/plan_import.dart) (doppelte Namen abgelehnt)
- Tests: [test/rename_test.dart](../test/rename_test.dart), [test/rename_ui_test.dart](../test/rename_ui_test.dart)

## Kundenproblem

Eine Übung hat keine Id, ihr Name ist ihre Identität. Umbenennen startete einen leeren Verlauf (Trend, Rekorde, Plateau weg), und derselbe Name zweimal in einem Workout gab beim Beenden einem Eintrag beide Ergebnisse.

## Festlegungen (2026-11-12)

| # | Frage | Entscheidung |
|---|---|---|
| Q1 | Ids für Übungen? | Nein (wie die Spec): Umbenennen schreibt den Namen überall um. |
| Q2 | Was `renameExercise` umschreibt | Pläne aller Workouts, alle Trainings (auch `replaces`; ein Tausch auf sich selbst verliert `replaces`), das laufende Training, `planBefore`, die Muskeln (die des Ziels bleiben, wenn es eigene hat) und zurückgestellte Hinweise (`kind:name[:datum]`). Ein Speichern. |
| Q3 | Zusammenführen zweier Namen aus einem Workout | Abgelehnt (`StateError`), das Workout hätte die Übung sonst zweimal. Im Statistik-Menü stehen solche Ziele gar nicht zur Wahl. |
| Q4 | Wann die Frage kommt | Beim Umbenennen im Workout-Editor und von der Workout-Karte, wenn der alte Name Verlauf hat. Nicht bei einem Tausch (neuer Name hat eigenen Verlauf, alter steht noch in einem anderen Workout) und nicht, wenn beide in einem anderen Workout stehen. Ohne Wegklicken: „Übertragen“ oder „Neue Übung“. |
| Q5 | Wann übertragen wird | Im Workout-Editor erst mit „Speichern“ des Workouts; zweimal umbenannt zählt der erste Name. Von der Workout-Karte sofort. |
| Q6 | Doppelte Namen | Der Übungs-Editor sperrt „Speichern“ mit Hinweis, wenn der Name (per `searchKey`) schon im Workout steht. Der Plan-Import lehnt solche Pläne ab. Ältere doppelte Einträge bekommen beim Beenden je ihr eigenes Ergebnis (n-ter Log ↔ n-ter Eintrag), ebenso `planOf` im Training. |
| Q7 | Rückgängig | Keins; das Zusammenführen fragt vorher und sagt das. |

## Phasen

1. **Erledigt**: WP5.
