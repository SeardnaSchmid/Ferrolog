# Progressionsprotokoll

Stand der Umsetzung. Wird bei jedem Schritt fortgeschrieben.

- Code: [lib/model.dart](../lib/model.dart) (`PlanTarget`, `PlanDecision`, `ExerciseLog.decision`, `Exercise.decide`, `Store._progress`, `format` im Export), [lib/recap.dart](../lib/recap.dart) (Zeile „Nächstes Mal“), [lib/l10n/app_de.arb](../lib/l10n/app_de.arb) / [app_en.arb](../lib/l10n/app_en.arb), [tool/demo_server.py](../tool/demo_server.py)
- Tests: [test/plan_decision_test.dart](../test/plan_decision_test.dart), [test/recap_progression_test.dart](../test/recap_progression_test.dart)

## Kundenproblem

Im Export stand die Kniebeuge am 24.11. mit 3 × 5 bei 130 kg, Reserve 2 im letzten Satz und 10 kg Schritt, der Plan vom 27.11. aber mit 132,5 kg. Ob FerroLog die 132,5 kg am 24.11. selbst gesetzt hat oder ob sie später von Hand geändert wurden, war nicht zu erkennen: der Export enthielt nur den Plan von heute, `planBefore` wird nicht exportiert und lebt nur am neuesten Training.

## Festlegungen (2026-11-27)

| # | Frage | Entscheidung |
|---|---|---|
| Q1 | Wo steht es? | Pro Übung im Verlaufseintrag: `ExerciseLog.decision` (`PlanDecision`), gespeichert und exportiert als `exercises[].decision`. Nie beim Export aus dem aktuellen Plan rekonstruiert. |
| Q2 | Wann wird es geschrieben? | Genau dort, wo die Progression läuft: `Store._progress` (aus `finishSession` und `reapplyProgression`). Plan vorher = Plan unmittelbar vor `Exercise.decide`, Plan nachher = unmittelbar danach. |
| Q3 | Inhalt | `before`/`after` (`PlanTarget`): Sätze, Gewicht, `setWeights`/`setReps` wenn pro Satz verschieden, Wdh., `maxReps`, `fails` (Fehlversuche in Folge), `bridgeFrom` (Wdh.-Brücke im Auto-Modus). Dazu `loadStep` (kg) mit `loadStepSource` (`set`, `plates`, `learned`, `guess`) und `outcome` (ein `Progression`-Wert). |
| Q4 | Schritt | Der Schritt, nach dem tatsächlich gerechnet wurde: in der Übung oder im Training gesetzt (`set`) vor `loadStepOf` (Scheiben, gelernt, Standard), wie in `Exercise.decide`. |
| Q5 | Grund im festen Modus | `applyResult` gibt weiter nur im Auto-Modus etwas zurück (`progression` unverändert). Neues `Exercise.decide` liefert den Grund in beiden Modi: `up`, `limit` (Steigerung aus), `stepTooLarge` (Steigerung passt nicht zum Schritt), `range`, `miss`, `deload`, `lighter`, `fewer`. Keine neuen Enum-Werte, Texte wie bisher (`progressionLabel`). |
| Q6 | Ohne Eintrag | Cardio, ganz ausgelassene Übungen, Übungen außerhalb des Plans (getauscht, hinzugefügt) und Trainings von vor dieser Änderung. |
| Q7 | Bearbeiten | `replaceSession` / `updateSession(replan)` am neuesten Training: `reapplyProgression` → `_progress` schreibt den Eintrag neu. Älteres Training bearbeitet oder hinter ein anderes verschoben: Plan bleibt, Eintrag bleibt (er beschreibt, was damals entschieden wurde). `deleteSession`: Eintrag geht mit dem Training. Umbenennen läuft über JSON und behält ihn. |
| Q8 | Recap | Die Zeile „Nächstes Mal:“ kommt aus dem Eintrag, also auch bei älteren Trainings: Pfeil, Ziel („3×5 mit 80 kg“, pro Satz „5/5/8 mit 70/70/60 kg“) und Grund. Antippen klappt „Vorher: …“ und „Schritt: 2,5 kg · in der Übung festgelegt“ auf. Ohne Eintrag wie bisher (nur neuestes Training, Gewicht aus dem Plan). Übungen ohne Gewicht zeigen keine Zeile. |
| Q9 | Ziel im Text | Mit geschützten Leerzeichen, damit „3×5 mit 80 kg“ nicht mitten umbricht; ersetzt die frühere Row im WidgetSpan, die bei längerem Text überlief. |
| Q10 | Demodaten | `decision` an allen Übungen der letzten acht Wochen, abgeleitet aus dem Generator (Plan vorher = `planBefore`, nachher = Plan vor dem nächsten Training bzw. heutiger Plan). Näherung, die Bankdrück-Stagnation zählt als `limit`. |

## Phasen

1. **Erledigt**: Eintrag schreiben, speichern, exportieren (`format` beschreibt ihn), beim Bearbeiten/Neuplanen konsistent halten, Recap-Zeile, Tests, Demodaten.
2. Später, falls gewünscht: Eintrag auch in Verlauf oder Statistik zeigen; `progression` durch `decision.outcome` ersetzen.
