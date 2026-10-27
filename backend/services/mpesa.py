"""Safaricom Daraja (M-Pesa Express / STK Push). Sandbox by default."""
import base64
import os
import time
from datetime import datetime, timedelta, timezone

import requests

EAT = timezone(timedelta(hours=3))


class Mpesa:
    def __init__(self):
        env = os.getenv("MPESA_ENV", "sandbox")
        self.base = "https://sandbox.safaricom.co.ke" if env == "sandbox" else "https://api.safaricom.co.ke"
        self.key = os.getenv("MPESA_CONSUMER_KEY", "")
        self.secret = os.getenv("MPESA_CONSUMER_SECRET", "")
        self.shortcode = os.getenv("MPESA_SHORTCODE", "174379")
        self.passkey = os.getenv("MPESA_PASSKEY", "")
        self.public_url = os.getenv("PUBLIC_BASE_URL", "").rstrip("/")
        self.cb_secret = os.getenv("MPESA_CALLBACK_SECRET", "change-me")
        self.mock = os.getenv("MPESA_MOCK", "false").lower() == "true"
        self._tok, self._exp = None, 0

    @property
    def mode(self):
        return "mock" if self.mock else os.getenv("MPESA_ENV", "sandbox")

    @property
    def callback_url(self):
        return f"{self.public_url}/api/mpesa/callback/{self.cb_secret}"

    def token(self):
        if self._tok and time.time() < self._exp:
            return self._tok
        r = requests.get(f"{self.base}/oauth/v1/generate?grant_type=client_credentials",
                         auth=(self.key, self.secret), timeout=20)
        r.raise_for_status()
        self._tok = r.json()["access_token"]
        self._exp = time.time() + 3300
        return self._tok

    def stk_push(self, phone, amount, account_ref, desc):
        ts = datetime.now(EAT).strftime("%Y%m%d%H%M%S")
        pwd = base64.b64encode(f"{self.shortcode}{self.passkey}{ts}".encode()).decode()
        payload = {
            "BusinessShortCode": self.shortcode, "Password": pwd, "Timestamp": ts,
            "TransactionType": "CustomerPayBillOnline", "Amount": int(amount),
            "PartyA": phone, "PartyB": self.shortcode, "PhoneNumber": phone,
            "CallBackURL": self.callback_url, "AccountReference": account_ref[:12], "TransactionDesc": desc[:13],
        }
        r = requests.post(f"{self.base}/mpesa/stkpush/v1/processrequest", json=payload,
                          headers={"Authorization": f"Bearer {self.token()}"}, timeout=30)
        if r.status_code >= 400:
            raise RuntimeError(f"Daraja error {r.status_code}: {r.text[:300]}")
        return r.json()
