# Aufwärmsätze und Scheibenrechner

Stand der Umsetzung (WP6a der Improvement-Spec). Wird bei jedem Schritt fortgeschrieben.

- Code: [lib/loading.dart](../lib/loading.dart) (`warmupSets`, `platesPerSide`, Stange und Scheiben aus den Einstellungen), [lib/timing.dart](../lib/timing.dart) (`isBarbell`, vorher `_barbell`), [lib/session.dart](../lib/session.dart) (`_warmup` auf der Karte, „Pro Seite“ in `showWeightSheet`), [lib/settings.dart](../lib/settings.dart) (Gruppe „Hantel“), [lib/plan_import.dart](../lib/plan_import.dart) (`capabilities`)
- Tests: [test/loading_test.dart](../test/loading_test.dart), [test/warmup_test.dart](../test/warmup_test.dart)

## Kundenproblem

Die Zeitschätzung rechnete schon mit Aufwärmsätzen, gezeigt hat die App sie nie. Und die Scheiben pro Seite musste man im Kopf ausrechnen.

## Festlegungen (2026-11-12)

| # | Frage | Entscheidung |
|---|---|---|
| Q1 | Aufwärmen bis zu welchem Gewicht? | Bis zum ersten Satz (`weights.first`), nicht zum schwersten: bei Rampen und Back-off-Sätzen ist das der, vor dem aufgewärmt wird. |
| Q2 | Rechnen in kg oder lb? | In der angezeigten Einheit: Stufen auf 2,5 kg bzw. 5 lb gerundet, „zu nah“ heißt unter 5 kg bzw. 10 lb vor dem Arbeitssatz. Stange und Scheiben sind pro Einheit gespeichert (`barbell.bar.kg`, `barbell.plates.lb` …). |
| Q3 | Stangen zur Wahl | kg: 20, 15, 10. lb: 45, 35, 15 (die Spec nennt nur 45). |
| Q4 | Wo die Häkchen leben | Nur im Zustand der Trainingsseite: nicht geloggt, kein Volumen, keine Pause. Die Zeile verschwindet mit dem ersten geloggten Satz. Jeder Aufwärmsatz zeigt seine Scheiben pro Seite. |
| Q5 | Wann gezeigt | Nur wenn eingeschaltet (Q9); Langhantel-Übungen nach `isBarbell`, nicht Cardio, nicht auf Zeit, erster Satz schwerer als die Stange. Assistenz (≤ 0) zeigt nichts. |
| Q6 | Gewichts-Sheet | Unter dem Feld „Pro Seite: 25 + 10 + 2,5“, „Nur die Stange“ oder „Mit deinen Scheiben nicht ladbar“; auch beim Bearbeiten vergangener Trainings. |
| Q7 | Export | Keine neuen Felder. `capabilities` sagt jetzt, dass Langhantel-Übungen das Aufwärmen von selbst zeigen; eigene Aufwärmsätze stehen unter `cannot`. |
| Q9 | An oder aus? (2026-11-12) | Aufwärmsätze sind optional und standardmäßig aus: Schalter „Aufwärmsätze zeigen“ in der Gruppe „Hantel“ (`session.warmup`). „Pro Seite“ im Gewichts-Sheet bleibt immer an. |
| Q8 | Zeitschätzung | Unverändert (eigene Formel in `_setupSeconds`), sie liegt für 100 kg ebenfalls bei 4 Aufwärmsätzen. |

## Phasen

1. **Erledigt**: WP6a.
