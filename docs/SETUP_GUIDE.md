# Autocall - Setup Guide (Windows)

Work through the parts **in order**. Where you get stuck, copy the exact error message to Claude.

## 0. How the pieces fit together

```
 Google Colab (browser)            VS Code (your laptop)                         Phone
 -----------------------           ----------------------------------------      ----------------
 01 recommendation notebook  --->  backend\models\*.pkl  --\
 02 RoBERTa notebook         --->  backend\models\roberta_sentiment\ -> Flask API <--- Flutter app
                                                               |        (ngrok https URL)   (mobile\)
                                                               v
                                                      Firebase (Auth + Firestore)
```

* **Colab** only *trains*. It produces files. Nothing from Colab "runs" in your app - you download the files.
* **VS Code** is where you edit and run *everything* (Python backend, Flutter app, Git).
* **Android Studio** is only needed to supply the Android SDK (and optionally the emulator / Logcat).
  You do **not** have to open it day to day. Because you connected the same GitHub repo to both, just
  `git pull` in whichever one you open.
* The **app never talks to Colab**. It talks to your Flask backend, which loads the files Colab produced.

| Thing | Runs on | Command / action |
|---|---|---|
| Model training | Colab | Runtime > Run all |
| Backend | your laptop | `python app.py` (terminal 1) |
| Public URL for the phone + M-Pesa callback | your laptop | `ngrok http 5000` (terminal 2) |
| App | your phone (USB) | `flutter run ...` (terminal 3) |

---

## 1. Free up disk space and fix `flutter doctor` (without big downloads)

**Do not install an emulator** - system images are several GB. Use your real Android phone instead (Part 6).

Free space (aim for roughly 10 GB free before building):
1. Settings > System > Storage > **Temporary files** (tick Recycle bin, Downloads you don't need, Delivery Optimization) > Remove.
2. Settings > System > Storage > **Storage Sense** > Run now.
3. If an Android emulator image exists, delete `%LOCALAPPDATA%\Android\Sdk\system-images` and `%USERPROFILE%\.android\avd`.
4. Your repo sits in **OneDrive** (`...\OneDrive\Desktop\Autocall`). OneDrive syncing thousands of build files is slow and
   can break Flutter builds. Keep the project in `C:\dev\Autocall` instead (see Part 2).
5. Later, `flutter clean` frees the app's `build/` folder, and `%USERPROFILE%\.gradle\caches` can be cleared if you are desperate.

**Fix "cmdline-tools component is missing" manually (about 150 MB, no Android Studio needed):**
1. Run `flutter doctor -v` and note the line `Android SDK at ...` (usually `C:\Users\mercy\AppData\Local\Android\Sdk`).
2. Download **"Command line tools only"** for Windows from https://developer.android.com/studio#command-line-tools-only
3. Unzip it. You get a folder `cmdline-tools` containing `bin`, `lib`... Create this exact structure:
   `...\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat` (i.e. rename the unzipped inner content to `latest`).
4. In PowerShell:
   ```powershell
   flutter config --android-sdk "C:\Users\mercy\AppData\Local\Android\Sdk"
   flutter doctor --android-licenses     # press y (then Enter) for each prompt
   flutter doctor
   ```
5. Ignore the *Visual Studio / Windows 10 SDK* warning - it is only for Windows desktop apps, not Android.

---

## 2. Put the project in your Git repo

```powershell
cd C:\dev
git clone https://github.com/<your-username>/<your-repo>.git Autocall
```
Unzip `autocall_project.zip` and copy **everything inside it** into `C:\dev\Autocall` (so you see `backend`, `colab`, `data`, `docs`, `mobile`, `firestore.rules`...).
```powershell
cd C:\dev\Autocall
git add .
git commit -m "Add Autocall implementation"
git push
```
The included `.gitignore` keeps secrets (`.env`, `serviceAccountKey.json`) and the big trained models out of GitHub.
Open the folder in VS Code: **File > Open Folder > C:\dev\Autocall**. In Android Studio you may later open `C:\dev\Autocall\mobile`.

---

## 3. Train the models in Google Colab

1. Go to https://colab.research.google.com > **File > Upload notebook** > choose `colab\01_recommendation_model.ipynb`.
   (Or *File > Open notebook > GitHub* and paste your repo URL if the repo is public.)
2. **Runtime > Run all.** When the upload box appears choose `data\autocall_recommendation_dataset.csv`.
3. At the end a file `recommendation_export.zip` downloads. Unzip it into `C:\dev\Autocall\backend\models\`:
   you should now have `recommendation_model.pkl`, `recommendation_scaler.pkl`, `model_info.json` (and some `fig_*.png`).
   Move the `fig_*.png` files to `docs\figures\` - they are your Chapter 5 figures.
4. Open `colab\02_roberta_sentiment.ipynb` the same way. **Before running:** Runtime > Change runtime type > **T4 GPU**.
   Run all; upload `data\autocall_nlp_reviews_dataset.csv` **and** `data\autocall_nlp_challenge_set.csv` when asked.
   If Colab says "restart session" after the install cell, restart and Run all again.
5. Download `roberta_export.zip` (a few hundred MB) and unzip into `backend\models\` so that this exists:
   `backend\models\roberta_sentiment\config.json` (+ `model.safetensors`, tokenizer files).
   Move its `fig_*.png` and `sentiment_info.json` to `docs\figures\`.
6. **Copy the printed numbers** (MAE, R2, tier accuracy, F1, challenge-set results) - they fill your Chapter 5 tables.

> The models are optional for first run: without the files the backend falls back to a rule-based scorer and a keyword
> sentiment checker (`/api/health` tells you which mode it is in). Real RoBERTa serving needs ~2 GB for `torch`
> (Part 5, step 4). If disk is tight, finish everything else first and add RoBERTa last.

---

## 4. Firebase console setup (one time, free Spark plan)

1. https://console.firebase.google.com > **Add project** > name `autocall` (Analytics optional).
2. **Build > Authentication > Get started > Sign-in method**: enable **Email/Password**, **Phone**, **Google** (choose a support email).
   * Phone: under *Phone numbers for testing* add a fake number (e.g. `+254 700 000 000`, code `123456`) so you can test without real SMS.
     Real SMS on the free plan has a small daily quota.
3. **Build > Firestore Database > Create database** > Production mode > pick the nearest region you are offered.
4. Firestore > **Rules** tab: paste the whole content of `firestore.rules` > **Publish**.
5. **Project settings (gear) > Service accounts > Generate new private key** > save the JSON as
   `C:\dev\Autocall\backend\serviceAccountKey.json`. **Never commit or share it.**

---

## 5. Backend (Flask)

```powershell
cd C:\dev\Autocall\backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1          # if blocked:  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
pip install -r requirements.txt
copy .env.example .env                # then edit .env in VS Code
python -m pytest -q tests             # 8 unit tests should pass
python scripts\benchmark.py          # latency + route + 'vs nearest mechanic' tables for Chapter 5 (needs internet for routes)
```

1. **Seed demo mechanics around where you are testing.** Get your coordinates (Google Maps > long-press > copy lat,lng), then:
   ```powershell
   python scripts\seed_firestore.py --lat -1.2921 --lng 36.8219
   ```
   *Optional - real Kenyan garages from OpenStreetMap (free, no key):*
   ```powershell
   python scripts\fetch_osm_garages.py --nairobi
   python scripts\seed_firestore.py --osm ..\data\osm_kenya_garages.csv
   ```
2. **Run it:** `python app.py` and open http://localhost:5000/api/health - you should see `"status":"ok"`.
3. **M-Pesa Daraja:**
   * https://developer.safaricom.co.ke > create account > **My Apps > Add a new app** > tick *Lipa Na M-Pesa Sandbox* >
     copy **Consumer Key / Secret** into `.env`.
   * Under **APIs > M-Pesa Express (STK Push) > Simulate** copy the sandbox **Passkey**; shortcode is `174379`.
   * Install ngrok (free account), then in a **second terminal**: `ngrok config add-authtoken <token>` and `ngrok http 5000`.
     Copy the `https://....ngrok-free.app` URL into `PUBLIC_BASE_URL` in `.env`, set a long random `MPESA_CALLBACK_SECRET`, and restart `python app.py`.
   * The sandbox *simulates* the customer - a real phone does not get a PIN prompt, and sandbox callbacks are sometimes slow.
     For demos or when Daraja misbehaves set `MPESA_MOCK=true` (the payment succeeds after 6 s). State in your report which mode produced which evidence.
4. **RoBERTa serving (only if you have ~2 GB free):**
   ```powershell
   pip install torch --index-url https://download.pytorch.org/whl/cpu
   pip install -r requirements-ml.txt
   ```
   Restart the backend: `/api/health` should now show `"sentiment":"roberta"`.

---

## 6. Flutter app

**6.1 Create the Android project and drop my code in** (PowerShell, from `C:\dev\Autocall`):
```powershell
Rename-Item mobile mobile_src
flutter create --org com.autocall --project-name autocall --platforms=android mobile
Copy-Item mobile_src\pubspec.yaml mobile\pubspec.yaml -Force
Remove-Item mobile\lib -Recurse -Force
Copy-Item mobile_src\lib mobile\lib -Recurse
Remove-Item mobile\test -Recurse -Force
Remove-Item mobile_src -Recurse -Force
cd mobile
flutter pub get
```

**6.2 Connect Firebase:**
```powershell
firebase login
dart pub global activate flutterfire_cli      # if 'flutterfire' is not found afterwards, add %LOCALAPPDATA%\Pub\Cache\bin to PATH
flutterfire configure --platforms=android     # choose your autocall project, package com.autocall.autocall
```
This creates `lib\firebase_options.dart` (the app will not compile without it).

**6.3 Permissions.** Open `mobile\android\app\src\main\AndroidManifest.xml` and add these *above* `<application ...>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<queries>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="sms"/></intent>
</queries>
```

**6.4 SHA-1 fingerprint (needed for Google and Phone sign-in).** Run the app once (6.5) so `debug.keystore` exists, then:
```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```
(If Android Studio lives elsewhere use any `keytool.exe` from a JDK.) Copy **SHA1** and **SHA-256** into
Firebase > Project settings > Your apps > Android app > **Add fingerprint**, then run `flutterfire configure --platforms=android` again.

**6.5 Run on your phone (no emulator):**
1. Phone: Settings > About phone > tap **Build number** 7 times > Developer options > **USB debugging** on. Plug in, accept the prompt.
2. `flutter devices` should list it. Then:
   ```powershell
   flutter run -d <device-id> --dart-define=BACKEND_URL=https://<your-ngrok-url>.ngrok-free.app
   ```
   (Using the ngrok https URL means the phone can reach your laptop from any Wi-Fi/mobile data.)
3. In VS Code you can store this once in `.vscode\launch.json`:
   ```json
   { "version": "0.2.0", "configurations": [ { "name": "Autocall", "request": "launch", "type": "dart",
     "cwd": "mobile", "args": ["--dart-define=BACKEND_URL=https://<your-ngrok-url>.ngrok-free.app"] } ] }
   ```
   The ngrok URL changes every time you restart ngrok on the free plan - update `.env` (backend) **and** this value.

**6.6 Create the three roles**
* **Admin:** register normally in the app, then `python scripts\seed_firestore.py --make-admin you@email.com`; sign out and in.
* **Mechanic:** register choosing *I am a mechanic* > on the Home tab tap **Submit verification details** (National ID number 7-8 digits,
  ID photo, optional registration/certification) > log in as admin > Dashboard > *Pending Verifications* > Review > Approve.
  Log in as the mechanic again and switch **online** (this shares GPS). On an accepted job, the **Jobs** tab shows the route to the motorist.
* **Notifications:** the bell icon (motorist and mechanic Home) shows unread counts; a banner appears when a new one arrives.
* **Motorist:** register normally > Home > Request a Mechanic > pick a problem > Find a Mechanic > Request.
* With one phone, switch accounts via Profile > Sign out. With a second phone you can watch live tracking between two devices.

**6.7 Dark mode:** Profile tab > Appearance > Light / Dark / System (remembered between launches).

### Where Android Studio fits
* Needed once for the SDK. After that, VS Code + the terminal is enough.
* Open `mobile\` in Android Studio if you want Logcat (filter by `flutter`) or Device Manager. It uses the same files - `git pull` keeps both in sync.
* If a Gradle error appears, open `mobile\android` in Android Studio and let it sync - the error message is easier to read there.

---

## 7. Daily workflow
1. Terminal 1: `cd backend; .\.venv\Scripts\Activate.ps1; python app.py`
2. Terminal 2: `ngrok http 5000` (new URL? update `.env` + restart backend + `--dart-define`)
3. Terminal 3: `cd mobile; flutter run -d <id> --dart-define=BACKEND_URL=...`
4. Commit often: `git add . ; git commit -m "..." ; git push` (this is also your Chapter 5.5 evidence).

## 8. Quick troubleshooting
| Symptom | Likely cause / fix |
|---|---|
| App says "Could not reach the Autocall server" | Backend/ngrok not running, or `--dart-define=BACKEND_URL` is stale |
| Recommended list is empty | No *verified + online* mechanics within 30 km: re-run the seed with your `--lat/--lng` |
| `PERMISSION_DENIED` in the app | Firestore rules not published, or you are not logged in as the right role |
| Google sign-in fails (error 10 / 12500) | SHA-1 missing in Firebase, or `google-services.json` not refreshed |
| Phone OTP never arrives | Use a *test phone number* from Firebase console, or check SHA-1 |
| "The query requires an index" | Tell Claude the exact message - queries were written to avoid indexes |
| M-Pesa stays "waiting" | Sandbox callback delay: check the backend log for `Daraja callback`, or use `MPESA_MOCK=true` |
| `flutter pub get` conflicts | Paste the output to Claude (package versions move) |
