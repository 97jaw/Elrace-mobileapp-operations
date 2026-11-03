# Notification check

Read-only checks against production Odoo. The script never calls create, write, or unlink.

Credentials come from the environment. `ODOO_API_KEY` is an RPC API key, not a password. It is never printed and never committed.

```bash
cd tools/notify_check
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
export ODOO_URL=https://erp.elrace.com
export ODOO_DB=your-database
export ODOO_LOGIN=you@elrace.com
export ODOO_API_KEY=your-rpc-api-key
PYTHONPATH=. .venv/bin/python -m notify_check check-config
PYTHONPATH=. .venv/bin/python -m notify_check check-render
PYTHONPATH=. .venv/bin/python -m notify_check check-events --since 24h --include-shadow
PYTHONPATH=. .venv/bin/python -m notify_check report
```

`report` writes `out/notify_check.md` and `out/notify_check.json`. Exit code 0 means every check passed.

Offline rule tests (no Odoo):

```bash
PYTHONPATH=. .venv/bin/python -m unittest discover -s tests
```

`check-render` calls `elrace.notify.type.preview`, which is added in notif(B16). Until that module update is installed on the server, preview is absent and check-render fails closed. check-config still compares the types that are already there. A missing `shadow` column is reported once.
