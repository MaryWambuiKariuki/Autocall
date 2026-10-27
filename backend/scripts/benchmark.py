"""
Evidence for Chapter 5 (NFR3 performance, Table 12 recommendation, Table 13 route evaluation).
Run from backend/ with the venv active (needs no Firebase):   python scripts/benchmark.py
Prints Markdown tables you can paste into your report. Run it on the same laptop you describe in Table 6.
"""
import os, statistics, sys, time
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv
load_dotenv()
from ml.recommender import Recommender, rule_score
from ml.sentiment import SentimentModel
from services import geo
from utils import haversine_km

def pct(xs, p):
    xs = sorted(xs); return xs[min(len(xs) - 1, int(round(p / 100 * (len(xs) - 1))))]

def timeit(fn, n):
    t = []
    for _ in range(n):
        s = time.perf_counter(); fn(); t.append((time.perf_counter() - s) * 1000)
    return t

rec = Recommender(os.getenv("RECOMMENDER_MODEL", "models/recommendation_model.pkl"), os.getenv("RECOMMENDER_SCALER", "models/recommendation_scaler.pkl"))
sent = SentimentModel(os.getenv("SENTIMENT_MODEL_DIR", "models/roberta_sentiment"))
print(f"\nRecommender mode: **{rec.mode}**   Sentiment mode: **{sent.mode}**\n")
print("| Operation | Runs | Median (ms) | 95th pct (ms) | Max (ms) |\n|---|---|---|---|---|")
for n_cand in (10, 50, 200):
    rows = [[1 + i * 0.1, 3 + (i % 20) / 10, 10 + i % 30, 1, i * 3] for i in range(n_cand)]
    t = timeit(lambda: rec.score(rows), 200)
    print(f"| Score {n_cand} mechanics | 200 | {statistics.median(t):.2f} | {pct(t, 95):.2f} | {max(t):.2f} |")
reviews = ["He arrived quickly and fixed my battery. Very professional!", "Overcharged me and was rude. Never again.",
           "The service was okay, nothing special.", "Waited three hours and he never came."]
t = timeit(lambda: [sent.predict(r) for r in reviews], 30)
print(f"| Classify review ({sent.mode}), per review | {30 * len(reviews)} | {statistics.median(t) / len(reviews):.1f} | {pct(t, 95) / len(reviews):.1f} | {max(t) / len(reviews):.1f} |")

print("\n**Route evaluation (Table 13) - OSRM through services/geo.py**\n")
print("| Scenario | Result | Time (ms) | Distance (km) | Duration (min) | Straight-line (km) |\n|---|---|---|---|---|---|")
pairs = [("Westlands -> CBD", -1.2676, 36.8108, -1.2864, 36.8172), ("South B -> Kasarani", -1.3105, 36.8344, -1.2213, 36.8961),
         ("Karen -> Industrial Area", -1.3190, 36.7090, -1.3095, 36.8468), ("Rongai -> Westlands", -1.3960, 36.7600, -1.2676, 36.8108)]
for name, a, b, c, d in pairs:
    s = time.perf_counter()
    try:
        r = geo.route(a, b, c, d); ms = (time.perf_counter() - s) * 1000
        print(f"| {name} | OK | {ms:.0f} | {r['km']} | {r['minutes']} | {haversine_km(a, b, c, d):.2f} |")
    except Exception as e:
        print(f"| {name} | FAILED ({type(e).__name__}) | {(time.perf_counter() - s) * 1000:.0f} | - | - | {haversine_km(a, b, c, d):.2f} |")
try:
    geo.route(999, 999, -1.28, 36.82); print("| Invalid coordinates | NOT rejected (unexpected) | - | - | - | - |")
except ValueError as e:
    print(f"| Invalid coordinates | Rejected: {e} | - | - | - | - |")
except Exception as e:
    print(f"| Invalid coordinates | {type(e).__name__} | - | - | - | - |")

print("\n**Recommendation vs 'nearest mechanic' baseline (controlled simulation, rubric = ground truth)**\n")
import random
random.seed(7)
def mech(): return [round(random.uniform(0.3, 15), 2), round(min(5, max(1, random.gauss(3.8, .9))), 1), round(random.uniform(3, 45), 1), 1, random.randint(0, 400)]
wins = {"model": 0, "nearest": 0, "rating_only": 0}; gap = {"model": [], "nearest": [], "rating_only": []}
N = 500
for _ in range(N):
    cands = [mech() for _ in range(8)]
    truth = [rule_score(*c) for c in cands]; best = max(truth)
    pick = {"model": max(range(8), key=lambda i: rec.score([cands[i]])[0]), "nearest": min(range(8), key=lambda i: cands[i][0]),
            "rating_only": max(range(8), key=lambda i: cands[i][1])}
    for k, i in pick.items():
        wins[k] += truth[i] == best; gap[k].append(best - truth[i])
print("| Method | Picked the best mechanic | Mean score gap to best |\n|---|---|---|")
for k in wins: print(f"| {k} | {wins[k] / N * 100:.1f}% | {statistics.mean(gap[k]):.2f} |")
