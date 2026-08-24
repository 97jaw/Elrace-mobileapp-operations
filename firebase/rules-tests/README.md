# Firebase security rules tests

Hub Phase 2 acceptance harness (membership, spoofing, signing, RTDB payloads, Storage paths).

## Prerequisites

- Java **21+** (`export JAVA_HOME=...`)
- Firebase CLI
- `npm --prefix firebase/rules-tests install`

## Run

From repo root:

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
firebase emulators:exec --project elrace-new --only firestore,database,storage \
  "npm --prefix firebase/rules-tests test"
```

## Fingerprints (after rule changes)

```bash
shasum -a 256 firestore.rules database.rules.json storage.rules
```
