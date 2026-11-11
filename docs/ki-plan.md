# KI-Plan: Optimierung zurück in die App

Stand der Umsetzung. Wird bei jedem Schritt fortgeschrieben.

- Code: [lib/plan_import.dart](../lib/plan_import.dart) (`capabilities`, `planImport`, Prüfung, Unterschiede, Übernehmen), [lib/plan_import_page.dart](../lib/plan_import_page.dart) (Einfügen, Vorschau), Export und Prompt in [lib/main.dart](../lib/main.dart) (`analysisExtras`, `analysisPrompt`)
- Tests: [test/derived_test.dart](../test/derived_test.dart), [test/plan_import_test.dart](../test/plan_import_test.dart)

## Kundenproblem

Die KI-Analyse des Exports endet mit einem Plan in Textform, den man von Hand in den Editor übertragen muss.
Außerdem schlägt die KI Dinge vor, die FerroLog nicht abbilden kann (z. B. Supersätze).

## Festlegungen (2026-11-11)

| # | Frage | Entscheidung |
|---|---|---|
| Q1 | Wie erfährt die KI, was geht? | Der Export erklärt sich selbst: `capabilities` (kann / kann nicht) und `planImport` (Rückformat mit Beispiel). Kein MCP fürs Erste. |
| Q2 | Rückformat | Das Planschema aus dem Export. Gelistete Workouts werden als Ganzes ersetzt (nach `id`), ohne `id` neu, `delete` entfernt, nicht gelistete bleiben. Keine Patch-Operationen. |
| Q3 | Weggelassenes | `fails` lässt die KI weg, die App behält ihn bei gleichem Übungsnamen. Ebenso bleiben bei vorhandenen Übungen Steigerung, Entlastung und Pausen, wenn sie fehlen; neue Übungen bekommen die App-Standards. |
| Q4 | Begründungen | `why` pro Übung, nur in der Vorschau, nicht gespeichert. |
| Q5 | Trainings | Werden vom Import nie angefasst. |
| Q6 | Ablauf im Chat | Zwei Schritte: erst nur Analyse, dann fragt die KI, ob sie eine Optimierung vorschlagen soll. Plan und `planImport`-Block erst nach Ja. Prompt in der Systemsprache (Deutsch, sonst Englisch mit Antwort in der Systemsprache). |
| Q7 | Anleitung wird übersehen | Anleitung, `capabilities`, `planImport` und `derived` stehen gleich nach dem Kopf, vor den Rohdaten (vorher am Dateiende). Feld heißt `instructions` statt `prompt`, mit Überschriften pro Schritt und explizitem Stopp. Beim Export kommt der Prompt zusätzlich in die Zwischenablage, weil viele Apps beim Teilen nur die Datei nehmen. |

## Phasen

1. **Erledigt** (`f51ab0c`): Export erklärt sich selbst, Prompt fragt nach einem `planImport`-Block.
2. **Erledigt** (`f51ab0c`): Einstellungen → Daten → „Plan von KI übernehmen“. Dialog zum Einfügen (aus der Zwischenablage vorbefüllt, Codeblock und Text drumherum werden ignoriert) oder „Datei öffnen“ (jede Textdatei: .json, .txt; `file_picker`; ein kompletter Export wird erkannt und abgelehnt), Prüfung mit deutscher Fehlermeldung, Vorschau pro Workout (neu, fällt weg, geänderte Werte, neue Reihenfolge, Begründung der KI), Warnung bei Training seit dem Export, Übernehmen mit Rückgängig in der Snackbar. Gesperrt, solange ein Training läuft. Muskeln der KI nur für Übungen, die die App nicht kennt.
3. Später, falls nötig: Remote-MCP über die GitHub-Synchronisierung (`propose_plan`, das auf dem Server prüft).
