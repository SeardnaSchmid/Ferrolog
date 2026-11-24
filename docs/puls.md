# Puls im Training (Ideen)

Ideensammlung, noch nichts umgesetzt. Puls nur rund ums Training: kurz davor, währenddessen, kurz danach. Nichts im Alltag, keine Messung über mehrere Tage.

## Quelle: Amazfit Helio Strap per Bluetooth

- Der Helio Strap kann den Puls live per Bluetooth senden ([Amazfit](https://us.amazfit.com/products/helio-strap)). Ferrolog verbindet sich direkt, ohne die Zepp-App (z. B. mit `flutter_blue_plus`), wie mit einem Brustgurt. Ein Brustgurt (Polar H10 usw.) geht dann genauso.
- Health Connect / Apple Health sind für Echtzeit zu langsam (Zepp synchronisiert verzögert, in Paketen). Siehe auch WP8e in [android.md](android.md).
- Verbunden nur, solange ein Training läuft. Ohne Verbindung läuft alles wie bisher nach Zeit.
- Am Oberarm tragen: am Handgelenk verfälscht das Greifen die optische Messung.
- Nötig: Bluetooth-Rechte (Android), Bluetooth-Hinweistext und Hintergrundmodus (iOS), Gerät koppeln in den Einstellungen. Web nur in Chrome (Web Bluetooth), nicht in Safari auf iOS.

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

## Verworfen

- Ruhepuls über mehrere Tage und Krankheitserkennung im Alltag: nicht rund ums Training.
- Kalorien: beim Krafttraining oft 20–40 % daneben.
- Sätze automatisch erkennen: Der Puls reagiert 10–20 s verzögert.

## Reihenfolge, falls umgesetzt

1. Bluetooth-Anbindung, Live-Puls, dynamische Pausen (zuerst mit simuliertem Puls testbar).
2. Satzwerte speichern, Zusammenfassung nach dem Training.
3. Tagesform-Check und Aufwärmen.
4. Cardio-Zonen.
