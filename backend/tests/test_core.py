import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from utils import eta_minutes, flag_level, haversine_km, normalize_phone
from ml.recommender import Recommender, rule_score
from ml.sentiment import SentimentModel


def test_haversine():
    assert haversine_km(-1.28, 36.82, -1.28, 36.82) == 0
    assert abs(haversine_km(0, 36, 1, 36) - 111.2) < 0.5                     # 1 degree latitude
    assert abs(haversine_km(-1.28, 36.8, -1.30, 36.9) - haversine_km(-1.30, 36.9, -1.28, 36.8)) < 1e-9


def test_phone_normalisation():
    for raw in ["0712345678", "+254712345678", "254712345678", "0712 345 678", "0112345678", "712345678"]:
        assert normalize_phone(raw) is not None, raw
    assert normalize_phone("0712345678") == "254712345678"
    for bad in ["", "12345", "0812345678", "abc", None]:
        assert normalize_phone(bad) is None, bad


def test_eta_grows_with_distance():
    assert eta_minutes(1) < eta_minutes(5) < eta_minutes(15)


def test_rule_score_ordering():
    best = rule_score(0.8, 4.9, 5, 1, 300)
    worst = rule_score(15, 2.0, 45, 1, 5)
    assert best > worst and 0 <= worst <= best <= 100
    assert rule_score(1, 4.5, 10, 1, 100) > rule_score(1, 4.5, 10, 0, 100)    # availability matters


def test_recommender_fallback_without_files():
    r = Recommender("missing.pkl", "missing2.pkl")
    assert r.mode == "rule_based"
    s = r.score([[0.8, 4.9, 5, 1, 300], [15, 2.0, 45, 1, 5]])
    assert s[0] > s[1]


def test_flag_levels():
    assert flag_level("negative", 0.91, 1) == "high"
    assert flag_level("negative", 0.55, 2) == "low"
    assert flag_level("neutral", 0.70, 3) == "low"
    assert flag_level("positive", 0.95, 5) == "none"


def test_sentiment_fallback():
    s = SentimentModel("no-such-dir")
    assert s.mode == "lexicon_fallback"
    assert s.predict("Terrible, rude mechanic who overcharged me")[0] == "negative"
    assert s.predict("Excellent and professional, highly recommend")[0] == "positive"
    assert s.predict("He arrived and fixed it")[0] == "neutral"


def test_geo_validation_and_decimation():
    from services import geo
    assert geo.valid_coord(-1.28, 36.82) and not geo.valid_coord(999, 0) and not geo.valid_coord(0, 181)
    pts = [[i, i] for i in range(1000)]
    d = geo._decimate(pts, 400)
    assert len(d) == 400 and d[-1] == pts[-1] and d[0] == pts[0]
    try:
        geo.route(999, 999, 0, 0)
        assert False, "invalid coordinates must raise"
    except ValueError:
        pass
