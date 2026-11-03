"""
Seed demo mechanics into Firestore, optionally import real garages from OpenStreetMap, or promote an admin.
Run from backend/ with the venv active:
  python scripts/seed_firestore.py --lat -1.2921 --lng 36.8219         # demo mechanics around YOU (your test location)
  python scripts/seed_firestore.py --osm ../data/osm_kenya_garages.csv  # listed real garages (no ratings, no phones)
  python scripts/seed_firestore.py --make-admin you@email.com           # after you registered that account in the app
  python scripts/seed_firestore.py --clear-seeds
Writes are sent in batches of 100 so a slow or unstable connection needs far fewer round trips.
"""
import argparse, csv, os, random, sys
import firebase_admin
from firebase_admin import auth as fb_auth, credentials, firestore
from google.cloud.firestore_v1 import GeoPoint, SERVER_TIMESTAMP

ap = argparse.ArgumentParser()
ap.add_argument("--creds", default="serviceAccountKey.json")
ap.add_argument("--csv", default="../data/autocall_mechanics_seed_kenya.csv")
ap.add_argument("--lat", type=float); ap.add_argument("--lng", type=float)
ap.add_argument("--osm"); ap.add_argument("--make-admin"); ap.add_argument("--clear-seeds", action="store_true")
a = ap.parse_args()
firebase_admin.initialize_app(credentials.Certificate(a.creds))
db = firestore.client()
BATCH = 100


def commit_all(items, label):
    """items = [(DocumentReference, dict)] -> written in batches; prints progress."""
    done = 0
    for i in range(0, len(items), BATCH):
        b = db.batch()
        for ref, data in items[i:i + BATCH]:
            b.set(ref, data)
        b.commit()
        done += len(items[i:i + BATCH])
        print(f"  {label}: {done}/{len(items)}", flush=True)


if a.clear_seeds:
    refs = [d.reference for d in db.collection("Mechanics").where("isSeed", "==", True).stream()]
    for i in range(0, len(refs), BATCH):
        b = db.batch()
        for r in refs[i:i + BATCH]:
            b.delete(r)
        b.commit()
    print("deleted", len(refs), "seed mechanics")

if a.make_admin:
    u = fb_auth.get_user_by_email(a.make_admin)
    db.collection("Users").document(u.uid).set({"name": u.display_name or "Admin", "email": a.make_admin, "phone": "",
                                                "role": "admin", "createdAt": SERVER_TIMESTAMP}, merge=True)
    print("admin set for", a.make_admin, "(sign out and in again)")

if a.osm:
    items = []
    for r in csv.DictReader(open(a.osm, encoding="utf-8")):
        items.append((db.collection("Mechanics").document("osm_" + r["osm_id"]), {
            "name": r["name"], "area": r.get("suburb") or r.get("city") or "", "phone": "",
            "location": GeoPoint(float(r["lat"]), float(r["lon"])), "specializations": ["General Mechanic"],
            "rating": 0, "reviewCount": 0, "avgResponseMin": 20, "completedJobs": 0, "experienceYears": 0,
            "calloutFee": 800, "isAvailable": True, "isVerified": True, "verificationStatus": "listed",
            "isSeed": True, "source": "OpenStreetMap (ODbL)"}))
    commit_all(items, "OSM garages")
    print("imported", len(items), "OSM garages")

if (a.lat is not None and a.lng is not None) or (not a.osm and not a.make_admin and not a.clear_seeds):
    items = []
    for r in csv.DictReader(open(a.csv, encoding="utf-8")):
        lat, lng = float(r["lat" \
        "itude"]), float(r["longitude"])
        if a.lat is not None and a.lng is not None:           # re-centre demo data around the tester
            lat, lng = a.lat + random.uniform(-.07, .07), a.lng + random.uniform(-.07, .07)
        items.append((db.collection("Mechanics").document("demo_" + r["mechanic_id"]), {
            "name": r["name"], "area": r["area"], "phone": "", "location": GeoPoint(lat, lng),
            "specializations": [r["specialization"]], "rating": float(r["rating"]), "reviewCount": int(r["review_count"]),
            "avgResponseMin": float(r["response_time_min"]), "completedJobs": int(r["completed_jobs"]),
            "experienceYears": int(r["experience_years"]), "calloutFee": int(r["callout_fee_kes"]),
            "isAvailable": r["is_available"] == "1", "isVerified": r["is_verified"] == "1",
            "verificationStatus": "approved" if r["is_verified"] == "1" else "pending",
            "isSeed": True, "source": "synthetic demo data"}))
    commit_all(items, "demo mechanics")
    print("seeded", len(items), "demo mechanics")