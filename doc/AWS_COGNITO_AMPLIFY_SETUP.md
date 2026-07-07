# Cognito + Amplify config for Face Liveness (mobile)

The tablet must run **StartFaceLivenessSession** via the native AWS widget. Firebase only creates the session; Cognito gives the device credentials to stream video.

## 1. Create Cognito Identity Pool (`ap-south-1`)

1. AWS Console → **Amazon Cognito** → **Identity pools** → **Create identity pool**.
2. Name: `elrace-face-liveness`.
3. Region: **Asia Pacific (Mumbai) `ap-south-1`** (same as Rekognition Face Liveness).
4. Enable **Guest access** (unauthenticated identities) if workers do not sign in with Cognito User Pool.
5. Create pool and note **Identity pool ID** — copy exactly from the console, e.g. `ap-south-1:24ab6a72-d19a-4d9a-9c22-faa230205a52`. **Do not** prefix `ap-south-1:` again in JSON (wrong: `ap-south-1:ap-south-1:...`).

## 2. IAM policy on the unauthenticated role

Cognito creates a role like `Cognito_elrace-face-livenessUnauth_Role`.

### Use the JSON tab (avoids “No resources are specified”)

In IAM → **Roles** → open the **unauthenticated** role → **Add permissions** → **Create inline policy** → switch to **JSON** and paste:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "FaceLivenessStart",
      "Effect": "Allow",
      "Action": "rekognition:StartFaceLivenessSession",
      "Resource": "*"
    }
  ]
}
```

Name the policy e.g. `ElRaceFaceLivenessStart` → **Create policy**.

### Why the visual editor complains

The **visual** policy builder often requires you to pick a resource type. `StartFaceLivenessSession` has no bucket-like ARN to pick in the UI — **`"*"` is correct** for this action (AWS Rekognition liveness client flow). The JSON policy above is the supported approach.

Do **not** add `CreateFaceLivenessSession` or `GetFaceLivenessSessionResults` to this role — those stay on the **Firebase** IAM user only.

Backend IAM user (Firebase secrets) keeps **Create** + **Get** only — do not put those keys in the app.

## 3. Amplify config files in the Flutter project

```bash
cp config/amplify/amplifyconfiguration.json.example config/amplify/amplifyconfiguration.json
cp config/amplify/awsconfiguration.json.example config/amplify/awsconfiguration.json
# Edit both — set PoolId to your identity pool ID (ap-south-1:xxxx)
./scripts/copy_amplify_liveness_config.sh
cd ios && pod install && cd ..
flutter pub get
```

**iOS:** `Amplify.configure()` runs at app launch in `AmplifyLivenessBootstrap.swift`. Config must exist at `ios/Runner/amplifyconfiguration.json` (copy script writes it and Xcode bundles it).

**Android:** Plugin calls `Amplify.configure()` automatically; config in `res/raw/amplifyconfiguration.json`.

1. Step 1 on-device PAD passes.
2. Step 2 opens **AWS oval / liveness UI** (not just a button).
3. After challenge, logs should show `status=SUCCEEDED`, `confidence` ≥ 80.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `conf=0.0` right after tap | Native UI not run — complete Cognito + copy config |
| Native error on launch | Wrong PoolId/region; Pool must be `ap-south-1` |
| Access denied on Start | Add `rekognition:StartFaceLivenessSession` to **unauth** role |
| Still IN_PROGRESS | Wait for poll; move face in oval, good lighting |
| iOS crash: `Authentication category is not configured` | Run `./scripts/copy_amplify_liveness_config.sh`, rebuild; `Amplify.configure()` runs at launch in `AmplifyLivenessBootstrap.swift` |
