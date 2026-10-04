#!/usr/bin/env python3
"""
Read-only export of Purchase access over XML-RPC (no Odoo install needed).

Writes five CSVs: roles, access rights, record rules, users (app scope from
the role flags vs. their groups), and whether each role flag is redundant
with a group the roles already carry. Only search/read calls are made.

Usage (staging first):
    ODOO_URL=https://erp.elrace.com ODOO_DB=odoo.elrace.com ODOO_LOGIN=admin \
        python3 docs/access_audit/purchase_access_export.py

The password is prompted (or ODOO_PASSWORD).
4_users.csv is only filled for ODOO_USERS=login1,login2 (a few test users).
If login is refused because the admin has a web session (restrict_logins),
set ODOO_UID=<admin user id> to skip the login step.
ODOO_INSECURE=1 skips TLS verification (macOS Python without certificates).
Output: docs/access_audit/output/
"""

import csv
import getpass
import os
import ssl
import sys
import xmlrpc.client
from datetime import date

URL = os.environ.get('ODOO_URL', 'https://erp.elrace.com').rstrip('/')
DB = os.environ.get('ODOO_DB', 'odoo.elrace.com')
LOGIN = os.environ.get('ODOO_LOGIN', 'admin')
PASSWORD = os.environ.get('ODOO_PASSWORD') or getpass.getpass(
    'Odoo password for %s on %s: ' % (LOGIN, URL))
OUT = os.environ.get('ODOO_EXPORT_DIR') or os.path.join(
    os.path.dirname(os.path.abspath(__file__)), 'output')

MODELS = [
    'purchase.order',
    'purchase.order.line',
    'material.purchase.requisition',
    'material.purchase.requisition.line',
]
# Same field lists as elrace_backend_apis/utils/purchase_module_access.py
MANAGEMENT_FLAGS = ('x_is_management', 'x_management', 'x_studio_management')
MANAGER_FLAGS = ('x_purchase_manager_role', 'x_purchaes_manager_role',
                 'x_is_purchase_manager', 'x_purchase_manager')
OFFICER_FLAGS = ('x_purchase_officer', 'x_is_purchase_officer', 'x_is_purchase_rep')
DC_FLAGS = ('x_is_dc_role', 'x_dc_role', 'x_is_doc_controller')
MANAGEMENT_NAMES = {'Branch Manager Access', 'Branch Manager', 'Management'}
MANAGER_NAMES = {'Purchase Manager', 'ODOO SUPPORT', 'Cost Control'}
OFFICER_NAMES = {'Purchase Officer', 'Purchase Representative'}

context = ssl._create_unverified_context() if os.environ.get('ODOO_INSECURE') else None
common = xmlrpc.client.ServerProxy(URL + '/xmlrpc/2/common', context=context, allow_none=True)
rpc = xmlrpc.client.ServerProxy(URL + '/xmlrpc/2/object', context=context, allow_none=True)

LOGIN_REJECTED = (
    'Odoo rejected the password for %s. Use that user\'s real Odoo password '
    '(not an API key: API keys fail on this server with "column reference '
    'user_id is ambiguous").' % LOGIN
)
try:
    UID = int(os.environ['ODOO_UID']) if os.environ.get('ODOO_UID') else \
        common.authenticate(DB, LOGIN, PASSWORD, {})
except xmlrpc.client.Fault as exc:
    if 'user_id" is ambiguous' in exc.faultString:
        sys.exit(LOGIN_REJECTED)
    raise
if not UID:
    sys.exit('Login failed. Check ODOO_LOGIN / password, or set ODOO_UID.')

all_company_ids = None


def call(model, method, *args, **kw):
    if all_company_ids and 'context' not in kw:
        kw['context'] = {'allowed_company_ids': all_company_ids, 'active_test': False}
    return rpc.execute_kw(DB, UID, PASSWORD, model, method, list(args), kw)


def read_all(model, domain, fields):
    return call(model, 'search_read', domain, fields=fields)


def m2o_id(value):
    return value[0] if value else False


def write_csv(name, header, rows):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with open(path, 'w', newline='') as fh:
        writer = csv.writer(fh)
        writer.writerow(header)
        writer.writerows(rows)
    print('wrote %s (%s rows)' % (path, len(rows)))


print('connected to %s as uid %s' % (URL, UID))
all_company_ids = call('res.users', 'read', [UID], fields=['company_ids'])[0]['company_ids']
print('companies in scope: %s (counts only cover these)' % all_company_ids)
today = date.today().isoformat()
models_present = [m for m in MODELS if call('ir.model', 'search_count', [('model', '=', m)])]

# --- Groups and their XML ids ------------------------------------------------
groups = {g['id']: g for g in read_all(
    'res.groups', [], ['full_name', 'implied_ids', 'trans_implied_ids'])}
xmlids = {}
for row in read_all('ir.model.data', [('model', 'in', ['res.groups', 'ir.rule'])],
                    ['model', 'module', 'name', 'res_id']):
    xmlids[(row['model'], row['res_id'])] = '%s.%s' % (row['module'], row['name'])


def group_label(gid):
    g = groups.get(gid)
    name = g['full_name'] if g else 'group %s' % gid
    return '%s [%s]' % (name, xmlids.get(('res.groups', gid)) or 'id %s' % gid)


def labels(gids):
    return '; '.join(sorted(group_label(g) for g in gids))


# --- Roles, flags, lines -----------------------------------------------------
role_fields = call('res.users.role', 'fields_get', attributes=['type'])
all_flags = sorted(n for n, f in role_fields.items()
                   if n.startswith('x_') and f['type'] == 'boolean')
roles = {r['id']: r for r in read_all(
    'res.users.role', [], ['name', 'group_id', 'implied_ids'] + all_flags)}
role_own_groups = {m2o_id(r['group_id']) for r in roles.values() if r['group_id']}

line_fields = call('res.users.role.line', 'fields_get', attributes=['type'])
wanted = [f for f in ('role_id', 'user_id', 'date_from', 'date_to', 'is_enabled')
          if f in line_fields]
lines = read_all('res.users.role.line', [], wanted)


def line_enabled(line):
    if 'is_enabled' in line:
        return bool(line['is_enabled'])
    if line.get('date_from') and line['date_from'] > today:
        return False
    if line.get('date_to') and line['date_to'] < today:
        return False
    return True


def role_groups(role):
    """Groups a role grants (direct + implied), excluding role groups themselves."""
    result = set()
    for gid in role['implied_ids']:
        result.add(gid)
        result.update(groups.get(gid, {}).get('trans_implied_ids', []))
    return result - role_own_groups


lines_by_role, lines_by_user = {}, {}
for line in lines:
    rid, uid_ = m2o_id(line['role_id']), m2o_id(line['user_id'])
    if rid and uid_:
        lines_by_role.setdefault(rid, []).append(line)
        lines_by_user.setdefault(uid_, []).append(line)

# 1. Roles -------------------------------------------------------------------
purchase_flag_fields = [f for f in MANAGEMENT_FLAGS + MANAGER_FLAGS + OFFICER_FLAGS + DC_FLAGS
                        if f in all_flags]
rows = []
for role in sorted(roles.values(), key=lambda r: r['name'] or ''):
    rlines = lines_by_role.get(role['id'], [])
    enabled_users = {m2o_id(l['user_id']) for l in rlines if line_enabled(l)}
    all_users = {m2o_id(l['user_id']) for l in rlines}
    rows.append([
        role['id'], role['name'],
        ', '.join(f for f in purchase_flag_fields if role.get(f)),
        ', '.join(f for f in all_flags if role.get(f)),
        labels(role['implied_ids']),
        labels(role_groups(role)),
        len(enabled_users), len(all_users - enabled_users),
    ])
write_csv('1_roles.csv', [
    'role_id', 'role', 'purchase_flags_ticked', 'all_flags_ticked',
    'groups_direct', 'groups_all_implied',
    'users_enabled_lines', 'users_only_disabled_or_expired_lines',
], rows)

# 2. Access rights -------------------------------------------------------------
acls = read_all('ir.model.access', [('model_id.model', 'in', models_present)],
                ['model_id', 'name', 'active', 'group_id',
                 'perm_read', 'perm_write', 'perm_create', 'perm_unlink'])
model_names = {m['id']: m['model'] for m in read_all(
    'ir.model', [('model', 'in', models_present)], ['model'])}
rows = [[
    model_names.get(m2o_id(a['model_id'])), a['name'], a['active'],
    group_label(m2o_id(a['group_id'])) if a['group_id'] else 'ALL USERS',
    int(a['perm_read']), int(a['perm_write']), int(a['perm_create']), int(a['perm_unlink']),
] for a in acls]
write_csv('2_access_rights.csv', [
    'model', 'acl', 'active', 'group', 'read', 'write', 'create', 'unlink'], sorted(rows))

# 3. Record rules ---------------------------------------------------------------
rules = read_all('ir.rule', [('model_id.model', 'in', models_present)],
                 ['model_id', 'name', 'active', 'groups', 'domain_force',
                  'perm_read', 'perm_write', 'perm_create', 'perm_unlink'])
rows = [[
    model_names.get(m2o_id(r['model_id'])), r['name'], r['active'],
    xmlids.get(('ir.rule', r['id']), ''),
    labels(r['groups']) if r['groups'] else 'GLOBAL',
    int(r['perm_read']), int(r['perm_write']), int(r['perm_create']), int(r['perm_unlink']),
    (r['domain_force'] or '').replace('\n', ' '),
] for r in rules]
write_csv('3_record_rules.csv', [
    'model', 'rule', 'active', 'xmlid', 'groups',
    'read', 'write', 'create', 'unlink', 'domain'], sorted(rows))

# 4. Users ---------------------------------------------------------------------
po_fields = call('purchase.order', 'fields_get', attributes=['type'])
mr_fields = call('material.purchase.requisition', 'fields_get', attributes=['type']) \
    if 'material.purchase.requisition' in models_present else {}


def present(fields_map, domain):
    """Drop leaves on fields this database doesn't have (keeps OR structure valid)."""
    leaves = [t for t in domain if isinstance(t, tuple)]
    kept = [t for t in leaves if t[0].split('.')[0] in fields_map]
    if not kept:
        return [('id', '=', 0)]
    return ['|'] * (len(kept) - 1) + kept


def app_scope(user_lines):
    """Mirror of purchase_access_for_mobile: OR over ALL role lines, then names."""
    flags = {'management': False, 'manager': False, 'officer': False, 'dc': False}
    names = set()
    for line in user_lines:
        role = roles.get(m2o_id(line['role_id']))
        if not role:
            continue
        names.add((role['name'] or '').strip())
        flags['management'] |= any(role.get(f) for f in MANAGEMENT_FLAGS)
        flags['manager'] |= any(role.get(f) for f in MANAGER_FLAGS)
        flags['officer'] |= any(role.get(f) for f in OFFICER_FLAGS)
        flags['dc'] |= any(role.get(f) for f in DC_FLAGS)
    flags['management'] |= bool(names & MANAGEMENT_NAMES)
    flags['manager'] |= bool(names & MANAGER_NAMES)
    flags['officer'] |= bool(names & OFFICER_NAMES)
    if flags['management']:
        scope = 'all'
    elif flags['manager']:
        scope = 'department'
    elif flags['officer']:
        scope = 'own'
    elif flags['dc']:
        scope = 'receiving'
    else:
        scope = 'none'
    return scope, flags


def acl_allows(user_groups, model, perm):
    for a in acls:
        if model_names.get(m2o_id(a['model_id'])) != model or not a['active'] or not a[perm]:
            continue
        if not a['group_id'] or m2o_id(a['group_id']) in user_groups:
            return 1
    return 0


def rules_for(user_groups, model):
    names = []
    for r in rules:
        if model_names.get(m2o_id(r['model_id'])) != model or not r['active']:
            continue
        if not r['groups'] or set(r['groups']) & user_groups:
            names.append(r['name'] + ('' if r['groups'] else ' (global)'))
    return '; '.join(sorted(names))


purchase_group_ids = {m2o_id(a['group_id']) for a in acls if a['group_id']}
# Per-user rows are slow on large databases; only for a few named logins.
user_logins = [l.strip() for l in os.environ.get('ODOO_USERS', '').split(',') if l.strip()]
users = read_all('res.users', [('login', 'in', user_logins), ('share', '=', False)],
                 ['login', 'name', 'groups_id', 'employee_ids']) if user_logins else []
employees = {e['id']: e for e in read_all(
    'hr.employee', [('user_id', 'in', [u['id'] for u in users])], ['department_id'])}

rows = []
for user in sorted(users, key=lambda u: u['name'] or ''):
    user_lines = lines_by_user.get(user['id'], [])
    scope, flags = app_scope(user_lines)
    user_groups = set(user['groups_id'])
    emp = employees.get(user['employee_ids'][0]) if user['employee_ids'] else None
    dept = emp['department_id'] if emp else False

    if scope == 'all':
        po_dom, mr_dom = [], []
    elif scope == 'department':
        po_dom = [('department_id', 'child_of', dept[0])] if dept else [('id', '=', 0)]
        mr_dom = po_dom
    elif scope == 'own' and emp:
        po_dom = present(po_fields, [
            ('projects_manager', '=', emp['id']), ('project_manager_user', '=', user['id']),
            ('requester_manager_id', '=', user['id']), ('requested_by_id', '=', emp['id']),
            ('user_id', '=', user['id'])])
        mr_dom = present(mr_fields, [
            ('employee_id', '=', emp['id']), ('project_manager_id', '=', emp['id']),
            ('task_user_id', '=', user['id']), ('requester_manager_id', '=', user['id'])])
    else:
        po_dom = mr_dom = [('id', '=', 0)]

    po_count = call('purchase.order', 'search_count', [('state', '!=', 'cancel')] + po_dom)
    mr_count = call('material.purchase.requisition', 'search_count', mr_dom) if mr_fields else ''

    rows.append([
        user['id'], user['login'], user['name'], dept[1] if dept else '',
        '; '.join(sorted({roles[m2o_id(l['role_id'])]['name'] for l in user_lines
                          if line_enabled(l) and m2o_id(l['role_id']) in roles})),
        '; '.join(sorted({roles[m2o_id(l['role_id'])]['name'] for l in user_lines
                          if not line_enabled(l) and m2o_id(l['role_id']) in roles})),
        ', '.join(k for k, v in flags.items() if v), scope,
        labels(user_groups & purchase_group_ids),
        acl_allows(user_groups, 'purchase.order', 'perm_read'),
        acl_allows(user_groups, 'purchase.order', 'perm_create'),
        acl_allows(user_groups, 'material.purchase.requisition', 'perm_read'),
        acl_allows(user_groups, 'material.purchase.requisition', 'perm_create'),
        rules_for(user_groups, 'purchase.order'),
        rules_for(user_groups, 'material.purchase.requisition'),
        po_count, mr_count,
    ])
write_csv('4_users.csv', [
    'user_id', 'login', 'name', 'department',
    'roles_enabled', 'roles_disabled_or_expired', 'purchase_flags_from_all_lines', 'app_scope',
    'purchase_groups', 'po_read', 'po_create', 'mr_read', 'mr_create',
    'po_rules_applying', 'mr_rules_applying', 'po_count_app_scope', 'mr_count_app_scope',
], rows)

# 5. Is each flag redundant with a group? -------------------------------------
role_group_sets = {rid: role_groups(r) for rid, r in roles.items()}
enabled_users_by_role = {
    rid: {m2o_id(l['user_id']) for l in rl if line_enabled(l)}
    for rid, rl in lines_by_role.items()
}
rows = []
for flag in all_flags:
    with_flag = [rid for rid, r in roles.items() if r.get(flag)]
    without_flag = [rid for rid in roles if rid not in with_flag]
    users_count = len(set().union(*[enabled_users_by_role.get(r, set()) for r in with_flag])) \
        if with_flag else 0
    if not with_flag:
        rows.append([flag, 0, 0, 'flag unused', '', '', '', '', ''])
        continue
    candidates = set().union(*[role_group_sets[r] for r in with_flag])
    if not candidates:
        rows.append([flag, len(with_flag), users_count,
                     'NEEDED: roles with this flag carry no groups', '', '', '', '',
                     '; '.join(roles[r]['name'] for r in with_flag)])
        continue
    scored = []
    for gid in candidates:
        both = sum(1 for r in with_flag if gid in role_group_sets[r])
        flag_only = len(with_flag) - both
        group_only = sum(1 for r in without_flag if gid in role_group_sets[r])
        scored.append((flag_only + group_only, -both, group_label(gid), gid,
                       both, flag_only, group_only))
    scored.sort()
    for rank, (errors, _, label, gid, both, flag_only, group_only) in enumerate(scored[:3], 1):
        if rank == 1:
            if errors == 0:
                verdict = 'REPLACEABLE by group'
            elif errors <= max(1, len(with_flag) // 5):
                verdict = 'CLOSE: fix the listed roles, then replaceable'
            else:
                verdict = 'NEEDED: no group matches this flag'
        else:
            verdict = 'alternative %s' % rank
        mismatched = (
            [roles[r]['name'] + ' (flag, no group)' for r in with_flag
             if gid not in role_group_sets[r]]
            + [roles[r]['name'] + ' (group, no flag)' for r in without_flag
               if gid in role_group_sets[r]]
        )
        rows.append([flag, len(with_flag), users_count, verdict, label,
                     both, flag_only, group_only, '; '.join(mismatched[:15])])
write_csv('5_flag_vs_groups.csv', [
    'flag', 'roles_with_flag', 'users_enabled', 'verdict', 'candidate_group',
    'roles_flag_and_group', 'roles_flag_not_group', 'roles_group_not_flag',
    'mismatched_roles',
], rows)

print('done; read-only, nothing was changed in Odoo')
