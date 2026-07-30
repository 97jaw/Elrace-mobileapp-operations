# Firebase deploy without App Engine (elrace-new)

## Why “Create App Engine application” fails

Common causes for **Failed to create GAE app**:

### 1. Firestore is in `me-central1` (very likely for this project)

Google’s docs state:

- **`me-central1` does not support App Engine.**
- If your **default Firestore** is already in `me-central1`, you **cannot** create App Engine in `asia-south1`, `europe-west1`, or any other region — locations must align, and App Engine is not offered in Doha.

**Check:** Firebase Console → **Firestore** → see database location (e.g. `me-central1`).

**Implication:** You may **never** get a classic App Engine app on this project if Firestore stays in `me-central1`. That is OK for **2nd gen Cloud Functions** (liveness callables).

### 2. APIs / billing / permissions

- [Enable App Engine Admin API](https://console.cloud.google.com/apis/library/appengine.googleapis.com?project=elrace-new)
- Firebase **Blaze** plan
- Your account: **Owner** or **Editor** on project `elrace-new`

### 3. Organization policies

Some orgs block App Engine or Cloud Build defaults. Ask GCP admin if creation fails with a policy error.

---

## What to do instead (recommended)

**Do not block on GAE** for Face Liveness or assignment FCM. Deploy Gen2 functions to **`asia-south1`** in isolated codebases:

```bash
# Face Liveness
firebase deploy --project elrace-new --only \
  functions:liveness:createFaceLivenessSession,functions:liveness:getFaceLivenessSessionResults

# Task / ticket assignment pushes
cd functions-assignment && npm install && cd ..
firebase deploy --project elrace-new --only \
  functions:assignment:onAssignedTodoCreated,functions:assignment:onAssignmentPushRequest,firestore:rules
```

Liveness lives in **`functions-liveness`** (`codebase: liveness`). Assignment FCM lives in **`functions-assignment`** (`codebase: assignment`). Both use **`asia-south1` only**.

The main **`functions`** folder still uses `me-central-1` for chat — do **not** deploy it until that region is fixed.

Flutter uses `kLivenessFunctionsRegion = 'asia-south1'`.

### Why `--only functions:createFace...` still hit me-central-1

Firebase analyzed the whole `functions/index.js` including `setGlobalOptions({ region: "me-central-1" })`. The separate **`liveness`** / **`assignment`** codebases avoid that.

Gen2 functions in `asia-south1` do **not** require an App Engine app (per Firebase: scheduled 1st gen / default bucket coupling — not applicable here).

---

## If deploy still fails

| Error | Action |
|-------|--------|
| 403 on `me-central-1` | Expected for global `setGlobalOptions`; liveness uses `asia-south1` only — use `--only` flags above. |
| 403 on `asia-south1` | Enable Cloud Functions, Cloud Build, Artifact Registry APIs; confirm Blaze billing. |
| Permission denied | IAM: grant your user **Cloud Functions Admin** + **Service Account User**. |
| Secrets | Re-run `firebase functions:secrets:set` for AWS keys; redeploy. |

---

## Optional: create GAE via CLI (only if Firestore allows)

If Firestore is **not** in `me-central1` (e.g. still uninitialized), you can try:

```bash
gcloud app create --region=asia-south1 --project=elrace-new
```

If Firestore is already `me-central1`, this will **fail** — skip GAE and use Gen2 deploy in `asia-south1` only.

---

## Regions summary (El Race)

| Service | Region | Notes |
|---------|--------|--------|
| Firestore (likely) | `me-central1` | No App Engine support |
| Firebase Functions (chat, etc.) | `me-central-1` | May need GAE workaround / support ticket |
| **Liveness callables** | **`asia-south1`** | Deploy target in repo |
| **Assignment FCM triggers** | **`asia-south1`** | `functions-assignment` codebase |
| AWS Rekognition Liveness | **`ap-south-1`** | Mumbai; set in Firebase secrets / `.env` |

---

## When to contact Google

If `asia-south1` deploy still returns 403 after Blaze + APIs + Owner role, open Firebase/GCP support with:

- Project ID: `elrace-new`
- Function names: `createFaceLivenessSession`, `getFaceLivenessSessionResults`
- Firestore location (from console)
- Full deploy log (redact secrets)
