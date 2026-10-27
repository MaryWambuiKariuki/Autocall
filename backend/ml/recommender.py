import logging
import os
import pickle

log = logging.getLogger("autocall.recommender")
FEATURES = ["proximity_km", "rating", "response_time_min", "is_available", "completed_jobs"]


def rule_score(prox, rating, resp, avail, jobs):
    """Same weighted rubric used to label the training data (also the fallback when no model file exists)."""
    s = (max(0, 1 - prox / 20) * 25 + (rating / 5) * 30 + max(0, 1 - resp / 60) * 20
         + avail * 15 + min(jobs / 200, 1) * 10)
    return max(0.0, min(100.0, s))


class Recommender:
    def __init__(self, model_path, scaler_path):
        self.model = self.scaler = None
        if os.path.exists(model_path) and os.path.exists(scaler_path):
            try:
                with open(model_path, "rb") as f:
                    self.model = pickle.load(f)
                with open(scaler_path, "rb") as f:
                    self.scaler = pickle.load(f)
                log.info("Loaded Random Forest recommender")
            except Exception as e:  # version mismatch etc.
                log.warning("Could not load recommender (%s) - using rule-based scoring", e)
                self.model = self.scaler = None

    @property
    def mode(self):
        return "random_forest" if self.model is not None else "rule_based"

    def score(self, rows):
        """rows: list of [proximity_km, rating, response_time_min, is_available, completed_jobs]."""
        if not rows:
            return []
        if self.model is None:
            return [round(rule_score(*r), 2) for r in rows]
        import numpy as np
        pred = self.model.predict(self.scaler.transform(np.array(rows, dtype=float)))
        return [round(float(max(0, min(100, p))), 2) for p in pred]
