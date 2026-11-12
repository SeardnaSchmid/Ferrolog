# Von GitHub wiederherstellen

Stand der Umsetzung (WP1 der Improvement-Spec). Wird bei jedem Schritt fortgeschrieben.

- Code: [lib/sync.dart](../lib/sync.dart) (`SyncConflict`, `lastSha`, `adopt`, `conflict`, `fetchRemote`, Wächter in `_put`), [lib/model.dart](../lib/model.dart) (`dataVersion`, `migrate`, `Store.importJson`, `Store.covers`), [lib/settings.dart](../lib/settings.dart) (`resolve`, `_ResolveDialog`, Eintrag unter „Daten“), [lib/main.dart](../lib/main.dart) (`remoteCovered`)
- Tests: [test/sync_test.dart](../test/sync_test.dart), [test/import_test.dart](../test/import_test.dart), [test/restore_test.dart](../test/restore_test.dart)

## Kundenproblem

Sync schrieb nur. Nach einer Neuinstallation oder auf einem neuen Handy hat das erste Speichern (oder schon die Repo-Auswahl) die Daten auf GitHub mit dem leeren Gerät überschrieben. Der alte Stand lag nur noch in der Git-Historie.

## Festlegungen (2026-11-12)

| # | Frage | Entscheidung |
|---|---|---|
| Q1 | Woran erkennt die App fremde Daten? | Am Blob-sha: `sync.lastSha` ist der sha, den diese Installation zuletzt geschrieben oder wiederhergestellt hat. Ein anderer sha auf GitHub ist ein Konflikt, eine fehlende Datei nicht. Abmelden und ein anderes Repo löschen den sha. |
| Q2 | Installationen von vor dem Wächter (kein `lastSha`) | Schieben weiter ohne Rückfrage, solange GitHub nichts enthält, was hier fehlt (`Store.covers`: jedes Training und jeder Plan von GitHub ist auch hier, und hier gibt es Trainings). Sonst Konflikt. Abweichung von der Spec, damit das Update auf dem eigenen Handy nicht einmal fragt. |
| Q3 | Während eines Konflikts | Sync pausiert (`push` fragt GitHub nicht mehr), bis wiederhergestellt oder überschrieben wird. Nach einem Neustart prüft der nächste Push wieder. Der Status bleibt „Konflikt: …“, darunter „Konflikt lösen“. |
| Q4 | Datei lesen | Zwei Anfragen: Metadaten für den sha, dann `application/vnd.github.raw+json` für den Inhalt (ohne 1-MB-Grenze). |
| Q5 | Prüfung und Migration | `migrate()` in model.dart ist der eine Einstieg für fremdes JSON (WP7b-Gerüst): app „ferrolog“, Version ≤ `dataVersion`, Workouts und Trainings vorhanden. Der lokale Speicher läuft nur bei abweichender Version hindurch. Der Plan-Import kann ihn später mitnutzen. |
| Q6 | Reihenfolge beim Wiederherstellen | `importJson` prüft und liest erst alles, dann `beforeSave` (sync übernimmt den sha), dann ein Speichern. Der Push danach ist kein Konflikt. Eine abgelehnte Datei ändert nichts. |
| Q7 | Nicht lesbare Datei auf GitHub | Der Dialog nennt den Grund, „Wiederherstellen“ ist aus, „GitHub überschreiben“ geht (z. B. kaputte Handbearbeitung). |

## Phasen

1. **Erledigt**: WP1.
2. Später, falls gewünscht: Wiederherstellen aus einer lokalen Datei (braucht ein Dateiauswahl-Paket).
