# -*- coding: utf-8 -*-
"""Config, render, and event checks. Odoo access is search_read / preview only."""

import re
from datetime import datetime, timedelta

from .rules import DELIVERY_STATES, duplicate_groups, evaluate, within_window

FLAG_FIELDS = (
    'mandatory', 'exclude_labour', 'exclude_actor', 'active', 'takeover', 'shadow',
)
COMPARE_FIELDS = ('channel', 'action', 'title_template', 'body_template') + FLAG_FIELDS
_PLACEHOLDER = re.compile(r'\{[^{}]+\}')
_REAL_STATES = (
    'skipped_flag', 'skipped_labour', 'skipped_actor', 'skipped_muted',
    'skipped_duplicate', 'queued', 'delivered', 'failed',
)
_SHADOW_STATES = (
    'shadow_skipped_flag', 'shadow_skipped_labour', 'shadow_skipped_actor',
    'shadow_skipped_muted', 'shadow_skipped_duplicate', 'shadow_queued',
)


def _text(value):
    if value in (None, False):
        return ''
    return str(value)


def _bool(value):
    return bool(value) and value is not False


def leftovers(text):
    found = []
    if _PLACEHOLDER.search(text or ''):
        found.append('placeholder')
    if 'None' in (text or ''):
        found.append('None')
    if 'False' in (text or ''):
        found.append('False')
    if '  ' in (text or ''):
        found.append('double space')
    if text != (text or '').rstrip(' '):
        found.append('trailing space')
    return found


def parse_since(text):
    raw = (text or '24h').strip().lower()
    number = int(raw[:-1])
    unit = raw[-1]
    if unit == 'h':
        delta = timedelta(hours=number)
    elif unit == 'd':
        delta = timedelta(days=number)
    elif unit == 'm':
        delta = timedelta(minutes=number)
    else:
        raise ValueError('since must look like 24h, 7d, or 30m')
    return (datetime.utcnow() - delta).strftime('%Y-%m-%d %H:%M:%S')


def check_config(client, spec_types):
    fields = [
        'code', 'channel', 'action', 'title_template', 'body_template',
        'category_id', 'mandatory', 'exclude_labour', 'exclude_actor',
        'active', 'takeover',
    ]
    shadow_available = True
    try:
        rows = client.search_read('elrace.notify.type', [], fields + ['shadow'])
    except Exception as exc:
        message = str(exc)
        if 'shadow' in message and ('Invalid field' in message or 'does not exist' in message or 'unknown' in message.lower()):
            shadow_available = False
            rows = client.search_read('elrace.notify.type', [], fields)
        else:
            raise
    categories = {
        row['id']: row.get('code') or ''
        for row in client.search_read('mobile.notification.category', [], ['code'])
    }
    by_code = {}
    for row in rows:
        category = row.get('category_id')
        category_id = category[0] if isinstance(category, (list, tuple)) and category else None
        by_code[row['code']] = {
            'channel': _text(row.get('channel')),
            'action': _text(row.get('action')),
            'title_template': _text(row.get('title_template')),
            'body_template': _text(row.get('body_template')),
            'category': categories.get(category_id, ''),
            'mandatory': _bool(row.get('mandatory')),
            'exclude_labour': _bool(row.get('exclude_labour')),
            'exclude_actor': _bool(row.get('exclude_actor')),
            'active': _bool(row.get('active')),
            'takeover': _bool(row.get('takeover')),
            'shadow': _bool(row.get('shadow')) if shadow_available else None,
            'id': row.get('id'),
        }
    expected = {item['code']: item for item in spec_types}
    issues = []
    for code in sorted(set(expected) - set(by_code)):
        issues.append({'code': code, 'problem': 'missing in Odoo'})
    for code in sorted(set(by_code) - set(expected)):
        issues.append({'code': code, 'problem': 'extra in Odoo', 'link': client.record_link('elrace.notify.type', by_code[code]['id'])})
    if not shadow_available:
        issues.append({'problem': 'shadow is not on this server yet'})
    text_fields = ('channel', 'action', 'title_template', 'body_template')
    for code in sorted(set(expected) & set(by_code)):
        spec = expected[code]
        live = by_code[code]
        link = client.record_link('elrace.notify.type', live['id'])
        if live['category'] != spec.get('category'):
            issues.append({
                'code': code, 'field': 'category',
                'expected': spec.get('category'), 'actual': live['category'], 'link': link,
            })
        for field in COMPARE_FIELDS:
            if field == 'shadow' and live['shadow'] is None:
                continue
            if field in text_fields:
                wanted = '' if spec.get(field) in (None, False) else str(spec.get(field))
                got = live[field]
            else:
                wanted = bool(spec.get(field))
                got = bool(live[field])
            if got != wanted:
                issues.append({
                    'code': code, 'field': field, 'expected': wanted, 'actual': got, 'link': link,
                })
    return {'ok': not issues, 'issues': _dedupe_issues(issues), 'count': len(by_code)}


def _dedupe_issues(issues):
    seen = set()
    out = []
    for issue in issues:
        key = (issue.get('code'), issue.get('field'), issue.get('problem'), str(issue.get('expected')), str(issue.get('actual')))
        if key in seen:
            continue
        seen.add(key)
        out.append(issue)
    return out


def check_render(client, spec_types):
    issues = []
    for spec in spec_types:
        code = spec['code']
        try:
            rendered = client.preview(code, spec.get('sample') or {})
        except Exception as exc:
            issues.append({'code': code, 'problem': 'preview failed: %s' % _safe_error(exc)})
            continue
        for label, actual, expected in (
            ('title', rendered['title'], spec.get('expected_title') or ''),
            ('body', rendered['body'], spec.get('expected_body') or ''),
        ):
            if actual != expected:
                issues.append({
                    'code': code, 'field': label, 'expected': expected, 'actual': actual,
                })
            for problem in leftovers(actual):
                issues.append({'code': code, 'field': label, 'problem': problem, 'actual': actual})
    return {'ok': not issues, 'issues': issues}


def check_events(client, since, type_code=None, include_shadow=False):
    states = list(_REAL_STATES)
    if include_shadow:
        states.extend(_SHADOW_STATES)
    domain = [('create_date', '>=', since), ('state', 'in', states)]
    if type_code:
        domain.append(('type_id.code', '=', type_code))
    rows = client.search_read(
        'elrace.notify.event', domain,
        ['type_id', 'user_id', 'model', 'res_ref', 'event_key', 'state', 'title', 'body', 'create_date', 'params_json'],
        order='id asc',
    )
    events = []
    for row in rows:
        type_field = row.get('type_id')
        events.append({
            'id': row.get('id'),
            'type_code': type_field[1] if isinstance(type_field, (list, tuple)) and len(type_field) > 1 else '',
            'type_id': type_field[0] if isinstance(type_field, (list, tuple)) and type_field else None,
            'user_id': row.get('user_id'),
            'model': row.get('model') or '',
            'res_ref': row.get('res_ref') or '',
            'event_key': row.get('event_key') or '',
            'state': row.get('state'),
            'title': _text(row.get('title')),
            'body': _text(row.get('body')),
            'create_date': row.get('create_date'),
            'params_json': row.get('params_json') or '',
            'link': client.record_link('elrace.notify.event', row.get('id')),
        })
    # type name from the many2one is the type's name, not its code. Resolve codes.
    type_ids = sorted({event['type_id'] for event in events if event['type_id']})
    code_by_id = {}
    if type_ids:
        for row in client.search_read('elrace.notify.type', [('id', 'in', type_ids)], ['code']):
            code_by_id[row['id']] = row['code']
    for event in events:
        event['type_code'] = code_by_id.get(event['type_id']) or event['type_code']

    issues = []
    labour_ids = _labour_user_ids(client)
    for event in events:
        source = _load_source(client, event, labour_ids)
        result = evaluate(event['type_code'], source)
        link = event['link']
        if not result.known:
            issues.append({'code': event['type_code'], 'problem': result.place_detail, 'link': link})
            continue
        if not result.place_ok:
            issues.append({'code': event['type_code'], 'problem': result.place_detail, 'link': link})
        if event['state'] in DELIVERY_STATES and not within_window(event['create_date'], result.trigger_at):
            issues.append({
                'code': event['type_code'],
                'problem': 'event time is outside 120s of %s' % (result.trigger_at or 'the source time'),
                'link': link,
            })
        user_id = event['user_id'][0] if isinstance(event['user_id'], (list, tuple)) and event['user_id'] else None
        if user_id and user_id in labour_ids:
            issues.append({'code': event['type_code'], 'problem': 'labour user %s is present' % user_id, 'link': link})
        if result.actor_id and user_id == result.actor_id and event['state'] in DELIVERY_STATES:
            issues.append({'code': event['type_code'], 'problem': 'actor is a recipient', 'link': link})
        if event['state'] in DELIVERY_STATES:
            try:
                rendered = client.preview(event['type_code'], result.values)
            except Exception as exc:
                issues.append({'code': event['type_code'], 'problem': 'preview failed: %s' % _safe_error(exc), 'link': link})
                rendered = None
            if rendered is not None and (event['title'] != rendered['title'] or event['body'] != rendered['body']):
                issues.append({
                    'code': event['type_code'],
                    'problem': 'title/body differ from preview',
                    'expected_title': rendered['title'], 'actual_title': event['title'],
                    'expected_body': rendered['body'], 'actual_body': event['body'],
                    'link': link,
                })
    grouped = {}
    for event in events:
        if event['state'] not in DELIVERY_STATES:
            continue
        key = (event['type_code'], event['model'], str(event['res_ref']), event.get('event_key') or '')
        grouped.setdefault(key, []).append(event)
    for key, rows_for_source in grouped.items():
        result = evaluate(key[0], _load_source(client, rows_for_source[0], labour_ids))
        actual = set()
        for event in rows_for_source:
            if isinstance(event['user_id'], (list, tuple)) and event['user_id']:
                actual.add(event['user_id'][0])
        recipients_match = (
            actual.issubset(result.recipient_ids)
            if key[0] in ('project.member.added', 'circular.published')
            else actual == result.recipient_ids
        )
        if not recipients_match:
            issues.append({
                'code': key[0],
                'problem': 'recipients differ',
                'expected': sorted(result.recipient_ids),
                'actual': sorted(actual),
                'link': rows_for_source[0]['link'],
            })
    for rows_dup in duplicate_groups(events):
        issues.append({
            'code': rows_dup[0]['type_code'],
            'problem': 'duplicate events',
            'count': len(rows_dup),
            'link': rows_dup[0]['link'],
        })
    return {'ok': not issues, 'issues': issues, 'events': len(events)}


def _safe_error(exc):
    text = str(exc)
    for secret_name in ('ODOO_API_KEY',):
        pass
    return text.split('\n')[0][:300]


def _labour_user_ids(client):
    try:
        rows = client.search_read(
            'hr.employee', [('is_labor', '=', True), ('user_id', '!=', False)], ['user_id'],
        )
    except Exception:
        return set()
    found = set()
    for row in rows:
        user = row.get('user_id')
        if isinstance(user, (list, tuple)) and user:
            found.add(user[0])
    return found


def _load_source(client, event, labour_ids):
    model = event.get('model') or ''
    res_ref = event.get('res_ref') or ''
    source = {
        'exists': False,
        'model': model,
        'res_ref': res_ref,
        'res_id': int(res_ref) if str(res_ref).isdigit() else None,
        'labour_user_ids': sorted(labour_ids),
        'event_key': event.get('event_key') or '',
        'trigger_at': event.get('create_date'),
        'values': {},
    }
    source['line_user_id'] = _line_user_from_key(client, source['event_key'])
    if model.startswith('firestore.') and res_ref:
        source['exists'] = True
        return source
    if not source['res_id'] or not model:
        return source
    try:
        if model == 'employee.requests':
            rows = client.search_read(
                model, [('id', '=', source['res_id'])],
                ['status', 'write_date', 'employee_id', 'name', 'request_type_id', 'leave_request_type'],
                limit=1,
            )
            if not rows:
                return source
            row = rows[0]
            approvals = client.search_read(
                'request.validation.status',
                [('emp_request_id', '=', source['res_id'])],
                ['validation_status', 'skipped', 'write_date', 'validating_users'],
            )
            pending = [line for line in approvals if not line.get('validation_status') and not line.get('skipped')]
            source.update({
                'exists': True,
                'status': row.get('status'),
                'write_date': row.get('write_date'),
                'pending': bool(pending),
                'trigger_at': (pending or approvals or [{}])[-1].get('write_date') or row.get('write_date'),
                'requester_user_id': _employee_user(client, row.get('employee_id')),
                'pending_user_ids': [_m2o_id(line.get('validating_users')) for line in pending],
                'values': {
                    'request_type': _hr_label(row),
                    'reference': _text(row.get('name')),
                },
            })
        elif model == 'purchase.order':
            rows = client.search_read(model, [('id', '=', source['res_id'])], ['name', 'partner_id', 'project_id', 'write_date'], limit=1)
            if not rows:
                return source
            reviews = client.search_read(
                'tier.review', [('model', '=', model), ('res_id', '=', source['res_id'])],
                ['status', 'write_date', 'reviewer_id'],
            )
            pending = [line for line in reviews if line.get('status') == 'pending']
            rejected = [line for line in reviews if line.get('status') == 'rejected']
            approved = [line for line in reviews if line.get('status') == 'approved']
            source.update({
                'exists': True,
                'write_date': rows[0].get('write_date'),
                'trigger_at': (approved[-1].get('write_date') if approved else rows[0].get('write_date')),
                'review_count': len(reviews),
                'reviews_pending': len(pending),
                'reviews_rejected': len(rejected),
                'pending_user_ids': [_m2o_id(line.get('reviewer_id')) for line in pending],
                'project_manager_user_id': _lpo_manager_user(client, rows[0].get('project_id')),
                'values': {
                    'vendor_name': _m2o_name(rows[0].get('partner_id')) or 'Vendor',
                    'request_type': 'LPO',
                    'reference': _text(rows[0].get('name')),
                },
            })
        elif model == 'hr.expense.sheet':
            rows = client.search_read(model, [('id', '=', source['res_id'])], ['state', 'name', 'employee_id', 'write_date'], limit=1)
            if not rows:
                return source
            reviews = client.search_read(
                'tier.review', [('model', '=', model), ('res_id', '=', source['res_id'])],
                ['status', 'reviewer_id', 'write_date'],
            )
            pending = [line for line in reviews if line.get('status') == 'pending']
            source.update({
                'exists': True,
                'state': rows[0].get('state'),
                'paid': rows[0].get('state') == 'done',
                'write_date': rows[0].get('write_date'),
                'trigger_at': (pending[-1].get('write_date') if pending else rows[0].get('write_date')),
                'holder_user_id': _employee_user(client, rows[0].get('employee_id')),
                'pending_user_ids': [_m2o_id(line.get('reviewer_id')) for line in pending],
                'values': {
                    'request_number': _text(rows[0].get('name')),
                    'request_type': 'Petty Cash',
                    'reference': _text(rows[0].get('name')),
                },
            })
        elif model == 'hr.employee':
            rows = client.search_read(model, [('id', '=', source['res_id'])], ['parent_id', 'create_date', 'user_id'], limit=1)
            if not rows:
                return source
            source.update({
                'exists': True,
                'create_date': rows[0].get('create_date'),
                'manager_user_id': _employee_user(client, rows[0].get('parent_id')),
            })
        elif model == 'project.project':
            rows = client.search_read(model, [('id', '=', source['res_id'])], ['name', 'user_id', 'write_date'], limit=1)
            if not rows:
                return source
            staff = client.search_read(
                'staff.list', [('project_id', '=', source['res_id'])], ['employee_id'],
            )
            source.update({
                'exists': True,
                'write_date': rows[0].get('write_date'),
                'manager_user_id': _m2o_id(rows[0].get('user_id')),
                'staff_user_ids': [_employee_user(client, line.get('employee_id')) for line in staff],
                'values': {'project_name': _text(rows[0].get('name'))},
            })
        elif model == 'account.move':
            rows = client.search_read(model, [('id', '=', source['res_id'])], ['move_type', 'name', 'write_date'], limit=1)
            if not rows:
                return source
            reviews = client.search_read(
                'tier.review', [('model', '=', model), ('res_id', '=', source['res_id'])],
                ['status', 'reviewer_id'],
            )
            pending = [line for line in reviews if line.get('status') == 'pending']
            source.update({
                'exists': True,
                'move_type': rows[0].get('move_type'),
                'write_date': rows[0].get('write_date'),
                'pending_user_ids': [_m2o_id(line.get('reviewer_id')) for line in pending],
                'values': {'request_type': 'Invoice', 'reference': _text(rows[0].get('name'))},
            })
        elif model == 'it.hardware.request':
            rows = client.search_read(model, [('id', '=', source['res_id'])], ['name', 'state', 'write_date'], limit=1)
            if not rows:
                return source
            lines = client.search_read(
                'it.hardware.request.approval',
                [('request_id', '=', source['res_id']), ('validation_status', '=', False)],
                ['delegated_user_id', 'validating_user_id'],
            )
            pending_users = []
            for line in lines:
                pending_users.append(_m2o_id(line.get('delegated_user_id')) or _m2o_id(line.get('validating_user_id')))
            source.update({
                'exists': True,
                'write_date': rows[0].get('write_date'),
                'pending_user_ids': pending_users,
                'values': {'request_type': 'IT Request', 'reference': _text(rows[0].get('name'))},
            })
        elif model == 'odx.announcement':
            rows = client.search_read(
                model, [('id', '=', source['res_id'])],
                ['name', 'announcement_active', 'write_date', 'general_announcement', 'company_id'],
                limit=1,
            )
            if not rows:
                return source
            source.update({
                'exists': True,
                'announcement_active': bool(rows[0].get('announcement_active')),
                'published': bool(rows[0].get('announcement_active')),
                'write_date': rows[0].get('write_date'),
                'values': {'circular_title': _text(rows[0].get('name'))},
                'audience_user_ids': _circular_audience(client, source['res_id'], rows[0]),
            })
        elif model == 'hr.employee.document':
            rows = client.search_read(
                model, [('id', '=', source['res_id'])],
                ['write_date', 'expiry_date', 'name', 'employee_ref', 'document_type'],
                limit=1,
            )
            if rows:
                expiry = rows[0].get('expiry_date')
                days = _days_from_event_key(source.get('event_key'))
                if days is None:
                    days = _days_until(expiry)
                type_name = _m2o_name(rows[0].get('document_type')) or _text(rows[0].get('name')) or 'Document'
                source.update({
                    'exists': True,
                    'write_date': rows[0].get('write_date'),
                    'days_to_expiry': days,
                    'cron_at': event.get('create_date'),
                    'owner_user_id': _employee_user(client, rows[0].get('employee_ref')),
                    'values': {
                        'document_type': type_name,
                        'expiry_date': _expiry_label(expiry),
                    },
                })
        else:
            rows = client.search_read(model, [('id', '=', source['res_id'])], ['write_date'], limit=1)
            if rows:
                source.update({'exists': True, 'write_date': rows[0].get('write_date'), 'trigger_at': rows[0].get('write_date')})
    except Exception:
        return source
    return source


def _line_user_from_key(client, event_key):
    text = event_key or ''
    if ':' not in text:
        return None
    kind, raw_id = text.split(':', 1)
    if not raw_id.isdigit():
        return None
    line_id = int(raw_id)
    try:
        if kind == 'validation':
            rows = client.search_read('request.validation.status', [('id', '=', line_id)], ['validating_users'], limit=1)
            return _m2o_id(rows[0].get('validating_users')) if rows else None
        if kind == 'tier':
            rows = client.search_read('tier.review', [('id', '=', line_id)], ['reviewer_id'], limit=1)
            return _m2o_id(rows[0].get('reviewer_id')) if rows else None
        if kind == 'it':
            rows = client.search_read(
                'it.hardware.request.approval', [('id', '=', line_id)],
                ['delegated_user_id', 'validating_user_id'], limit=1,
            )
            if not rows:
                return None
            return _m2o_id(rows[0].get('delegated_user_id')) or _m2o_id(rows[0].get('validating_user_id'))
    except Exception:
        return None
    return None


def _lpo_manager_user(client, project_field):
    analytic_id = _m2o_id(project_field)
    if not analytic_id:
        return None
    try:
        projects = client.search_read(
            'project.project', [('analytic_account_id', '=', analytic_id)], ['user_id'], limit=1,
        )
    except Exception:
        return None
    if not projects:
        return None
    return _m2o_id(projects[0].get('user_id'))


def _circular_audience(client, announcement_id, row):
    try:
        links = client.search_read(
            'odx.announcement.users', [('announcement_id', '=', announcement_id)], ['user_id'],
        )
    except Exception:
        links = []
    selected = [user_id for user_id in (_m2o_id(link.get('user_id')) for link in links) if user_id]
    if selected:
        return selected
    domain = [('share', '=', False), ('active', '=', True)]
    company_id = _m2o_id(row.get('company_id'))
    if company_id:
        domain.append(('company_ids', 'in', [company_id]))
    try:
        users = client.search_read('res.users', domain, ['id'])
    except Exception:
        return []
    return [user['id'] for user in users if user.get('id')]


def _days_from_event_key(event_key):
    parts = (event_key or '').split(':')
    if len(parts) >= 3 and parts[-1].isdigit():
        return int(parts[-1])
    return None


def _days_until(expiry):
    if not expiry:
        return None
    try:
        day = datetime.strptime(str(expiry)[:10], '%Y-%m-%d').date()
    except ValueError:
        return None
    return (day - datetime.utcnow().date()).days


def _expiry_label(expiry):
    if not expiry:
        return ''
    try:
        day = datetime.strptime(str(expiry)[:10], '%Y-%m-%d')
    except ValueError:
        return str(expiry)
    return day.strftime('%d %b %Y')


def _hr_label(row):
    name = _m2o_name(row.get('request_type_id')) or _text(row.get('leave_request_type')) or 'Request'
    name = name.replace('_', ' ').strip()
    if not name.lower().endswith('request'):
        name = '%s Request' % name
    return name


def _m2o_id(value):
    if isinstance(value, (list, tuple)) and value:
        return value[0]
    return None


def _m2o_name(value):
    if isinstance(value, (list, tuple)) and len(value) > 1:
        return value[1]
    return ''


def _employee_user(client, employee):
    employee_id = _m2o_id(employee)
    if not employee_id:
        return None
    rows = client.search_read('hr.employee', [('id', '=', employee_id)], ['user_id'], limit=1)
    if not rows:
        return None
    return _m2o_id(rows[0].get('user_id'))
