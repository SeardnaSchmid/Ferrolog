# Auto-Modus für die Steigerung

Stand der Umsetzung (über die Improvement-Spec hinaus, baut auf WP6b auf). Wird bei jedem Schritt fortgeschrieben.

- Code: [lib/model.dart](../lib/model.dart) (`Exercise.auto`, `Exercise.state`, `AutoState`, `applyResult`/`_auto`, `deloadTo`, `Progression`, `progressionLabel`, `badDayTags`, `painTag`, `isBarbell`; im `Store`: `loadStepOf`, `comebackOf`, `comebackWeights`, `startSession`, `_progress`, `revertProgression`, `updateSession(replan:)`; `PlanState.auto`; `format`), [lib/edit.dart](../lib/edit.dart) („Gewicht anpassen“: Automatisch / Fest, „Alle automatisch“ im Workout-Editor), [lib/session.dart](../lib/session.dart) (`autoRir`), [lib/edit_session.dart](../lib/edit_session.dart), [lib/main.dart](../lib/main.dart) (Workout-Karte, Start), [lib/recap.dart](../lib/recap.dart) (Grund am Pfeil, Neuberechnung bei geänderten Umständen), [lib/plan_import.dart](../lib/plan_import.dart), [lib/settings.dart](../lib/settings.dart), [tool/demo_server.py](../tool/demo_server.py)
- Tests: [test/auto_test.dart](../test/auto_test.dart), [test/edit_test.dart](../test/edit_test.dart)
- Bewertung durch einen Analysten: https://claude.ai/artifact/MvwVswnhSr3N6JEiT7tRww (Fassung vor Version 2)

## Kundenproblem

Feste Schritte („+2,5 kg bei Erfolg, −10 kg nach 3 Fehlversuchen“) kennen weder die Reserve noch das Gewicht noch die Tagesform. Ein leichtes Schulterdrücken springt zu weit, ein Training mit viel Reserve zu kurz, ein kranker Tag zählt als Fehlversuch, nach dem Urlaub geht es mit dem alten Gewicht weiter.

## Festlegungen

Version 1 (2026-11-13) hatte einen einstellbaren Grundschritt. Version 2 (2026-11-13) setzt das Feedback des Besitzers (keine Schritt-Einstellung im Auto-Modus) und die Empfehlungen des Analysten um.

| # | Frage | Entscheidung |
|---|---|---|
| Q1 | Pro Übung oder global | Pro Übung: „Gewicht anpassen“ im Übungseditor, Automatisch oder Fest. Fest ist das bisherige Verhalten. Im Auto-Modus gibt es nichts einzustellen, `increment`, `up`, `down`, `decrement` und `failsToDeload` gelten nicht. |
| Q2 | Vorgabe | Neue Übungen starten auf Automatisch; steht der Name schon in einem anderen Workout, gilt dessen Einstellung. Bestehende Übungen, Vorlagen und KI-Pläne ohne `auto` bleiben auf Fest. Der Workout-Editor bietet „Alle automatisch“ mit einem Tipp an. |
| Q3 | Schrittgröße | Ein Anteil des Gewichts (`AutoState.pct`), Start 2,5 %, gerundet auf die Ladestufe der Übung. Adaptiv statt wählbar: jede Entlastung halbiert ihn (bis 0,5 %), 3 geschaffte Trainings in Folge mit 2 oder mehr Reserve verdoppeln ihn wieder (bis 2,5 %). |
| Q4 | Reserve | Am Limit (0): Gewicht bleibt, beim zweiten Mal in Folge ein halber Schritt. 1–2 oder keine Antwort: normaler Schritt. 3 oder mehr: doppelter Schritt. Wiederholungen über dem Ziel im letzten Satz zählen zur Reserve dazu (bei einer Spanne über deren Obergrenze). Übungen im Auto-Modus fragen die Reserve immer ab, auch wenn „Reserve abfragen“ aus ist. |
| Q5 | Ladestufe | Pro Übung einstellbar (`loadStep`, Chips „Automatisch“, 1 / 1,25 / 2 / 2,5 / 5 kg, „Eigene“), z. B. eine Beinpresse, die nur 5-kg-Scheiben nimmt; eingestellt geht vor allem anderen (Wunsch des Besitzers, 2026-11-13). Auf „Automatisch“: Langhantel (`isBarbell`): zweimal die kleinste Scheibe des Nutzers. Sonst gelernt aus den benutzten Gewichten: die gröbste Stufe aus 5 / 2,5 / 2 / 1,25 / 1 / 0,5 kg (lb: 10 / 5 / 2,5 / 1), die alle trifft, sobald es 3 verschiedene gibt. Vorher ein Startwert: Kurzhanteln 2 kg, Maschinen und Kabel 2,5 kg (je 5 lb), sonst der alte Schritt. Der Editor zeigt Stufe und Herkunft („deine Scheiben“, „aus deinen Gewichten“, „Startwert, lernt mit“, „eingestellt“). |
| Q6 | Zu kleine Schritte | Rundet der Schritt auf null, überbrückt die App mit Wiederholungen: +1 pro Satz (mit Reserve 3+ +2) bis zur Brücke (`bridgeTo`, 1–3 Wiederholungen je nach Größe der Ladestufe, etwa 5 % pro Wiederholung), dann eine Ladestufe mehr und die Wiederholungen zurück. Kein gemerktes Zielgewicht: Jeder Schritt braucht einen Leistungsnachweis. Eine Spanne ist ihre eigene Brücke: oben angekommen eine Ladestufe mehr. Wiederholungen von Hand geändert beenden die Brücke. |
| Q7 | Verfehlt | Gewicht bleibt. Der zweite Fehlversuch in Folge beendet eine Brücke (Wiederholungen zurück), der dritte nimmt etwa 10 % weg, abgerundet auf die Ladestufe, und halbiert den Anteil. |
| Q8 | Schlechter Tag | Nur Umstände, nicht die Stimmung (sie kommt nach dem Training, und ein Fehlversuch macht sie schlecht): „Krank“, „Schlecht geschlafen“, „Stress“, „Wenig gegessen“ entschuldigen einen Fehlversuch, höchstens 2× in Folge pro Übung. „Schmerzen“ hält das Gewicht in jedem Fall und sagt in der Zusammenfassung, die Übung prüfen zu lassen. Ändern sich die Umstände in der Zusammenfassung, rechnet die App den Plan neu (über `planBefore`). |
| Q9 | Rückkehr nach Pause | Automatisch: ab 14 Tagen ohne die Übung 5 % leichter, ab 4 Wochen 10 %, ab 8 Wochen 20 %. Schon die Workout-Karte zeigt die leichteren Gewichte. Beim Beenden wird der leichtere Start zum Plan, das alte Gewicht zu `comebackTo`; bis dorthin doppelte Schritte, nicht darüber hinaus. Löschen oder Bearbeiten nimmt alles zurück. |
| Q10 | Zurücknehmen | `planBefore` speichert für Auto-Übungen auch Wiederholungen, `setReps` und `AutoState`, damit Bearbeiten und Löschen Brücken und Anteil mit zurücknehmen. |
| Q11 | Anzeige | In der Zusammenfassung hinter dem Gewicht fürs nächste Mal der Grund, z. B. „↑ 105 kg · viel Reserve, doppelter Schritt“, „→ 12 kg · nächstes Mal 11 Wdh., bei 13 mehr Gewicht“, „→ 100 kg · am Limit, Gewicht bleibt“. Im Editor: „Gerade +2,5 % pro Training · Ladestufe 2 kg (aus deinen Gewichten)“. |
| Q12 | Export | Plan: `auto: true`, `loadStep` (falls eingestellt), `autoState` (`pct`, `streak`, `limits`, `excused`, `bridgeFrom`, `bridgeTo`, `comebackTo`). Training: `exercises[].backoff`, `exercises[].progression` (`up`, `up2`, `half`, `limit`, `bridge`, `range`, `miss`, `reset`, `badDay`, `pain`, `deload`, `lighter`, `fewer`). Regeln im `format`, Auto-Modus unter `can` in `capabilities`; KI-Pläne dürfen `auto` setzen, `autoState` bleibt erhalten. |
| Q13 | Demodaten | Bizepscurls und Rumänisches Kreuzheben stehen auf Automatisch, ihr Verlauf stammt noch aus festen Schritten. |

## Phasen

1. **Erledigt** (nicht committet): Version 1.
2. **Erledigt** (nicht committet): Version 2 nach Besitzer und Analyst (Q1–Q13).
3. Offen: eine Obergrenze aus dem geschätzten 1RM; ein Hinweis auf der Startseite, wenn „Schmerzen“ wiederkommt.
