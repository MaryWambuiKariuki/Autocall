"""Pure helper functions (no Firebase / network) so they can be unit-tested."""
import math
import re

_PHONE = re.compile(r"^(?:\+?254|0)?([17]\d{8})$")

CATEGORY_MAP = {
    "Engine": ["Engine Overhaul", "General Mechanic"],
    "Battery": ["Electrical"],
    "Tyre": ["Tyre & Alignment"],
    "Electrical": ["Electrical"],
    "Brakes": ["Exhaust & Brakes"],
    "Fuel": ["General Mechanic"],
    "Other": ["General Mechanic"],
}


def haversine_km(lat1, lon1, lat2, lon2):
    r = 6371.0088
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi, dl = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def normalize_phone(raw):
    """Return Kenyan number as 2547XXXXXXXX / 2541XXXXXXXX, or None if invalid."""
    s = re.sub(r"[\s\-()]", "", str(raw or ""))
    m = _PHONE.match(s)
    return "254" + m.group(1) if m else None


def eta_minutes(distance_km):
    """Rough urban ETA: 3 min dispatch + 25 km/h average."""
    return int(round(3 + distance_km / 25.0 * 60))


def flag_level(label, confidence, rating):
    """high = negative with confidence >= 0.70 (admin review); low = mixed/contradictory; none otherwise."""
    if label == "negative" and confidence >= 0.70:
        return "high"
    if label == "negative" or (label == "neutral" and rating <= 3) or (label == "positive" and rating <= 2):
        return "low"
    return "none"
