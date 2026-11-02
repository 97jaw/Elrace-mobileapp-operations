# Firebase rules deploy

Rules are deployed only from `main`, after the pull request is merged. Do not deploy from a feature branch.

```bash
git checkout main
git pull origin main
firebase deploy --only firestore:rules,storage,database --project elrace-new --non-interactive
```

This publishes Firestore rules, Storage rules, and the Realtime Database rules. It does not deploy Cloud Functions.
