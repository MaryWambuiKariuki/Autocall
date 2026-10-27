"""
Seed demo mechanics into Firestore, optionally import real garages from OpenStreetMap, or promote an admin.
Run from backend/ with the venv active:
  python scripts/seed_firestore.py --lat -1.2921 --lng 36.8219        # demo mechanics around YOU (use your location)
  python scripts/seed_firestore.py --osm ../data/osm_kenya_garages.csv # listed real garages (no ratings, no phones)
  python scripts/seed_firestore.py --make-admin you@email.com          # after you registered that account in the app
  python scripts/seed_firestore.py --clear-seeds
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

if a.clear_seeds:
    n = 0
    for d in db.collection("Mechanics").where("isSeed", "==", True).stream():
        d.reference.delete(); n += 1
    print("deleted", n, "seed mechanics")

if a.make_admin:
    u = fb_auth.get_user_by_email(a.make_admin)
    db.collection("Users").document(u.uid).set({"name": u.display_name or "Admin", "email": a.make_admin, "phone": "",
                                                "role": "admin", "createdAt": SERVER_TIMESTAMP}, merge=True)
    print("admin set for", a.make_admin, "(sign out and in again)")

if a.osm:
    n = 0
    for r in csv.DictReader(open(a.osm, encoding="utf-8")):
        db.collection("Mechanics").document("osm_" + r["osm_id"]).set({
            "name": r["name"], "area": r.get("suburb") or r.get("city") or "", "phone": "",
            "location": GeoPoint(float(r["lat"]), float(r["lon"])), "specializations": ["General Mechanic"],
            "rating": 0, "reviewCount": 0, "avgResponseMin": 20, "completedJobs": 0, "experienceYears": 0,
            "calloutFee": 800, "isAvailable": True, "isVerified": True, "verificationStatus": "listed",
            "isSeed": True, "source": "OpenStreetMap (ODbL)"})
        n += 1
    print("imported", n, "OSM garages")

if (a.lat is not None and a.lng is not None) or (not a.osm and not a.make_admin and not a.clear_seeds):
    n = 0
    for r in csv.DictReader(open(a.csv, encoding="utf-8")):
        lat, lng = float(r["latitude"]), float(r["longitude"])
        if a.lat is not None and a.lng is not None:           # re-centre demo data around the tester
            lat, lng = a.lat + random.uniform(-.07, .07), a.lng + random.uniform(-.07, .07)
        db.collection("Mechanics").document("demo_" + r["mechanic_id"]).set({
            "name": r["name"], "area": r["area"], "phone": "", "location": GeoPoint(lat, lng),
            "specializations": [r["specialization"]], "rating": float(r["rating"]), "reviewCount": int(r["review_count"]),
            "avgResponseMin": float(r["response_time_min"]), "completedJobs": int(r["completed_jobs"]),
            "experienceYears": int(r["experience_years"]), "calloutFee": int(r["callout_fee_kes"]),
            "isAvailable": r["is_available"] == "1", "isVerified": r["is_verified"] == "1",
            "verificationStatus": "approved" if r["is_verified"] == "1" else "pending",
            "isSeed": True, "source": "synthetic demo data"})
        n += 1
    print("seeded", n, "demo mechanics")
