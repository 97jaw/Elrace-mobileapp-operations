# -*- coding: utf-8 -*-
"""Place, time, and recipient rules. One function per notification type. No Odoo."""

from datetime import datetime

WINDOW_SECONDS = 120
DELIVERY_STATES = ('queued', 'delivered', 'shadow_queued')

# trigger_at field, per type: the source moment the event must sit within 120s of.
# approval.waiting: pending tier/validation line write_date.
#   Includes vendor bills (account.move in_invoice/in_refund); label is Invoice.
# hr.request.approved / hr.request.rejected: request write_date (state change)
# hr.employee.assigned: employee create_date (confirm)
# purchase.lpo.issued: latest approved review write_date
# expense.petty_cash.paid: sheet write_date when it became paid
# project.manager.assigned: project write_date (user_id change)
# project.member.added: project write_date (staff users)
# document.expiry: cron_at (the daily run, not the document write)
# share.* / document.signed / tasks / tickets / chat: trigger_at on the snapshot
# circular.published: announcement write_date
# account.vendor_invoice: channel none, no mobile recipients. On takeover it only
#   retires requester "INVOICE Approved" and "INVOICE Fully Approved".
# attendance.*: no mobile send; trigger_at unused


class RuleResult(object):
    def __init__(self, known, place_ok, place_detail, trigger_at, recipient_ids, actor_id, values):
        self.known = known
        self.place_ok = place_ok
        self.place_detail = place_detail
        self.trigger_at = trigger_at
        self.recipient_ids = set(recipient_ids or [])
        self.actor_id = actor_id
        self.values = dict(values or {})


def parse_stamp(value):
    if not value or value is False:
        return None
    if isinstance(value, datetime):
        return value
    text = str(value).replace('T', ' ')[:19]
    try:
        return datetime.strptime(text, '%Y-%m-%d %H:%M:%S')
    except ValueError:
        return None


def within_window(event_at, trigger_at, seconds=WINDOW_SECONDS):
    left = parse_stamp(event_at)
    right = parse_stamp(trigger_at)
    if left is None or right is None:
        return False
    return abs((left - right).total_seconds()) <= seconds


def duplicate_groups(events):
    """Groups of delivery-state events that share type, model, res_ref, user, event_key."""
    buckets = {}
    for event in events or []:
        if event.get('state') not in DELIVERY_STATES:
            continue
        key = (
            event.get('type_code') or '',
            event.get('model') or '',
            str(event.get('res_ref') or ''),
            _m2o(event.get('user_id')),
            event.get('event_key') or '',
        )
        buckets.setdefault(key, []).append(event)
    return [rows for rows in buckets.values() if len(rows) > 1]


def evaluate(type_code, source):
    source = source or {}
    fn = RULES.get(type_code)
    if fn is None:
        return RuleResult(
            False, False, 'unknown type %s' % type_code, None, [], None, {},
        )
    return fn(source)


def _m2o(value):
    if isinstance(value, (list, tuple)):
        value = value[0] if value else None
    if value in (None, False, ''):
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _id_set(source, key):
    raw = source.get(key) or []
    if isinstance(raw, (int, str)) or (
        isinstance(raw, (list, tuple))
        and raw
        and not isinstance(raw[0], (list, tuple, dict))
    ):
        if not isinstance(raw, (list, tuple)):
            raw = [raw]
    found = set()
    for item in raw:
        ident = _m2o(item)
        if not ident:
            continue
        found.add(ident)
    return found


def _clean_recipients(source, ids):
    labour = _id_set(source, 'labour_user_ids')
    actor = _m2o(source.get('actor_user_id'))
    cleaned = set(ids or []) - labour
    if actor:
        cleaned.discard(actor)
    return cleaned


def _values(source):
    raw = source.get('values')
    if isinstance(raw, dict):
        return dict(raw)
    return {}


def _result(source, place_ok, detail, trigger_at, recipient_ids):
    return RuleResult(
        True,
        bool(place_ok),
        detail,
        trigger_at,
        _clean_recipients(source, recipient_ids),
        _m2o(source.get('actor_user_id')),
        _values(source),
    )


def _missing(source, expected_model):
    return _result(source, False, 'source %s is missing' % expected_model, None, [])


def _approval_waiting(source):
    allowed = {
        'employee.requests', 'purchase.order', 'hr.expense.sheet',
        'account.move', 'firestore.signature', 'it.hardware.request',
    }
    if not source.get('exists') or source.get('model') not in allowed:
        return _result(source, False, 'waiting source is missing or the wrong model', None, [])
    # Vendor bills use the same pending-reviewer push as customer invoices.
    line_user = _m2o(source.get('line_user_id'))
    pending = {line_user} if line_user else _id_set(source, 'pending_user_ids')
    if not pending:
        return _result(source, False, 'no current pending reviewer', source.get('trigger_at'), [])
    return _result(
        source, True, 'pending reviewer on %s' % source.get('model'),
        source.get('trigger_at'), pending,
    )


def _hr_approved(source):
    if not source.get('exists') or source.get('model') != 'employee.requests':
        return _missing(source, 'employee.requests')
    final = source.get('status') == 'approve' and not source.get('pending')
    return _result(
        source, final,
        'final approved' if final else 'request is not in its final approved state',
        source.get('write_date'),
        [_m2o(source.get('requester_user_id'))] if final else [],
    )


def _hr_rejected(source):
    if not source.get('exists') or source.get('model') != 'employee.requests':
        return _missing(source, 'employee.requests')
    refused = source.get('status') == 'refuse'
    return _result(
        source, refused,
        'rejected' if refused else 'request is not rejected',
        source.get('write_date'),
        [_m2o(source.get('requester_user_id'))] if refused else [],
    )


def _employee_assigned(source):
    if not source.get('exists') or source.get('model') != 'hr.employee':
        return _missing(source, 'hr.employee')
    manager = _m2o(source.get('manager_user_id'))
    ok = bool(manager)
    return _result(
        source, ok,
        'manager assigned' if ok else 'employee has no manager user',
        source.get('create_date'),
        [manager] if ok else [],
    )


def _lpo_issued(source):
    if not source.get('exists') or source.get('model') != 'purchase.order':
        return _missing(source, 'purchase.order')
    final = (
        int(source.get('review_count') or 0) > 0
        and int(source.get('reviews_pending') or 0) == 0
        and int(source.get('reviews_rejected') or 0) == 0
    )
    manager = _m2o(source.get('project_manager_user_id'))
    return _result(
        source, final,
        'final PO tier' if final else 'PO is not past the final tier',
        source.get('trigger_at'),
        [manager] if final and manager else [],
    )


def _vendor_invoice(source):
    # No push recipients. Takeover only retires "INVOICE Approved" and
    # "INVOICE Fully Approved". The pending reviewer is approval.waiting.
    move_ok = source.get('move_type') in ('in_invoice', 'in_refund')
    return _result(
        source, bool(source.get('exists') and move_ok),
        'vendor bill (no mobile recipients)' if move_ok else 'not a vendor bill',
        source.get('write_date'),
        [],
    )


def _petty_paid(source):
    if not source.get('exists') or source.get('model') != 'hr.expense.sheet':
        return _missing(source, 'hr.expense.sheet')
    paid = bool(source.get('paid')) or source.get('state') == 'done'
    holder = _m2o(source.get('holder_user_id'))
    return _result(
        source, paid,
        'sheet is paid' if paid else 'sheet is not paid',
        source.get('write_date'),
        [holder] if paid and holder else [],
    )


def _project_manager(source):
    if not source.get('exists') or source.get('model') != 'project.project':
        return _missing(source, 'project.project')
    manager = _m2o(source.get('manager_user_id'))
    return _result(
        source, bool(manager),
        'project manager set' if manager else 'project has no user_id',
        source.get('write_date'),
        [manager] if manager else [],
    )


def _project_member(source):
    if not source.get('exists') or source.get('model') != 'project.project':
        return _missing(source, 'project.project')
    staff = _id_set(source, 'staff_user_ids')
    return _result(
        source, bool(staff),
        'staff on the project' if staff else 'project has no staff users',
        source.get('write_date') or source.get('trigger_at'),
        staff,
    )


def _document_expiry(source):
    if not source.get('exists') or source.get('model') != 'hr.employee.document':
        return _missing(source, 'hr.employee.document')
    days = source.get('days_to_expiry')
    due = days in (30, 7, 1)
    owner = _m2o(source.get('owner_user_id'))
    return _result(
        source, due,
        'expiry threshold %s' % days if due else 'days-to-expiry is not 30, 7, or 1',
        source.get('cron_at') or source.get('trigger_at'),
        [owner] if due and owner else [],
    )


def _share(source, model, label, recipient_key):
    if not source.get('exists') or source.get('model') != model:
        return _result(source, False, '%s source is missing' % label, None, [])
    recipient = _m2o(source.get(recipient_key))
    return _result(
        source, bool(recipient),
        label,
        source.get('trigger_at'),
        [recipient] if recipient else [],
    )


def _share_note(source):
    return _share(source, 'firestore.note', 'note shared', 'recipient_user_id')


def _share_document(source):
    if source.get('exists'):
        return _share(
            source, source.get('model') or '', 'document shared', 'recipient_user_id',
        )
    return _result(source, False, 'document share source is missing', None, [])


def _document_signed(source):
    return _share(source, 'firestore.signature', 'document signed', 'sender_user_id')


def _circular(source):
    if not source.get('exists') or source.get('model') != 'odx.announcement':
        return _missing(source, 'odx.announcement')
    published = bool(source.get('published') or source.get('announcement_active'))
    audience = _id_set(source, 'audience_user_ids')
    return _result(
        source, bool(published and audience),
        'published circular' if published else 'announcement is not published',
        source.get('write_date'),
        audience if published else [],
    )


def _none_type(source):
    return _result(source, True, 'mobile send stays off', source.get('trigger_at'), [])


def _snapshot_people(source, model, label):
    if not source.get('exists') or source.get('model') != model:
        return _result(source, False, '%s source is missing' % label, None, [])
    if not source.get('res_ref') and not source.get('res_id'):
        return _result(source, False, '%s has no record id' % label, None, [])
    return _result(
        source, True, label, source.get('trigger_at'),
        _id_set(source, 'recipient_user_ids'),
    )


def _task(source):
    return _snapshot_people(source, 'firestore.todo', 'task')


def _ticket(source):
    return _snapshot_people(source, 'firestore.ticket', 'ticket')


def _chat(source, model):
    return _snapshot_people(source, model, 'chat')


RULES = {
    'approval.waiting': _approval_waiting,
    'hr.request.approved': _hr_approved,
    'hr.request.rejected': _hr_rejected,
    'hr.employee.assigned': _employee_assigned,
    'purchase.lpo.issued': _lpo_issued,
    'account.vendor_invoice': _vendor_invoice,
    'expense.petty_cash.paid': _petty_paid,
    'project.manager.assigned': _project_manager,
    'project.member.added': _project_member,
    'document.expiry': _document_expiry,
    'share.note': _share_note,
    'share.document': _share_document,
    'document.signed': _document_signed,
    'circular.published': _circular,
    'attendance.checkin_reminder': _none_type,
    'attendance.biotime_sync': _none_type,
    'task.assigned': _task,
    'task.comment': _task,
    'task.completed': _task,
    'task.deadline_24h': _task,
    'task.deadline_1h': _task,
    'ticket.assigned': _ticket,
    'ticket.updated': _ticket,
    'ticket.reassigned': _ticket,
    'ticket.closed': _ticket,
    'chat.direct': lambda source: _chat(source, 'firestore.chat'),
    'chat.group': lambda source: _chat(source, 'firestore.chat'),
}
