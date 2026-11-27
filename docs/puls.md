# Puls im Training (Ideen)

Ideensammlung für Puls rund ums Training: kurz davor, währenddessen, kurz danach.
Live-Puls und dynamische Pausen funktionieren mit einem Bluetooth-Pulssensor
im geöffneten Training. In der [Web-Demo](http://localhost:8091/?pulse) sind
sie auch mit simulierten Werten testbar.

1. In Zepp unter **Gerät → Amazfit Helio Strap → Gesundheitsüberwachung**
   die Pulsübertragung (**Heart Rate Push**) einschalten.
   [Amazfit-Anleitung](https://support.amazfit.com/us/amazfit_helio_strap/docs/GyUIdtHLvoMqNUxOkuNcQB4hn4d)
2. In FerroLog ein Training öffnen, oben auf das Bluetooth-Symbol tippen
   und den Helio Strap auswählen. Sobald Messwerte eintreffen, zeigt die
   Live-Leiste den Puls an.
3. Einen Satz loggen. Wenn der Puls nach Ablauf der Mindestpause noch bei
   mindestens 110 bpm liegt, wartet FerroLog höchstens bis zur doppelten
   Pausendauer. Fehlt das Signal fünf Sekunden lang oder bricht die
   Verbindung ab, gilt die Mindestpause. Ist sie schon abgelaufen,
   erscheint sofort „LOS“.

Für echte Messwerte im Browser die Web-Demo ohne `?pulse` in einem Browser
mit Web Bluetooth öffnen. Der Android-Testbuild verwendet die native
Bluetooth-Verbindung.

Nach dem Loggen eines Satzes fällt der simulierte Puls von 150 bpm alle vier
Sekunden um 1 bpm. Die Pause endet frühestens nach der geplanten Dauer,
sobald der Puls unter 110 bpm fällt, spätestens nach der doppelten geplanten
Dauer. Mit 90 Sekunden geplanter Pause greift die Pulsschwelle, mit 30 Sekunden
die Obergrenze. Die normale Demo ist unter `http://localhost:8091/` erreichbar.

## Quelle: Amazfit Helio Strap per Bluetooth

- FerroLog verbindet sich direkt über den Bluetooth Heart Rate Service
  (`0x180D`, Messwerte über `0x2A37`). Auch Brustgurte mit diesem Dienst
  können ausgewählt werden.
- Health Connect / Apple Health sind für Echtzeit zu langsam (Zepp synchronisiert verzögert, in Paketen). Siehe auch WP8e in [android.md](android.md).
- Beim Verlassen der Trainingsansicht trennt FerroLog die Sensorverbindung.
- Wenn das Betriebssystem die App im Hintergrund anhält, kann der native
  Pausentimer bei aktivem Sensor bis zur Obergrenze weiterlaufen.
- Am Oberarm tragen: am Handgelenk verfälscht das Greifen die optische Messung.
- Android und iOS fragen die Bluetooth-Berechtigung beim Verbinden an.

### Vorher prüfen (nRF Connect)

1. Pulsübertragung des Straps in der Zepp-App einschalten.
2. In nRF Connect scannen: taucht der Strap mit „Heart Rate“ (Service `0x180D`) auf und liefert Werte?
3. Kommt das Feld „RR Interval“ mit? Davon hängt die HRV beim Tagesform-Check ab.

## Kurz davor

- **Tagesform-Check:** 1–2 Minuten Ruhepuls (und HRV aus den RR-Abständen, falls der Strap sie sendet). Deutlich über dem üblichen Wert vor dem Training: Vorschlag für einen leichteren Tag (weniger Gewicht, Deload).
- **Aufwärmen:** Erster Arbeitssatz erst, wenn der Puls eine Zone erreicht hat.

## Während

- **Live-Puls** in der Live-Leiste neben der Pausenzeit.
- **Dynamische Pausen** (Timer in [lib/session.dart](../lib/session.dart), `restTarget` / `restLeft`):
  - Geplante Pause (`restSeconds` / `failRestSeconds`) bleibt die Mindestpause.
  - Danach „los“, sobald der Puls unter eine Schwelle fällt: fester Wert (z. B. 110 bpm) oder Abfall um X Schläge seit Satzende.
  - Obergrenze (z. B. doppelte geplante Pause), falls der Puls nicht sinkt.
  - Grund für die Mindestpause: Der Puls zeigt die Erholung von Herz und Kreislauf, nicht die der Muskeln. Bei schweren Sätzen brauchen die Muskeln oft länger.
- **Pro Satz speichern:** Spitzenpuls und Abfall in 60 s nach Satzende.
- **Cardio:** Zielzone (z. B. Zone 2), Vibration bei darüber oder darunter.
- Optional: vorsichtige Warnung bei ungewöhnlich hohem Puls, ohne medizinischen Anspruch.

## Kurz danach

- **Pulskurve im Rückblick (umgesetzt):** Während das Training offen ist, speichert FerroLog alle 5 s
  den Puls (`pulse` im Training, `[Sekunden seit Start, bpm]`). Der Rückblick zeigt die Kurve mit
  Ø/Spitzenpuls, Minuten über der Pausenschwelle (110 bpm, gestrichelt), nummerierten Markern beim
  ersten Satz jeder Übung und einem Strich je Satz auf der Zeitachse. Signallücken (> 20 s) bleiben
  Lücken. Die Demo hat Pulsdaten für die letzten drei Wochen, simuliert auch mit `?pulse`.
- **Zusammenfassung:** Zeit in den Zonen, Durchschnitts- und Spitzenpuls, Trainingslast nach Edwards (Minuten je Zone × 1–5).
- **Erholungsmessung:** 1–2 Minuten nach dem letzten Satz, wie schnell der Puls fällt.

## Intensität

- Beim Heben ist Intensität die Last (% vom Maximalgewicht, Wiederholungen in Reserve). Der Puls misst sie schlecht: Eine schwere Einzelwiederholung hebt ihn kaum, 15 leichte stark. Dafür bleiben Gewicht und Wiederholungen.
- Gut misst der Puls die Belastung für Herz und Kreislauf: Zonen, Trainingslast, Dichte (Durchschnittspuls), Erholung.
- Zonen nach % Maximalpuls (geschätzt 208 − 0,7 × Alter nach Tanaka, oder selbst eingetragen), genauer mit Ruhepuls (Karvonen). Braucht Alter oder Maximalpuls in den Einstellungen.

## Auswertung (offen, ob gewünscht)

Nutzt nur die oben gespeicherten Trainingsdaten, misst nichts zusätzlich:

- Puls bei gleicher Last über Wochen (z. B. 5×5 Kniebeuge mit 100 kg): sinkt = Gewöhnung; steigt plötzlich = Müdigkeit, Krankheit, schlechter Schlaf. Kandidat für einen Befund in „Dein Training“.
- Erholung nach dem Satz über Wochen.
- Werte in `ferrolog.json` für die KI-Analyse.

## Lernende Pausen (nächstes Feature nach der Pulskurve)

Umsetzungsvorgabe mit Prüffällen: [adaptive-pausen-und-progression.md](adaptive-pausen-und-progression.md).
Kurz: eine Größe pro Training ändern (Last, Wdh. oder Pause), zuerst nur
Verlängerung vor einem späten Satz, Verkürzen nur auf ausdrücklichen Wunsch.

Einstellung **„Pausen lernen“**: aus / nur Dauer / Dauer + Puls. Gebaut wird
zuerst „nur Dauer“, das funktioniert ohne Gurt. Leitfrage: „Passt meine Pause
vor dem fünften Satz Bankdrücken?“ Änderungen am Plan schlägt FerroLog nur vor,
du bestätigst sie.

### Was gemessen wird

Der Nutzer tippt wie bisher nur nach dem Satz auf den Satzkreis (zweimal bei
weniger Wiederholungen). Alles andere misst FerroLog nebenher:

| Wert | Woher |
|---|---|
| Satzende | `doneAt` beim Tipp, exakt |
| Satzbeginn | Loggzeit − geschätzte Satzdauer (übungsabhängiges Tempo × ausgeführte Wdh., bei Haltesätzen die Dauer) |
| Tatsächliche Pause | Satzende bis geschätzter Beginn des nächsten Satzes, daher nur grobe Bereiche |
| Ergebnis | Wdh. pro Satz; `rir` nur einmal pro Übung, gehört zum letzten Satz |
| Puls (später) | aus `pulse` (alle 5 s) und `doneAt` nachträglich berechenbar, braucht keine eigene Speicherung |

### Nur Dauer: Ausgangspunkt letzter Satz

- **Letzter Satz zuerst:** Dort liegt am meisten Information. 5/5 kann gerade so oder mit 2 in Reserve gelungen sein, das unterscheidet `rir`. Fehlversuche in früheren Sätzen zählen zusätzlich, ihnen fehlt aber der RIR.
- **Vergleichbar heißt:** dieselbe Übung, derselbe Satz im Plan, ähnliche Last. Eine Gewichtserhöhung erklärt einen schwereren Satz 5 oft besser als die Pause.
- **Grobe Zeitbereiche** (z. B. „rund 2 min“, „rund 2½ min“), keine Sekunden: `doneAt` ist der Tipp, der Satzbeginn geschätzt.
- **Vorschlag erst bei einem Muster:** mehrere vergleichbare Trainings mit *unterschiedlich* langen Pausen. Sechsmal 2:00 sagt nichts über 2:30. Keine Zähleranzeige („12/30“), sie verspricht Gewissheit, die durch Weiterzählen kaum wächst.
- **Kriterium:** die kürzeste Pause, die gut genug ist (höchstens ~1 Wdh. bzw. 1 RIR weniger als mit längerer Pause), nicht die mit den meisten Wdh. Längere Pausen bringen fast immer mehr Wdh., für das Wachstum ab einem Knick aber kaum mehr (siehe Quellen unten).
- **Pause gehört zum Satz danach.** Für Satz 1 gibt es keine. Verworfen werden Übergänge mit fehlendem/widersprüchlichem Zeitstempel, anderer Übung dazwischen, ausgelassenem Satz, auffällig langer Lücke, Backoff/Ersatz, Deload, Schmerz, schlechtem Tag, Wiedereinstieg und das erste Training nach einer Steigerung.
- **Startwert Pilot:** je Zeitbereich ≥ 3 vergleichbare Trainings an verschiedenen Tagen, ≥ 2 Verfehlungen im kürzeren, höhere Quote im längeren. Kippt die Empfehlung an einer Bereichsgrenze, auf mehr Daten warten. Schwellen an echten Verläufen kalibrieren.
- **Selektion:** Vor einem erwartet schweren Satz pausiert man von selbst länger. Darum ist der Vorschlag ein Test, kein Urteil.

Beispiel (fiktiv):

> **Bankdrücken · Pause vor Satz 5**
> Bei ähnlichem Gewicht hast du nach rund 2 Minuten in drei von vier Trainings 4/5 geschafft. Nach rund 2½ Minuten waren es dreimal 5/5.
> [Einmal testen] [Beibehalten]

Der Test gilt einmal, nur vor dem genannten Satz, bei gleicher Last und gleichem
Ziel. Danach zeigt FerroLog Soll, Ist und geschätzte Pause. Dauerhaft übernehmen
erst nach wiederholt gelungenen Tests, gespeichert pro Satzposition. Ein
fälliger Deload oder eine Planänderung verwirft den Vorschlag, der
Fehlversuchszähler bleibt unberührt. Das ersetzt das früher angedachte heimliche Lockern der
Schwelle: Streuung entsteht durch bewusste Tests. Kürzere Pausen nur mit
fester Untergrenze (z. B. 90 s bei Grundübungen).

### Dauer + Puls: erst im Hintergrund prüfen

- **Frage:** Sagt der Puls bei ähnlicher Last und ungefähr gleicher Pause *zusätzlich* etwas darüber, wie der nächste Satz läuft? Erst wenn ja, darf er den Timer beeinflussen. Bis dahin rechnet FerroLog nur mit.
- **Persönliche Schwelle** statt pauschal 110 bpm, relativ: Erholung = (Spitze − Wert) / (Spitze − Ruhepuls).
- **Derselbe Wert beim Lernen und im Timer:** das Minimum seit Satzende bis zum Satzbeginn. Steigt der Puls kurz vor der Hantel wieder (Aufregung), würde der Startpuls etwas anderes lernen, als der Timer entscheidet. Einmal unter der Schwelle gilt als erreicht.
- **Nur nach oben:** Die geplante Pause bleibt die Mindestpause, die doppelte die Obergrenze. Der Puls zeigt den Kreislauf, nicht die Muskeln.
- **Ignorieren bei kleinem Anstieg:** unter ~20–25 bpm im Satz (typisch Isolationsübungen) ist die Erholung in % Rauschen, dann zählt nur die Zeit. Automatisch nach Anstieg, nicht nach Übungsliste.

### Pausenlogik nach Satzart, kein Trainingsziel einstellen

Kraft, Hypertrophie und Kraftausdauer brauchen andere Pausen. Bei Kraftausdauer
ist die unvollständige Erholung selbst der Reiz. Statt einer Zieleinstellung
leitet FerroLog die Satzart aus der Übung ab:

| Satzart | Erkennbar an | Pausenlogik |
|---|---|---|
| Schwer, 1–5 Wdh. | 5×5, feste Steps | Knick weit rechts, Obergrenze 5 min |
| Mittel, 6–15 Wdh. | Wdh.-Bereich (Curls 8–12) | Knick ~1:30 (Singer 2024), Obergrenze 3:00 |
| Leicht/lang, > 15 Wdh. oder Zeit | Farmer's Walk 30–45 s | kurz halten, Leistungsverlust erlaubt |

### Quellen (geprüft 2026-11-27, Abstracts)

- [Schoenfeld et al. 2016](https://pubmed.ncbi.nlm.nih.gov/26605807/), JSCR: 21 trainierte Männer, 8 Wochen, 3 × 8–12 RM, 1 vs. 3 min. Kraft (Kniebeuge, Bank) klar besser mit 3 min, Hypertrophie tendenziell. Klein, einzelne Studie.
- [Singer et al. 2024](https://pmc.ncbi.nlm.nih.gov/articles/PMC11349676/), Bayes-Metaanalyse, 9 Studien: kleiner Hypertrophie-Vorteil über 60 s, über 90 s kein erkennbarer Zusatznutzen. Vermutlich über das Volumen vermittelt, große Streuung. Stützt den Knick bei Hypertrophie um 90 s.
- [Grgic et al. 2017](https://pubmed.ncbi.nlm.nih.gov/28641044/), Review: kurze (≤ 60 s) und lange Pausen wirken beide, bei Trainierten möglicher Vorteil für lange.
- [Longo et al. 2022](https://pubmed.ncbi.nlm.nih.gov/35622106/), JSCR: 1 vs. 3 min bei 80 % 1RM. Hypertrophie folgt dem Volumen, nicht der Pause. Kurze Pausen brauchen mehr Sätze für gleiches Volumen.
- [de Salles et al. 2009](https://pubmed.ncbi.nlm.nih.gov/19691365/), Review: 3–5 min erlauben mehr Wdh. über mehrere Sätze und mehr Maximalkraft. Stützt die Obergrenze 5 min für schwere Sätze.
- [Robinson et al. 2024](https://rke.abertay.ac.uk/en/publications/exploring-the-dose-response-relationship-between-estimated-resist/), Sports Med, Meta-Regression: Hypertrophie nimmt näher am Versagen zu, Kraft kaum abhängig vom RIR. Genaue RIR-Grenzen unklar.

## Verworfen

- Ruhepuls über mehrere Tage und Krankheitserkennung im Alltag: nicht rund ums Training.
- Kalorien: beim Krafttraining oft 20–40 % daneben.
- Sätze automatisch erkennen: Der Puls reagiert 10–20 s verzögert.

## Reihenfolge

1. Bluetooth-Anbindung, Live-Puls, dynamische Pausen (umgesetzt).
2. Pulskurve im Rückblick (umgesetzt).
3. Lernende Pausen „nur Dauer“:
   1. Reserve nur dem letzten Satz und nicht schwereren Sätzen zurechnen (umgesetzt, siehe [Auto-Modus](auto-modus.md) Q4).
   2. Pausenbeobachtungen aus `doneAt` rekonstruieren und verwerfen wie oben (umgesetzt: `restObservations` und `restAboutLabel` in [timing.dart](../lib/timing.dart), noch ohne Anzeige). Jede Beobachtung trägt Satzposition, Soll/Ist, Last, geschätzte Pause, Pausenart (normal/nach Fehlversuch), geplante Pause, ob die Sätze davor ihr Ziel erreichten, RIR nur beim letzten Satz und `regular` (falsch bei Ersatz/zusätzlich, Wiedereinstieg, Schmerzen, schlechtem Tag, leichteren/fehlenden Sätzen). Vergleich gleicher Last und Deload-Ausschluss folgen in 3.3.
   3. Einmal-Test „Verlängern vor Satz N“ im Rückblick, dann dauerhafte Übernahme mit Bestätigung (umgesetzt: [rest_learning.dart](../lib/rest_learning.dart), Karte im [Rückblick](../lib/recap.dart), Schalter „Pausen lernen“ pro Übung in der Pausen-Karte (`Exercise.learnRest`; neue Grundübungen an, sonst aus), darunter ein anstehender Test und gelernte Pausen, je mit ✕). Nur der letzte Satz, nur gleiche Last, gleiches Ziel und gleiche Satzzahl wie im aktuellen Plan, nur reguläre Trainings mit allen Sätzen davor geschafft, ohne Pause nach Fehlversuch und ohne Deload. Pausen in 30-s-Stufen; liegt eine Pause höchstens 5 s an einer Stufengrenze und würde die andere Zuordnung das Ergebnis drehen, kein Vorschlag. Vorschlag, wenn kurze und lange Stufe je ≥ 3 Tage haben, die kurze ≥ 2 Fehlversuche und die lange eine höhere Erfolgsquote; nur länger als die aktuelle Pause, höchstens 5 Min. „Einmal testen“ speichert `restTrial` (Satz, Sekunden, Last, Ziel, seit); das nächste Training setzt ihn, wenn Last, Ziel und Satzzahl noch passen (nicht beim Wiedereinstieg), die Fehlversuchspause hat Vorrang. Ergebnis steht im Rückblick des Testtrainings. Nach ≥ 2 erfolgreichen Tests fragt die Karte nach Übernahme in `setRests` (sichtbar und löschbar beim Bearbeiten der Übung). „Beibehalten“/„Nicht übernehmen“ merkt das Datum, derselbe Vorschlag kommt erst mit neueren Trainings wieder. Nur eine Pause gleich oft: Hinweis, dass Vergleich fehlt. Einschränkung: bei linearer Steigerung hebt ein Erfolg die Last, gleiche Last kommt vor allem bei Plateaus und Deload-Zyklen vor; Schwellen auf echten Daten kalibrieren. Offen: Position der Übung im Training (Kreuzheben zuerst vs. zuletzt) ändert die Ermüdung; Vergleich bisher ohne Position.
   4. Allgemein optimieren nach [Arbeitsanweisung](adaptive-pausen-und-progression.md) (umgesetzt): Pausen-Karte wie „Gewicht und Steigerung“ mit Umschalter **Intelligent / Fest** (`learnRest`) und aufklappbarer Erklärung; Fest = eingetragene Zeiten gelten, gelernte `setRests` werden ignoriert (bleiben gespeichert). Alle Pausen zwischen Arbeitssätzen, nicht nur vor dem letzten. Reihenfolge: länger (spätester Satz zuerst, Schwellen wie 3.3) → kürzer aus Historie (Stufe unter der aktuellen, ≥ Untergrenze 2:00 bei ≤ 5 Wdh., sonst 1:00, ≥ 3 Tage, dort jedes Mal ganze Übung geschafft und Reserve ≠ 0) → Kürzer-Versuch (letzte 4 vergleichbare Trainings gleichmäßig geschafft, Reserve ≥ 2 wo beantwortet: 30 s kürzer vor der längsten Pause). Neue Last/Ziel/Deload: keine vergleichbaren Trainings, also bewährte Pausen, kein Test. Test gilt als gelungen, wenn die ganze Übung geschafft ist und die Gesamtwiederholungen nicht unter dem Median der üblichen Trainings liegen (wichtig bei Bereichen). Schalter „Herzfrequenz berücksichtigen“ (`restPulse`, Standard an = bisheriges Verhalten) steuert pro Übung die pulsabhängige Verlängerung. Abweichung: Schalter in beiden Modi sichtbar, nicht nur in Intelligent. Offen: Fehlversuchspause lernt noch nicht (Startwert gilt), Puls-Lernen (Abschnitt 5) später. Position der Übung: siehe 3.5.
   5. Faire Vergleiche nach tatsächlicher Reihenfolge (umgesetzt, [rest_learning.dart](../lib/rest_learning.dart) `preloadOf`): Reihenfolge wechselt oft (Maschinen belegt), daher zählt `doneAt`, nicht die Planposition. Vorbelastung = Arbeitssätze anderer Übungen vor dem Satz mit gemeinsamem **Hauptmuskel** (jeder Satz einmal): **ohne** (0–1, Daten schließen 2 aus), **vorbelastet** (≥ 2, Pilotregel `preloadMinSets`), **unbekannt** (fehlende Zeitstempel/Muskeln könnten es ändern). Bestimmt am ersten und letzten Satz; verschieden (verschachtelt mit überlappender Übung) → unbekannt, satzweise Neubewertung später. Unbekannt stützt und widerlegt nichts. **Länger** nur, wenn eine Stufe es allein zeigt; zeigt die andere, ebenfalls belegte Stufe das Gegenteil → warten (verhindert: frisch+lang gelingt, vorbelastet+kurz scheitert). **Kürzer** nur mit Belegen in jeder regelmäßigen Stufe (≥ 25 % der letzten 8 bekannten Trainings); asymmetrisch, weil kürzer Sätze kostet, länger nur Zeit. **Kürzer-Versuch**: letzte 4 Trainings mit bekannter Stufe. **Test**: gelungen / nicht gelungen / **Vergleich fehlt** (keine übliche Einheit gleicher Stufe oder Stufe unbekannt; kein Rückfall auf alle Trainings, zählt nicht zur Übernahme, im Rückblick sichtbar mit „nach 3 Sätzen Dips“). Übernahme kürzerer Pausen braucht einen gelungenen Test je regelmäßiger Stufe. Fehler behoben: Testläufe zählen nur bei gleicher Last, gleichen Zielen, gleichem Satzschema, regulär, ohne Deload (vorher zählten alte leichtere Tests mit). Konstante Reihenfolge = eine Stufe = Verhalten wie vorher. Karte: im Smart-Modus „Aktuell vor jedem Satz“ als Satz-Kacheln wie in der Sätze-Karte (oben Wdh. × Last, unten die Pause davor; Satz 1 „Start“, gelernte ✦ in Primärfarbe, Tippen fragt und setzt auf Startwert zurück), darunter Chips als „Startwert“; „Herzfrequenz berücksichtigen“ direkt unter dem Umschalter (im Fest-Modus unten) mit Info-Dialog; Kopf zeigt Spanne. Erklärungen nur noch als ⓘ-Dialog (`infoButton`): neben „Pause“ im Smart-Modus, neben „Gewicht und Steigerung“ im Automatik-Modus, beim Puls-Schalter; die aufklappbaren „So funktioniert …“-Kacheln sind weg. Demo: jedes dritte B-Training der letzten 2 Monate mit Kreuzheben vor den Kniebeugen. Später: getrennte Pausen je Stufe, satzweise Neubewertung, „Pulsverlauf als zusätzliches Signal für die Satzbereitschaft“.
   6. Vollautomatisch, ohne Test (27.11.2026, ersetzt Test und Übernahme aus 3): Öffnet sich der Rückblick des letzten Trainings eines Workouts, stellt Smart die vorgeschlagene Pause sofort in `setRests` ein (`autoRestStep`; ein alter Test, der schon 2× gelang, wird übernommen; alte geplante Tests werden verworfen). Höchstens eine Änderung pro Training (`restDeclined` = Trainingsdatum). Eine Änderung, die schlechter läuft, korrigieren dieselben Regeln mit den folgenden Trainings. Karte: Begründung + „Ab jetzt 4:00.“ mit „Rückgängig“ (`undoRestStep`). Hinweis „fehlen noch unterschiedliche Pausen“ entfällt. Hilfetexte ohne „Test“. Offen: Bearbeiten/Löschen des Trainings nimmt die Änderung nicht zurück.
4. Lernende Pausen mit Puls, zuerst nur im Hintergrund prüfen.
5. Satzwerte und Zusammenfassung nach dem Training.
6. Cardio-Zonen.

Zurückgestellt: Tagesform-Check (Deload aus kurzer Messung vor dem Training)
und Aufwärmen nach Pulszone. Ein nachvollziehbarer Hinweis zur nächsten Pause
bringt mehr als eine allgemeine Aussage zur Tagesform.
