"""Autocall backend (Flask): recommendations, review sentiment, M-Pesa STK push, auth helper."""
import hmac
import logging
import os
import threading
import time
import uuid
from functools import wraps

from dotenv import load_dotenv
from flask import Flask, g, jsonify, request

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("autocall")

import firebase_admin
from firebase_admin import auth as fb_auth
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1 import SERVER_TIMESTAMP

from ml.recommender import Recommender
from ml.sentiment import SentimentModel
from services import geo
from services.mpesa import Mpesa
from utils import CATEGORY_MAP, eta_minutes, flag_level, haversine_km, normalize_phone

cred_path = os.getenv("FIREBASE_CREDENTIALS", "serviceAccountKey.json")
firebase_admin.initialize_app(credentials.Certificate(cred_path))
db = firestore.client()

recommender = Recommender(os.getenv("RECOMMENDER_MODEL", "models/recommendation_model.pkl"),
                          os.getenv("RECOMMENDER_SCALER", "models/recommendation_scaler.pkl"))
sentiment = SentimentModel(os.getenv("SENTIMENT_MODEL_DIR", "models/roberta_sentiment"))
mpesa = Mpesa()
app = Flask(__name__)

# Collection names exactly as in Chapter 4 (Users, Mechanics, ServiceRequests, Reviews, Payments, Notifications, Verifications)
C_USERS, C_MECH, C_REQ, C_REV, C_PAY, C_NOTIF, C_VER = (
    "Users", "Mechanics", "ServiceRequests", "Reviews", "Payments", "Notifications", "Verifications")


@app.before_request
def _start_timer():
    g.t0 = time.perf_counter()


@app.after_request
def _stop_timer(resp):
    ms = (time.perf_counter() - g.get("t0", time.perf_counter())) * 1000
    resp.headers["X-Response-Time-ms"] = f"{ms:.1f}"      # used as evidence for NFR3 (performance)
    if request.path.startswith("/api/"):
        log.info("%s %s -> %s in %.0f ms", request.method, request.path, resp.status_code, ms)
    return resp


def notif_data(user_id, title, body, kind, request_id=None):
    return {"userId": user_id, "title": title, "body": body, "type": kind, "requestId": request_id,
            "read": False, "fromUid": "system", "createdAt": SERVER_TIMESTAMP}


def err(msg, code=400):
    return jsonify({"error": msg}), code


def require_auth(fn):
    @wraps(fn)
    def wrapper(*a, **kw):
        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return err("Missing bearer token", 401)
        try:
            g.uid = fb_auth.verify_id_token(header[7:])["uid"]
        except Exception:
            return err("Invalid or expired token", 401)
        return fn(*a, **kw)
    return wrapper


@app.get("/api/health")
def health():
    return jsonify({"status": "ok", "recommender": recommender.mode, "sentiment": sentiment.mode, "mpesa": mpesa.mode})


# ------------------------------------------------------------------ auth helper (phone -> email)
@app.post("/api/auth/resolve")
def resolve_identifier():
    ident = ((request.get_json(silent=True) or {}).get("identifier") or "").strip()
    if "@" in ident:
        return jsonify({"email": ident})
    phone = normalize_phone(ident)
    if not phone:
        return err("Invalid phone number")
    for d in db.collection(C_USERS).where("phone", "==", "+" + phone).limit(1).stream():
        email = d.to_dict().get("email")
        if email:
            return jsonify({"email": email})
    return err("Not found", 404)


# ------------------------------------------------------------------ recommendations
@app.post("/api/recommend")
@require_auth
def recommend():
    b = request.get_json(silent=True) or {}
    try:
        lat, lng = float(b["lat"]), float(b["lng"])
    except (KeyError, TypeError, ValueError):
        return err("lat and lng are required numbers")
    radius = float(b.get("radiusKm", 30))
    wanted = CATEGORY_MAP.get(b.get("category"), [])
    cands, rows = [], []
    for doc in db.collection(C_MECH).where("isVerified", "==", True).stream():
        m = doc.to_dict()
        loc = m.get("location")
        if doc.id == g.uid or not m.get("isAvailable") or m.get("isSuspended") or loc is None:
            continue
        dist = haversine_km(lat, lng, loc.latitude, loc.longitude)
        if dist > radius:
            continue
        n_rev = int(m.get("reviewCount", 0) or 0)
        rating = float(m.get("rating") or 0) if n_rev > 0 else 3.5   # neutral prior for unrated mechanics
        resp = float(m.get("avgResponseMin") or 20)
        jobs = int(m.get("completedJobs", 0) or 0)
        rows.append([dist, rating, resp, 1, jobs])
        cands.append((doc.id, m, dist, rating, n_rev, jobs))
    scores = recommender.score(rows)
    out = []
    for (mid, m, dist, rating, n_rev, jobs), s in zip(cands, scores):
        specs = m.get("specializations") or []
        if wanted and any(w in specs for w in wanted):
            s = min(100.0, s + 5)
        out.append({
            "id": mid, "name": m.get("name", "Mechanic"), "area": m.get("area", ""), "phone": m.get("phone", ""),
            "specializations": specs, "rating": round(rating, 1), "reviewCount": n_rev, "completedJobs": jobs,
            "experienceYears": int(m.get("experienceYears", 0) or 0), "distanceKm": round(dist, 2),
            "etaMin": eta_minutes(dist), "estFee": int(m.get("calloutFee", 800) or 800), "score": round(s, 2),
            "lat": m["location"].latitude, "lng": m["location"].longitude, "isVerified": True,
        })
    out.sort(key=lambda x: x["score"], reverse=True)
    return jsonify({"mechanics": out[:15], "count": len(out), "model": recommender.mode})


# ------------------------------------------------------------------ maps (OpenStreetMap services behind the backend)
@app.post("/api/route")
@require_auth
def api_route():
    b = request.get_json(silent=True) or {}
    try:
        flat, flng, tlat, tlng = (float(b[k]) for k in ("fromLat", "fromLng", "toLat", "toLng"))
    except (KeyError, TypeError, ValueError):
        return err("fromLat, fromLng, toLat and toLng are required numbers")
    if not (geo.valid_coord(flat, flng) and geo.valid_coord(tlat, tlng)):
        return err("Invalid coordinates")
    try:
        r = geo.route(flat, flng, tlat, tlng)
        r["source"] = "osrm"
    except Exception as e:   # routing service down / no road route: degrade to a straight line + estimate
        log.warning("OSRM unavailable (%s) - straight-line fallback", e)
        d = haversine_km(flat, flng, tlat, tlng)
        r = {"points": [[flat, flng], [tlat, tlng]], "minutes": float(eta_minutes(d)), "km": round(d, 2), "source": "straight_line"}
    return jsonify(r)


@app.post("/api/geocode/reverse")
@require_auth
def api_reverse():
    b = request.get_json(silent=True) or {}
    try:
        lat, lng = float(b["lat"]), float(b["lng"])
        return jsonify({"name": geo.reverse(lat, lng)})
    except (KeyError, TypeError, ValueError):
        return err("lat and lng are required valid numbers")
    except Exception as e:
        log.warning("Reverse geocode failed: %s", e)
        return jsonify({"name": "Current location"})


# ------------------------------------------------------------------ reviews + NLP flagging (one atomic transaction)
class Reject(Exception):
    def __init__(self, msg, code=400):
        super().__init__(msg)
        self.msg, self.code = msg, code


@firestore.transactional
def _review_txn(txn, req_ref, rev_ref, uid, rating, tags, comment, nlp):
    rs = req_ref.get(transaction=txn)
    if not rs.exists:
        raise Reject("Request not found", 404)
    r = rs.to_dict()
    if r.get("motoristId") != uid:
        raise Reject("Not your request", 403)
    if r.get("status") != "paid":
        raise Reject("You can review a service after payment", 409)
    if r.get("reviewed"):
        raise Reject("Already reviewed", 409)
    mref = db.collection(C_MECH).document(r["mechanicId"])
    ms = mref.get(transaction=txn)
    label, conf, scores = nlp
    level = flag_level(label, conf, rating) if comment else "none"
    txn.set(rev_ref, {
        "requestId": rs.id, "motoristId": uid, "motoristName": r.get("motoristName", ""),
        "mechanicId": r["mechanicId"], "mechanicName": r.get("mechanicName", ""),
        "rating": rating, "tags": tags, "comment": comment, "sentimentLabel": label,
        "sentimentConfidence": conf, "sentimentScores": scores, "sentimentModel": sentiment.mode,
        "flagLevel": level, "isFlagged": level != "none", "status": "open", "createdAt": SERVER_TIMESTAMP})
    txn.update(req_ref, {"reviewed": True, "rating": rating})
    if ms.exists:
        m = ms.to_dict()
        n, avg = int(m.get("reviewCount", 0) or 0), float(m.get("rating", 0) or 0)
        txn.update(mref, {"rating": round((avg * n + rating) / (n + 1), 2), "reviewCount": n + 1})
    txn.set(db.collection(C_NOTIF).document(), notif_data(
        r["mechanicId"], "New review", f"{r.get('motoristName', 'A motorist')} rated you {rating}/5.", "review", rs.id))


@app.post("/api/reviews")
@require_auth
def create_review():
    b = request.get_json(silent=True) or {}
    rid = b.get("requestId")
    try:
        rating = int(b.get("rating", 0))
    except (TypeError, ValueError):
        rating = 0
    if not rid or not 1 <= rating <= 5:
        return err("requestId and a rating between 1 and 5 are required")
    comment = (b.get("comment") or "").strip()[:1000]
    tags = [str(t)[:30] for t in (b.get("tags") or [])][:6]
    nlp = sentiment.predict(comment) if comment else ("neutral", 0.0, {})
    try:
        _review_txn(db.transaction(), db.collection(C_REQ).document(rid), db.collection(C_REV).document(), g.uid, rating, tags, comment, nlp)
    except Reject as e:
        return err(e.msg, e.code)
    return jsonify({"ok": True, "sentiment": nlp[0]})


# ------------------------------------------------------------------ M-Pesa payment finalisation (one atomic transaction)
@firestore.transactional
def _finalize_txn(txn, pref, code, desc, receipt, amount):
    ps = pref.get(transaction=txn)
    if not ps.exists:
        return False
    p = ps.to_dict()
    if p.get("status") in ("success", "failed"):
        return True   # idempotent: Safaricom may retry the callback
    rref = db.collection(C_REQ).document(p["requestId"])
    mref = db.collection(C_MECH).document(p.get("mechanicId") or "_")
    rs, ms = rref.get(transaction=txn), mref.get(transaction=txn)      # all reads first
    if code == 0:
        txn.update(pref, {"status": "success", "receipt": receipt, "paidAmount": amount, "resultDesc": desc, "completedAt": SERVER_TIMESTAMP})
        txn.update(rref, {"status": "paid", "paidAt": SERVER_TIMESTAMP, "receipt": receipt})
        if ms.exists:
            m, req = ms.to_dict(), (rs.to_dict() or {})
            n = int(m.get("completedJobs", 0) or 0)
            upd = {"completedJobs": n + 1}
            start, accepted = req.get("createdAt"), req.get("acceptedAt")
            if start and accepted:
                resp_min = max(0.0, (accepted - start).total_seconds() / 60)
                upd["avgResponseMin"] = round((float(m.get("avgResponseMin", 0) or 0) * n + resp_min) / (n + 1), 2)
            txn.update(mref, upd)
        txn.set(db.collection(C_NOTIF).document(), notif_data(p["motoristId"], "Payment received", f"M-Pesa ref {receipt} - KES {amount}.", "payment", p["requestId"]))
        if p.get("mechanicId"):
            txn.set(db.collection(C_NOTIF).document(), notif_data(p["mechanicId"], "You have been paid", f"KES {amount} received (ref {receipt}).", "payment", p["requestId"]))
    else:
        txn.update(pref, {"status": "failed", "resultCode": code, "resultDesc": desc, "completedAt": SERVER_TIMESTAMP})
        txn.set(db.collection(C_NOTIF).document(), notif_data(p["motoristId"], "Payment not completed", desc or "The M-Pesa payment was not completed.", "payment", p["requestId"]))
    return True


def finalize_payment(checkout_id, code, desc, receipt=None, amount=None):
    return _finalize_txn(db.transaction(), db.collection(C_PAY).document(checkout_id), code, desc, receipt, amount)


@app.post("/api/mpesa/stkpush")
@require_auth
def stk_push():
    b = request.get_json(silent=True) or {}
    phone = normalize_phone(b.get("phone"))
    if not phone:
        return err("Enter a valid Safaricom number, e.g. 0712 345 678")
    ref = db.collection(C_REQ).document(b.get("requestId") or "_")
    snap = ref.get()
    if not snap.exists:
        return err("Request not found", 404)
    r = snap.to_dict()
    if r.get("motoristId") != g.uid:
        return err("Not your request", 403)
    if r.get("status") != "completed":
        return err("Payment is only possible once the mechanic marks the job completed", 409)
    amount = int(round(float(r.get("total", 0) or 0)))
    if amount < 1:
        return err("Invalid amount", 409)
    if mpesa.mock:
        checkout_id = "ws_CO_MOCK_" + uuid.uuid4().hex[:12]
    else:
        try:
            resp = mpesa.stk_push(phone, amount, "ATC" + snap.id[:8], "Autocall")
        except Exception as e:
            log.exception("STK push failed")
            return err(f"M-Pesa request failed: {e}", 502)
        if str(resp.get("ResponseCode")) != "0":
            return err(resp.get("errorMessage") or resp.get("ResponseDescription") or "M-Pesa rejected the request", 502)
        checkout_id = resp["CheckoutRequestID"]
    db.collection(C_PAY).document(checkout_id).set({
        "checkoutRequestId": checkout_id, "requestId": snap.id, "motoristId": g.uid, "mechanicId": r.get("mechanicId"),
        "amount": amount, "phone": phone, "status": "pending", "mode": mpesa.mode, "createdAt": SERVER_TIMESTAMP})
    if mpesa.mock:   # demo mode: pretend the customer entered their PIN after 6 s
        threading.Timer(6, finalize_payment, args=(checkout_id, 0, "Mock success", "MOCK" + uuid.uuid4().hex[:7].upper(), amount)).start()
    return jsonify({"checkoutRequestId": checkout_id})


@app.post("/api/mpesa/callback/<secret>")
def mpesa_callback(secret):
    if not hmac.compare_digest(secret, mpesa.cb_secret):
        return jsonify({"ResultCode": 1, "ResultDesc": "Forbidden"}), 403
    cb = ((request.get_json(silent=True) or {}).get("Body") or {}).get("stkCallback") or {}
    items = (cb.get("CallbackMetadata") or {}).get("Item", [])
    meta = {i.get("Name"): i.get("Value") for i in items}
    log.info("Daraja callback: checkout=%s code=%s", cb.get("CheckoutRequestID"), cb.get("ResultCode"))
    if cb.get("CheckoutRequestID"):
        finalize_payment(cb["CheckoutRequestID"], int(cb.get("ResultCode", 1)), cb.get("ResultDesc", ""),
                         meta.get("MpesaReceiptNumber"), meta.get("Amount"))
    return jsonify({"ResultCode": 0, "ResultDesc": "Accepted"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 5000)), debug=False)
