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
   - Webhook: **Active** abhaken
   - Permissions → Repository → **Contents: Read and write**
   - Installierbar: **Any account**
2. Unter *Optional features* **User-to-server token expiration** abschalten
   (sonst läuft die Anmeldung nach 8 h ab).
3. **Client ID** in `lib/sync.dart` bei `githubClientId` eintragen (öffentlich, darf ins Repo).

### Nutzer: Sync einschalten

1. Privates Repo für die Daten anlegen, z. B. `ferrolog-data`, **mit README**
   (die API braucht einen vorhandenen `main`-Branch).
2. Die GitHub App installieren (`github.com/apps/<app-name>`) →
   *Only select repositories* → `ferrolog-data`.
3. In Ferrolog: Wolken-Symbol → *Mit GitHub anmelden* → Code eingeben → Repo wählen.

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
                    "increment": 2.5, "restSeconds": 180 }]
  }],
  "sessions": [{                       // absolvierte Trainings, neueste zuerst
    "id": "…", "workoutId": "…", "workoutName": "Push/Pull A",
    "date": "2026-10-30T18:12:00.000",
    "exercises": [{ "name": "Bankdrücken", "weight": 77.5, "targetReps": 5,
                    "reps": [5, 5, 3] }]  // null = Satz nicht gemacht
  }]
}
```

Progressive Overload: Sind alle Sätze einer Übung geschafft, steigt `weight` im Plan
um `increment`.
