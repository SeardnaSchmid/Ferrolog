# Arbeitsanweisung für adaptive Pausen und Progression in FerroLog

**Ziel:** Finde für jede Pause zwischen zwei Arbeitssätzen eine Dauer, mit der die Person das Ziel der gesamten Übung zuverlässig erreicht. Bei 5×5 kommen alle vier Pausen infrage. Frühe und späte Sätze dürfen unterschiedliche Pausen haben. Der Plan bestimmt Last und Wiederholungsziel.

**Umsetzungsstand 27.11.2026:** Abschnitte 1–4 umgesetzt für normale Pausen (Modus Intelligent/Fest pro Übung, alle Satzpositionen, länger/kürzer/Kürzer-Versuch, Bewertung über die ganze Übung, Übernahme nach 2 Erfolgen), Details in [puls.md](puls.md) Reihenfolge 3.4. Offen: eigenes Lernen der Fehlversuchspause, Abschnitt 5 (Puls-Lernen).

## 1. Pausenmodus pro Übung wählen

| Einstellung | Verhalten |
|---|---|
| **Feste Pause** | Nach einem gelungenen Satz gilt die eingetragene normale Dauer, nach einem verfehlten Satz die eingetragene Fehlversuchspause. Ein verbundener Sensor allein ändert die Einstellung nicht. |
| **Intelligente Pause** | Beide eingetragenen Zeiten dienen als Startwerte für ihre jeweilige Pausenart. Die App lernt aus vergleichbaren Trainings und kann für jede Satzposition eine kürzere oder längere Dauer vorschlagen. Die Wahl dieses Modus schließt beide Richtungen ein. |
| **Herzfrequenz berücksichtigen** | Option innerhalb der intelligenten Pause. Bei ausreichend persönlicher Erfahrung und verlässlichem Signal passt der Timer die gelernte Zeit an den heutigen Verlauf an. Ohne Uhr funktioniert dieselbe intelligente Pause anhand der Zeit. |

Halte Pausenmodus und Gewichtsprogression getrennt einstellbar. Übernimm bestehende feste Zeitvorgaben. Wer bereits eine pulsabhängige Verlängerung nutzt, behält diese Einstellung, bis die Person bewusst zur intelligenten Pause wechselt.

**Reihenfolge pro Übung:** Werte nach dem Training zuerst die Progression aus. Stehen mehr Gewicht, ein höheres Wiederholungsziel oder ein Deload an, verwende im ersten Training mit dieser Vorgabe die bewährten Pausenzeiten. Stelle persönliche Pulsanpassungen und neue Pausenversuche für diese Vergleichseinheit zurück. Bleibt der Plan stabil, kann die App eine einzelne Satzpause zum Test anbieten. Der Nutzer kann jederzeit selbst starten. Für die Auswertung zählt die tatsächlich eingehaltene Pause.

## 2. Eine Pause dem richtigen Satz zuordnen

Speichere oder rekonstruiere pro Beobachtung die Übung und Variante, Satzposition, damalige Soll-Wiederholungen, tatsächliche Wiederholungen und Last, Pausenvorgabe und Ergebnis. Halte fest, ob die normale Pause, die Fehlversuchspause oder ein bestätigter Versuch galt. Das Ergebnis gehört zum Satz **nach** der Pause. Für Satz eins gibt es innerhalb der Übung keine solche Beobachtung.

1. Verwende einen tatsächlich erfassten Satzbeginn, falls vorhanden. Ansonsten schätze die Pause aus dem Abstand der beiden Loggzeitpunkte abzüglich der geschätzten Dauer des zweiten Satzes. Nutze dafür die bereits vorhandenen übungsabhängigen Tempoannahmen. Rechne mit den ausgeführten Wiederholungen. Bei Haltesätzen steht die ausgeführte Dauer zur Verfügung.
2. Behandle den Tipp als **Loggzeitpunkt**. Zeige geschätzte Zeiten gerundet an. Ein abgelaufener Timer belegt lediglich, dass das Signal ausgelöst wurde. Er belegt keinen Satzbeginn. Verlange für den Lernmodus keinen zusätzlichen Tipp.
3. Verwerfe eine Zeitbeobachtung bei fehlenden oder widersprüchlichen Zeitstempeln, negativem Ergebnis, dazwischen geloggter anderer Übung, dokumentierter Unterbrechung oder auffällig langer Lücke. Überspringe die Pause auch, wenn ein Satz zwischen den beiden Satzpositionen fehlt. Die Wiederholungen eines gültig geloggten Satzes bleiben für die normale Progression auswertbar.
4. Vergleiche zunächst denselben Satz derselben Übungsvariante bei gleicher Last, gleichem Satzschema, ähnlicher Vorbelastung und gleicher Pausenart. Ein fünfter Satz nach vier vollständigen Arbeitssätzen ist anders einzuordnen als ein fünfter Satz nach zwei ausgelassenen Sätzen. Für die erste Version ist eine kleine, nachvollziehbare Vergleichsgruppe vorzuziehen.
5. Alte Trainings ohne damaliges Ziel oder Zeitstempel dürfen keine erfundenen Vergleichswerte erhalten. Stelle fehlende Reserve, fehlenden Puls und eine tatsächlich gemeldete Reserve von null getrennt dar.

## 3. Die Progression satzbezogen bewerten

Behalte den übungsbezogenen Gewichtsschritt und die vorhandenen Regeln für feste Wiederholungszahlen, Bereiche und Wiederholungsbrücken bei. Ändere gezielt den Umgang mit der Reserve und den Zusammenhang mit der Pause.

| Beobachtung | Entscheidung für den nächsten Plan |
|---|---|
| Alle Arbeitssätze erfüllen ihr Ziel bei üblicher Pause. | Bei einer normalen gewichtsbelasteten Übung den kleinsten tatsächlich verfügbaren Gewichtsschritt prüfen. Bei einem Wiederholungsbereich erst steigern, wenn alle dafür vorgesehenen Sätze die Obergrenze erreichen. |
| Der nächste Gewichtsschritt ist zu groß. | Bei fester Wiederholungszahl und ausreichender gemeldeter Reserve die bestehende Brücke nutzen. Jeweils eine Wiederholung ergänzen, höchstens drei über dem Grundziel. Nach dem Gewichtssprung zum Grundziel zurückkehren. Bei einem eingestellten Bereich dessen Obergrenze respektieren. |
| Eine Wiederholung fehlt schon im ersten Arbeitssatz. | Das Ergebnis nach der bestehenden Fehlversuchsregel behandeln. Aus diesem Satz lässt sich keine zu kurze Pause innerhalb der Übung ableiten. |
| Frühe Sätze gelingen, derselbe späte Satz scheitert wiederholt. | Gewicht zunächst gemäß bestehender Halteregel behandeln. Vor einem Pausenvorschlag prüfen, ob die Person unter vergleichbaren Bedingungen nach längeren Pausen bereits bessere Ergebnisse hatte. |
| Ein Satz wurde absichtlich leichter ausgeführt, ausgelassen oder ersetzt. | Den vorhandenen Umgang mit Backoff, Auslassen und Ersatz beibehalten. Solche Einheiten aus regulären Pausenvergleichen heraushalten. |
| Schmerzen, markierter schlechter Tag, Wiedereinstieg oder fälliger Deload. | Die vorhandene Sonderregel anwenden. Bei einem fälligen Deload keinen konkurrierenden Pausenversuch vorschlagen. Diese Einheiten bilden keine neue Referenz für die normale Pause. |

**Reserve konkret anwenden.** Ordne diese Angabe nur dem Satz zu, zu dem die Frage gestellt wurde. Bei gleichförmigem 5×5 prüft Auto, ob alle fünf Sätze gelungen sind, und nutzt die Reserve des fünften Satzes als zusätzliche Information für den nächsten Gewichtsschritt. Bei unterschiedlichen Satzgewichten oder Zielen muss die tragende Leistung zum geplanten Schritt passen. Beispiel: Auf einen schweren Dreiersatz folgen zwei leichte Achtersätze. Viel Reserve im letzten Achtersatz rechtfertigt für sich allein keine Erhöhung des schweren Dreiersatzes. Fehlt aussagekräftige Verlaufsevidenz für diesen Satz, halte seinen Planwert. Wenn der Plan nur eine gemeinsame Erhöhung erlaubt, halte den gemeinsamen Schritt.

Für gewichtsbasierte Auto-Entscheidungen mit fehlender RIR-Angabe gilt weiter die vorhandene Halteregel. Für Zeitübungen, Unterstützung und Übungen ohne Zusatzgewicht gelten ihre eigenen Progressionsregeln. Aus einem Zeitformat wie Farmer’s Walk allein lässt sich kein Wunsch nach kurzen Pausen ableiten.

## 4. Die Dauer ohne Sensor lernen

Bewerte jede Satzposition einzeln. Verwende je Position höchstens eine Beobachtung pro Trainingstag. Gruppiere geschätzte Pausen in grobe Zeitbereiche. Wenn die Unsicherheit des geschätzten Satzbeginns die Entscheidung kippen würde, sammle weitere Beobachtungen. Führe getrennte Verläufe für Pausen nach gelungenen und nach verfehlten Sätzen. Für die Fehlversuchspause gilt der eingetragene Startwert, bis genügend vergleichbare Daten gerade für diesen Fall vorliegen.

1. **Kürzere Pausen aus dem Verlauf erkennen.** Beispiel: Bei 5×5 Bankdrücken sind fünf Minuten eingetragen. Die Person startet vor Satz 2 gelegentlich schon nach rund drei Minuten. Gelingt anschließend in mehreren vergleichbaren Einheiten das gesamte 5×5 bei ähnlicher letzter Reserve, biete drei Minuten vor Satz 2 als Einmalversuch an.
2. **Bei gleichförmigen Daten einen kontrollierten Versuch ermöglichen.** Wer immer auf das Fünf-Minuten-Signal wartet, liefert keine Vergleichsdaten für drei Minuten. Nach wiederholt stabiler Leistung bei gleicher Last kann FerroLog eine kleine Verkürzung anbieten, etwa von 5:00 auf 4:30 vor Satz 2. Kennzeichne sie als Versuch. Die 30 Sekunden sind eine beispielhafte Testgröße. Eine einzelne gut gelungene Einheit reicht dafür nicht aus.
3. **Bei Leistungseinbruch längere Pausen prüfen.** Fehlen nach einer kurzen Pause wiederholt Wiederholungen, vergleiche Trainings mit längerer Pause bei gleicher Last. Als Pilotschwelle für diesen Vergleich gelten je Zeitbereich drei verschiedene Trainingstage, mindestens zwei Zielverfehlungen im kürzeren Bereich und eine höhere Erfolgsquote im längeren. Kalibriere solche Schwellen anhand realer Verläufe. Ein Fehlversuch allein begründet keine dauerhafte Änderung.
4. **Einen Versuch auswerten.** Ändere eine Pause und halte die übrigen Pausenziele, Last und Wiederholungsziele während des Versuchs konstant. Prüfe den Folgesatz und alle späteren Sätze. Bei 5×5 zählen die vollständigen 25 Wiederholungen und, sofern erfasst, die Reserve im letzten Satz. Bei einem Bereich von 8–12 vergleiche auch die tatsächlich erreichten Wiederholungen: Ein wiederholter Rückgang von 12/11/10 auf 12/9/8 ist ein Leistungsverlust trotz erreichtem Mindestziel. Eine fehlende Reserve bleibt unbekannt.
5. **Übernahme bewusst machen.** Zeige vorab „Bankdrücken · Vor Satz 2 einmal 4:30 testen?“ und danach die eingesparte oder zusätzliche Zeit sowie die Leistung über die ganze Übung. Ein Einmalversuch endet mit dieser Einheit. Bei wiederholt erfolgreichem Test biete „Für diese Pause übernehmen“ an. Bricht die Leistung nach einer Verkürzung wiederholt ein, verwende die zuletzt bewährte Dauer. Neue Vorschläge nach einer Ablehnung brauchen neue Beobachtungen.
6. Ein Pausenversuch ändert den Fehlversuchszähler nicht von sich aus. Wende auf das Training die regulären Progressionsregeln an. Bei geändertem Plan verwerfe ausstehende Versuche und kennzeichne bereits begonnene als nicht vergleichbar.

## 5. Mit Herzfrequenz den heutigen Startzeitpunkt anpassen

Ausgangspunkt ist die für diese Satzposition und Pausenart gelernte Zeit. Ermittle aus gelungenen vergleichbaren Trainings, in welchem Pulsbereich die Person vor dem Satz gewöhnlich startet und welche Pausendauern sich über die ganze Übung bewährt haben. Bis ausreichend persönliche Daten vorliegen, gilt die Zeitregel. Zeige einen frühen Pulsabfall bei Bedarf als Begründung für einen künftigen Verkürzungsversuch.

- **Heute früher bereit:** Wenn der geglättete Puls den persönlichen Bereich früher erreicht und eine so kurze Pause bei dieser Last und Satzposition bereits wiederholt funktioniert hat, darf der Timer früher „LOS“ anzeigen. Das früheste automatische Signal liegt bei der kürzesten bewährten Dauer. Sind bisher nur fünf Minuten erprobt, löst ein Pulsabfall nach einer Minute lediglich einen möglichen Test nach Abschnitt 4 aus.
- **Heute langsamer erholt:** Liegt der Puls zur gelernten Zeit noch deutlich über dem üblichen Startbereich, darf der Timer bis zum Erreichen des Bereichs verlängern. Begrenze das Warten durch die Obergrenze der dynamischen Pause, bezogen auf die aktuell angesetzte Zeit. Zeige den Grund und lasse den manuellen Start zu.
- **Unbrauchbares Signal:** Bei Signallücke, Abbruch, geringem Pulsanstieg oder unplausibler Kurve gilt die zeitbasierte Dauer. Ist sie bereits abgelaufen, signalisiere „LOS“ einmalig. Ein einzelner niedriger Messwert genügt nicht zur Freigabe.
- **Einheitliche Messung:** Verwende beim Lernen und im Live-Timer dieselbe geglättete Messgröße und nur Werte, die vor dem nächsten Satz verfügbar sind. Eine feste Schwelle wie 110 bpm oder „Puls normal plus 30 Sekunden“ ist keine persönliche Schätzung der muskulären Erholung. Aus dem Puls allein folgt keine Laständerung.
- **Nutzen prüfen:** Vergleiche an späteren echten Trainings das Zeitverfahren mit dem Verfahren einschließlich Puls. Bewerte eingesparte oder zusätzliche Sekunden, Zielerfüllung aller Sätze und gegebenenfalls letzte Reserve. Teste die Live-Anpassung getrennt von einem laufenden Einmalversuch, damit dessen Pausendauer nachvollziehbar bleibt.

## 6. Abnahme anhand konkreter Verläufe

| Prüffall | Erwartetes Ergebnis |
|---|---|
| 5×5 bei 70 kg, alle Ziele bei üblicher Pause erreicht, ausreichende letzte Reserve und 2,5 kg verfügbar | Auto prüft 72,5 kg. Es gibt keinen gleichzeitigen Vorschlag für eine kürzere Pause. |
| Bankdrücken, wiederholt verfehlter Satz 5 nach kurzer Pause und häufiger gelungen nach längerer Pause, kein Deload fällig | Im Rückblick erscheint ein freiwilliger Versuch für Satz 5. Nach Annahme gilt die längere Zeit einmal vor Satz 5. Alle anderen Sätze behalten ihre reguläre Pause. |
| Ein einziger Trainingstag mit fünf Sätzen | Die App verwendet die konfigurierten Startwerte. |
| Stabile Leistung über mehrere Einheiten mit stets 5:00 Pause | Ein kleiner Verkürzungsversuch vor einer einzelnen Satzposition ist möglich. Drei Minuten gelten erst nach entsprechenden Erfahrungen als bewährt. |
| Nach verkürzter Pause vor Satz 2 gelingt Satz 2, aber in Satz 5 fehlen wiederholt Wiederholungen | Versuch auslaufen lassen, bewährte Dauer verwenden. |
| Zeitbasis 3:00, vor Satz 2 sind auch 2:30 erprobt, heutiger Puls erreicht den persönlichen Bereich nach 2:10 | Frühestes automatisches Signal bei 2:30, sofern der Pulsverlauf die Freigabe weiterhin stützt. |
| Satz verfehlt, nur für reguläre Pausen liegen ausreichende Daten vor | Der Timer verwendet die konfigurierte Fehlversuchspause. |
| Gewicht gesteigert, im nächsten Training fehlt eine Wiederholung | Den neuen Lastbereich getrennt bewerten. Den Einbruch nicht als Beleg gegen die alte Pausendauer verbuchen. |
| Letzter Satz leicht, erster Satz schwer, RIR nur im letzten Satz erfasst | Die Reserve des leichten Satzes wird dem schweren Satz nicht zugerechnet. |
| Satz vier absichtlich ausgelassen, Übungswechsel dazwischen oder Zeitstempel fehlen | Keine Pausenbeobachtung für den betroffenen Übergang. Kein zusätzlicher Fehlversuch durch das Pausenlernen. |
| Sensor verliert während einer Verlängerung das Signal | Rückfall auf die Zeitregel. Ist die gelernte Zeit vorbei, erscheint „LOS“. Kein doppeltes Endsignal bei Rückkehr aus dem Hintergrund. |
| Nutzer korrigiert oder löscht das jüngste Training, öffnet den Rückblick zweimal oder importiert ältere Daten | Aus gültigen Logs reproduzierbare Ergebnisse. Keine doppelt gezählte Einheit, kein zweiter Verbrauch desselben Versuchs. Manuell bestätigte Planänderungen bleiben als solche nachvollziehbar. |

**Reihenfolge der Umsetzung:** Erst die satzbezogene Progressionsentscheidung mit bestehenden Trainings prüfen. Danach Zeitbeobachtungen auswerten und begründete Einmalversuche anbieten. Eine dauerhafte Anpassung braucht Bestätigung. Zuletzt den zusätzlichen Wert der Pulsdaten prüfen und erst auf dieser Grundlage den lernenden Live-Timer freigeben.

## Fachliche Grundlage und Projektbezug

Längere Satzpausen können die Kraftentwicklung im untersuchten Trainingsprogramm begünstigen. Eine Trainingsstudie mit 21 trainierten Männern verglich eine mit drei Minuten Pause über acht Wochen. Daraus folgt keine individuelle Minutenvorgabe. Eine weitere Trainingsstudie verglich Laststeigerung mit Wiederholungssteigerung und stützt beide Wege als praktikable Progression. Die hier vorgeschlagenen Vergleichsgruppen, Fallzahlen und Freigaberegeln sind Produktentscheidungen für FerroLog. [Schoenfeld et al.](https://pubmed.ncbi.nlm.nih.gov/26605807/) · [Plotkin et al.](https://pubmed.ncbi.nlm.nih.gov/36199287/)

Eine Crossover-Studie zum Bankdrücken verglich eine persönliche Pulsschwelle mit festen 60 Sekunden Pause. Mit Pulssteuerung wurden insgesamt mehr Wiederholungen erreicht, und die Pausen wurden über die Sätze länger. Ob Puls gegenüber einer bereits individuell gelernten Zeit einen Zusatznutzen hat, bleibt für FerroLog zu prüfen. [Buskard et al.](https://www.asep.org/asep/asep/JEPonlineFEBRUARY2017_Andrew_Buskard.pdf)

Die vorhandenen Regeln, Messgrößen und Einstiegspunkte sind im Projekt dokumentiert. [Auto-Modus](auto-modus.md) · [Puls und lernende Pausen](puls.md) · [Pausentimer](pause.md) · [Progressionsmodell](../lib/model.dart) · [Zeitmessung](../lib/timing.dart)
