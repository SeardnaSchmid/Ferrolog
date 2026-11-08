# Statistik: Reihenfolge, Kennzahlen, Einklappen

Stand der Statistik-Seite ([lib/stats.dart](../lib/stats.dart)). Wird bei jedem Schritt fortgeschrieben.

## Festlegungen (2026-11-08)

| # | Frage | Entscheidung |
|---|---|---|
| S1 | Reihenfolge | Kennzahlen, Kraftentwicklung, Sätze je Muskel, Balance, Übungen, Cardio. |
| S2 | Trainings pro Woche | Keine eigene Karte mehr: Kachel „Pro Woche“ zeigt „Ziel 3 · 10 von 13 Wochen“, der Verlauf geht beim Antippen auf. |
| S3 | Kennzahlen | Jede Kachel öffnet beim Antippen ihren Verlauf darunter (eine zur Zeit): Trainings pro Woche mit Ziellinie, Ø Dauer mit Schnittlinie, Volumen, neue Höchstgewichte. Bis 90 Tage je Woche, darüber je Monat. |
| S4 | Muskeln | Titel „Sätze je Muskel“, rechts „pro Woche“; über den Balken erklärt: Band 10–20 = üblicher Bereich für Muskelaufbau, orange = unter 10. |
| S5 | Einklappen | Kraftentwicklung, Sätze je Muskel, Balance: einklappbar, standardmäßig offen. Übungen, Cardio: standardmäßig zu. Zugeklappt eine Zeile Zusammenfassung. Gemerkt pro Karte (`stats.open.<id>`). Eine Karte, auf die ein Befund zeigt, ist immer offen. |
| S6 | Sprung „Wochenziel“ | Öffnet die Kachel „Pro Woche“ mit Verlauf, Kachel 4 s orange umrandet. |

## Zusammenfassungen eingeklappt

- Kraftentwicklung: die drei größten Zuwächse („Kreuzheben +11 % · …“)
- Sätze je Muskel: nicht trainierte Muskeln, Anzahl unter 10 Sätzen
- Balance: „N Hinweise · M von 6 ausgewogen“
- Übungen: „8 Übungen · 2 hängen fest“
- Cardio: „Ø 40 Min pro Woche“

## Stand

| Schritt | Inhalt | Stand |
|---|---|---|
| 1 | Reihenfolge (erste Runde) | ✅ `ee62411` |
| 2 | Kennzahlen mit Verlauf, Einklappen, neue Reihenfolge, Muskel-Titel | ✅ |
