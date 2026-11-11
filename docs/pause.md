# Pause, die das Verlassen der Seite übersteht

Stand der Umsetzung (WP2 der Improvement-Spec). Wird bei jedem Schritt fortgeschrieben.

- Code: [lib/model.dart](../lib/model.dart) (`Session.restStartedAt`, `restSeconds`, `restPausedAt`, `restLeft`; geleert in `finishSession`), [lib/session.dart](../lib/session.dart) (Pausenzustand über die Session-Felder), [lib/main.dart](../lib/main.dart) (`RestLeft` auf der Karte „Training läuft“)
- Tests: [test/session_test.dart](../test/session_test.dart)

## Kundenproblem

Die Pause lebte nur in der Trainingsseite. Zurück zum Startbildschirm und wieder „Fortsetzen“, oder die App wurde beendet: die Pause war weg. Außerhalb der App kommt kein Signal.

## Festlegungen (2026-11-11)

| # | Frage | Entscheidung |
|---|---|---|
| Q1 | Wo liegt die Pause? | In der laufenden Session (`ferrolog.active`), nur solange sie läuft. `finishSession` leert die Felder, sie erscheinen nie im Verlauf oder Export; deshalb keine Änderung an `format`, README oder Demodaten. |
| Q2 | Signal nach dem Wiederöffnen? | Nein, wenn die Pause schon abgelaufen ist (`alerted` startet dann wahr). |
| Q3 | Startbildschirm | Die Karte „Training läuft“ zeigt „· Pause 2:49“ bzw. „· Pause angehalten“, nichts nach Ablauf. |
| Q4 | Signal außerhalb der App (Teil B: exakter Alarm, `RestAlarmReceiver`) | Nicht gebaut: WP8d (Vordergrunddienst mit Benachrichtigung) ersetzt ihn laut Spec. |

## Phasen

1. **Erledigt**: Teil A, Pause gespeichert, Anzeige auf dem Startbildschirm.
2. Offen: Signal im Hintergrund, kommt mit WP8d (siehe [android.md](android.md)).
