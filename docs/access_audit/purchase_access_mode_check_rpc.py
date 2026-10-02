#!/usr/bin/env python3
"""
Purchase APIs: today's access (role flags) vs Odoo access rights, from a laptop.

Calls res.users.elrace_purchase_access_check over XML-RPC (admin only). The
server runs every Purchase API twice per user — legacy and Odoo rules — on a
private copy of the service, then rolls back. The system parameter
elrace.mobile_access_mode.purchase is not touched, so it is safe on production.

Also prints the MOBILE_ACCESS_COMPARE differences recorded from real app
traffic for every module whose elrace.mobile_access_mode.<module> parameter is
set to "compare" (purchase, projects, hr, timesheet, approvals).

Usage:
    ODOO_URL=https://erp.elrace.com ODOO_DB=odoo.elrace.com ODOO_LOGIN=jawad@elrace.com \
    PURCHASE_CHECK_ROLES="Purchase Officer,Purchase Manager,Project Manager" \
        python3 docs/access_audit/purchase_access_mode_check_rpc.py

Options (environment variables):
    ODOO_PASSWORD            admin password (prompted when missing)
    ODOO_UID                 admin user id, skips the login step (restrict_logins)
    ODOO_INSECURE=1          skip TLS verification
    PURCHASE_CHECK_USERS     login1,login2
    PURCHASE_CHECK_ROLES     role names; PURCHASE_CHECK_PER_ROLE users each (default 3)
    PURCHASE_COMPARE_DAYS    days of compare-mode logs to show (default 3, 0 = skip)
    COMPARE_MODULES          modules to show compare logs for (default: all)

Output: console + docs/access_audit/output/purchase_access_check_*.csv
(staff data, gitignored).
"""

import csv
import getpass
import os
import ssl
import sys
import xmlrpc.client
from datetime import datetime, timedelta, timezone

URL = os.environ.get('ODOO_URL', 'https://erp.elrace.com').rstrip('/')
DB = os.environ.get('ODOO_DB', 'odoo.elrace.com')
LOGIN = os.environ.get('ODOO_LOGIN', 'jawad@elrace.com')
PASSWORD = os.environ.get('ODOO_PASSWORD') or getpass.getpass(
    'Odoo password for %s on %s: ' % (LOGIN, URL))
OUT = os.environ.get('ODOO_EXPORT_DIR') or os.path.join(
    os.path.dirname(os.path.abspath(__file__)), 'output')


def env_list(name):
    return [v.strip() for v in os.environ.get(name, '').split(',') if v.strip()]


context = ssl._create_unverified_context() if os.environ.get('ODOO_INSECURE') else None
common = xmlrpc.client.ServerProxy(URL + '/xmlrpc/2/common', context=context, allow_none=True)
rpc = xmlrpc.client.ServerProxy(URL + '/xmlrpc/2/object', context=context, allow_none=True)

try:
    UID = int(os.environ['ODOO_UID']) if os.environ.get('ODOO_UID') else \
        common.authenticate(DB, LOGIN, PASSWORD, {})
except xmlrpc.client.Fault:
    UID = None
if not UID:
    sys.exit('Login failed. Check ODOO_LOGIN / password, or set ODOO_UID.')


def call(model, method, *args, **kw):
    return rpc.execute_kw(DB, UID, PASSWORD, model, method, list(args), kw)


def dry_run():
    logins = env_list('PURCHASE_CHECK_USERS')
    roles = env_list('PURCHASE_CHECK_ROLES')
    if not logins and not roles:
        print('Dry run skipped: set PURCHASE_CHECK_USERS and/or PURCHASE_CHECK_ROLES.')
        return
    per_role = int(os.environ.get('PURCHASE_CHECK_PER_ROLE', '3') or 3)
    try:
        rows = call('res.users', 'elrace_purchase_access_check',
                    logins=logins, roles=roles, per_role=per_role)
    except xmlrpc.client.Fault as exc:
        if 'elrace_purchase_access_check' in exc.faultString:
            sys.exit('Server does not have the check yet: deploy elrace_backend_apis '
                     'and restart Odoo.')
        raise
    if not rows:
        print('No users matched.')
        return

    current = None
    counts = {'same': 0, 'DIFF': 0, 'ERROR': 0}
    for row in rows:
        counts[row['status']] = counts.get(row['status'], 0) + 1
        if row['login'] != current:
            current = row['login']
            print('\n=== %s  roles: %s' % (current, row.get('roles') or '-'))
        extra = []
        if row.get('loses_ids'):
            extra.append('loses=%s' % row['loses_ids'])
        if row.get('gains_ids'):
            extra.append('gains=%s' % row['gains_ids'])
        if row.get('legacy_ms') != '' and row.get('legacy_ms') is not None:
            extra.append('ms %s/%s' % (row.get('legacy_ms'), row.get('odoo_ms')))
        if row.get('error'):
            extra.append(row['error'])
        print('  %-24s %-5s legacy=%-8s odoo=%-8s %s' % (
            row['endpoint'], row['status'], row.get('legacy'), row.get('odoo'),
            '  '.join(extra)))
        if row.get('trace'):
            print('    ' + row['trace'].rstrip().replace('\n', '\n    '))

    print('\nUsers: %s  same: %s  DIFF: %s  ERROR: %s' % (
        len({r['login'] for r in rows}), counts['same'], counts['DIFF'], counts['ERROR']))
    if counts['ERROR']:
        print('ERROR rows would break in enforce mode — fix before enforcing.')

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, 'purchase_access_check_%s.csv' % datetime.now().strftime('%Y%m%d_%H%M'))
    fields = ['login', 'user_id', 'roles', 'endpoint', 'status', 'legacy', 'odoo',
              'loses_ids', 'gains_ids', 'legacy_ms', 'odoo_ms', 'error']
    with open(path, 'w', newline='') as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(rows)
    print('CSV: %s' % path)


def compare_logs():
    days = int(os.environ.get('PURCHASE_COMPARE_DAYS', '3') or 0)
    if days <= 0:
        return
    since = (datetime.now(timezone.utc) - timedelta(days=days)).strftime('%Y-%m-%d %H:%M:%S')
    domain = [('name', '=', 'MOBILE_ACCESS_COMPARE'), ('create_date', '>=', since)]
    modules = env_list('COMPARE_MODULES')
    if modules:
        domain.append(('path', 'in', modules))
    logs = call('ir.logging', 'search_read', domain,
                fields=['create_date', 'path', 'func', 'message'], order='id desc', limit=1000)
    print('\nCompare-mode differences from app traffic (last %s days): %s' % (days, len(logs)))
    for log in logs:
        print('  %s  %-10s %-34s %s' % (
            log['create_date'], log['path'], log['func'], log['message']))
    if logs:
        os.makedirs(OUT, exist_ok=True)
        path = os.path.join(OUT, 'access_compare_logs_%s.csv' % datetime.now().strftime('%Y%m%d_%H%M'))
        with open(path, 'w', newline='') as fh:
            writer = csv.DictWriter(fh, fieldnames=['create_date', 'path', 'func', 'message'],
                                    extrasaction='ignore')
            writer.writeheader()
            writer.writerows(logs)
        print('CSV: %s' % path)


dry_run()
compare_logs()
