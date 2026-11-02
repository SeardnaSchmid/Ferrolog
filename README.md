# Ferrolog

Trainings-Logbuch für Kraftsport (Flutter). Workouts planen, Trainings live loggen,
Verlauf und Statistik ansehen, Daten für KI-Analysen nach GitHub synchronisieren.

```bash
flutter run          # Handy per USB
flutter test
```

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
