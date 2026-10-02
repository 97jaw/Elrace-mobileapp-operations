#!/usr/bin/env python3
"""
Read-only checks of Mobile Role Access over XML-RPC (no Odoo install needed).

Checks:
  1. Module version, feature catalogue and system parameters.
  2. Role templates: roles without a template, templates without features,
     "Selected users only" templates with nobody selected, user settings for
     users who are not in the role.
  3. Every employee's app features as Odoo computes them (employee form,
     App Features page) against an independent recalculation from the role
     templates, user settings, enabled role lines and the direct-reports rule.
  4. Employees still flagged for force logout.
  5. Optional: the live API (/api/v3/mobile/access_profile) for one user.

Nothing is written to Odoo, so no user is logged out by running this.

Usage:
    ODOO_URL=https://erp.elrace.com ODOO_DB=odoo.elrace.com ODOO_LOGIN=jawad@elrace.com \
        python3 docs/access_audit/mobile_role_access_test.py

Options (environment variables):
    ODOO_PASSWORD     admin password (prompted when missing)
    ODOO_UID          admin user id, skips the login step (restrict_logins)
    ODOO_USERS        login1,login2 — only check these users (default: all)
    ODOO_INSECURE=1   skip TLS verification (macOS Python without certificates)
    MOBILE_TOKEN      a mobile JWT (Bearer) to also check the live API
    MOBILE_LOGIN      login of the MOBILE_TOKEN user (to compare with Odoo)

Output: console summary + docs/access_audit/output/mobile_role_access_*.csv
(staff data, gitignored).
"""

import csv
import getpass
import json
import os
import ssl
import sys
import urllib.request
import xmlrpc.client
from datetime import date

URL = os.environ.get('ODOO_URL', 'https://erp.elrace.com').rstrip('/')
DB = os.environ.get('ODOO_DB', 'odoo.elrace.com')
LOGIN = os.environ.get('ODOO_LOGIN', 'jawad@elrace.com')
PASSWORD = os.environ.get('ODOO_PASSWORD') or getpass.getpass(
    'Odoo password for %s on %s: ' % (LOGIN, URL))
OUT = os.environ.get('ODOO_EXPORT_DIR') or os.path.join(
    os.path.dirname(os.path.abspath(__file__)), 'output')
ONLY_USERS = [u.strip() for u in os.environ.get('ODOO_USERS', '').split(',') if u.strip()]
EXPECTED_VERSION = '0.6.5'
PROJECT_DOC_CODES = {
    'projects.attachments_tab',
    'projects.documents_hub',
    'projects.documents.work_orders',
    'projects.documents.estimation',
    'projects.documents.sharepoint',
}

context = ssl._create_unverified_context() if os.environ.get('ODOO_INSECURE') else None
common = xmlrpc.client.ServerProxy(URL + '/xmlrpc/2/common', context=context, allow_none=True)
rpc = xmlrpc.client.ServerProxy(URL + '/xmlrpc/2/object', context=context, allow_none=True)

try:
    UID = int(os.environ['ODOO_UID']) if os.environ.get('ODOO_UID') else \
        common.authenticate(DB, LOGIN, PASSWORD, {})
except xmlrpc.client.Fault as exc:
    if 'user_id" is ambiguous' in exc.faultString:
        sys.exit('Odoo rejected the password for %s. Use the real password, '
                 'not an API key.' % LOGIN)
    raise
if not UID:
    sys.exit('Login failed. Check ODOO_LOGIN / password, or set ODOO_UID.')

results = {'PASS': 0, 'WARN': 0, 'FAIL': 0}


def call(model, method, *args, **kw):
    kw.setdefault('context', {'active_test': False})
    return rpc.execute_kw(DB, UID, PASSWORD, model, method, list(args), kw)


def search_read(model, domain, fields, **kw):
    return call(model, 'search_read', domain, fields=fields, **kw)


def has_fields(model, names):
    available = call(model, 'fields_get', attributes=['type'])
    return [n for n in names if n in available]


def report(level, title, detail=''):
    results[level] += 1
    print('  [%s] %s%s' % (level, title, (' — ' + detail) if detail else ''))


def section(title):
    print('\n== %s ==' % title)


def m2o_id(value):
    return value[0] if value else False


def write_csv(name, header, rows):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with open(path, 'w', newline='', encoding='utf-8') as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        writer.writerows(rows)
    return path


# ---------------------------------------------------------------------------
section('1. Module, catalogue and system parameters')

module = search_read('ir.module.module', [('name', '=', 'emp_mobile_conf')],
                     ['state', 'latest_version'])
version = module[0]['latest_version'] if module else None
if module and module[0]['state'] == 'installed' and (version or '').endswith(EXPECTED_VERSION):
    report('PASS', 'emp_mobile_conf installed', version)
else:
    report('FAIL', 'emp_mobile_conf version', 'found %s, expected *%s (upgrade the module)'
           % (version, EXPECTED_VERSION))

features = search_read('mobile.feature', [],
                       has_fields('mobile.feature',
                                  ['code', 'name', 'category', 'active',
                                   'requires_direct_reports', 'is_default', 'all_users']))
feature_by_id = {f['id']: f for f in features}
codes = {f['code'] for f in features if f['active']}
missing_docs = sorted(PROJECT_DOC_CODES - codes)
report('FAIL' if missing_docs else 'PASS', 'Project document features in catalogue',
       ('missing ' + ', '.join(missing_docs)) if missing_docs else '%s active features' % len(codes))
manager_only = [f['code'] for f in features if f['requires_direct_reports'] and f['active']]
report('PASS' if 'hr.attendance.team_view' in manager_only else 'FAIL',
       'Attendance Team view only for employees with direct reports',
       ', '.join(manager_only) or 'none set')
if features and 'all_users' not in features[0]:
    report('FAIL', 'Field "For All Mobile Users" is missing',
           'the server is not running the new emp_mobile_conf code (pull + restart + upgrade)')
else:
    everyone = sorted(f['code'] for f in features if f.get('all_users') and f['active'])
    report('PASS' if 'qr.survey' in everyone else 'FAIL', 'Features for all mobile users',
           ', '.join(everyone) or 'none set')

params = {p['key']: p['value'] for p in search_read(
    'ir.config_parameter',
    [('key', 'in', ['elrace.mobile_features_enforce', 'elrace.mobile_features_compare',
                    'elrace.mobile_sessions_keep'])],
    ['key', 'value'])}
enforce = str(params.get('elrace.mobile_features_enforce', '0')).strip().lower()
if enforce in ('0', 'false', 'no', 'off', ''):
    report('PASS', 'Feature enforcement is off (correct until the app update)')
else:
    report('WARN', 'Feature enforcement is ON',
           'document APIs refuse features a role lacks; the current app does not hide them')
print('  info: compare log = %s, sessions kept = %s' % (
    params.get('elrace.mobile_features_compare', '1 (default)'),
    params.get('elrace.mobile_sessions_keep', '5 (default)')))

# ---------------------------------------------------------------------------
section('2. Role templates and user settings')

roles = search_read('res.users.role', [], ['name'])
role_name = {r['id']: r['name'] for r in roles}
template_fields = has_fields('mobile.widget.role.template',
                             ['role_id', 'feature_ids', 'widget_ids', 'feature_scope',
                              'feature_user_ids', 'active'])
templates = search_read('mobile.widget.role.template', [], template_fields)
if 'feature_scope' not in template_fields:
    report('FAIL', 'Role templates have no "Apply Features To" field', 'upgrade to 0.6.3')
template_by_role = {}
for t in templates:
    template_by_role.setdefault(m2o_id(t['role_id']), t)

no_template = sorted(role_name[r] for r in role_name if r not in template_by_role)
report('WARN' if no_template else 'PASS', 'Roles without Mobile Role Access',
       ', '.join(no_template[:15]) + (' …' if len(no_template) > 15 else '') if no_template
       else 'every role has one')
no_features = sorted(role_name.get(m2o_id(t['role_id']), '?') for t in templates
                     if t['active'] and not t['feature_ids'])
report('WARN' if no_features else 'PASS', 'Active roles with no app features ticked',
       ', '.join(no_features[:15]) or 'none')
empty_selected = sorted(role_name.get(m2o_id(t['role_id']), '?') for t in templates
                        if t['active'] and t.get('feature_scope') == 'selected'
                        and not t.get('feature_user_ids'))
report('WARN' if empty_selected else 'PASS', '"Selected users only" with nobody selected',
       ', '.join(empty_selected) or 'none')

line_fields = has_fields('res.users.role.line',
                         ['role_id', 'user_id', 'is_enabled', 'date_from', 'date_to'])
lines = search_read('res.users.role.line', [], line_fields)
today = date.today().isoformat()


def line_enabled(line):
    if not line['role_id']:
        return False
    if 'is_enabled' in line:
        return bool(line['is_enabled'])
    if line.get('date_from') and line['date_from'] > today:
        return False
    if line.get('date_to') and line['date_to'] < today:
        return False
    return True


members_any = {}
enabled_roles_by_user = {}
for line in lines:
    uid, rid = m2o_id(line['user_id']), m2o_id(line['role_id'])
    if not uid or not rid:
        continue
    members_any.setdefault(rid, set()).add(uid)
    if line_enabled(line):
        enabled_roles_by_user.setdefault(uid, set()).add(rid)

settings = []
if call('ir.model', 'search_count', [('model', '=', 'mobile.role.user.feature')]):
    settings = search_read('mobile.role.user.feature', [('active', '=', True)],
                           ['template_id', 'user_id', 'added_feature_ids',
                            'removed_feature_ids', 'note'])
    report('PASS', 'User settings found', str(len(settings)))
else:
    report('FAIL', 'User settings model missing', 'upgrade to 0.6.3')
template_by_id = {t['id']: t for t in templates}
setting_by_key = {}
outsiders = []
for s in settings:
    tid, uid = m2o_id(s['template_id']), m2o_id(s['user_id'])
    setting_by_key[(tid, uid)] = s
    rid = m2o_id(template_by_id.get(tid, {}).get('role_id'))
    if uid not in members_any.get(rid, set()):
        outsiders.append('%s in %s' % (s['user_id'][1], role_name.get(rid, '?')))
report('FAIL' if outsiders else 'PASS', 'User settings for users not in the role',
       ', '.join(outsiders) or 'none')

# ---------------------------------------------------------------------------
section('3. Employee app features: Odoo vs recalculation')

emp_fields = has_fields('hr.employee', ['name', 'user_id', 'parent_id', 'active', 'is_labor',
                                        'mobile_access', 'force_logout',
                                        'effective_mobile_feature_ids'])
emp_domain = [('user_id', '!=', False), ('active', '=', True)]
if ONLY_USERS:
    emp_domain.append(('user_id.login', 'in', ONLY_USERS))
base_fields = [f for f in emp_fields if f != 'effective_mobile_feature_ids']
employees = search_read('hr.employee', emp_domain, base_fields)
all_active = search_read('hr.employee', [('active', '=', True), ('parent_id', '!=', False)],
                         [f for f in ('parent_id', 'is_labor') if f in emp_fields])
managers_with_reports = {
    m2o_id(e['parent_id']) for e in all_active if not e.get('is_labor')
}
emp_ids_by_user = {}
for emp in search_read('hr.employee', [('user_id', '!=', False), ('active', '=', True)],
                       ['user_id']):
    emp_ids_by_user.setdefault(m2o_id(emp['user_id']), set()).add(emp['id'])

effective = {}
batch = 50
emp_ids = [e['id'] for e in employees]
for start in range(0, len(emp_ids), batch):
    for row in call('hr.employee', 'read', emp_ids[start:start + batch],
                    ['effective_mobile_feature_ids']):
        effective[row['id']] = set(row['effective_mobile_feature_ids'])
    print('  … read %s/%s employees' % (min(start + batch, len(emp_ids)), len(emp_ids)),
          end='\r')
print()


def expected_features(uid):
    result = set()
    for rid in enabled_roles_by_user.get(uid, set()):
        template = template_by_role.get(rid)
        if not template or not template['active']:
            continue
        scope = template.get('feature_scope', 'all')
        base = set(template['feature_ids']) if (
            scope != 'selected' or uid in template.get('feature_user_ids', [])) else set()
        setting = setting_by_key.get((template['id'], uid))
        if setting:
            base = (base | set(setting['added_feature_ids'])) - set(setting['removed_feature_ids'])
        result |= base
    result |= {f['id'] for f in features if f.get('all_users')}
    result = {fid for fid in result if feature_by_id.get(fid, {}).get('active')}
    has_reports = bool(emp_ids_by_user.get(uid, set()) & managers_with_reports)
    if not has_reports:
        result = {fid for fid in result
                  if not feature_by_id[fid]['requires_direct_reports']}
    return result, has_reports


def code_list(ids):
    return sorted(feature_by_id[i]['code'] for i in ids if i in feature_by_id)


rows = []
mismatches = []
no_features_users = []
for emp in employees:
    uid = m2o_id(emp['user_id'])
    expected, has_reports = expected_features(uid)
    actual = effective.get(emp['id'], set())
    status = 'OK' if expected == actual else 'MISMATCH'
    if status == 'MISMATCH':
        mismatches.append(emp['name'])
    if not actual and emp.get('mobile_access', True):
        no_features_users.append(emp['name'])
    user_settings = [s for (tid, u), s in setting_by_key.items() if u == uid]
    rows.append([
        emp['user_id'][1], emp['name'],
        '; '.join(sorted(role_name.get(r, '?') for r in enabled_roles_by_user.get(uid, set()))),
        'yes' if has_reports else 'no',
        'yes' if emp.get('mobile_access', True) else 'no',
        len(user_settings),
        status,
        ', '.join(code_list(actual)),
        ', '.join(code_list(expected - actual)),
        ', '.join(code_list(actual - expected)),
    ])

report('FAIL' if mismatches else 'PASS',
       'Odoo features match the recalculation for %s employees' % len(employees),
       ('%s mismatches, e.g. %s' % (len(mismatches), ', '.join(mismatches[:5])))
       if mismatches else '')
report('WARN' if no_features_users else 'PASS', 'Mobile employees with no app features',
       ('%s, e.g. %s' % (len(no_features_users), ', '.join(no_features_users[:5])))
       if no_features_users else 'none')
path = write_csv('mobile_role_access_users.csv',
                 ['login', 'employee', 'enabled roles', 'has direct reports', 'mobile access',
                  'user settings', 'check', 'features (Odoo)', 'missing vs recalculation',
                  'extra vs recalculation'], rows)
print('  info: per-employee features written to %s' % path)

setting_rows = [[
    s['user_id'][1],
    role_name.get(m2o_id(template_by_id.get(m2o_id(s['template_id']), {}).get('role_id')), '?'),
    ', '.join(code_list(s['added_feature_ids'])),
    ', '.join(code_list(s['removed_feature_ids'])),
    s.get('note') or '',
] for s in settings]
if setting_rows:
    print('  info: user settings written to %s' % write_csv(
        'mobile_role_access_user_settings.csv',
        ['user', 'role', 'extra features', 'removed features', 'note'], setting_rows))

# ---------------------------------------------------------------------------
section('4. Force logout')

if 'force_logout' in emp_fields:
    flagged = search_read('hr.employee', [('force_logout', '=', True), ('active', '=', True)],
                          ['name'])
    report('PASS' if not flagged else 'WARN', 'Employees waiting for force logout',
           ('%s (they are logged out on their next app action), e.g. %s'
            % (len(flagged), ', '.join(e['name'] for e in flagged[:5]))) if flagged else 'none')

# ---------------------------------------------------------------------------
section('5. Live API (optional)')

token = os.environ.get('MOBILE_TOKEN')
if not token:
    print('  skipped: set MOBILE_TOKEN (and MOBILE_LOGIN) to check /api/v3/mobile/access_profile')
else:
    request = urllib.request.Request(
        URL + '/api/v3/mobile/access_profile',
        data=json.dumps({'jsonrpc': '2.0', 'params': {}}).encode(),
        headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token},
        method='POST',
    )
    try:
        with urllib.request.urlopen(request, context=context, timeout=30) as response:
            body = json.loads(response.read().decode())
    except Exception as exc:
        body = None
        report('FAIL', 'access_profile call failed', str(exc))
    if body is not None:
        result = body.get('result') or {}
        if result.get('status') != 'success':
            report('FAIL', 'access_profile returned an error',
                   '%s %s' % (result.get('code', ''), result.get('message', '')))
        else:
            api_codes = set(result['data'].get('features') or [])
            report('PASS', 'access_profile answered',
                   '%s features, roles: %s' % (len(api_codes),
                                               ', '.join(result['data'].get('roles') or [])))
            login = os.environ.get('MOBILE_LOGIN')
            match = [r for r in rows if login and r[0] == login]
            if match:
                odoo_codes = {c for c in match[0][7].split(', ') if c}
                same = odoo_codes == api_codes
                report('PASS' if same else 'FAIL', 'API features match Odoo for %s' % login,
                       '' if same else 'API only: %s; Odoo only: %s' % (
                           ', '.join(sorted(api_codes - odoo_codes)) or '-',
                           ', '.join(sorted(odoo_codes - api_codes)) or '-'))
            elif login:
                print('  info: %s was not in the checked users (see ODOO_USERS)' % login)

# ---------------------------------------------------------------------------
print('\nSummary: %(PASS)s passed, %(WARN)s warnings, %(FAIL)s failed' % results)
sys.exit(1 if results['FAIL'] else 0)
