# Dein Training: Statistik meldet sich

Stand der Umsetzung der Startseiten-Karte „Dein Training“. Wird bei jedem Schritt fortgeschrieben.

- Entwurf (Canvas): https://claude.ai/artifact/KjrBveaiuAr7qzegrXcHhY
- Code: [lib/findings.dart](../lib/findings.dart) (Befunde, ohne UI), [lib/training_card.dart](../lib/training_card.dart) (Karte, Sheet, Knöpfe), Sprünge in [lib/stats.dart](../lib/stats.dart)
- Tests: [test/findings_test.dart](../test/findings_test.dart), [test/home_test.dart](../test/home_test.dart)

## Kundenproblem

Man trainiert, schaut aber nicht in die Statistik. Die Statistik soll sich melden, wenn sie etwas findet,
eine Empfehlung geben und zeigen, woher sie es weiß.

## Festlegungen (Grill-Runden, 2026-11-08)

| # | Frage | Entscheidung |
|---|---|---|
| Q1 | Was wird zusammengelegt? | Eine Karte „Dein Training“ ersetzt Motivations-Karussell und Aufgaben. |
| Q2 | Pflege (Körpergewicht, Muskeln) | Raus von der Startseite: Körpergewicht in der Zusammenfassung nach dem Training, Muskeln im Übungs-Editor. |
| Q3 | Knöpfe, die den Plan ändern | Nur im Detail-Sheet, mit Rückgängig. |
| Q4 | Während ein Training läuft | Karte weg. |
| Q5 | Wie oft melden | Höchstens ein Ratschlag gleichzeitig, danach 1 Woche Pause; „Später“ = 2 Wochen; nach Planänderung 4 Wochen still. |
| Q6 | Katalog | Handlungsbedarf: Wochenziel knapp, Ausgelassen, Balance, Plateau. Positiv: Rekord, Fortschritt, Meilenstein, Rekordmonat. Gestrichen: today, tonnage, next, close, streak, fresh, journey, bodyWeight-Verhältnis, pause. |
| Q7 | Reihenfolge | Oben immer Handlungsbedarf (falls vorhanden), darunter max. 2 Zeilen, bevorzugt Positives. |
| Q8 | Positive Befunde | Gelten bis zum nächsten Training. |
| Q9 | Nichts gefunden | Eine Zeile „Alles im Lot · Statistik ansehen“. |
| Q10 | Tippen | Handlungsbedarf öffnet das Sheet, Positives springt direkt in die Statistik. |
| Q11 | Knöpfe je Typ | Balance: Vorziehen / −1 Satz. Ausgelassen: Vorziehen. Plateau: kein Knopf (Erklärung, Deload-Status, Link in den Editor). Wochenziel: kein Knopf. |
| Q12 | Linkziele | Balance → Balance-Karte mit Paar. Plateau, Rekord, Fortschritt, Ausgelassen → Übungsdetail mit markierten Trainings. Wochenziel → Wochengrafik. Meilenstein, Rekordmonat → Verlauf. |
| Q13 | Ausgelassen ab wann | Mindestens 2× komplett ausgelassen in 4 Wochen. |
| Q14 | Ausgelassen + Balance | Nur „Ausgelassen“ (Ursache schlägt Folge); das Sheet nennt die Folge und verlinkt die Balance. |
| Q15 | Rangfolge Handlungsbedarf | Wochenziel > Ausgelassen > Balance > Plateau; innerhalb eines Typs der stärkste Ausschlag. |
| Q16 | Wochenpause gilt für | Ausgelassen, Balance, Plateau gemeinsam; Wochenziel und Positives ausgenommen. |
| Q17 | Einstellungen | Zwei Schalter: „Hinweise zum Training“ (`home.tasks`) und „Erfolge“ (`home.insights`). |
| Q18 | Export | `derived.findings` ersetzt `tasks` und `facts`: `type`, `kind`, `title`, `evidence`, `advice`, `source`. |
| — | Höhe | Max. ca. 240 dp, „Starten“ des nächsten Workouts ohne Scrollen sichtbar (Pixel 6). |

Spätere Präzisierungen beim Bauen:

- Ein Plateau braucht einen verfehlten oder leichter gemachten Satz; ohne eingeschaltete Steigerung kein Plateau. Gezählt werden nur Wiederholungen mit vollem Gewicht.
- Erklärt ein Auslassen eine Balance-Lücke, führt der Link zur Balance-Karte, sonst zum Übungsdetail.
- Balance-Beleg: Prozent zuerst, dann die Muskelgruppen („60 % · Schultern 7,5 : Latissimus 4,5 Sätze/Woche“); die Übungsnamen stehen im „Warum“.
- Die Balance im Befund rechnet über dieselben 30 Tage und Wochen wie die Statistik, damit die Zahlen dort übereinstimmen. „Ausgelassen“ bleibt bei 4 Wochen.

## Phasen

| Phase | Inhalt | Stand |
|---|---|---|
| 1 | Befunde als Modell (`findings.dart`) mit Tests | ✅ `238f43c` |
| 2 | Startseite: Karte, Detail-Sheet, Knöpfe mit Rückgängig, Einstellungen; alte Karten, `tasks.dart` und `homeFacts` entfernt | ✅ `f17b4a7` |
| 3 | Sprünge in die Statistik: Balance-Karte und Wochengrafik scrollen ins Bild und werden hervorgehoben, Übungsdetail markiert Trainings und nennt ausgelassene | ✅ `4559014` |
| 4 | Pflege an ihren Ort: Körpergewicht in der Zusammenfassung hervorheben, eigene Übungen ohne Muskeln im Editor und in der Workout-Liste markieren | ✅ `e96ce06` |
| 5 | Export: `derived.findings` statt `tasks`/`facts`, `about` und Tests anpassen | ⏳ offen. Bis dahin füllt eine Übergangslösung `tasks`/`facts` aus den Befunden. |
| 6 | Demo-Daten mit jedem Befundtyp, Durchklicken im `web-demo`, Commits; Push und Handy nur auf Zuruf | ⏳ offen |

### Phase 3 im Detail

- `statsFocus` in `stats.dart`: Ziel für den nächsten Aufruf des Statistik-Tabs, wird einmal verbraucht.
- Statistik-Tab: Zeitraum 30 Tage (ohne die gespeicherte Wahl zu ändern), scrollt seitenweise, bis die Karte gebaut ist, dann `ensureVisible`; Karte 4 s umrandet, Balance-Paar getönt.
- `ExerciseStats(name, marked: …)`: markierte Trainings getönt; Trainings ohne Satz der Übung als „Ausgelassen am …“ oben; Zeitraum weit genug für alle markierten.
- Verlauf (Meilenstein, Rekordmonat): öffnet nur den Tab, ohne Markierung.
- Gefunden beim Testen: Die Statistik-Liste baut Karten außerhalb des Bildschirms nicht; ohne das schrittweise Scrollen sprang der Link ins Leere.

### Phase 4 im Detail

- Zusammenfassung nach dem Training ([recap.dart](../lib/recap.dart)): Liegt das letzte eingetragene Körpergewicht mehr als 30 Tage zurück, steht unter dem Feld orange „Zuletzt vor N Tagen eingetragen. Einmal im Monat hält die Statistik aktuell.“ Wer nie ein Körpergewicht einträgt, wird nicht gefragt (wie vorher).
- Workout-Karte ([main.dart](../lib/main.dart), `WorkoutCard`): Unter eigenen Übungen ohne bekannte Muskeln (kein Cardio) steht „Muskeln festlegen, sonst fehlt sie in der Statistik“; antippen öffnet den Übungs-Editor (`editExerciseIn`, auch vom Plateau-Sheet genutzt).
- Übungs-Editor ([edit.dart](../lib/edit.dart), Muskel-Karte): oben der Hinweis, dass eine unbekannte Übung ohne Muskeln in Balance und Muskelkarte fehlt.
- Tests: [test/home_test.dart](../test/home_test.dart) „care where it belongs“. Im Browser nicht sichtbar, weil die Demo weder eine unbekannte Übung noch ein altes Körpergewicht hat (kommt mit Phase 6).

## Offene Punkte

- Workout-Übersicht zeigt bei Übungen mit Range nur die Untergrenze („8 8 8“ statt „8–12“).
- Für die letzten 3 s des Vorlaufs bei Zeitübungen gibt es keinen eigenen Piepton, nur das Signal bei „Los“.
