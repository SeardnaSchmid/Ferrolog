# Auto-Modus für die Steigerung

Stand der Umsetzung (über die Improvement-Spec hinaus, baut auf WP6b auf). Wird bei jedem Schritt fortgeschrieben.

- Code: [lib/model.dart](../lib/model.dart) (`Exercise.auto`, `Exercise.state`, `AutoState`, `applyResult`/`_auto`, `deloadTo`, `Progression`, `progressionLabel`, `badDayTags`, `painTag`, `isBarbell`; im `Store`: `loadStepOf`, `comebackOf`, `comebackWeights`, `startSession`, `_progress`, `revertProgression`, `updateSession(replan:)`; `PlanState.auto`; `format`), [lib/edit.dart](../lib/edit.dart) („Gewicht und Steigerung“: Automatisch / Fest, „Alle automatisch“ im Workout-Editor), [lib/session.dart](../lib/session.dart) (`autoRir`), [lib/edit_session.dart](../lib/edit_session.dart), [lib/main.dart](../lib/main.dart) (Workout-Karte, Start), [lib/recap.dart](../lib/recap.dart) (Grund am Pfeil, Neuberechnung bei geänderten Umständen), [lib/plan_import.dart](../lib/plan_import.dart), [lib/settings.dart](../lib/settings.dart), [tool/demo_server.py](../tool/demo_server.py)
- Tests: [test/auto_test.dart](../test/auto_test.dart), [test/edit_test.dart](../test/edit_test.dart)
- Bewertung durch einen Analysten: https://claude.ai/artifact/MvwVswnhSr3N6JEiT7tRww (Fassung vor Version 2)

## Kundenproblem

Feste Schritte („+2,5 kg bei Erfolg, −10 kg nach 3 Fehlversuchen“) kennen weder die Reserve noch das Gewicht noch die Tagesform. Ein leichtes Schulterdrücken springt zu weit, ein Training mit viel Reserve zu kurz, ein kranker Tag zählt als Fehlversuch, nach dem Urlaub geht es mit dem alten Gewicht weiter.

## Festlegungen

Version 1 (2026-11-13) hatte einen einstellbaren Grundschritt. Version 2 (2026-11-13) setzt das Feedback des Besitzers (keine Schritt-Einstellung im Auto-Modus) und die Empfehlungen des Analysten um.

| # | Frage | Entscheidung |
|---|---|---|
| Q1 | Pro Übung oder global | Pro Übung: „Gewicht und Steigerung“ im Übungseditor, Automatisch oder Fest. Fest ist das bisherige Verhalten. Im Auto-Modus gibt es nichts einzustellen, `increment`, `up`, `down`, `decrement` und `failsToDeload` gelten nicht. |
| Q2 | Vorgabe | Neue Übungen starten auf Automatisch; steht der Name schon in einem anderen Workout, gilt dessen Einstellung. Bestehende Übungen, Vorlagen und KI-Pläne ohne `auto` bleiben auf Fest. Der Workout-Editor bietet „Alle automatisch“ mit einem Tipp an. |
| Q3 | Nächste Stufe | Sind alle Sätze geschafft, wird genau eine Stufe geprüft. Geschätztes Zielgewicht = aktuelles Gewicht × (30 + geschaffte Wiederholungen + Reserve) ÷ (30 + Grundziel + 1). Die Stufe darf höchstens so hoch sein. Bei unterschiedlichen Sätzen prüft Auto jeden Satz mit dessen Gewicht und Ziel. |
| Q4 | Reserve | Die gemeldete Reserve im letzten Satz dient als Schätzung für die Sätze. Ohne Angabe hält Auto das Gewicht. Übungen im Auto-Modus fragen die Reserve auch dann ab, wenn die globale Option aus ist. Haltezeit und Unterstützung verwenden eigene Regeln, da dort das Gesamtgewicht oder die Wiederholungszahl fehlt. |
| Q5 | Kleinster Gewichtsschritt | Unter „Gewicht und Steigerung“ im Übungseditor. Eingegeben wird die Änderung des Gesamtgewichts, zum Beispiel 2,5 kg für je 1,25 kg pro Seite. Plus und Minus verwenden den Schritt ab dem aktuellen Satzgewicht. Die Vorgaben und der eigene Wert unter „Fest“ müssen zum Schritt passen. Gespeicherte Scheiben oder verwendete Gewichte dienen ohne Eingabe als Vorschlag. |
| Q6 | Wiederholungsbrücke | Liegt die nächste Stufe über der Schätzung, erhöht Auto bei mindestens zwei Wiederholungen Reserve das Ziel um eins, maximal auf Grundziel plus drei. Nach Erreichen der Obergrenze wird das Ziel gehalten, wenn die nächste Stufe zu groß bleibt. Beim erfolgreichen Wechsel kehren die Sätze zum ursprünglichen Ziel zurück. Ein eingestellter Wiederholungsbereich bleibt erhalten. |
| Q7 | Verfehlt | Der zweite Fehlversuch in Folge beendet eine Brücke. Der dritte nimmt etwa 10 % in ganzen Gewichtsschritten weg, sofern eine leichtere Stufe verfügbar ist. |
| Q8 | Schlechter Tag | Nur Umstände, nicht die Stimmung (sie kommt nach dem Training, und ein Fehlversuch macht sie schlecht): „Krank“, „Schlecht geschlafen“, „Stress“, „Wenig gegessen“ entschuldigen einen Fehlversuch, höchstens 2× in Folge pro Übung. „Schmerzen“ hält das Gewicht in jedem Fall und sagt in der Zusammenfassung, die Übung prüfen zu lassen. Ändern sich die Umstände in der Zusammenfassung, rechnet die App den Plan neu (über `planBefore`). |
| Q9 | Rückkehr nach Pause | Nach 14 Tagen ohne die Übung startet sie 5 % leichter, nach vier Wochen 10 %, nach acht Wochen 20 %, in verfügbaren Schritten. Danach gilt wieder die normale Auto-Regel. |
| Q10 | Zurücknehmen | planBefore speichert für Auto-Übungen Wiederholungen, Satzwiederholungen und den Auto-Zustand, damit Bearbeiten und Löschen die Brücke zurücknehmen können. |
| Q11 | Anzeige | Der Editor, die Trainingskarte und die Zusammenfassung zeigen bei aktiver Brücke das aktuelle und das ursprüngliche Wiederholungsziel. Die Zusammenfassung erklärt auch fehlende Reserve und zu große Schritte. |
| Q12 | Export | loadStep (in kg) ist für Auto und Fest verfügbar. autoState speichert bridgeFrom und excused. Im Trainingslog stehen backoff und progression. |
| Q13 | Demodaten | Bizepscurls und Rumänisches Kreuzheben stehen auf Automatisch, ihr Verlauf stammt noch aus festen Schritten. |

## Phasen

1. **Erledigt** (nicht committet): Version 1.
2. **Erledigt** (nicht committet): Version 2 nach Besitzer und Analyst (Q1–Q13).
3. Gemeinsamer Gewichtsschritt und Auto-Progression mit Wiederholungsreserve.
