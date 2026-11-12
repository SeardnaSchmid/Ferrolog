# Ferrolog

Trainings-Logbuch für Kraftsport (Flutter). Workouts planen, Trainings live loggen,
Verlauf und Statistik ansehen, Daten für KI-Analysen nach GitHub synchronisieren.

```bash
flutter run          # Handy per USB
flutter test
```

## GitHub-Sync

Die App meldet sich per Device Flow als GitHub App an. Der Token erreicht damit
nur die Repos, auf denen der Nutzer die App installiert hat.

### Entwickler: GitHub App registrieren (einmalig für alle Nutzer)

1. GitHub → Settings → Developer settings → GitHub Apps → **New GitHub App**
   - Name: global eindeutig, z. B. `Ferrolog Sync`; Homepage-URL: Projekt-Repo
   - **Enable Device Flow** anhaken, Callback-URL leer lassen
   - **Expire user authorization tokens** abhaken (sonst läuft die Anmeldung nach 8 h ab)
   - Webhook: **Active** abhaken
   - Permissions → Repository → **Single file: Read and write**, Pfad `ferrolog.json`
     (Contents bleibt *No access*: die App erreicht nur diese eine Datei)
   - Installierbar: **Any account**
2. **Client ID** in `lib/sync.dart` bei `githubClientId` eintragen (öffentlich, darf ins Repo).

### Nutzer: Sync einschalten

1. Privates Repo für die Daten anlegen, z. B. `ferrolog-data`, **mit README**
   (die API braucht einen vorhandenen `main`-Branch).
2. Die GitHub App installieren (`github.com/apps/<app-name>`) →
   *Only select repositories* → `ferrolog-data`.
3. In Ferrolog: Wolken-Symbol → *Mit GitHub anmelden* → Code eingeben → Repo wählen.

Liegt im Repo schon eine `ferrolog.json`, die nicht von diesem Gerät stammt (Neuinstallation,
zweites Handy, Änderung von Hand oder durch eine KI), schreibt die App nicht darüber, sondern
fragt: *Von GitHub wiederherstellen* oder *GitHub überschreiben*. Wiederherstellen geht auch
jederzeit unter *Daten*.

## Daten für die KI

Die App schreibt nach jedem Training `ferrolog.json` in ein GitHub-Repo
(Einstellungen: Wolken-Symbol oben rechts) oder exportiert sie über den Teilen-Knopf.

```jsonc
{
  "app": "ferrolog", "version": 1, "units": "kg",
  "exportedAt": "2026-11-02T21:40:00.000",
  "workouts": [{                       // Pläne mit dem Gewicht fürs NÄCHSTE Training
    "id": "…", "name": "Push/Pull A",
    "exercises": [{ "name": "Kniebeuge", "weight": 110, "sets": 3, "reps": 5,
                    "increment": 2.5, "restSeconds": 180, "auto": true }]  // auto = Auto-Modus statt fester Schritte
  }],
  "sessions": [{                       // absolvierte Trainings, neueste zuerst
    "id": "…", "workoutId": "…", "workoutName": "Push/Pull A",
    "date": "2026-10-30T18:12:00.000",
    "exercises": [{ "name": "Bankdrücken", "weight": 77.5, "targetReps": 5,
                    "reps": [5, 5, 3], "rir": 0,    // null = Satz nicht gemacht; rir = Wdh. übrig nach dem letzten Satz (falls abgefragt)
                    "backoff": 10, "progression": "miss" },  // Auto-Modus: nach Pause 10 % leichter gestartet, Ergebnis
                  { "name": "Kabelrudern", "weight": 45, "targetReps": 10,
                    "reps": [10, 10, 9], "replaces": "Rudern" }]  // im Training getauscht; "added": true = dazugenommen
  }]
}
```

Progressive Overload: Sind alle Sätze einer Übung geschafft, steigt `weight` im Plan
um `increment`. Im Auto-Modus steigt es um einen Anteil des Gewichts, der sich selbst anpasst und
nach der Reserve richtet; zu kleine Schritte überbrückt die App mit Wiederholungen, ein schlechter Tag
zählt nicht, nach einer Pause geht es leichter los (siehe `docs/auto-modus.md`).
