# Release must-have tasks

Check every item before the next release goes live.

## 1. Lock down `/my/public/file/<id>` (security, critical)

Today `/my/public/file/<id>` serves any attachment to anyone with the id (no login).
Signed v2 links replace it (backend commits `0b0fbc640`, `0ec98fbaa`, `37e81185d`, `1baafbf1d`, branch `elrace-addons`;
route map and test cases in `elrace_backend_apis/docs/SIGNED_FILE_LINKS_V2.md`).

- [x] Deploy the backend with `/api/v2/file_url`, `/public/v2/file/<id>/<exp>/<sig>` and the signed endpoint versions.
- [ ] Deploy the expiry-bucketing commit `1baafbf1d` (cache-friendly URLs).
- [x] App switched to signed endpoints + viewer/expiry/cache fixes, JWT removed from file URLs (tested on device, all cases passed).
- [ ] Ship the app build that installs `SignedFileHttpOverrides` (`lib/core/security/signed_file_links.dart`).
- [ ] Set a minimum app version / force update so old builds stop using `/my/public/file`.
- [ ] Hub links are tracked in section 2 below.
- [ ] Move the Odoo share/QR links (`elrace_s3_bucket` `get_share_url`, QR) to long-lived signed links. Confirm first.
- [ ] After most users are on the new app and the Hub (section 2) is done: restrict `/my/public/file/<id>` in **both** `elrace_backend_apis/controllers/public_controller.py` and `elrace_s3_bucket/controllers/aws_controller.py`. This changes an existing API, so get confirmation first.
- [ ] nginx rate limiting for public routes (still to be discussed).

## 2. Hub APIs (Hub developer, coordinate before changing)

- [ ] Secure the Hub export routes (`/api/hub/export/projects`, `users`, `employees`, `foremen`, `timesheets`, `signatures`, `departments`, `clearance`, and `/api/hub/partners`). They are currently reachable from the internet without credentials.
- [ ] Secure the Hub action routes (`/api/hub/clearance/action`, `/api/hub/users/update_rcchub_id`). They change data with no credentials.
- [ ] Move the Hub file links (`hub_common_widgets.py`, `hub_common_explorers.py`) from `/my/public/file/<id>` to signed v2 links.
- [ ] Hub developer confirms everything works before `/my/public/file` is restricted.

## 3. Module upgrade

- [ ] Upgrade `survey_question_user_group` (`-u survey_question_user_group`) so photo records no longer need a File URL.

## 4. Home widget API cleanup (after old builds retire)

- [ ] Deploy `total_count` in `elrace_backend_apis/services/lpo_widget_service.py` (additive; new app shows Total LPO in K/M from it).
- [ ] Deploy the database-paged `/api/v3/get_circular_announcement` (`services/circular_announcement_service.py`, adds `current_year_counters` and `category`). The new app pages 10 at a time and works against the old server too, but the HRMS badge falls back to downloading the full list until this is deployed.
- [ ] After old app builds are retired: remove `pending_count` / `approved_count` from the LPO widget payload. The installed app computes Total from them, so removing them now would show 0. Confirm first.

## 5. Rotate the mobile JWT secret (security, critical)

The old signing key `mySuperSecretKey123!` is in git, so anyone with repo access can forge a login token for any user.
`elrace_backend_apis/utils/jwt_keys.py` signs new tokens with a System Parameter and still accepts old tokens during the transition. No app change is needed and nobody is logged out.

- [ ] Deploy the backend with `utils/jwt_keys.py` (behaves exactly as before until the parameter is set).
- [ ] Generate a secret on the server (`python3 -c "import secrets; print(secrets.token_urlsafe(64))"`) and set System Parameter `elrace.mobile_jwt_secret` to it. Minimum 32 characters; never commit or share it. Note the date.
- [ ] 31+ days later (tokens live 30 days): set `elrace.mobile_jwt_accept_legacy` to `False`. Old-key tokens, including forged ones, are rejected from then on.
- [ ] Not covered, decide separately: the Hub client token (`elrace_web_hub_apis/services/hub_client_login_service.py`) and `pandora_rcchub_apis` QR login still use the old key. Check with the Hub developer whether the Hub verifies the client token itself before changing them.
