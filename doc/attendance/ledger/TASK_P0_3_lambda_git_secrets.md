# TASK P0_3 — Lambda under git, credentials out of code

Folder `~/projects/biotime_lambda`.

## Before starting (user)

Rotate the Odoo password of the Lambda's Odoo user — it is visible in `odoo_client.py` (default value
and docstring). Put the new value only in the Lambda environment variable `ODOO_PASSWORD` (or AWS
Secrets Manager). Confirm `ODOO_URL`, `ODOO_DB`, `ODOO_USER` are also set as env vars on the function.

## Steps

1. The root `.py` files are an old copy (2 Apr). The deployed code (4 Nov) is in `deployed_2026-11-04/`.
   Move the four old root files into `archive_2026-04-02/` and copy the four files from
   `deployed_2026-11-04/` to the root. Keep `deployed_2026-11-04/` as is (reference).
2. Add `.gitignore`: vendored packages and build output — `bin/`, `certifi*/`, `charset_normalizer*/`,
   `idna*/`, `pytz*/`, `requests*/`, `urllib3*/`, `*.so`, `__pycache__/`, `.DS_Store`, `*.zip`.
   Keep `requirements.txt` tracked.
3. In `odoo_client.py`:
   - Remove the credentials from the module docstring.
   - `ODOO_USER`, `ODOO_PASS`, `ODOO_DB` read from env with NO default (`os.environ.get("ODOO_PASSWORD")`).
     `_get_session()` already raises a clear error when one is missing — keep that.
   - `ODOO_URL` may keep `https://erp.elrace.com` as default.
4. `git init`, branch `main`, first commit: "chore: deployed Lambda code of 2026-11-04".
   Make sure no password string is in any committed file (`git grep -n "Odoo@"` returns nothing).

## Done when

- `git log` on `main` has one commit with the deployed code; credentials only in env.
- Deploying `main` to the Lambda (zip with vendored packages, as today) behaves exactly as before.
