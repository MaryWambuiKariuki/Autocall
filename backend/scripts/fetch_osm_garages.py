"""
Download REAL car-repair garages in Kenya from OpenStreetMap (Overpass API - free, no key, no card).
  python scripts/fetch_osm_garages.py            # whole of Kenya
  python scripts/fetch_osm_garages.py --nairobi  # Nairobi only (faster)
Output: ../data/osm_kenya_garages.csv   Data (c) OpenStreetMap contributors, ODbL - credit them in your report.
"""
import argparse, csv, os, requests

ap = argparse.ArgumentParser(); ap.add_argument("--nairobi", action="store_true"); a = ap.parse_args()
area = '(-1.45,36.65,-1.15,37.10)' if a.nairobi else '(area.ke)'
head = '' if a.nairobi else 'area["ISO3166-1"="KE"][admin_level=2]->.ke;'
q = f'[out:json][timeout:120];{head}(node["shop"="car_repair"]{area};way["shop"="car_repair"]{area};);out center tags;'
r = requests.post("https://overpass-api.de/api/interpreter", data={"data": q}, timeout=180,
                  headers={"User-Agent": "AutocallStudentProject/1.0"})
r.raise_for_status()
rows = []
for e in r.json()["elements"]:
    t = e.get("tags", {})
    if not t.get("name"): continue
    c = e if "lat" in e else e.get("center", {})
    if "lat" not in c: continue
    rows.append([e["id"], t["name"], c["lat"], c["lon"], t.get("addr:suburb", ""), t.get("addr:city", ""), t.get("opening_hours", "")])
dst = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "data", "osm_kenya_garages.csv")
with open(dst, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f); w.writerow(["osm_id", "name", "lat", "lon", "suburb", "city", "opening_hours"]); w.writerows(rows)
print(len(rows), "named garages saved to", os.path.normpath(dst))
