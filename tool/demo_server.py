"""Web preview with a demo user, for trying the app and its statistics without own data.

Serves build/web like the plain preview, but injects a script into index.html that fills the
browser storage with 1.5 years of StrongLifts 5x5 (A/B, Mon/Wed/Fri) up to a training this morning:
accessories added later and one just weeks ago, holidays, sick weeks, bad days with missed reps,
plateaus and deloads, rows lagging behind the bench press. The data lives only here,
never in the app or a release build. Storage is per port, so other previews keep their data.

    python tool/demo_server.py [port]      then open http://localhost:8091 (?reset reseeds)
"""
import datetime as dt
import http.server
import json
import random
import sys
from pathlib import Path

WEB = Path(__file__).resolve().parent.parent / 'build' / 'web'


def demo_data():
    random.seed(7)
    D = dt.datetime
    # A year and a half up to this morning, so the demo always looks current and has a training today.
    end = D.combine(dt.date.today(), dt.time(18))
    start = end - dt.timedelta(days=548)
    def days(a, b):
        return (start + dt.timedelta(days=a), start + dt.timedelta(days=b))
    breaks = [days(63, 76), days(105, 111), days(200, 210), days(330, 340), days(420, 434), days(470, 474)]  # holidays, sick, Christmas
    new_lift = end - dt.timedelta(days=25)  # Romanian deadlifts, recently added

    # name: (start kg, capacity at start, newbie growth per week (diminishing), step, sets, reps); after the
    # newbie phase strength keeps growing slowly. Rows lag behind the bench press, for the balance check.
    lifts = {
        'Kniebeuge': [40, 60, 4.6, 2.5, 5, 5],
        'Bankdrücken': [40, 52, 1.4, 2.5, 5, 5],
        'Langhantelrudern': [35, 38, 0.6, 2.5, 5, 5],
        'Schulterdrücken': [25, 33, 0.8, 2.5, 5, 5],
        'Kreuzheben': [50, 80, 3.8, 5.0, 1, 5],
        'Bizepscurls': [20, 24, 0.5, 2.5, 3, 10],
        'Rumänisches Kreuzheben': [60, 72, 0.8, 2.5, 3, 8],
    }
    weight = {k: v[0] for k, v in lifts.items()}
    fails = {k: 0 for k in lifts}
    last_done = {}
    A = ['Kniebeuge', 'Bankdrücken', 'Langhantelrudern']
    B = ['Kniebeuge', 'Schulterdrücken', 'Kreuzheben']
    week_accessories = 10  # from week 10: curls on A, pull-ups on B
    week_cardio = 14

    sessions, bw = [], 84.0
    day, n = start, 0
    while day <= end:
        wk = (day - start).days // 7
        skip = any(a <= day <= b for a, b in breaks) or random.random() < .12
        if (day.weekday() in (0, 2, 4) and not skip) or day == end:
            is_a = n % 2 == 0
            names = list(A if is_a else B)
            if wk >= week_accessories:
                names.append('Bizepscurls' if is_a else 'Klimmzüge')
            if is_a and day >= new_lift:
                names.append('Rumänisches Kreuzheben')
            if not is_a and wk >= week_cardio and random.random() < (.6 if wk < 52 else .8):
                names.append('Laufen')
            bad = random.random() < .1
            tags = []
            if bad:
                tags.append(random.choice(['Schlecht geschlafen', 'Alkohol', 'Stress']))
            good = not bad and random.random() < .08
            if good:
                tags.append('Voller Energie')
            exercises = []
            for name in names:
                if name == 'Laufen':
                    mins = random.choice([18, 20, 22, 25])
                    exercises.append({'name': name, 'weight': 0.0, 'weights': [0.0], 'targetReps': 20, 'reps': [mins],
                                      'type': 'cardio', 'km': round(mins / 5.8, 1)})
                    continue
                if name == 'Klimmzüge':
                    top = min(8, 3 + (wk - week_accessories) // 2)
                    reps = [max(1, top - i - (1 if bad else 0) + random.choice([0, 0, 1])) for i in range(3)]
                    reps = [min(8, r) for r in reps]
                    exercises.append({'name': name, 'weight': 0.0, 'weights': [0.0] * 3, 'targetReps': 8, 'reps': reps})
                    continue
                w0, cap0, growth, step, sets, target = lifts[name]
                # Back after >10 days off: 10 % lighter.
                if name in last_done and (day - last_done[name]).days > 10:
                    weight[name] = max(w0, round(weight[name] * .9 / 2.5) * 2.5)
                capacity = cap0 + growth * 6 * (1 - 0.86 ** max(0, wk)) + growth * .14 * wk
                capacity *= .91 if bad else 1.04 if good else 1
                capacity *= random.uniform(.97, 1.03)
                w = weight[name]
                reps = []
                for i in range(sets):
                    over = (w - capacity) / capacity
                    fatigue = i * .012
                    r = target if over + fatigue <= 0 else max(1, round(target * (1 - (over + fatigue) * 3.2)))
                    reps.append(min(target, r))
                exercises.append({'name': name, 'weight': w, 'weights': [w] * sets, 'targetReps': target, 'reps': reps})
                last_done[name] = day
                if all(r >= target for r in reps):
                    weight[name] = w + step
                    fails[name] = 0
                else:
                    fails[name] += 1
                    if fails[name] >= 3:
                        weight[name] = round(w * .9 / 2.5) * 2.5
                        fails[name] = 0
            bw += random.uniform(-.3, .3) + (80.5 - bw) * .02
            # Today's training was in the morning, the others in the evening.
            date = day.replace(hour=6 if day == end else 18, minute=random.choice([0, 10, 25, 40]))
            dur = 42 + 9 * len(names) + random.randint(-6, 8)
            s = {'id': f'demo{n}', 'workoutId': 'wA' if is_a else 'wB',
                 'workoutName': 'StrongLifts A' if is_a else 'StrongLifts B',
                 'date': date.isoformat(), 'finishedAt': (date + dt.timedelta(minutes=dur)).isoformat(),
                 'exercises': exercises}
            if random.random() < .45:
                s['bodyWeight'] = round(bw, 1)
            if random.random() < .6:
                s['mood'] = 1 if bad else random.choice([2, 3, 3])
            if tags:
                s['tags'] = tags
            sessions.append(s)
            n += 1
        day += dt.timedelta(days=1)


    def plan(name, sets, reps, w, step=2.5, cardio=False):
        e = {'name': name, 'weight': w, 'sets': sets, 'reps': reps, 'increment': step, 'up': True, 'decrement': 10.0,
             'down': True, 'failsToDeload': 3, 'fails': fails.get(name, 0), 'restSeconds': 180 if sets == 5 else 90}
        if cardio:
            e.update({'type': 'cardio', 'up': False})
        return e


    workouts = [
        {'id': 'wA', 'name': 'StrongLifts A', 'exercises': [
            plan('Kniebeuge', 5, 5, weight['Kniebeuge']), plan('Bankdrücken', 5, 5, weight['Bankdrücken']),
            plan('Langhantelrudern', 5, 5, weight['Langhantelrudern']), plan('Bizepscurls', 3, 10, weight['Bizepscurls']),
            plan('Rumänisches Kreuzheben', 3, 8, weight['Rumänisches Kreuzheben'])]},
        {'id': 'wB', 'name': 'StrongLifts B', 'exercises': [
            plan('Kniebeuge', 5, 5, weight['Kniebeuge']), plan('Schulterdrücken', 5, 5, weight['Schulterdrücken']),
            plan('Kreuzheben', 1, 5, weight['Kreuzheben'], 5.0), plan('Klimmzüge', 3, 8, 0.0, 0.0),
            plan('Laufen', 1, 20, 0.0, 0.0, cardio=True)]},
    ]
    sessions.reverse()  # newest first
    return {'app': 'ferrolog', 'version': 1, 'units': 'kg', 'workouts': workouts, 'sessions': sessions}


def seed_script():
    # shared_preferences on the web keeps each value JSON-encoded under "flutter.<key>".
    value = json.dumps(json.dumps(demo_data(), ensure_ascii=False))
    return (
        '<script>(() => {\n'
        "  const reset = new URLSearchParams(location.search).has('reset');\n"
        "  if (!reset && localStorage.getItem('flutter.ferrolog')) return;\n"
        '  localStorage.clear();\n'
        f"  localStorage.setItem('flutter.ferrolog', {json.dumps(value)});\n"
        "  localStorage.setItem('flutter.unit', '\"kg\"');\n"
        "  if (reset) history.replaceState(null, '', location.pathname);\n"
        '})();</script>\n'
    )


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB), **kwargs)

    def do_GET(self):
        if self.path.split('?')[0] not in ('/', '/index.html'):
            return super().do_GET()
        html = (WEB / 'index.html').read_text().replace('<body>', '<body>\n' + seed_script(), 1).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(html)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(html)


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8091
    http.server.ThreadingHTTPServer(('', port), Handler).serve_forever()
