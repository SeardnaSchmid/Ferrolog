"""Web preview with a demo user, for trying the app and its statistics without own data.

Serves build/web like the plain preview, but injects a script into index.html that fills the
browser storage with 1.5 years of StrongLifts 5x5 (A/B, Mon/Wed/Fri) up to a training this morning:
accessories added later and one just weeks ago, holidays, sick weeks, bad days with missed reps or a
last set done lighter, plateaus and deloads, rows lagging behind the bench press, curls in a rep range,
a farmer's walk held for 30–45 s, accessories skipped for lack of time, pull-ups left out twice in the
last four weeks (the home card's top finding), no body weight for the last 40 days and an own exercise
without muscles. The data lives only here,
never in the app or a release build. Storage is per port, so other previews keep their data.

    python tool/demo_server.py [port]      then open http://localhost:8091 (?reset reseeds)

?reset&lang=en reseeds in English: the app's language set to English and the exercises under their
English names, as a user who set them up in English would have them (tags stay keyed in German, like
in the app).
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
    carry_from = end - dt.timedelta(days=120)  # farmer's walk on B, 30–45 s
    carry_kg, carry_base = 24.0, 30.0

    # name: (start kg, capacity at start, newbie growth per week (diminishing), step, sets, reps); after the
    # newbie phase strength keeps growing slowly. Rows lag behind the bench press, for the balance check.
    lifts = {
        'Kniebeuge': [40, 60, 4.6, 2.5, 5, 5],
        'Bankdrücken': [40, 52, 1.4, 2.5, 5, 5],
        'Langhantelrudern': [35, 38, 0.6, 2.5, 5, 5],
        'Schulterdrücken': [25, 33, 0.8, 2.5, 5, 5],
        'Kreuzheben': [50, 80, 3.8, 5.0, 1, 5],
        'Bizepscurls': [20, 24, 0.5, 2.5, 3, 8],
        'Rumänisches Kreuzheben': [60, 72, 0.8, 2.5, 3, 8],
    }
    tops = {'Bizepscurls': 12}  # rep ranges: the weight goes up once every set reaches the top
    weight = {k: v[0] for k, v in lifts.items()}
    fails = {k: 0 for k in lifts}
    last_done = {}
    A = ['Kniebeuge', 'Bankdrücken', 'Langhantelrudern']
    B = ['Kniebeuge', 'Schulterdrücken', 'Kreuzheben']
    week_accessories = 10  # from week 10: curls on A, pull-ups on B
    week_cardio = 14

    sessions, bw = [], 84.0
    late_b = 0  # B trainings in the last four weeks, oldest first: the 1st and 3rd leave out the pull-ups
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
            if not is_a and day >= carry_from:
                names.append('Farmers Walk')
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
            before = {}  # the plan before this training's progression, see planBefore below
            # Now and then no time left for the last accessory: skipped entirely, no miss.
            rushed = random.random() < .08
            if not is_a and 0 < (end - day).days < 28:
                late_b += 1
            no_pullups = not is_a and 0 < (end - day).days < 28 and late_b in (1, 3)
            # Changed during the training, now and then: curl station taken (swapped), calves added on
            # top. Own generator, so the rest of the data stays the same.
            rng = random.Random(1000 + n)
            swap_curls, add_calves = rng.random() < .06, rng.random() < .07 and not rushed and not no_pullups
            for name in names:
                if name == 'Klimmzüge':
                    before[name] = {'weight': 0.0, 'fails': 0}
                if name == 'Klimmzüge' and no_pullups:
                    exercises.append({'name': name, 'weight': 0.0, 'weights': [0.0] * 3, 'targetReps': 8, 'reps': [None] * 3})
                    continue
                if rushed and name in ('Klimmzüge', 'Farmers Walk', 'Bizepscurls') and name == names[-1 if names[-1] != 'Laufen' else -2]:
                    sets = 2 if name == 'Farmers Walk' else 3
                    e = {'name': name, 'weight': 0.0, 'weights': [0.0] * sets, 'targetReps': 8, 'reps': [None] * sets}
                    if name == 'Farmers Walk':
                        e.update({'weight': carry_kg, 'weights': [carry_kg] * sets, 'targetReps': 30, 'maxReps': 45, 'type': 'timed'})
                    elif name == 'Bizepscurls':
                        e.update({'weight': weight[name], 'weights': [weight[name]] * sets, 'maxReps': 12})
                    exercises.append(e)
                    continue
                if name == 'Farmers Walk':
                    before[name] = {'weight': carry_kg, 'fails': 0}
                    held = [min(45, max(15, round(carry_base - 4 * i - (5 if bad else 0) + random.uniform(-3, 3)))) for i in range(2)]
                    exercises.append({'name': name, 'weight': carry_kg, 'weights': [carry_kg] * 2, 'targetReps': 30,
                                      'maxReps': 45, 'reps': held, 'type': 'timed'})
                    if all(h >= 45 for h in held):
                        carry_kg, carry_base = carry_kg + 2.5, 32.0
                    else:
                        carry_base += 3
                    continue
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
                before[name] = {'weight': w, 'fails': fails[name]}
                top = tops.get(name, target)
                reps, weights = [], [w] * sets
                for i in range(sets):
                    over = (w - capacity) / capacity
                    fatigue = i * .012
                    # In a range more reps are possible below the limit, so it starts from the top.
                    r = top if over + fatigue <= 0 else max(1, round(top * (1 - (over + fatigue) * 3.2)))
                    # Last set about to miss: sometimes dropped back a step and done in full instead.
                    if i == sets - 1 and sets > 1 and r < target and name not in tops and random.random() < .08:
                        weights[i], r = w - step, target
                    reps.append(r)
                e = {'name': name, 'weight': w, 'weights': weights, 'targetReps': target, 'reps': reps}
                if name in tops:
                    e['maxReps'] = top
                exercises.append(e)
                last_done[name] = day
                if any(x < w for x in weights):
                    pass  # a lighter set holds the weight: no increase, no miss
                elif all(r >= top for r in reps):
                    weight[name] = w + step
                    fails[name] = 0
                elif all(r >= target for r in reps):
                    fails[name] = 0  # within the range
                else:
                    fails[name] += 1
                    if fails[name] >= 3:
                        weight[name] = round(w * .9 / 2.5) * 2.5
                        fails[name] = 0
            if add_calves:
                exercises.append({'name': 'Wadenheben', 'weight': 40.0, 'weights': [40.0] * 3, 'targetReps': 12,
                                  'reps': [rng.choice([12, 12, 14, 15]) for _ in range(3)], 'added': True,
                                  'restSeconds': 60, 'increment': 2.5})
            bw += random.uniform(-.3, .3) + (80.5 - bw) * .02
            # Today's training was in the morning, the others in the evening.
            date = day.replace(hour=6 if day == end else 18, minute=random.choice([0, 10, 25, 40]))
            dur = 42 + 9 * len(names) + random.randint(-6, 8)
            finished = date + dt.timedelta(minutes=dur)
            # The last two months with a timestamp per set (older trainings predate that): setup and
            # warm-ups before the first set (more for heavy barbell lifts), the rest running a bit over.
            if (end - day).days <= 60:
                clock = date
                for e in exercises:
                    rnd = rng if e.get('added') else random  # an added exercise leaves the shared generator alone
                    if e.get('type') == 'cardio':
                        clock += dt.timedelta(minutes=e['reps'][0] + rnd.uniform(1, 3))
                        e['doneAt'] = [clock.isoformat()]
                        continue
                    heavy = e['weight'] > 30
                    clock += dt.timedelta(seconds=rnd.uniform(60, 120) + (e['weight'] / 25) * rnd.uniform(50, 80)
                                          if heavy else rnd.uniform(40, 100))
                    rest = 180 if len(e['reps']) == 5 else 90
                    if all(r is None for r in e['reps']):
                        continue  # skipped: nothing logged
                    done = []
                    for i in range(len(e['reps'])):
                        if i:
                            work = e['reps'][i] if e.get('type') == 'timed' else e['targetReps'] * 4
                            clock += dt.timedelta(seconds=rest * rnd.uniform(1.0, 1.45) + work)
                        done.append(clock.isoformat())
                    e['doneAt'] = done
                finished = clock + dt.timedelta(minutes=random.uniform(1, 3))
            # Swapped after the fact, with the curls' set times, so the shared generator runs as without it.
            # (The curls' progression in the plan runs on as if trained; close enough for a demo.)
            if swap_curls and 'Bizepscurls' in names:
                i = next(i for i, e in enumerate(exercises) if e['name'] == 'Bizepscurls')
                if any(r is not None for r in exercises[i]['reps']):
                    exercises[i] = {'name': 'Hammercurls', 'weight': 16.0, 'weights': [16.0] * 3, 'targetReps': 10,
                                    'reps': [rng.choice([9, 10, 10]) for _ in range(3)], 'replaces': 'Bizepscurls',
                                    'restSeconds': 90, 'increment': 2.0,
                                    **({'doneAt': exercises[i]['doneAt']} if 'doneAt' in exercises[i] else {})}
            # Reps in reserve, asked for the last two months (the setting came then): at the limit after missed
            # reps, else one to three left; now and then not answered. Own generator, the rest stays the same.
            if (end - day).days <= 60:
                rr = random.Random(5000 + n)
                for e in exercises:
                    if e.get('type') or e['weight'] < 0 or None in e['reps'] or rr.random() < .15:
                        continue
                    top = e.get('maxReps', e['targetReps'])
                    e['rir'] = 0 if any(r < e['targetReps'] for r in e['reps']) else \
                        rr.choice([0, 1, 1]) if any(r < top for r in e['reps']) else rr.choice([1, 2, 2, 3, 4])
            s = {'id': f'demo{n}', 'workoutId': 'wA' if is_a else 'wB',
                 'workoutName': 'StrongLifts A' if is_a else 'StrongLifts B',
                 'date': date.isoformat(), 'finishedAt': finished.isoformat(),
                 'exercises': exercises, 'planBefore': before}
            # Body weight now and then, but not for the last 40 days: the recap asks for it.
            if random.random() < .45 and (end - day).days > 40:
                s['bodyWeight'] = round(bw, 1)
            if random.random() < .6:
                s['mood'] = 1 if bad else random.choice([2, 3, 3])
            if tags:
                s['tags'] = tags
            sessions.append(s)
            n += 1
        day += dt.timedelta(days=1)


    def plan(name, sets, reps, w, step=2.5, cardio=False, timed=False, top=None):
        e = {'name': name, 'weight': w, 'sets': sets, 'reps': reps, 'increment': step, 'up': True, 'decrement': 10.0,
             'down': True, 'failsToDeload': 3, 'fails': fails.get(name, 0), 'restSeconds': 180 if sets == 5 else 90}
        if cardio:
            e.update({'type': 'cardio', 'up': False})
        if timed:
            e['type'] = 'timed'
        if top:
            e['maxReps'] = top
        return e


    workouts = [
        {'id': 'wA', 'name': 'StrongLifts A', 'exercises': [
            plan('Kniebeuge', 5, 5, weight['Kniebeuge']), plan('Bankdrücken', 5, 5, weight['Bankdrücken']),
            # The accessories run in auto mode (switched on lately: their history came from the fixed steps).
            plan('Langhantelrudern', 5, 5, weight['Langhantelrudern']),
            {**plan('Bizepscurls', 3, 8, weight['Bizepscurls'], top=12), 'auto': True},
            {**plan('Rumänisches Kreuzheben', 3, 8, weight['Rumänisches Kreuzheben']), 'auto': True},
            # An own exercise the app knows no muscles of: the workout card asks for them.
            {**plan('Atemübung', 1, 10, 0.0, 0.0), 'up': False, 'down': False}]},
        {'id': 'wB', 'name': 'StrongLifts B', 'exercises': [
            plan('Kniebeuge', 5, 5, weight['Kniebeuge']), plan('Schulterdrücken', 5, 5, weight['Schulterdrücken']),
            plan('Kreuzheben', 1, 5, weight['Kreuzheben'], 5.0), plan('Klimmzüge', 3, 8, 0.0, 0.0),
            plan('Farmers Walk', 2, 30, carry_kg, timed=True, top=45),
            plan('Laufen', 1, 20, 0.0, 0.0, cardio=True)]},
    ]
    sessions.reverse()  # newest first
    # Only the newest training of a workout keeps the plan before it (editing it recomputes the plan). The
    # squat is shared by A and B here, unlike in the app: it goes to the newer one only.
    seen_workouts, seen_lifts = set(), set()
    for s in sessions:
        before = s.pop('planBefore')
        if s['workoutId'] not in seen_workouts:
            seen_workouts.add(s['workoutId'])
            s['planBefore'] = {k: v for k, v in before.items() if k not in seen_lifts}
        seen_lifts.update(e['name'] for e in s['exercises'])
    return {'app': 'ferrolog', 'version': 1, 'units': 'kg', 'workouts': workouts, 'sessions': sessions}


# The demo's exercises under the names the app's English catalogue gives them (exerciseNamesEn).
ENGLISH = {
    'Kniebeuge': 'Squat', 'Bankdrücken': 'Bench Press', 'Langhantelrudern': 'Barbell Row',
    'Bizepscurls': 'Biceps Curl', 'Hammercurls': 'Hammer Curl', 'Rumänisches Kreuzheben': 'Romanian Deadlift',
    'Schulterdrücken': 'Overhead Press', 'Kreuzheben': 'Deadlift', 'Klimmzüge': 'Pull-ups',
    'Wadenheben': 'Calf Raise', 'Laufen': 'Running', 'Atemübung': 'Breathing Drill',
}


def in_english(data):
    """[data] with every exercise name (plans, trainings, swaps, plans before) in English."""
    def name(n):
        return ENGLISH.get(n, n)
    for w in data['workouts']:
        for e in w['exercises']:
            e['name'] = name(e['name'])
    for s in data['sessions']:
        for e in s['exercises']:
            e['name'] = name(e['name'])
            if 'replaces' in e:
                e['replaces'] = name(e['replaces'])
        if 'planBefore' in s:
            s['planBefore'] = {name(k): v for k, v in s['planBefore'].items()}
    return data


def seed_script(english=False):
    # shared_preferences on the web keeps each value JSON-encoded under "flutter.<key>".
    data = in_english(demo_data()) if english else demo_data()
    value = json.dumps(json.dumps(data, ensure_ascii=False))
    return (
        '<script>(() => {\n'
        "  const reset = new URLSearchParams(location.search).has('reset');\n"
        "  if (!reset && localStorage.getItem('flutter.ferrolog')) return;\n"
        '  localStorage.clear();\n'
        f"  localStorage.setItem('flutter.ferrolog', {json.dumps(value)});\n"
        "  localStorage.setItem('flutter.unit', '\"kg\"');\n"
        # The demo has answered reps in reserve, so it asks for them too.
        "  localStorage.setItem('flutter.session.askRir', 'true');\n"
        + ("  localStorage.setItem('flutter.language', '\"en\"');\n" if english else '') +
        "  if (reset) history.replaceState(null, '', location.pathname);\n"
        '})();</script>\n'
    )


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB), **kwargs)

    def do_GET(self):
        if self.path.split('?')[0] not in ('/', '/index.html'):
            return super().do_GET()
        english = 'lang=en' in self.path
        html = (WEB / 'index.html').read_text().replace('<body>', '<body>\n' + seed_script(english), 1).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(html)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(html)


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8091
    http.server.ThreadingHTTPServer(('', port), Handler).serve_forever()
