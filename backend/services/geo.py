"""Routing + reverse geocoding through free OpenStreetMap services (OSRM, Nominatim).
Called by the Flask backend so the architecture matches 'Flask <-> Maps services' in Chapter 4."""
import time

import requests

UA = {"User-Agent": "AutocallStudentApp/1.0 (university student project)"}
OSRM = "https://router.project-osrm.org/route/v1/driving"
NOMINATIM = "https://nominatim.openstreetmap.org/reverse"
_cache = {}


def valid_coord(lat, lng):
    return -90 <= lat <= 90 and -180 <= lng <= 180


def _decimate(points, limit=400):
    if len(points) <= limit:
        return points
    step = len(points) / float(limit)
    out = [points[int(i * step)] for i in range(limit)]
    out[-1] = points[-1]
    return out


def route(flat, flng, tlat, tlng):
    """Returns {'points': [[lat,lng],...], 'minutes', 'km'}. Raises on any failure (caller decides the fallback)."""
    if not (valid_coord(flat, flng) and valid_coord(tlat, tlng)):
        raise ValueError("Invalid coordinates")
    r = requests.get(f"{OSRM}/{flng},{flat};{tlng},{tlat}", params={"overview": "full", "geometries": "geojson"},
                     headers=UA, timeout=10)
    r.raise_for_status()
    j = r.json()
    if j.get("code") != "Ok" or not j.get("routes"):
        raise ValueError(j.get("message") or j.get("code") or "No route")
    rt = j["routes"][0]
    pts = [[c[1], c[0]] for c in rt["geometry"]["coordinates"]]
    return {"points": _decimate(pts), "minutes": round(rt["duration"] / 60.0, 1), "km": round(rt["distance"] / 1000.0, 2)}


def reverse(lat, lng):
    """Short human-readable area name, cached ~1 km."""
    if not valid_coord(lat, lng):
        raise ValueError("Invalid coordinates")
    key = (round(lat, 3), round(lng, 3))
    hit = _cache.get(key)
    if hit and time.time() - hit[0] < 3600:
        return hit[1]
    r = requests.get(NOMINATIM, params={"format": "jsonv2", "zoom": 16, "lat": lat, "lon": lng}, headers=UA, timeout=8)
    r.raise_for_status()
    j = r.json()
    a = j.get("address") or {}
    parts = [p for p in (a.get("suburb") or a.get("neighbourhood") or a.get("road"),
                         a.get("city") or a.get("town") or a.get("county")) if p]
    name = ", ".join(parts) if parts else (j.get("display_name") or "Current location")
    _cache[key] = (time.time(), name)
    return name
