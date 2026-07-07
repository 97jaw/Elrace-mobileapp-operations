# Attendance Records API — Paginated records for the Records tab
#
# Add controller method → elrace_backend_apis/controllers/attendance_controller.py
# Add service method    → elrace_backend_apis/services/attendance_service.py
#
# Route:
#   POST /api/attendance/records
#
# Request params:
#   date_from       str   "YYYY-MM-DD"          (required)
#   date_to         str   "YYYY-MM-DD"          (required, max 31-day window)
#   keyword         str   employee name filter  (optional)
#   attendance_type str   see TYPE_CHOICES below (optional, default "all")
#   limit           int   1–200, default 50     (optional)
#   offset          int   >= 0, default 0       (optional)
#
# TYPE_CHOICES: all | ontime | late | absent | jm_tp | leaves
#   "jm_tp"  → x_attendance_type in (jm_morning, jm_afternoon, temp_permission)
#   "leaves" → x_attendance_type in (short, sick, annual, death, maternity, parental, compensation)
#
# Response (on success):
#   {
#     "status": "success",
#     "data": {
#       "records": [ <RecordDict>, ... ],
#       "total": 247,
#       "limit": 50,
#       "offset": 0,
#       "date_from": "2026-07-01",
#       "date_to":   "2026-07-31"
#     }
#   }
#
# RecordDict fields:
#   id, employee_id, employee_name, employee_image_url,
#   check_in (ISO datetime), check_out (ISO datetime | null),
#   check_date ("YYYY-MM-DD"), worked_hours (float),
#   x_attendance_type (str), x_status_clock (str),
#   day_status (human label), x_needs_review (bool)

from datetime import date as _date, timedelta
import logging

_logger = logging.getLogger(__name__)

_JM_TP_TYPES = ('jm_morning', 'jm_afternoon', 'temp_permission')
_LEAVE_TYPES  = ('short', 'sick', 'annual', 'death', 'maternity', 'parental', 'compensation')

# ─── Helpers ─────────────────────────────────────────────────────────────────

def _day_status_label(att_type, status_clock):
    """Map (x_attendance_type, x_status_clock) → human label."""
    if att_type == 'absent':        return 'Absent'
    if att_type == 'jm_morning':    return 'JM Morning'
    if att_type == 'jm_afternoon':  return 'JM Afternoon'
    if att_type == 'temp_permission': return 'Temp Permission'
    _leave_labels = {
        'short': 'Short Leave', 'sick': 'Sick Leave',
        'annual': 'Annual Leave', 'death': 'Death Leave',
        'maternity': 'Maternity', 'parental': 'Parental Leave',
        'compensation': 'Compensation',
    }
    if att_type in _leave_labels:   return _leave_labels[att_type]
    if status_clock == 'ontime':    return 'On Time'
    if status_clock == 'late':      return 'Late'
    if att_type:                    return att_type.replace('_', ' ').title()
    return 'Present'


def _emp_image_url(emp_id):
    return f'/web/image/hr.employee/{emp_id}/image_1920'


# ─── Controller method (paste inside AttendanceController class) ──────────────
#
# from odoo import http
# from odoo.http import request
#
# class AttendanceController(http.Controller):
#
#   @http.route(
#       '/api/attendance/records',
#       type='json', auth='none', methods=['POST'],
#       website=False, csrf=False
#   )
#   def get_attendance_records(self, date_from=None, date_to=None,
#                              keyword=None, attendance_type=None,
#                              limit=50, offset=0):
#       auth = self._validate_mobile_request()
#       if not auth['status']:
#           return self._error(auth['message'], auth.get('code'))
#       from ..services.attendance_service import AttendanceService
#       svc = AttendanceService(request.env)
#       return svc.get_attendance_records(
#           date_from, date_to, keyword, attendance_type, limit, offset
#       )


# ─── Service method (paste inside AttendanceService class) ────────────────────

def get_attendance_records(self, date_from_str, date_to_str,
                           keyword=None, attendance_type=None,
                           limit=50, offset=0):
    """
    Paginated flat attendance records for the mobile Records tab.

    self — AttendanceService instance (provides self.env, self._ok, self._err).
    """
    try:
        # ── Date validation ───────────────────────────────────────────────
        today = _date.today()
        d_from = _date.fromisoformat(str(date_from_str or today))
        d_to   = _date.fromisoformat(str(date_to_str   or today))
        if d_to < d_from:
            d_from, d_to = d_to, d_from
        # Hard cap: 31-day window
        if (d_to - d_from).days > 30:
            d_from = d_to - timedelta(days=30)

        limit  = max(1, min(int(limit  or 50),  200))
        offset = max(0,       int(offset or 0))

        # ── Build domain ──────────────────────────────────────────────────
        domain = [
            ('check_date', '>=', str(d_from)),
            ('check_date', '<=', str(d_to)),
            ('employee_id.active', '=', True),
        ]

        if keyword and keyword.strip():
            domain.append(('employee_id.name', 'ilike', keyword.strip()))

        att_type = (attendance_type or 'all').lower().strip()
        if att_type not in ('all', ''):
            if att_type == 'jm_tp':
                domain.append(('x_attendance_type', 'in', list(_JM_TP_TYPES)))
            elif att_type == 'leaves':
                domain.append(('x_attendance_type', 'in', list(_LEAVE_TYPES)))
            elif att_type == 'ontime':
                domain.append(('x_status_clock', '=', 'ontime'))
            elif att_type == 'late':
                domain.append(('x_status_clock', '=', 'late'))
            elif att_type == 'absent':
                domain.append(('x_attendance_type', '=', 'absent'))
            else:
                domain.append(('x_attendance_type', '=', att_type))

        # ── Query ─────────────────────────────────────────────────────────
        Att = self.env['hr.attendance'].sudo()
        fields = [
            'id', 'employee_id',
            'check_in', 'check_out',
            'check_date', 'worked_hours',
            'x_attendance_type', 'x_status_clock', 'x_needs_review',
        ]

        total   = Att.search_count(domain)
        raw_recs = Att.search_read(
            domain, fields,
            order='check_date desc, check_in desc',
            limit=limit, offset=offset,
        )

        # ── Serialise ─────────────────────────────────────────────────────
        records = []
        for r in raw_recs:
            emp      = r['employee_id']            # (id, name) tuple
            emp_id   = emp[0] if isinstance(emp, (list, tuple)) else int(emp or 0)
            emp_name = emp[1] if isinstance(emp, (list, tuple)) else ''

            a_type = r.get('x_attendance_type') or ''
            s_clk  = r.get('x_status_clock')    or ''
            ci     = r.get('check_in')
            co     = r.get('check_out')

            records.append({
                'id':                 r['id'],
                'employee_id':        emp_id,
                'employee_name':      emp_name,
                'employee_image_url': _emp_image_url(emp_id),
                'check_in':           str(ci) if ci else None,
                'check_out':          str(co) if co else None,
                'check_date':         str(r.get('check_date') or ''),
                'worked_hours':       round(float(r.get('worked_hours') or 0), 2),
                'x_attendance_type':  a_type,
                'x_status_clock':     s_clk,
                'day_status':         _day_status_label(a_type, s_clk),
                'x_needs_review':     bool(r.get('x_needs_review')),
            })

        return self._ok({
            'records':   records,
            'total':     total,
            'limit':     limit,
            'offset':    offset,
            'date_from': str(d_from),
            'date_to':   str(d_to),
        })

    except Exception as exc:
        _logger.error('AttendanceService.get_attendance_records: %s', exc, exc_info=True)
        return self._err(str(exc))
