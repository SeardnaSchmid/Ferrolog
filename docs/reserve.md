# Wiederholungen in Reserve (RIR)

Stand der Umsetzung (WP6b der Improvement-Spec). Wird bei jedem Schritt fortgeschrieben.

- Code: [lib/model.dart](../lib/model.dart) (`ExerciseLog.rir`, `rirLabel`, `format`), [lib/session.dart](../lib/session.dart) (`askRir`, `_rirQuestion` auf der Übungskarte, Anzeige auf der Karte), [lib/settings.dart](../lib/settings.dart) („Reserve abfragen“), [lib/edit_session.dart](../lib/edit_session.dart) (Chips „Gingen noch“), [lib/main.dart](../lib/main.dart) und [lib/recap.dart](../lib/recap.dart) (Verlauf und Zusammenfassung), [lib/findings.dart](../lib/findings.dart) (`_plateaus`), [lib/derived.dart](../lib/derived.dart) (`rirLast`), [lib/plan_import.dart](../lib/plan_import.dart) (`capabilities`), README, [tool/demo_server.py](../tool/demo_server.py)
- Tests: [test/rir_test.dart](../test/rir_test.dart), [test/model_test.dart](../test/model_test.dart), [test/findings_test.dart](../test/findings_test.dart), [test/derived_test.dart](../test/derived_test.dart)

## Kundenproblem

Die App wusste, ob die Wiederholungen geschafft waren, nicht wie schwer. 5/5/5 mit zwei in Reserve und 5/5/5 am Limit sahen gleich aus; Plateau-Hinweis und KI mussten raten.

## Festlegungen (2026-11-13)

| # | Frage | Entscheidung |
|---|---|---|
| Q1 | Bauen, obwohl im „Recommended cut“ als „Not planned“? | Ja (Entscheidung des Besitzers). |
| Q2 | Skala | Wiederholungen in Reserve 0–4, 4 heißt vier oder mehr. Kein RPE. |
| Q3 | Wann gefragt | Schalter „Reserve abfragen“ unter „Training“, standardmäßig aus. Einmal pro Übung, wenn ihr letzter offener Satz geloggt wird; nur Kraftsätze: kein Cardio, keine Zeitübung, keine Unterstützung (negatives Gewicht). |
| Q4 | Wo | Auf der Karte der Übung, unter ihren Sätzen (2026-11-13 vom Live-Streifen dorthin verschoben, auf Wunsch des Besitzers: die Frage gehört zur Übung, der Streifen bleibt bei der Pause). Ohne Zeitlimit: sie bleibt durch die Pause, bis zur Antwort oder bis der nächste Satz getippt wird, der normal geloggt wird. Ignorieren speichert nichts. |
| Q5 | Rückgängig | Wird der letzte Satz wieder offen (zurückgetippt, mehr Sätze beim Bearbeiten), geht die Antwort mit. |
| Q6 | Anzeige | Auf der Trainingskarte, im Verlauf und in der Zusammenfassung: „am Limit“, „noch 2 übrig“, „noch 4+ übrig“. Nachträglich änderbar auf der Seite „Training bearbeiten“ (Chips „Gingen noch“, sichtbar mit Schalter an oder schon vorhandener Antwort). |
| Q7 | Plateau | Neuestes Training mit 2 oder mehr übrig: „Das Gewicht ist nicht die Grenze“ (Technik, kein Deload). Die letzten 2 am Limit: Deload um etwa 10 % vorschlagen. Sonst wie bisher. |
| Q8 | Export | `exercises[].rir` im `format`, im README-Beispiel, `rirLast`/`rirLastDate` pro Übung in `derived`. `capabilities`: Erfassen unter `can`, geplante RIR-Ziele weiter unter `cannot`. Nicht im 1RM. |
| Q9 | Demodaten | Kraftübungen der letzten zwei Monate: 0 nach verfehlten Wiederholungen, sonst 1–4, 15 % ohne Antwort; eigener Zufallsgenerator. Der Seed schaltet die Abfrage ein. |

## Phasen

1. **Erledigt** (nicht committet): WP6b.
