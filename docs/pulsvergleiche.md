# Arbeitsanweisung für Pulsvergleiche im Übungsverlauf

**Umsetzungsstand 27.11.2026:** umgesetzt in [pulse_compare.dart](../lib/pulse_compare.dart) (Zuordnung, Vergleich, Text) und [stats.dart](../lib/stats.dart) (Kennzahl „Max. Puls“), Tests in [pulse_compare_test.dart](../test/pulse_compare_test.dart).

- **Anzeige:** Segment „Max. Puls“ erscheint, sobald irgendein Training eine Pulskurve hat. Punkte pro Training, Linie bricht bei Trainings ohne Wert, y-Achse mindestens 20 bpm hoch (kleine Unterschiede wirken sonst groß). Zeile „163 bpm · 3×8 mit 80 kg“ oder „Kein Pulswert · …“, bei Teilabdeckung darunter „Puls für 2 von 4 Sätzen“. Keine Bestleistungs- oder Rückschritt-Markierung, die 1RM-Zeile ist in dieser Ansicht ausgeblendet. Screenreader: Diagramm und Zeilen mit „Schläge pro Minute“.
- **Fenster:** Satzbeginn = Tipp minus geschätzte Satzdauer (`setWorkSeconds`: Wdh. × Tempo, Haltesätze ihre Sekunden), Nachlauf 30 s (`pulseTail`), gekappt am geschätzten Beginn des nächsten Satzes irgendeiner Übung (nach Loggzeit sortiert). Cardio mit Start und Ende zählt als Fenster mit, damit nichts doppelt zugeordnet wird. Sample in Fenstern zweier Übungen → verworfen.
- **Verwertbar:** ≥ 2 Samples im Fenster, keine Lücke über `pulseGap` (wie die Pulskurve, 20 s), erstes Sample höchstens `pulseGap` nach Satzbeginn, letztes höchstens `pulseGap` vor dem Tipp. Ohne Zeitstempel keine Zuordnung. Maximum nur aus verwertbaren Fenstern; alle Sätze verwertbar = vollständig.
- **Hinweis:** Ziel = jüngstes vollständig gemessenes Training im Zeitraum, ohne ausgelassene Sätze, Backoff, Deload, leichtere/weniger Sätze, Schmerz. Ist es nicht sauber, kein Hinweis. Vergleich: bis 5 frühere saubere, vollständig gemessene Trainings mit gleicher Satzzahl, gleichen ausgeführten Wdh. und gleichen Gewichten, Vorbelastung gleich oder unbekannt; mindestens 3 (`pulseMinRefs`). Sonst „mehr Last“: dieselben Wdh., vorher einheitlich ein niedrigeres Gewicht (das jüngste), mindestens 3, nur „ähnlich“ wird gesagt. Ähnlich = in der Spannweite und ≤ 5 bpm vom Median (`pulseSimilarBpm`), niedriger/höher = außerhalb und ≥ 5 bpm; dazwischen kein Hinweis.
- **Text:** zwei ganze lokalisierte Sätze, „Heute:“ oder „Am {Datum}:“ vorneweg. Zusätzlich zur Tabelle: gleiche Arbeit und ähnlicher Puls („…blieb mit 152 bpm im üblichen Bereich“).
- **Abweichungen:** Die Kurzform für das erste vollständig gemessene Training entfällt, weil die Listenzeile darunter dasselbe sagt. Ähnliche tatsächliche Pausen werden noch nicht abgeglichen, nur die Vorbelastung. Reserve wird nicht geprüft, keine Aussage setzt sie voraus.
- **Demo:** Pulskurven in den letzten acht Wochen (Zeitstempel gibt es nur in den letzten zwei Monaten), vor 27–29 Tagen ohne Gurt: Kniebeugen-Linie mit Lücke. Bankdrücken (Plateau) zeigt den Hinweis. Geprüft auf 375 px in Deutsch und Englisch.


Wer „Rumänisches Kreuzheben“ öffnet, soll sehen, welchen höchsten Puls FerroLog bei dieser Übung in jedem Training gemessen hat. Dazu soll die App bei ausreichenden Daten einen kurzen Hinweis geben, etwa „Heute 85 kg für 3×8. Bei deinen letzten drei vergleichbaren Trainings waren es 80 kg. Dein Spitzenpuls lag dabei in einem ähnlichen Bereich.“

## 1. Den Maximalpuls im Verlauf anzeigen

Erweitere bei Kraftübungen die bestehende Kennzahlenauswahl in der Einzelstatistik um **„Max. Puls“**. Verwende den gewählten Zeitraum und die vorhandene Trainingsliste. Zeige pro Training einen Punkt, auf der Zeitachse das Datum und auf der Wertachse bpm. In der zugehörigen Listenzeile stehen beispielsweise **„163 bpm · 3×8 mit 80 kg“**. Bei unterschiedlichen Satzgewichten zeige die vorhandene Satzdarstellung. Ein hoher Spitzenwert erhält keine Bestleistungsmarkierung. [Einzelstatistik](../lib/stats.dart)

- Der erste verwertbare Wert genügt für einen Punkt. Ein Vergleichshinweis kann später hinzukommen.
- Trainings ohne verwertbare Pulswerte bleiben in der Liste. Zeige dort „Kein Pulswert“ und unterbrich die Linie. Bei vollständig fehlenden Messungen genügt in der Pulsansicht „Für diese Übung liegen im gewählten Zeitraum keine Pulswerte vor.“
- Zeige bei teilweise erfassten Trainings die Abdeckung, etwa „154 bpm · Puls für 2 von 4 Sätzen“. Das ist der höchste **gemessene** Wert der erfassten Sätze. Verwende solche Einheiten zunächst nur für die Anzeige.
- Beim Wechsel von Übung oder Zeitraum aktualisieren sich Diagramm, Liste und Hinweis gemeinsam. Stelle die Kennzahl und ihre Einheit auch für Screenreader bereit.

## 2. Den Wert der richtigen Übung zuordnen

Leite die Werte aus der gespeicherten Pulskurve der jeweiligen Session und den Loggzeitpunkten der ausgeführten Sätze ab. Die nummerierten Übungsmarker im Rückblick zeigen bei Kraftübungen den ersten geloggten Satz. Eine Aufteilung der Kurve allein an diesen Markern würde den ersten Satz der nächsten Übung teilweise dem Vorgänger zuschlagen. [Pulskurve und Marker](../lib/pulse_chart.dart) · [Vorhandene Zeitabschätzung](../lib/timing.dart)

1. Bilde pro ausgeführtem Arbeitssatz ein Zeitfenster vom gemessenen oder geschätzten Satzbeginn bis kurz nach dem Loggzeitpunkt. Nutze vorhandene Zeitabschätzungen oder bei Haltesätzen die ausgeführte Dauer. Als Startwert für den Nachlauf gelten höchstens 30 Sekunden, damit auch eine kurz verzögerte Spitze erfasst wird.
2. Begrenze den Nachlauf spätestens am Beginn des nächsten Satzes irgendeiner Übung. Verarbeite die tatsächlich geloggte Reihenfolge. Bei überlappenden oder widersprüchlichen Zeitfenstern lasse uneindeutige Samples aus. Kein Sample darf zwei Übungen zugerechnet werden.
3. Ermittle das Maximum aus den gültigen Samples der zugeordneten Fenster. Werte außerhalb der Fenster, etwa beim Weg zur nächsten Station, bleiben außen vor. Überbrücke keine Signallücken. Ein einzelner isolierter Messpunkt reicht nicht für ein verwertbares Satzfenster. Verwende die vorhandene Lückendefinition für die Pulskurve. Markiere unterbrochene oder unzureichend abgedeckte Fenster für die Vergleichsauswahl.
4. Fasse alle verwertbaren Sätze derselben Übung in derselben Session zu einem Wert zusammen, auch bei unterbrochener Reihenfolge. Nutze bei zwei Trainings am selben Kalendertag die jeweilige Session als Bezug. Der Maximalpuls der gesamten Session gehört ausschließlich in den Trainingsrückblick.
5. Berechne den Verlauf auch für bestehende Trainings, soweit Puls und Zeitstempel vorliegen. Änderungen an Sätzen, Umbenennungen, Zusammenführungen und gelöschte Einheiten müssen sich wie im übrigen Übungsverlauf auswirken.

## 3. Einen verständlichen Hinweis zusammensetzen

Platziere höchstens einen Hinweis unter dem Diagramm. Beziehe ihn auf das jüngste angezeigte Training mit vollständiger Messung und nenne dessen Datum, wenn inzwischen ein neueres Training vorliegt. Baue den Text aus höchstens zwei vollständigen, lokalisierbaren Sätzen: zuerst die beobachtete Leistung, dann der Pulsvergleich. Für die deutsche und englische Fassung ganze übersetzbare Nachrichten mit Zahlenplatzhaltern verwenden.

**Vergleich auswählen.** Nutze zunächst drei bis fünf frühere Trainings derselben Übung innerhalb des gewählten Zeitraums. Bevorzuge gleiche Satzanzahl, Wiederholungen, Satzgewichte und ähnliche tatsächliche Pausen sowie vergleichbare Vorbelastung, soweit bekannt. Schließe ausgelassene Sätze, Backoffs, Deloads, erkennbare Messaussetzer und uneindeutige Zuordnung aus. Wenn die Aussage eine gleiche Reserve voraussetzt, muss sie tatsächlich angegeben sein. Ohne passende Basis bleibt es beim Messwert.

**Ähnliche Werte und Abweichungen unterscheiden.** Vergleiche den heutigen Maximalpuls mit dem Median der persönlichen Referenzwerte. Für den ersten Entwurf gilt ein Wert als ähnlich, wenn er innerhalb der bisherigen Spannweite liegt und höchstens 5 bpm vom Median abweicht. „Niedriger“ oder „höher“ ist als Hinweis erst sinnvoll, wenn er außerhalb der Spannweite und mindestens 5 bpm vom Median entfernt liegt. Dazwischen entfällt der Pulssatz. Die 5 bpm sind ein einstellbarer Entwicklungswert für ruhige Texte, keine sportliche Zielgröße. Einen mehrwöchigen Trend erst beschreiben, wenn wiederholte Beobachtungen diese Richtung zeigen.

| Wann der Hinweis passt | Beispieltext mit fiktiven Daten |
|---|---|
| Gleiche Arbeit, heute geringerer Spitzenpuls | „Wieder 3×8 mit 80 kg geschafft. Dein Spitzenpuls lag heute bei 151 bpm, in drei vergleichbaren Trainings typischerweise bei 160 bpm.“ |
| Mehr Last bei denselben ausgeführten Wiederholungen und ähnlichem Puls | „Heute 3×8 mit 85 kg, zuvor dreimal mit 80 kg. Dein Spitzenpuls blieb mit 158 bpm im üblichen Bereich.“ |
| Gleiche Arbeit bei höherem Puls | „Alle 3×8 mit 80 kg geschafft. Dein Spitzenpuls lag mit 166 bpm heute über deinen letzten drei vergleichbaren Trainings.“ |
| Erstes Training mit vollständiger Messung | „Heute 3×8 mit 80 kg, maximal 158 bpm.“ Diese Kurzform nur verwenden, wenn sie zusätzliche Information zur aktuellen Ansicht liefert. |

Für „mehr Last“ darf gezielt **eine** Vergleichsgröße wechseln. Vergleiche denselben Satzaufbau und dieselben ausgeführten Wiederholungen bei einem vorherigen einheitlichen niedrigeren Arbeitsgewicht. Bei unterschiedlichen Satzprofilen oder ebenfalls geänderter Satzzahl entfällt diese Aussage. Hat die bestehende Progressionslogik bereits einen nächsten Schritt bestimmt, darf dessen begründeter Vorschlag im Rückblick erscheinen. Der Pulsvergleich löst selbst keine Änderung an Gewicht, Wiederholungen oder Pausentimer aus.

## 4. Abnahme

- Zwei Übungen im selben Training, Sitzungsspitze 163 bpm beim Kreuzheben und Bankdrückspitze 146 bpm. Der Bankdrückverlauf zeigt 146 bpm. Ein höherer Wert zwischen den Übungen verändert keinen der beiden Punkte.
- Zwei Sätze unterschiedlicher Übungen liegen kurz hintereinander. Eine verzögerte Spitze erscheint höchstens bei einer Übung. Fehlende Zeitstempel erzeugen keine Zuordnung nach Planreihenfolge.
- Ein Training ohne Sensor liegt zwischen zwei gemessenen Trainings. Die Linie hat eine Lücke. Eine nur teilweise erfasste Übung zeigt ihre Abdeckung und liefert keine Vergleichsaussage.
- Bei Referenzwerten von 158, 160 und 162 bpm sowie gleichen 3×8 mit 80 kg liefert ein heutiger Wert von 151 bpm den ersten Vergleichstext. Bei heute 85 kg und 158 bpm passt der zweite. Bei verändertem Satzschema oder nur einem früheren Vergleichstraining entfällt der Vergleich.
- Prüfe den exakten Bildschirm „Übungsverlauf → Max. Puls“ auf schmalem Display in Deutsch und Englisch, einschließlich Datumsfilter und Einheiten. Verwende realistische Beispieldaten ausschließlich in der Web-Demo auf Port 8091 und prüfe die Zuordnung und Textauswahl gezielt mit automatisierten Tests.

## Erweiterung 27.11.2026: Zusammenfassung nach dem Training (A + B)

- **A – Puls pro Satz:** Die Satzkacheln in der Zusammenfassung haben eine dritte Zeile mit dem Spitzenpuls des Satzes (`setPulses`, gleiche Fenster wie oben; „–“ = nicht messbar). Rot mit ↑ / blau mit ↓ nur, wenn der Satz außerhalb der Spanne und ≥ 5 bpm vom Median desselben Satzes in ≥ 3 früheren Trainings mit gleicher Arbeit liegt (`setPulseDirs`: gleiche Wdh., Gewichte, Vorbelastung; kein Backoff/Deload). Mehr Last = andere Arbeit, kein Pfeil.
- **B – Vergleichszeile** unter „a set every …“: „♥ max 152 · wie üblich / 6 über üblich / 4 unter üblich / mehr Last, Puls wie üblich“ (Hinweis aus `pulseNote`, nur wenn er dieses Training betrifft), dann der 4-Wochen-Trend bis zu diesem Training (`exerciseTrend`, wie in der Statistik: steigt/stabil/sinkt/hängt fest ±x %).
- Nur in der Zusammenfassung (`RecapPage`), nicht in den Verlaufskarten; tippen auf eine Verlaufskarte öffnet sie.
- Tests: `setPulses` pro Satz, `setPulseDirs` (Pfeile, < 3 Refs, mehr Last, fehlender Satz).
