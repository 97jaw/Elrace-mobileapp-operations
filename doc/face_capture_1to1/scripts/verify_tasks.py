#!/usr/bin/env python3
"""Local verification runner for the face-capture 1:1 tasks.

Usage
    python3 doc/face_capture_1to1/scripts/verify_tasks.py            # all tasks
    python3 doc/face_capture_1to1/scripts/verify_tasks.py 01         # one task
    python3 doc/face_capture_1to1/scripts/verify_tasks.py 01 07      # several

The script asks for the Odoo base URL, database, login, password and a
device id, logs in through POST /api/login/new to get a Bearer token, then
runs the Verify section of every requested task. Base URL / db / login /
device id are remembered in ~/.elrace_task_verify.json (never the password
or the token).

Optionally (answer "y" when asked) the script can change System Parameters
through XML-RPC with the same login, so the "set parameter X, call again"
steps run automatically and the previous values are restored at the end.
Without it, the script prints what to set by hand and re-checks on Enter.

Adding a task: write `def task_NN(ctx)` that calls ctx.check(...) and
register it in TASKS at the bottom. Only the Python standard library is used.
"""
import getpass
import json
import os
import sys
import urllib.error
import urllib.request
import xmlrpc.client

PREFS_PATH = os.path.expanduser("~/.elrace_task_verify.json")
PARAM_MODEL = "ir.config_parameter"


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
class Ctx:
    def __init__(self, base_url, db, login, password, device_id):
        self.base_url = base_url.rstrip("/")
        self.db = db
        self.login = login
        self.password = password
        self.device_id = device_id
        self.token = None
        self.user_id = None
        self.xmlrpc_uid = None
        self.results = []  # (task, name, ok, detail)
        self.current_task = "--"
        self._param_backup = {}

    # ---- HTTP -------------------------------------------------------------
    def jsonrpc(self, path, params=None, method="POST", auth=False):
        body = json.dumps({
            "jsonrpc": "2.0",
            "method": "call",
            "id": 1,
            "params": params or {},
        }).encode()
        headers = {"Content-Type": "application/json"}
        if auth:
            if not self.token:
                raise RuntimeError("no token — login failed earlier")
            headers["Authorization"] = "Bearer %s" % self.token
        req = urllib.request.Request(
            self.base_url + path, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                payload = json.loads(resp.read().decode())
        except urllib.error.HTTPError as e:
            raise RuntimeError("%s %s -> HTTP %s: %s" % (
                method, path, e.code, e.read().decode()[:300]))
        if "error" in payload:
            raise RuntimeError("%s %s -> JSON-RPC error: %s" % (
                method, path, json.dumps(payload["error"])[:400]))
        return payload.get("result")

    def login_api(self):
        result = self.jsonrpc("/api/login/new", {
            "db": self.db,
            "login": self.login,
            "password": self.password,
            "device_id": self.device_id,
            "fcm_token": "task-verify-script",
        })
        if not result or not result.get("success"):
            raise RuntimeError("login failed: %s" % (
                (result or {}).get("message", result)))
        self.token = result["token"]
        self.user_id = result.get("user_id")
        return result

    # ---- XML-RPC system parameters ----------------------------------------
    def xmlrpc_connect(self):
        common = xmlrpc.client.ServerProxy(self.base_url + "/xmlrpc/2/common")
        uid = common.authenticate(self.db, self.login, self.password, {})
        if not uid:
            raise RuntimeError("XML-RPC authenticate failed")
        self.xmlrpc_uid = uid
        self._models = xmlrpc.client.ServerProxy(
            self.base_url + "/xmlrpc/2/object")
        return uid

    def _exec(self, model, method, *args, **kw):
        return self._models.execute_kw(
            self.db, self.xmlrpc_uid, self.password, model, method,
            list(args), kw)

    def get_param(self, key):
        return self._exec(PARAM_MODEL, "get_param", key, False)

    def set_param(self, key, value):
        """value None/'' removes the parameter. Backs up the first old value."""
        if key not in self._param_backup:
            self._param_backup[key] = self.get_param(key)
        self._exec(PARAM_MODEL, "set_param", key, value or False)

    def restore_params(self):
        for key, old in self._param_backup.items():
            try:
                self._exec(PARAM_MODEL, "set_param", key, old or False)
            except Exception as e:  # noqa: BLE001
                print("  ! could not restore %s: %s" % (key, e))
        if self._param_backup:
            print("  restored %d system parameter(s)" % len(self._param_backup))
        self._param_backup.clear()

    @property
    def can_set_params(self):
        return self.xmlrpc_uid is not None

    # ---- reporting --------------------------------------------------------
    def check(self, name, ok, detail=""):
        mark = "PASS" if ok else "FAIL"
        print("  [%s] %s%s" % (mark, name, (" — " + str(detail)) if detail else ""))
        self.results.append((self.current_task, name, bool(ok), detail))
        return ok

    def manual(self, instruction):
        """Pause for a manual step when XML-RPC is not available."""
        print("  MANUAL: %s" % instruction)
        input("  ...press Enter when done: ")


def load_prefs():
    try:
        with open(PREFS_PATH) as f:
            return json.load(f)
    except Exception:  # noqa: BLE001
        return {}


def save_prefs(prefs):
    try:
        with open(PREFS_PATH, "w") as f:
            json.dump(prefs, f, indent=2)
    except Exception as e:  # noqa: BLE001
        print("could not save prefs: %s" % e)


def ask(prompt, default=None):
    suffix = " [%s]" % default if default else ""
    value = input("%s%s: " % (prompt, suffix)).strip()
    return value or (default or "")


# --------------------------------------------------------------------------
# TASK 01 — /api/app/config exposes face verification bars
# --------------------------------------------------------------------------
FLOAT_KEYS = ("face_verify_min_score", "face_verify_min_lead",
              "face_verify_min_score_no_cohort")
INT_KEYS = ("face_verify_min_cohort", "face_verify_min_face_px")
NEW_KEYS = FLOAT_KEYS + INT_KEYS
LEGACY_KEYS = ("success", "isTestMode", "splash_video_url",
               "face_match_min_score", "face_match_min_lead")


def app_config(ctx):
    # Route is type='json', methods=['GET']; Odoo reads the JSON-RPC body.
    return ctx.jsonrpc("/api/app/config", {}, method="GET") or {}


def task_01(ctx):
    cfg = app_config(ctx)
    ctx.check("config call succeeds", cfg.get("success") is True, cfg.get("message", ""))
    for key in LEGACY_KEYS:
        ctx.check("existing key present: %s" % key, key in cfg, cfg.get(key))
    for key in NEW_KEYS:
        ctx.check("new key present: %s" % key, key in cfg, cfg.get(key))
    baseline = {k: cfg.get(k) for k in LEGACY_KEYS}

    # Step 2 — nothing set → null
    if ctx.can_set_params:
        for key in NEW_KEYS:
            ctx.set_param("elrace.%s" % key, None)
        cfg = app_config(ctx)
    else:
        unset = all(cfg.get(k) is None for k in NEW_KEYS)
        if not unset:
            ctx.manual("remove all elrace.face_verify_* System Parameters")
            cfg = app_config(ctx)
    for key in NEW_KEYS:
        ctx.check("unset -> null: %s" % key, cfg.get(key) is None, cfg.get(key))

    # Step 3 — valid values
    if ctx.can_set_params:
        ctx.set_param("elrace.face_verify_min_score", "0.32")
        ctx.set_param("elrace.face_verify_min_cohort", "6")
    else:
        ctx.manual("set elrace.face_verify_min_score = 0.32 and "
                   "elrace.face_verify_min_cohort = 6")
    cfg = app_config(ctx)
    ctx.check("face_verify_min_score = 0.32",
              cfg.get("face_verify_min_score") == 0.32, cfg.get("face_verify_min_score"))
    ctx.check("face_verify_min_cohort = 6 (int)",
              cfg.get("face_verify_min_cohort") == 6
              and isinstance(cfg.get("face_verify_min_cohort"), int),
              cfg.get("face_verify_min_cohort"))

    # Step 4 — unparsable → null, others unaffected
    if ctx.can_set_params:
        ctx.set_param("elrace.face_verify_min_cohort", "abc")
    else:
        ctx.manual("set elrace.face_verify_min_cohort = abc")
    cfg = app_config(ctx)
    ctx.check("unparsable int -> null", cfg.get("face_verify_min_cohort") is None,
              cfg.get("face_verify_min_cohort"))
    ctx.check("other new key unaffected (min_score still 0.32)",
              cfg.get("face_verify_min_score") == 0.32, cfg.get("face_verify_min_score"))
    print("  NOTE: check the Odoo log for 'app config: invalid "
          "elrace.face_verify_min_cohort'")

    # Step 5 — legacy keys unchanged
    for key in LEGACY_KEYS:
        ctx.check("legacy unchanged: %s" % key, cfg.get(key) == baseline[key],
                  "%s -> %s" % (baseline[key], cfg.get(key)))

    if ctx.can_set_params:
        ctx.restore_params()
    else:
        print("  MANUAL: remove the test parameters you created, if any")


# --------------------------------------------------------------------------
# Registry — add new tasks here
# --------------------------------------------------------------------------
TASKS = {
    "01": ("Backend: /api/app/config face verification bars", task_01),
    # "02": ("App: ...", task_02),
    # "06": ("Backend: authenticated face image route", task_06),
    # "07": ("Backend: verification audit on submit", task_07),
}


def main(argv):
    wanted = [a.zfill(2) for a in argv[1:]] or sorted(TASKS)
    unknown = [w for w in wanted if w not in TASKS]
    if unknown:
        print("unknown task(s): %s — available: %s" % (
            ", ".join(unknown), ", ".join(sorted(TASKS))))
        return 2

    prefs = load_prefs()
    print("== Elrace face-capture task verifier ==")
    base_url = ask("Odoo base URL", prefs.get("base_url", "http://localhost:8069"))
    db = ask("Database", prefs.get("db"))
    login = ask("Login (mobile user)", prefs.get("login"))
    password = getpass.getpass("Password: ")
    device_id = ask("Device id", prefs.get("device_id", "task-verify-script"))
    use_xmlrpc = ask("Change System Parameters via XML-RPC with this login? (y/N)",
                     prefs.get("use_xmlrpc", "N")).lower().startswith("y")
    save_prefs({"base_url": base_url, "db": db, "login": login,
                "device_id": device_id, "use_xmlrpc": "y" if use_xmlrpc else "N"})

    ctx = Ctx(base_url, db, login, password, device_id)

    print("\n-- login /api/login/new")
    try:
        res = ctx.login_api()
        print("  token ok (user_id=%s, %s)" % (ctx.user_id, res.get("message")))
    except Exception as e:  # noqa: BLE001
        print("  login failed: %s" % e)
        print("  (tasks that only need public endpoints will still run)")

    if use_xmlrpc:
        try:
            uid = ctx.xmlrpc_connect()
            print("  xml-rpc ok (uid=%s) — parameters will be set automatically" % uid)
        except Exception as e:  # noqa: BLE001
            print("  xml-rpc failed: %s — falling back to manual steps" % e)

    for num in wanted:
        title, fn = TASKS[num]
        ctx.current_task = num
        print("\n-- TASK %s: %s" % (num, title))
        try:
            fn(ctx)
        except Exception as e:  # noqa: BLE001
            ctx.check("task ran without error", False, e)
            if ctx.can_set_params:
                ctx.restore_params()

    print("\n== Summary ==")
    failed = [r for r in ctx.results if not r[2]]
    for num in wanted:
        rows = [r for r in ctx.results if r[0] == num]
        bad = [r for r in rows if not r[2]]
        print("  TASK %s: %d checks, %d failed" % (num, len(rows), len(bad)))
    for task, name, _, detail in failed:
        print("  FAIL %s: %s — %s" % (task, name, detail))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
