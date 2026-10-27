"""
Regenerates the Autocall datasets. ALL DATA HERE IS SYNTHETIC - state this in your report.
Run from the repo root:   python data/generate_datasets.py
Outputs (in data/): autocall_recommendation_dataset.csv, autocall_nlp_reviews_dataset.csv,
                    autocall_nlp_challenge_set.csv, autocall_mechanics_seed_kenya.csv
"""
import csv, os, random
from collections import Counter

random.seed(42)
HERE = os.path.dirname(os.path.abspath(__file__))
out = lambda n: os.path.join(HERE, n)

# ---------------------------------------------------------------- 1. recommendation
def rubric(prox, rating, resp, avail, jobs):
    """Weighted scoring rubric (weights are a design decision - justify/validate in the report)."""
    return (max(0, 1 - prox / 20) * 25 + (rating / 5) * 30 + max(0, 1 - resp / 60) * 20
            + avail * 15 + min(jobs / 200, 1) * 10)

def gen_recommendation(n=1000):
    rows = []
    for i in range(n):
        prox = round(min(25, max(0.2, random.gammavariate(2.0, 3.0))), 2)
        rating = round(min(5, max(1.0, random.gauss(3.8, 0.9))), 1)
        resp = round(min(60, max(2, random.gauss(20, 11))), 1)
        avail = 1 if random.random() < 0.7 else 0
        jobs = int(min(500, random.expovariate(1 / 70)))
        score = round(min(100, max(0, rubric(prox, rating, resp, avail, jobs) + random.gauss(0, 2.5))), 2)
        rows.append([f"S{i+1:04d}", prox, rating, resp, avail, jobs, score])
    with open(out("autocall_recommendation_dataset.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["sample_id", "proximity_km", "rating", "response_time_min", "is_available",
                    "completed_jobs", "recommendation_score"])
        w.writerows(rows)
    tier = lambda s: "high" if s >= 70 else "medium" if s >= 50 else "low"
    print("recommendation rows:", n, "tiers (>=70 high, >=50 medium):", dict(Counter(tier(r[-1]) for r in rows)))

# ---------------------------------------------------------------- 2. mechanics seed (fictional)
AREAS = [("Westlands", -1.2676, 36.8108), ("Kilimani", -1.2905, 36.7870), ("Parklands", -1.2630, 36.8200),
         ("Ngong Road", -1.3023, 36.7619), ("Lang'ata", -1.3500, 36.7500), ("Karen", -1.3190, 36.7090),
         ("South B", -1.3105, 36.8344), ("Industrial Area", -1.3095, 36.8468), ("Eastleigh", -1.2710, 36.8547),
         ("Embakasi", -1.3000, 36.9000), ("Kayole", -1.2750, 36.9100), ("Kasarani", -1.2213, 36.8961),
         ("Roysambu", -1.2186, 36.8872), ("Ruiru", -1.1500, 36.9600), ("Rongai", -1.3960, 36.7600),
         ("Syokimau", -1.3610, 36.9340)]
OTHER = [("Nyali, Mombasa", -4.0300, 39.7200), ("Kisumu CBD", -0.0917, 34.7680)]
SPECS = ["General Mechanic", "Electrical", "Bodywork", "Tyre & Alignment", "AC Repair",
         "Engine Overhaul", "Transmission", "Exhaust & Brakes"]
SURN = ["Kamau", "Otieno", "Mwangi", "Njoroge", "Kiprotich", "Omondi", "Waweru", "Mutua", "Kimani", "Odhiambo",
        "Kariuki", "Githinji", "Muthoni", "Muturi", "Njuguna", "Ochieng", "Kiptoo", "Wekesa", "Achieng", "Mbugua"]
KINDS = ["Auto Care", "Motors", "Garage", "Auto Clinic", "Auto Works"]

def gen_mechanics(n=40):
    rows, used = [], set()
    for i in range(n):
        area, lat, lng = (random.choice(AREAS) if i < 34 else random.choice(OTHER))
        while True:
            name = f"{random.choice(SURN)} {random.choice(KINDS)}"
            if name not in used: used.add(name); break
        rows.append([f"DEMO{i+1:03d}", name, area, round(lat + random.uniform(-.012, .012), 6),
                     round(lng + random.uniform(-.012, .012), 6), random.choice(SPECS),
                     round(random.uniform(3.2, 5.0), 1), random.randint(5, 320),
                     round(random.uniform(6, 35), 1), random.randint(10, 450), random.randint(1, 15),
                     random.choice([500, 600, 700, 800, 900, 1000]), random.choice([1, 1, 1, 0]), 1])
    with open(out("autocall_mechanics_seed_kenya.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["mechanic_id", "name", "area", "latitude", "longitude", "specialization", "rating",
                    "review_count", "response_time_min", "completed_jobs", "experience_years",
                    "callout_fee_kes", "is_available", "is_verified"])
        w.writerows(rows)
    print("mechanics seed:", n, "(fictional demo garages - no phone numbers on purpose)")

# ---------------------------------------------------------------- 3. NLP reviews
NAMES = ["John", "Peter", "James", "David", "Samuel", "Joseph", "Patrick", "Michael", "Charles", "George",
         "Francis", "Simon", "Kevin", "Eric", "Brian"]
PLACES = ["Thika Road", "Mombasa Road", "Ngong Road", "Waiyaki Way", "Jogoo Road", "Outer Ring Road",
          "Langata Road", "Kiambu Road", "Westlands", "Kilimani", "South B", "Embakasi", "Kasarani",
          "Ruaka", "Syokimau", "Rongai", "Eastleigh", "Karen", "Mlolongo", "Juja"]
ISSUES = ["flat tyre", "dead battery", "overheating engine", "faulty alternator", "brake problem",
          "clutch failure", "starter motor", "fuel pump", "radiator leak", "broken fan belt",
          "gearbox problem", "faulty sensor"]

T = {
 "positive": dict(
  A=["{name} reached me on {place} in about {mins} minutes.",
     "Response was quick, the mechanic was at {place} within {mins} minutes of my request.",
     "I was stuck on {place} with a {issue} and help arrived in {mins} minutes.",
     "The mechanic showed up on time and called ahead to confirm where I was.",
     "He arrived earlier than the ETA shown in the app.",
     "Tracking the mechanic on the map was great, he reached {place} exactly when expected.",
     "Help came fast even though it was late at night.",
     "Within {mins} minutes of booking, {name} was already at my car."],
  B=["He diagnosed the {issue} quickly and fixed it properly.",
     "The repair of my {issue} was neat and professional.",
     "He explained what was wrong with the {issue} in simple terms.",
     "My car has been running perfectly since he sorted the {issue}.",
     "He had the right tools and parts for the {issue} and worked efficiently.",
     "He tested everything before leaving to make sure the {issue} was truly resolved.",
     "Very skilled mechanic who clearly knows his job.",
     "He fixed the {issue} without trying to sell me unnecessary extras."],
  C=["The price was fair and matched the estimate in the app.",
     "Paying with M-Pesa was smooth and I got a receipt.",
     "No hidden charges at all, KES {amt} as quoted.",
     "Great communication throughout, I always knew what was happening.",
     "He was polite and respectful from start to finish.",
     "Very reasonable rates compared with garages in town.",
     "He kept me updated and was honest about the cost.",
     "Good value for money."],
  D=["Highly recommend.", "Will definitely use Autocall again.", "Five stars from me.",
     "Asante sana, kazi safi!", "Best roadside help I have used in Nairobi."]),
 "neutral": dict(
  A=["The mechanic arrived about {mins} minutes after the ETA but it was not a big problem.",
     "He came to {place} and got to work on the {issue}.",
     "Response time was average, roughly {mins} minutes.",
     "Mechanic arrived and checked the {issue}.",
     "He reached me a bit later than expected but called to let me know.",
     "I booked from {place} and someone came eventually.",
     "The mechanic turned up without any fuss.",
     "He arrived in a reasonable time for the area."],
  B=["The {issue} was fixed but I am not sure how long it will last.",
     "The work on the {issue} was acceptable although nothing special.",
     "He sorted the {issue} though it took two attempts.",
     "He did not explain much about the {issue}, just fixed it and left.",
     "The repair of the {issue} was done to a basic standard.",
     "The job took about {mins2} minutes, which is average for this kind of fault.",
     "The car works again after the {issue} repair, which is the main thing.",
     "He seemed knowledgeable but a bit slow with the {issue}."],
  C=["The price was roughly what I expected, KES {amt}.",
     "Billing was slightly different from the app estimate but not by much.",
     "Communication was okay, nothing outstanding.",
     "Payment through M-Pesa worked after one retry.",
     "He was neither friendly nor unfriendly.",
     "I would not call it cheap or expensive.",
     "The app notifications were a bit slow but they worked.",
     "I cannot say I am impressed or disappointed."],
  D=["Average experience overall.", "It is fine, I might use it again.", "Ni sawa tu.",
     "Maybe I will try another mechanic next time.", "Three stars."]),
 "negative": dict(
  A=["I waited over {hrs} hours on {place} before the mechanic finally showed up.",
     "The mechanic never arrived even after confirming the request.",
     "He arrived {mins2} minutes late and did not apologise.",
     "He said he was five minutes away but took almost two hours to reach {place}.",
     "The mechanic cancelled on me after I had already waited a long time on {place}.",
     "He came without the tools needed for a {issue}.",
     "A different person showed up from the one on the profile.",
     "He turned up but kept making phone calls instead of working."],
  B=["He failed to fix the {issue} and the problem returned the same day.",
     "The repair on my {issue} was sloppy and unsafe.",
     "He made the {issue} worse and I had to tow the car to another garage.",
     "He misdiagnosed the {issue} and replaced parts that were not faulty.",
     "He damaged my car while working on the {issue} and denied it.",
     "Bolts were left loose after the {issue} repair and the car started rattling.",
     "He clearly did not know what he was doing with the {issue}.",
     "He left the job half done and disappeared."],
  C=["He overcharged me, demanding KES {amt} when the quote was much lower.",
     "He asked for extra cash outside the app, which is not allowed.",
     "He changed the price several times during the job.",
     "He was rude and aggressive when I asked for a receipt.",
     "No communication at all and he stopped answering my calls.",
     "I was charged for parts that I never saw being replaced.",
     "He insulted me when I questioned the bill.",
     "Total rip off."],
  D=["Do not use this mechanic.", "I will never use this again.", "Very disappointing experience.",
     "Sitarudia tena, huduma mbaya sana.", "Zero stars if I could.", "Avoid."]),
}

def fill(t):
    return t.format(name=random.choice(NAMES), place=random.choice(PLACES), issue=random.choice(ISSUES),
                    mins=random.choice([5, 8, 10, 12, 15, 18, 20, 25]), mins2=random.choice([35, 40, 45, 50, 60, 75]),
                    hrs=random.choice([2, 3, 4]), amt=random.choice([1500, 2000, 2500, 3000, 3500, 4500, 6000]))

def compose(parts):
    keep = random.choice([("A", "B"), ("B", "C"), ("A", "C"), ("A", "B", "C"), ("A", "B", "C")])
    s = " ".join(fill(random.choice(parts[k])) for k in keep)
    if random.random() < 0.65: s += " " + random.choice(parts["D"])
    return s

CHALLENGE = {
 "positive": [
  "Called around 6pm after my car died near Garden City. He was there before I finished my tea and sorted the alternator belt.",
  "Honestly did not expect much but the guy was sharp. Knew the fault just by listening to the engine.",
  "Fair quote, no drama, and he gave me the old spark plugs to show they were replaced.",
  "Nilikuwa na stress sana but the mechanic calmed me down and fixed the tyre in minutes. Asante!",
  "Tracking him on the map made the wait bearable, and he arrived exactly when the app said.",
  "Clean work, tools packed neatly, and he even checked my brake fluid for free.",
  "Best breakdown experience I have had on Waiyaki Way, hands down.",
  "He explained the radiator problem in simple language and did not push extra repairs.",
  "Paid via M-Pesa instantly and received a proper receipt. Smooth from start to finish.",
  "My Probox has not run this quietly in years. Whoever rated this mechanic highly was right.",
  "Came on a Sunday night when nobody else would answer the phone. Grateful.",
  "Quick diagnosis, reasonable charge, polite attitude. What more can one ask for?",
  "Battery was swapped in under twenty minutes and he tested everything before leaving.",
  "I was nervous being stranded alone at night, but he was respectful and professional throughout.",
  "Kazi nzuri kabisa. Car started on the first try after he cleaned the terminals."],
 "neutral": [
  "He fixed it, I paid, he left. Not much more to say.",
  "Arrived later than the ETA but not by too much. The repair itself was fine.",
  "Price was higher than I hoped but within what I see around Nairobi. Job done.",
  "Decent work although he barely spoke. I cannot complain, I cannot praise.",
  "The tyre was changed correctly. The app notifications were a bit slow though.",
  "Average. I have had better and I have had worse.",
  "Mechanic seemed experienced but needed two tries to find the fault.",
  "Service was alright, took about an hour. Nothing special.",
  "Okay experience, the car runs again, but I wish he had explained what he did.",
  "He was friendly but the fix only took care of half of the problem, so I will see how it holds.",
  "Reasonable service, slightly confusing billing.",
  "Not bad, not great. Would try another mechanic next time just to compare.",
  "The work was done properly but he arrived without one tool and had to borrow.",
  "Ni sawa tu, hakuna shida kubwa ila alichelewa kidogo.",
  "Okay response time, the final price was a bit different from the estimate in the app."],
 "negative": [
  "Waited almost three hours near Mlolongo and when he finally came he did not even have a jack.",
  "He changed the price three times while working. I felt completely cheated.",
  "The noise from the engine got worse after his repair. I had to tow the car to a proper garage.",
  "Rude from the moment he arrived and kept blaming me for the breakdown.",
  "Charged me for a new fuel pump and I later found the old one still inside the car.",
  "Phone switched off after I paid the deposit. Never showed up.",
  "He scratched my bumper while towing and refused to admit it.",
  "Terrible. I would give zero stars if I could.",
  "Overpriced and sloppy. The warning light came back the same evening.",
  "Alikuja amelewa na akaanza kunitusi. Nimeripoti.",
  "Not safe. He worked on my brakes without testing them and left me guessing.",
  "Completely wasted my afternoon. Claimed he had parts in the car but then said he must go and buy them.",
  "Demanded extra cash outside the app, which is clearly against the rules.",
  "He told me my engine was finished and I needed a new one for KES 180,000. Another garage fixed a loose wire for 800.",
  "Fake profile picture, different person showed up, and he could not diagnose anything."],
}

def gen_nlp(per_class=300):
    seeds = list(csv.DictReader(open(out("autocall_nlp_seed_reviews.csv"), encoding="utf-8")))
    rows, seen = [], set()
    for r in seeds:
        rows.append((r["review_text"], r["label"], "handwritten_seed")); seen.add(r["review_text"].lower())
    for label, parts in T.items():
        have = sum(1 for r in rows if r[1] == label)
        guard = 0
        while have < per_class and guard < 50000:
            guard += 1
            s = compose(parts)
            if s.lower() in seen: continue
            seen.add(s.lower()); rows.append((s, label, "template_generated")); have += 1
    random.shuffle(rows)
    with open(out("autocall_nlp_reviews_dataset.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(["review_id", "review_text", "label", "source"])
        for i, (t, l, s) in enumerate(rows): w.writerow([f"R{i+1:04d}", t, l, s])
    ch = [(t, l) for l, ts in CHALLENGE.items() for t in ts]
    with open(out("autocall_nlp_challenge_set.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(["review_id", "review_text", "label", "source"])
        for i, (t, l) in enumerate(ch): w.writerow([f"C{i+1:03d}", t, l, "handwritten_challenge"])
    print("nlp rows:", len(rows), dict(Counter(r[1] for r in rows)), "| challenge:", len(ch))

if __name__ == "__main__":
    gen_recommendation(); gen_mechanics(); gen_nlp()
