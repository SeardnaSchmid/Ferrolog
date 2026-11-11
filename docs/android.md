# Android: Training ohne Entsperren

Stand der Umsetzung (WP8 der Improvement-Spec). Wird bei jedem Schritt fortgeschrieben.

- Code: [MainActivity.kt](../android/app/src/main/kotlin/com/seardnaschmid/ferrolog/MainActivity.kt) (Kanal `ferrolog/alert`), [lib/session.dart](../lib/session.dart) (`showWhenLocked`, `keepScreenOn`), Schalter in [lib/settings.dart](../lib/settings.dart)
- Tests: [test/session_test.dart](../test/session_test.dart)

## Festlegungen (2026-11-11)

| # | Frage | Entscheidung |
|---|---|---|
| Q1 | Wie über den Sperrbildschirm? | `setShowWhenLocked` (API 27+, davor `FLAG_SHOW_WHEN_LOCKED`), kein `setTurnScreenOn`: das Display geht nur an, wenn man es selbst weckt. |
| Q2 | Wann aktiv? | Solange `SessionPage` offen ist (an in `initState`, aus in `dispose`, wie `keepScreenOn`). Einstellung `session.showWhenLocked`, Standard an. |

## Phasen

1. **Erledigt**: WP8a Trainingsseite über dem Sperrbildschirm.
2. Offen: WP8b Lautstärketasten loggen Sätze.
3. Offen: WP8c Eigene Vibrationsmuster.
4. Offen: WP8d Laufende Benachrichtigung und Live Update (bringt auch das Pausensignal im Hintergrund, Teil B von WP2, siehe [pause.md](pause.md)).
5. Offen: WP8e Health Connect (Puls, Körpergewicht).
