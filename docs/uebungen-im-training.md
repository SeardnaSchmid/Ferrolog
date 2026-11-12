# Übungen im Training ändern

Stand der Umsetzung (WP3 der Improvement-Spec). Wird bei jedem Schritt fortgeschrieben.

- Code: [lib/model.dart](../lib/model.dart) (`ExerciseLog.fromPlan`, `withSets`, `replaces`, `added`, eigene Pause/Schritt; `applyResult`), [lib/session.dart](../lib/session.dart) (Menü pro Karte, „+ Übung“), Export: `format` in `Store.toJson`, `capabilities` in [lib/plan_import.dart](../lib/plan_import.dart), README, [tool/demo_server.py](../tool/demo_server.py)
- Tests: [test/session_test.dart](../test/session_test.dart), [test/model_test.dart](../test/model_test.dart), [test/findings_test.dart](../test/findings_test.dart)

## Festlegungen (2026-11-11)

| # | Frage | Entscheidung |
|---|---|---|
| Q1 | Menü | Pro Karte (⋮): Übung ersetzen / Rest ersetzen, Satz hinzufügen, Letzten Satz entfernen, Nach oben/unten, Entfernen (nur dazugenommene ohne Satz). Gesperrt, solange eine Zeitübung oder Stoppuhr darauf läuft. |
| Q2 | Weniger Sätze als geplant | Gewicht bleibt, keine Steigerung, kein Fehlversuch (wie ein leichterer Satz). Mehr Sätze: normale Steigerung, Satzzahl im Plan bleibt. |
| Q3 | Knopf am Ende | „+ Übung“ wie im Workout-Editor (Spec: „Übung hinzufügen“). |
| Q5 | Menü überarbeitet (2026-11-12) | Statt „Übung ersetzen“, „Rest ersetzen“, „Satz hinzufügen“, „Letzten Satz entfernen“ nur noch **Bearbeiten**, Nach oben/unten, Entfernen (abgesetzt). „Bearbeiten“ öffnet den Übungs-Editor mit der Übung, wie sie im Training steht, ohne Pause und automatische Anpassung (die gehören zum Plan). Anderer Name: Tausch, geloggte Sätze bleiben, die neue Übung bekommt die restlichen Sätze. Gleicher Name: Sätze, Wiederholungen und Gewichte für dieses Training (`ExerciseLog.reshaped`), geloggte Sätze bleiben. Die Art (Cardio, Zeit) nur vor dem ersten Satz. Im Kopf der Karte „JETZT“ bzw. ✓, dann ⋮ am Rand auf Höhe des Titels. |
| Q4 | Demodaten | Drei Trainings mit Hammercurls statt Bizepscurls, acht mit Wadenheben dazu; eigener Zufallsgenerator, die übrigen Daten bleiben gleich. |

## Phasen

1. **Erledigt**: WP3.
2. Später: „Im Plan ersetzen?“ nach dreimal gleichem Tausch.
