import logging
import os
import re

log = logging.getLogger("autocall.sentiment")

NEG = {"terrible", "worst", "rude", "cheated", "scam", "scammer", "overcharged", "overpriced", "late", "never", "awful",
       "horrible", "unprofessional", "sloppy", "dishonest", "fraud", "fake", "damaged", "refused", "wasted", "stranded",
       "disappointing", "disappointed", "insulted", "rip", "mbaya", "avoid", "unsafe", "worse", "stole", "lied"}
POS = {"great", "excellent", "fast", "quick", "professional", "polite", "fair", "recommend", "helpful", "friendly",
       "reliable", "honest", "best", "amazing", "smooth", "clean", "skilled", "grateful", "safi", "nzuri", "asante",
       "perfect", "good", "satisfied", "impressed"}


class SentimentModel:
    """RoBERTa classifier if the exported folder + transformers/torch exist, otherwise a small lexicon fallback."""

    def __init__(self, model_dir):
        self.pipe = None
        if os.path.isdir(model_dir):
            try:
                from transformers import pipeline
                self.pipe = pipeline("text-classification", model=model_dir, tokenizer=model_dir,
                                     top_k=None, device=-1, truncation=True, max_length=128)
                log.info("Loaded RoBERTa sentiment model from %s", model_dir)
            except Exception as e:
                log.warning("Could not load RoBERTa (%s) - using lexicon fallback", e)

    @property
    def mode(self):
        return "roberta" if self.pipe is not None else "lexicon_fallback"

    def predict(self, text):
        """Returns (label, confidence 0-1, {label: prob})."""
        if self.pipe is not None:
            out = self.pipe(text)
            if out and isinstance(out[0], list):
                out = out[0]
            legacy = {"LABEL_0": "negative", "LABEL_1": "neutral", "LABEL_2": "positive"}
            scores = {legacy.get(o["label"], o["label"].lower()): float(o["score"]) for o in out}
            label = max(scores, key=scores.get)
            return label, round(scores[label], 4), scores
        words = re.findall(r"[a-z']+", text.lower())
        n, p = sum(w in NEG for w in words), sum(w in POS for w in words)
        if n > p:
            label, conf = "negative", min(0.95, 0.6 + 0.1 * (n - p))
        elif p > n:
            label, conf = "positive", min(0.95, 0.6 + 0.1 * (p - n))
        else:
            label, conf = "neutral", 0.55
        return label, round(conf, 4), {label: conf}
