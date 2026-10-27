# Autocall - Document vs Build alignment (checked against your current .docx)

I re-read your document (Chapters 1-6 as it stands now) and changed the **code** to match it wherever I could.
Only a small number of **wording** edits remain in the document; they are listed in section 3.

## 1. Requirement-by-requirement check (Table 2 and Table 4 in your document)

| ID | Requirement (your wording, shortened) | Status in the build | Where / how to show it |
|---|---|---|---|
| FR1 | Motorists and mechanics create accounts | Done | Register screen (email, phone OTP, Google; role choice) |
| FR2 | Log in / log out | Done | Login screen; Profile > Sign out |
| FR3 | Role-based functions (motorist / mechanic / admin) | Done | `AuthGate` routes by role + Firestore rules |
| FR4 | Mechanic professional profile | Done | Register (business name, specialisation, experience), mechanic doc |
| FR5 | Submit identity, certification, registration for verification | **Done** (new) | Mechanic Home > *Submit verification details*: National ID no., registration/licence no., certification, ID photo + certificate photo -> `Verifications` collection |
| FR6 | Obtain and share motorist location | Done | Request form + Home map (GPS, reverse-geocoded area name) |
| FR7 | Mechanic availability | Done | Online/offline switch on Mechanic Home |
| FR8 | Service request with problem description | Done | "What's wrong with your vehicle?" screen |
| FR9 | Identify and rank mechanics (proximity, rating, availability, response time, history) | Done | `POST /api/recommend` (Random Forest score); unavailable/unverified/suspended are excluded |
| FR10 | View mechanic profile before selecting | Done | Recommended list > Profile |
| FR11 | Mechanic accepts or rejects | Done | Accept / Decline (status `declined` = "reject") |
| FR12 | Status updated through the process | Done | pending > accepted > enRoute > arrived > inProgress > completed > paid |
| FR13 | GPS tracking during active request | Done | Mechanic location stream while online/on a job; motorist sees live marker |
| FR14 | Route information so mechanics reach motorists | **Done** (new) | Mechanic Jobs tab: route map, km/minutes, "Open in maps app" (`/api/route` via backend; straight-line fallback if routing is down) |
| FR15 | Notify motorists and mechanics of important changes | **Done in-app** (new) | `Notifications` collection, bell with unread badge, notification centre, instant banner. **Not** FCM push (see 4) |
| FR16 | Service history | Done | History tab (motorist), Completed jobs (mechanic) |
| FR17 / FR18 | Ratings / written reviews | Done | Review screen -> `POST /api/reviews` |
| FR19 | NLP classifies sentiment | Done | RoBERTa (or labelled fallback) in the backend |
| FR20 | Negative reviews flagged for admin | Done | Flag rule below; Admin > Reviews |
| FR21 | Initiate M-Pesa payment | Done | Pay with M-Pesa (STK push, sandbox or mock) |
| FR22 | Payment records and status | Done | `Payments` collection: reference/receipt, amount, status, date |
| FR23 | Admin monitors users, mechanics, requests, verification records, flagged reviews | **Done** (Users list added) | Admin Dashboard tiles, Users list, Mechanics (verification review with photos), Requests, Reviews |
| NFR1 | Role-restricted access | Done | `firestore.rules` + role gate. Test with two accounts |
| NFR2 | Privacy of personal/location/payment data | Done | Rules: users read only their own requests/payments/notifications; verification evidence readable by owner + admin only |
| NFR3 | Response-time evaluation | **Evidence tooling added** | Every API call returns `X-Response-Time-ms` and logs it; run `python scripts/benchmark.py` for model latency tables |
| NFR4 | Consistent data; no incomplete transaction when an external service fails | **Done** (new) | Review + rating update + notification are ONE Firestore transaction; payment success (payment record + request status + mechanic stats + notifications) is ONE transaction; a payment record is created only after Daraja accepts the request |
| NFR5 | Availability when internet/third-party services are up | Done | Errors surface as messages; routing degrades to a direct line |
| NFR6 | Role-specific interfaces | Done | Three shells |
| NFR7 | Modular components | Done | app / backend / ml / services folders |
| NFR8 | Android | Done | Android only |
| NFR9 | Predefined model measures | Done | Notebooks print them |
| NFR10 | Flagged reviews go to a human, no automatic action | Done | Admin chooses Take Action / Review / Dismiss |

**Flag rule (FR20):** *high priority* = sentiment "negative" with confidence >= 0.70. Extra low-priority flags (negative below 0.70, neutral with rating <= 3, positive with rating <= 2) appear as "Low priority" because your own admin wireframe shows a "Mixed sentiment - Low priority" card. FR20 (negative -> flag) is fully covered.

## 2. Names that now match your document exactly
Firestore collections: **Users, Mechanics, ServiceRequests, Reviews, Payments, Notifications, Verifications** (your Figure 6 caption lists "Verification records"; your ERD text does not - add a *Verifications* entity to the ERD: one mechanic - one verification record).
Data requirements: every field listed in your "Data Requirements" paragraph is stored (user name/email/phone/role; mechanic specialisation, experience, availability, verification information, ratings, response-time records; request motorist/mechanic/description/GPS/time/status; review text/rating/sentiment/flag status; payment reference/amount/status/date).
Email is collected for phone/Google sign-ups that have none (complete-profile screen), so "email address" is always stored.

## 3. Edits to make in the document (wording only)

**3a. Maps - the one real decision for you and your supervisor.** Your document names *Google Maps API* in 14 places (lines in the .docx: abstract/tools list 185, limitations 485, 3.5.4 heading + text 719-721, Table 1 row 758, Roadside module 789, Interfaces 893, use-case text 941, architecture 1073 and 1079, Chapter 5 intro 1089, environment 1099, 1115, Table 7 row 1129, deployment 1142, integration path 1473).
The build uses the **free OpenStreetMap stack** because you asked earlier for a map service that needs no billing details. Google Maps would need a Google Cloud project with a billing account (even though its monthly free credit normally covers a student project).
*Recommended:* keep OSM and apply the replacements below. *If your supervisor insists on Google Maps*, tell me and I will swap the map/route/geocode layer (Maps SDK key + Directions + Geocoding) - it is one contained change.

| Find | Replace with |
|---|---|
| "Google Maps API" / "Google Maps services" / "Google maps API Services" | "OpenStreetMap-based map services (OSM map tiles, OSRM routing and Nominatim geocoding)" |
| 3.5.4 "Google Maps API" paragraph | "OpenStreetMap services will provide the map display, reverse geocoding and driving-route estimates. Map tiles are rendered in the Flutter application with the flutter_map package; routes and place names are requested through the Flask backend from the OSRM and Nominatim services. These services are free and require no API billing account, but are subject to fair-use policies." |
| Table 1, Tool 4 "Google Maps API / Location tracking & routing" | "OpenStreetMap (flutter_map, OSRM, Nominatim) / Map display, location names & routing" |
| Table 7 "Google maps API Services" | "OpenStreetMap services (flutter_map x.y.z; OSRM public API; Nominatim)" - fill the flutter_map version from `pubspec.lock` |
| Limitations: "Google Maps API and Safaricom Daraja API ... associated costs" | "OpenStreetMap public services (OSRM, Nominatim) and the Safaricom Daraja API ... usage limitations" (+ add: public OSM servers have fair-use limits and no uptime guarantee) |
| Interfaces: "Google Maps API shall provide GPS location services, nearby mechanic discovery, route visualization and navigation support" | "GPS location is obtained from the device; the Flask backend shall obtain routes and place names from OpenStreetMap services (OSRM, Nominatim) and the application shall display them on an OpenStreetMap map. Nearby-mechanic discovery is performed by the backend using Firestore data and great-circle distance." |
| Use case / architecture text "Google Maps" | "OpenStreetMap services (OSRM, Nominatim)" |
| Integration path "Flask Backend <-> Google Maps Services" | "Flask Backend <-> OpenStreetMap services (OSRM, Nominatim)" - **this path exists in the build**: `/api/route` and `/api/geocode/reverse` |
| Abstract / keywords | add "OpenStreetMap" |
| Route Optimization technique (3.5) "minimize travel distance" | "obtain the fastest driving route and estimated travel time from the OSRM routing service; the system does not implement its own routing algorithm" (consistent with your delimitation) |

**3b. Typos and numbering found in your document**
* Table 4 IDs **NRF5-NRF10 should be NFR5-NFR10** (rows 872-877).
* "Table 3 Table of functional requirements" is an empty table (line 853) - delete it or move FR rows there.
* Section 5.2.1 says "Table 5.1" but the table is **Table 6**.
* Table 5 (traceability) lists only FR1-FR23, NFR1 and NFR10 - add NFR2-NFR9 rows (see section 1 above).
* Chapter 4 intro lists the ERD entities without *Verifications*; the class diagram has *Verification* - make them consistent.
* Mechanic Verification technique (Ch. 3) says "submitted identification documents, certifications and registration details" - this is now true (photos + numbers).

**3c. Statuses for "Notifications and Service Request Monitoring" (Chapter 5)**
Implemented values: `pending -> accepted -> enRoute -> arrived -> inProgress -> completed -> paid`, plus `declined` (mechanic rejects) and `cancelled` (motorist cancels). Your example sequence omitted *inProgress* and *paid*.

**3d. Recommendation scoring (Chapter 5 asks for formula, weights and normalisation)**
Printed by the notebook: proximity max(0,1-km/20)x25; rating (r/5)x30; response max(0,1-min/60)x20; availability x15; history min(jobs/200,1)x10; MinMax scaling fitted on the training split; Random Forest regressor learns this 0-100 score from 1,000 synthetic records. Production adds: only verified + available + not-suspended mechanics, +5 if specialisation matches, neutral rating 3.5 for unrated mechanics.
Baseline comparison (your Table 12 note): notebook cell "Ranking test" - Random Forest vs nearest-mechanic vs highest-rating vs random on 500 simulated requests (in my run the Random Forest picked the best mechanic 81.4% of the time versus 24.6% for nearest-mechanic; **re-run and quote your own numbers**).
Honest note: a plain linear regression scored slightly *better* than the Random Forest on MAE, because the synthetic labels come from a near-linear rubric. Say so.
Table 12 scenario 3 (unavailable): the implementation **excludes** unavailable mechanics before scoring (the notebook still prints what the model would score).

## 4. Where the build is still weaker than the document - decide, then word it honestly
1. **Push notifications (FCM) are not implemented.** FR15 says "notify"; the build notifies **in the app in real time** (bell, badge, banner) while the app is open or running. A push to a closed app needs Firebase Cloud Messaging (I can add it: extra package, Android 13 notification permission, and a backend call). Until then write "real-time in-app notifications".
2. **Verification photos are stored inside Firestore** (compressed, <= ~380 KB each) because Firebase Cloud Storage now requires a billing plan on new projects. Fine for a prototype; state it as a limitation.
3. **Payments are sandbox/mock only.** Your Chapter 5 already says sandbox results are not production evidence - keep that wording and say which mode produced each screenshot.
4. **Synthetic data** (see below) - keep your limitation paragraph and make it explicit.
5. **One active request per motorist; Android only; no automated UI tests.**
6. The Chapter 4 **diagrams** (use case, ERD, class, schema, architecture, wireframes) must be re-checked against the build: add *Verifications* + OTP/Google sign-in + notifications; show OpenStreetMap services instead of Google Maps; add the dark theme and phone-OTP / complete-profile / verification / notification screens to the wireframes you show.

## 5. Chapter 5 evidence you still must produce (nothing here can be invented)
* **Table 6 / 7:** laptop specs, phone model + Android version, internet type; versions from `flutter --version`, `dart --version`, `python --version`, `pip freeze` (Flask, firebase-admin, scikit-learn, transformers/torch), `pubspec.lock`, Firebase plan/region, Daraja sandbox, Git version.
* **Figure 5.1:** screenshot of your Firebase console showing the 7 collections.
* **Table 8 (dataset):** Name *Autocall Automotive Service Reviews (synthetic)*; Source: author-written seeds + template generation (`data/generate_datasets.py`) + 45 hand-written challenge reviews; Records 900 (+45); Language English with a few Swahili/Sheng phrases; Labels negative/neutral/positive (balanced, 300 each); Format CSV; Licence: author's own work. Split 70/15/15 stratified = 630 / 135 / 135.
* **Table 9:** accuracy, precision, recall, F1 + confusion matrix from the RoBERTa notebook - report **both** the test split and the challenge set (and the TF-IDF baseline).
* **Table 11 (TC-001..012):** run each test, record actual result and Pass/Fail honestly. TC-008 route, TC-010 flagging and TC-011 payment should state which mode ran (`/api/health`).
* **Table 12:** the notebook scenarios + ranking test. **Table 13:** `python scripts/benchmark.py` (route rows need your internet).
* **NFR3 performance:** the `X-Response-Time-ms` header / backend log lines + the benchmark table; state the workload (e.g. 50 mechanics) and device.
* **Usability evaluation:** real participants and tasks (your seven listed tasks) - not provided by the build.
* **Author oversight / AI declaration:** your section exists - add what Claude produced (code, datasets, notebooks, draft diagrams) and how you verified it; keep the AI-use log required by the Chapter 4 guidance.

## 6. Dataset honesty (Chapter 3.2 / 4 Data requirements / 5)
All three datasets are **synthetic**. Recommendation: 1,000 rows labelled by the weighted rubric (+noise). Reviews: 80 hand-written seeds + generated template sentences. Mechanics: 40 *fictional* demo garages (no phone numbers) plus optional real garage names/locations from OpenStreetMap with **no invented ratings**.
Do not call any of it "real" or "collected". The test-split NLP score will be optimistic; the hand-written challenge-set score is the realistic one. Privacy: users accept a consent statement; you still need to write the Terms/Privacy text (Kenya Data Protection Act, 2019) and say how long data is kept.
