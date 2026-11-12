# Vergangene Trainings bearbeiten

Stand der Umsetzung (WP4 der Improvement-Spec). Wird bei jedem Schritt fortgeschrieben.

- Code: [lib/model.dart](../lib/model.dart) (`Session.planBefore`, `Session.shift`, `Store.movesPlan`, `revertProgression`, `reapplyProgression`, `replaceSession`, `deleteSession`), [lib/edit_session.dart](../lib/edit_session.dart) (`EditSessionPage`, `showRepsSheet`), [lib/session.dart](../lib/session.dart) (`showWeightSheet`, `applyWeightScope`, `showCardioSheet`, `applyCardio` herausgelöst), [lib/main.dart](../lib/main.dart) (Stift im Verlauf), [lib/recap.dart](../lib/recap.dart) (Stift in der Zusammenfassung), [tool/demo_server.py](../tool/demo_server.py)
- Tests: [test/edit_session_model_test.dart](../test/edit_session_model_test.dart), [test/edit_session_test.dart](../test/edit_session_test.dart)

## Kundenproblem

Ein vertippter Satz blieb in jeder Statistik, jedem Rekord und im Export falsch, oder das ganze Training musste weg. Und Löschen oder Korrigieren des letzten Trainings ließ den Plan auf einem Gewicht, das die korrigierten Daten nicht hergeben.

## Festlegungen (2026-11-12)

| # | Frage | Entscheidung |
|---|---|---|
| Q1 | Was steht im Schnappschuss? | `planBefore` pro Planübung, die im Training vorkommt (auch ganz ausgelassene): Gewicht, `setWeights`, `fails`. Nur am neuesten Training eines Workouts, das nächste übernimmt ihn. |
| Q2 | Export | `planBefore` wird gespeichert, aber nicht exportiert (`exportJson` nimmt es heraus): Rückgängig-Zustand der App, keine Trainingsdaten. Deshalb keine Änderung an `format` und README; nach einem Wiederherstellen von GitHub gelten die Trainings als alt (Q5). |
| Q3 | Plan seitdem umgebaut | Eine Übung, deren Satzgewichte im Plan inzwischen anders aufgebaut sind (andere Anzahl, oder jetzt einheitlich), bleibt beim Zurücksetzen wie sie ist. Ein von Hand geändertes Gewicht wird dagegen auf den Stand vor dem Training gesetzt und neu berechnet. |
| Q4 | Neues Datum | Training, Ende und alle Satzzeiten verschieben sich gleich. Rutscht das neueste Training hinter ein anderes seines Workouts, bleibt der Plan, wie er ist, und keins der beiden bewegt ihn mehr. |
| Q5 | Trainings ohne Schnappschuss | Wie ältere Trainings: nur Verlauf und Statistik. |
| Q6 | Gewichts-Sheet beim Bearbeiten | Dasselbe wie im Training, vorausgewählt „Dieser Satz“. Wiederholungen: eigenes Sheet mit Stepper und „Nicht gemacht“. |
| Q7 | Verlassen mit Änderungen | Fragt „Änderungen verwerfen?“. Löschen des neuesten Trainings sagt, dass die Plan-Gewichte zurückgehen. |
| Q8 | Datumsauswahl | `showDatePicker`/`showTimePicker` mit deutschen Knopftexten, 24 h. Monatsnamen bleiben englisch, solange die App kein `flutter_localizations` hat. |
| Q9 | Demodaten | Das neueste Training je Workout trägt `planBefore`; die Kniebeuge (in der Demo von A und B geteilt) nur das neuere. |

## Phasen

1. **Erledigt**: WP4.
2. Später, falls gewünscht: Sätze oder Übungen beim Bearbeiten hinzufügen oder entfernen.
