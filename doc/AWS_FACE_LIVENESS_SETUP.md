# AWS Face Liveness (hybrid anti-spoof Step 2)

## Architecture

1. **On-device** — Dual MiniFASNet + temporal heuristics (multi-frame 4/5).
2. **AWS** — `createFaceLivenessSession` / `getFaceLivenessSessionResults` Firebase callables → Rekognition in **`ap-south-1`**.
3. **Capture** — Allowed only when both tiers pass; shutter re-checks MiniFASNet.

## Firebase Functions

Set environment variables before deploy:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION` = `ap-south-1` (Face Liveness is **not** in `me-central-1`)

**Liveness callables** deploy to **`asia-south1`** (Gen2 — **no App Engine required**). Other functions may stay `me-central-1`. Rekognition uses **`ap-south-1`**.

See **`doc/FIREBASE_GAE_AND_DEPLOY.md`** if App Engine creation fails (common when Firestore is `me-central1`).

### If deploy fails with 403

1. **Skip App Engine** for liveness — deploy with `--only` (see below).
2. Confirm **Blaze** billing on `elrace-new`.
3. Enable APIs: Cloud Functions, Cloud Build, Artifact Registry, Secret Manager.
4. Redeploy; Flutter region must match `LIVENESS_FUNCTIONS_REGION` in `functions/index.js` (`asia-south1`).

### Set secrets (project `elrace-new`)

```bash
cd functions && rm -rf node_modules && npm install
firebase login
firebase use elrace-new

firebase functions:secrets:set AWS_ACCESS_KEY_ID
# paste IAM access key when prompted

firebase functions:secrets:set AWS_SECRET_ACCESS_KEY
# paste IAM secret when prompted

firebase functions:secrets:set AWS_REGION
# enter: ap-south-1

cd functions-liveness && npm install && cd ..
firebase deploy --only functions:liveness:createFaceLivenessSession,functions:liveness:getFaceLivenessSessionResults
```

Without secrets, callables return `mock_mode: true` for local/tablet testing.

## Production client (mobile)

`TmAwsFaceLivenessScreen` uses **`face_liveness_detector`** (native AWS oval UI) + Firebase `getFaceLivenessSessionResults` after completion.

**Required once per environment:** Cognito Identity Pool + Amplify JSON — see **`doc/AWS_COGNITO_AMPLIFY_SETUP.md`** and run `./scripts/copy_amplify_liveness_config.sh`.

## Policy

- Check-in is **blocked** on spoof, low AWS confidence, or cancelled AWS step.
- No `flagged` pass-through after failed ML Kit challenges (challenges removed).
