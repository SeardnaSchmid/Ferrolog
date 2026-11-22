# Benachrichtigungen (Android)

Stand der Umsetzung (WP8d der Improvement-Spec, plus Erinnerungen). Wird bei jedem Schritt fortgeschrieben.

- Code: [lib/notify.dart](../lib/notify.dart) (Inhalte und Zeitpunkte, alles in Dart), [TrainingService.kt](../android/app/src/main/kotlin/com/seardnaschmid/ferrolog/TrainingService.kt) (laufendes Training, Signal „Pause vorbei“), [ReminderReceiver.kt](../android/app/src/main/kotlin/com/seardnaschmid/ferrolog/ReminderReceiver.kt) und [Notify.kt](../android/app/src/main/kotlin/com/seardnaschmid/ferrolog/Notify.kt) (Kanäle, Erinnerungen über `AlarmManager`), Kanal `ferrolog/notify` in [MainActivity.kt](../android/app/src/main/kotlin/com/seardnaschmid/ferrolog/MainActivity.kt), Schalter in [lib/settings.dart](../lib/settings.dart)
- Tests: [test/notify_test.dart](../test/notify_test.dart)

## Festlegungen (2026-11-21)

| # | Frage | Entscheidung |
|---|---|---|
| Q1 | Paket oder selbst? | Selbst über einen Methodenkanal, wie `ferrolog/alert`; kein neues Paket. Texte und Zeiten rechnet Dart, Android zeigt nur an. |
| Q2 | Laufendes Training | Vordergrunddienst (`specialUse`) vom ersten Satz bis Beenden, Verwerfen oder automatischem Ende. Folgt dem Store, nicht der Trainingsseite. Titel „Kniebeuge · Satz 2/3“, Text „100 kg × 5“, Workout als Untertext, die Pause als System-Countdown (`setChronometerCountDown`), angehalten als „Pause angehalten (2:20)“. Stumm (Kanal niedrig). Android 16: als Live Update angefragt (`android.requestPromotedOngoing`). |
| Q3 | Pause vorbei im Hintergrund | Der Dienst postet am Pausenende eine eigene Benachrichtigung mit Ton/Vibration (Kanal hoch, ohne Ton ein eigener stiller Kanal und Vibration von Hand), nur wenn die App nicht im Vordergrund ist; dort signalisiert wie bisher der Dart-Timer. Dart unterdrückt sein eigenes Signal im Hintergrund nur genau am Pausenende, Haltesätze signalisieren weiter selbst. Weg beim Zurückkehren in die App, beim nächsten Satz, nach 5 min. |
| Q4 | Erlaubnis (Android 13+) | Einmal gefragt, beim ersten geloggten Satz; erneut beim Einschalten eines Schalters. Abgelehnt: alles wie vorher, nur in der App. |
| Q5 | Erinnerung Wochenziel | Am letzten Tag, an dem das Ziel mit einem Training pro Tag noch geht (wie die Karte „Noch 2 Trainings diese Woche“), nicht in der Woche des allerersten Trainings. Mit laufender Serie: „Serie von 3 Wochen in Gefahr“. Für diese und die zwei nächsten Wochen geplant, jede Änderung plant neu. |
| Q6 | Erinnerung lange Pause | 7 und 14 Tage nach dem letzten Training, nennt das Workout, das am längsten her ist. |
| Q7 | Uhrzeit | Zwei Stunden vor der üblichen Startzeit (Median der letzten 20 Trainings, sonst 17 Uhr), zwischen 8 und 19 Uhr. Ungenauer Alarm (`setAndAllowWhileIdle`), braucht keine Exakt-Alarm-Erlaubnis; nach Neustart neu geplant (`BOOT_COMPLETED`). |
| Q8 | Rekorde, Wochenrückblick, Datenpflege | Nicht als Push: Rekorde sieht man ohnehin in der App, Datenpflege („Körpergewicht fehlt“) nervt als Push. |

## Phasen

1. **Erledigt**: Laufendes Training mit Pausen-Countdown, Signal im Hintergrund, Erinnerungen Wochenziel und lange Pause, drei Schalter. APK baut; auf dem Gerät noch nicht geprüft.
2. Offen: Aktionen in der Benachrichtigung („Satz geschafft“, „+30 s“), siehe WP8d der Spec.

## Pausensignale und andere Medien (2026-11-22)

- Zehn Sekunden vorher drei kurze Töne, am Ende ein längeres Signal. Ton, Vibration und Vorwarnung lassen sich getrennt einstellen. Beim Anhalten werden die geplanten Signale entfernt und beim Fortsetzen neu geplant.
- Android: Der Trainingsdienst spielt die Signale auch außerhalb der Trainingsseite; dafür fordert er kurz `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK` an und gibt den Fokus danach zurück. Wie stark abgesenkt wird und ob eine andere App stattdessen pausiert, bestimmt das System bzw. die andere App. Bei gesperrtem Gerät können Energiesparregeln den Dienst verzögern.
- iOS: Bei geöffneter App aktiviert eine kurze Audio-Session `duckOthers` und gibt sie nach dem Ton wieder frei. Im Hintergrund sind lokale Mitteilungen mit eigenen Tönen geplant; deren Wiedergabe und Vibration steuert iOS, eine aktive Audio-Session und Ducking lassen sich dafür nicht zusichern. Benachrichtigungserlaubnis ist erforderlich. Ein iOS-Build und Gerätetest stehen noch aus.
