# FerroLog

## Web previews (`.claude/launch.json`)

Both serve `build/web`, so run `flutter build web` first. Browser storage is per port, so the two never share data.

- **`web`** (port 8090): plain preview with the user's own test data. Don't click through it for testing, it may hold a running training.
- **`web-demo`** (port 8091): a representative demo user for checking statistics and the UI with realistic data. Use this one for testing.

## Demo data

The demo data lives only in [tool/demo_server.py](tool/demo_server.py), never in the app or a release build:

- `demo_data()` generates 1.5 years of StrongLifts 5x5 up to a training this morning, so every period (30 days to all) has data and the insight card has a "today" fact. It includes accessories, an exercise added three weeks ago, cardio, holidays, sick weeks, missed reps, plateaus, deloads, moods, tags and body weight, plus curls in a rep range (8–12), a farmer's walk held for 30–45 s, last sets dropped back a step (they hold the weight) and accessories skipped for lack of time (no miss). For the home card "Dein Training": pull-ups left out entirely twice in the last four weeks (its top finding), no body weight for the last 40 days (the recap asks for it) and an own exercise "Atemübung" without muscles (the workout card asks for them). Rows lag behind the bench press on purpose, so the balance check has something to flag. The last two months have a timestamp per set (`doneAt`), older trainings don't, like real data from before timing was recorded. The newest training of each workout carries `planBefore`, so editing or deleting it recomputes the plan. Strength exercises of the last two months carry reps in reserve (`rir`: 0 after missed reps, else 1–4, some unanswered), and the seed switches asking for it on. Curls and Romanian deadlifts are in auto mode (`auto`), the rest on fixed steps.
- The server injects a script into `index.html` that writes this data into `localStorage` (`flutter.ferrolog`, unit kg) on the first visit.
- Open `http://localhost:8091/?reset` to reseed.
- After editing the script, restart the `web-demo` server: it builds the data when a request comes in, but runs whatever code was loaded at start.
- After a new web build, unregister the service worker and clear its caches in the browser, otherwise the old build shows.
