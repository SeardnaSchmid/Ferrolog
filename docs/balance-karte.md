# Balance-Karte v4

Umbau der Balance-Karte in der Statistik nach dem Entwurf „Balance-Karte v4“ (Claude Design, Projekt „Balance card improvement“). Wird bei jedem Schritt fortgeschrieben.

- Code: [lib/muscles.dart](../lib/muscles.dart) (Paare, Richtwerte, Kraft-Verlauf), [lib/balance_card.dart](../lib/balance_card.dart) (Karte, Info-Sheet, Richtwert-Editor), Empfehlung in [lib/findings.dart](../lib/findings.dart) (`balanceAdvice`)
- Tests: [test/muscles_test.dart](../test/muscles_test.dart), [test/findings_test.dart](../test/findings_test.dart)

## Was der Entwurf vorgibt

- Zugeklappt: Anzahl Hinweise, „N von 6 ausgewogen“, pro Paar eine Waage mit beiden Namen; Paare mit Hinweis oben, die stärkere Seite orange.
- Antippen: Ergebnis als Satz („Schultern deutlich mehr trainiert als Latissimus“, „etwas“ unter 15 % daneben), Empfehlung, Zahlen und Richtwert.
- Sechs Paare, alle nach Sätzen pro Woche über 28 Tage: Brust ↔ Oberer Rücken (100–150 %), Schultern ↔ Latissimus (ab 100 %), Vordere ↔ Hintere Schulter (ab 50 %), Quadrizeps ↔ Hintere Oberschenkel (ab 60 %), Innen- ↔ Außenrotation (ab 50 %), Bauch ↔ Unterer Rücken (75–135 %).
- Kraft (1RM) nur noch als Verlauf über 90 Tage, zugeklappt: Rudern : Bankdrücken, Kreuzheben : Kniebeuge.
- Info-Sheet mit neuen Texten und 9 Quellen, „Richtwerte anpassen“.

## Entscheidungen beim Umsetzen

| # | Frage | Entscheidung |
|---|---|---|
| B1 | Zeitraum | Karte immer 28 Tage, unabhängig von der Zeitraum-Wahl oben. Die Befunde auf der Startseite rechnen ebenfalls 28 Tage (vorher 30), damit die Zahlen gleich sind. |
| B2 | Empfehlung auf der Karte | Dieselbe wie im Befund (`balanceAdvice`): nie mehr Arbeit. Damit ist der Widerspruch Karte ↔ Startseite weg. |
| B3 | Kraftpaare in den Befunden | Entfallen, Kraft ist nur noch Verlauf. |
| B4 | Vordere/hintere Schulter, Rotation | Kein eigener Muskel in den Daten, daher nach Namen: Face Pulls, Reverse Butterfly/Flys zählen für hintere Schulter, Face Pulls und Außenrotations-Übungen für Außenrotation. Drückübungen zählen halb für vordere Schulter und Innenrotation, Schulterdrücken und Frontheben voll für vordere Schulter, Rudern halb für hintere Schulter. |
| B5 | Unterer Rücken | Hauptmuskel voll, außer in Verbundübungen mit Beinen oder Trapez (Kreuzheben, Good Mornings, Rack Pulls): halb. Als Hilfsmuskel halb. |
| B6 | Offene Richtwerte („ab …“) | Im Entwurf würde ein Paar über dem 1,5-fachen der Untergrenze als „zu viel“ gewarnt. Umgesetzt: oben offen heißt nie zu viel; der Punkt bleibt dann am Rand des hellen Felds. |
| B7 | Wann ein Paar erscheint | Sobald eine der beiden Seiten Sätze hat. |
| B8 | „Weniger Sätze“-Knopf | Nur Übungen, die ausschließlich auf der stärkeren Seite zählen (Rudern ist kein Hebel für Bauch ↔ unterer Rücken). |
| B9 | Richtwerte anpassen | Sheet mit einem Regler pro Paar (Bereich oder Untergrenze, 20–200 % in 5er-Schritten), „Auf Standard zurücksetzen“. Gespeichert in den Einstellungen (`balance.guides`), gilt für Karte und Befunde. |
| B10 | Kraft-Verlauf | Start = bestes 1RM der ersten vier Trainings im 90-Tage-Fenster, jetzt = der letzten vier. ±2 Prozentpunkte = stabil. |
| B11 | Sprung von „Dein Training“ | Karte 4 s umrandet, Paar getönt und aufgeklappt; es bleibt offen, wenn die Hervorhebung endet. |
| B12 | Export | `balance28d` (statt `balance90d`, ohne `basis`) und neu `strength90d`. |

## Stand

| Schritt | Inhalt | Stand |
|---|---|---|
| 1 | Modell: sechs Paare, Anteile je Übung, eigene Richtwerte, Kraft-Verlauf | ✅ |
| 2 | Befunde: 28 Tage, ohne Kraftpaare, gemeinsame Empfehlung | ✅ |
| 3 | Karte, Info-Sheet, Richtwert-Editor | ✅ |
| 4 | Tests (59 grün), `web-demo` durchgeklickt | ✅ |
| 5 | Commit, Handy | offen, auf Zuruf |

## Offen

- In der Demo zeigt die Karte 4 Hinweise (Latissimus, hintere Schulter, Außenrotation, Bauch). StrongLifts hat weder Face Pulls noch Bauchübungen. Das sind echte Befunde, aber Außenrotation und Bauch werden bei fast jedem Grundübungs-Plan anschlagen und dann auch auf der Startseite stehen (ein Ratschlag gleichzeitig, „Später“ wirkt).
- Die Quellen im Info-Sheet stammen aus dem Entwurf, darunter Bodybuilding.com und Biolayne. Vor einer Veröffentlichung prüfen.
- Der Richtwert-Editor öffnet über dem Info-Sheet (zwei Sheets übereinander).
