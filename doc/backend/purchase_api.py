# Purchase Management API — Reference Controller
#
# Add to elrace_backend_apis/controllers/purchase_controller.py
# Register in __init__.py (from . import purchase_controller)
#
# All routes are READ-ONLY (no write/create/unlink).
# Workflow actions (confirm, approve, reject) stay in the tier_review flow.
#
# Routes:
#   POST /api/purchase/overview
#   POST /api/purchase/requisitions
#   POST /api/purchase/requisition_details
#   POST /api/purchase/rfqs
#   POST /api/purchase/invoice_receiving
#   POST /api/purchase/invoice_receiving_details
#
# Role flags injected into login payload (see login controller):
#   is_purchase_rep      bool
#   is_purchase_manager  bool
#   is_doc_controller    bool
#   purchase_scope       "own" | "department" | "all"
#   role_capabilities:   x_is_purchase_rep, x_is_purchase_manager, x_is_doc_controller

from datetime import datetime, date
from dateutil.relativedelta import relativedelta

from odoo import http
from odoo.http import request


# ---------------------------------------------------------------------------
# Helpers (mirrors timesheet_site_api.py conventions)
# ---------------------------------------------------------------------------

def _json_ok(payload):
    return {"success": True, **payload}


def _json_err(msg, code=400):
    return {"success": False, "error": msg, "code": code}


def _login_employee(env):
    uid = request.session.uid
    if not uid:
        return env["hr.employee"].browse()
    user = env["res.users"].sudo().browse(uid)
    emp = user.employee_id
    if not emp:
        emp = env["hr.employee"].sudo().search([("user_id", "=", uid)], limit=1)
    return emp


def _bool_flag(value):
    """Loose parse: True/1/'1'/'yes'/'true' → True, else False."""
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value != 0
    if isinstance(value, str):
        return value.lower() in ("1", "true", "yes")
    return False


# ---------------------------------------------------------------------------
# Purchase role resolution
# Reads emp_mobile_conf.role_ids (m2m on hr.employee or emp_mobile_conf model).
# Role codes expected on emp_mobile_conf.role_line_ids:
#   'purchase_rep'      → is_purchase_rep   + scope 'own'
#   'purchase_manager'  → is_purchase_manager + scope 'department' or 'all'
#   'doc_controller'    → is_doc_controller + scope receiving
#
# Adjust field/model names to match the actual Odoo customisation.
# ---------------------------------------------------------------------------

def _purchase_roles(emp):
    """Return dict of purchase role flags + scope for the employee."""
    result = {
        "is_purchase_rep": False,
        "is_purchase_manager": False,
        "is_doc_controller": False,
        "purchase_scope": "none",
    }
    if not emp:
        return result

    # Prefer explicit boolean fields on hr.employee if they exist
    if hasattr(emp, "x_is_purchase_rep"):
        result["is_purchase_rep"] = _bool_flag(emp.x_is_purchase_rep)
    if hasattr(emp, "x_is_purchase_manager"):
        result["is_purchase_manager"] = _bool_flag(emp.x_is_purchase_manager)
    if hasattr(emp, "x_is_doc_controller"):
        result["is_doc_controller"] = _bool_flag(emp.x_is_doc_controller)

    # Fall back to role_line_ids on emp_mobile_conf (adjust model if needed)
    EmpConf = request.env.get("emp.mobile.conf")
    if EmpConf is not None:
        conf = EmpConf.sudo().search([("employee_id", "=", emp.id)], limit=1)
        if conf:
            role_codes = [
                (getattr(line, "role_code", "") or "").lower()
                for line in getattr(conf, "role_line_ids", [])
            ]
            if "purchase_rep" in role_codes:
                result["is_purchase_rep"] = True
            if "purchase_manager" in role_codes:
                result["is_purchase_manager"] = True
            if "doc_controller" in role_codes:
                result["is_doc_controller"] = True

    # Scope: manager > rep > controller
    if result["is_purchase_manager"]:
        # All company POs if admin flag set, otherwise department
        result["purchase_scope"] = "all" if getattr(emp, "x_purchase_scope_all", False) else "department"
    elif result["is_purchase_rep"]:
        result["purchase_scope"] = "own"
    elif result["is_doc_controller"]:
        result["purchase_scope"] = "receiving"

    return result


def _scope_domain_po(emp, roles):
    """Domain for purchase.order records visible to this employee."""
    scope = roles.get("purchase_scope", "none")
    if scope == "all":
        return []
    if scope == "department":
        dept_id = emp.department_id.id if emp.department_id else False
        if dept_id:
            # POs linked to any employee in the same department
            return [("department_id", "=", dept_id)]
        return []
    if scope == "own":
        return [
            "|",
            ("x_purchase_representative_id", "=", emp.id),
            ("x_requested_by", "=", emp.id),
        ]
    if scope == "receiving":
        # Doc controller sees POs they are assigned to (adjust field name)
        return [("x_doc_controller_id", "=", emp.id)]
    return [("id", "=", -1)]  # no access


def _scope_domain_mr(emp, roles):
    """Domain for purchase.requisition (MR) records visible to this employee."""
    scope = roles.get("purchase_scope", "none")
    if scope in ("all",):
        return []
    if scope == "department":
        dept_id = emp.department_id.id if emp.department_id else False
        if dept_id:
            return [("department_id.id", "=", dept_id)]
        return []
    if scope in ("own", "receiving"):
        return [
            "|",
            ("requested_by", "=", emp.id),
            ("x_purchase_rep_id", "=", emp.id),
        ]
    return [("id", "=", -1)]


def _scope_domain_invoice(emp, roles):
    """Domain for account.move (vendor bill / invoice receiving) records."""
    scope = roles.get("purchase_scope", "none")
    if scope == "all":
        return [("move_type", "=", "in_invoice")]
    if scope == "department":
        dept_id = emp.department_id.id if emp.department_id else False
        if dept_id:
            return [
                ("move_type", "=", "in_invoice"),
                ("x_department_id", "=", dept_id),
            ]
        return [("move_type", "=", "in_invoice")]
    if scope in ("own", "receiving"):
        return [
            ("move_type", "=", "in_invoice"),
            "|",
            ("x_doc_controller_id", "=", emp.id),
            ("x_purchase_rep_id", "=", emp.id),
        ]
    return [("id", "=", -1)]


# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------

def _format_date(d):
    if not d:
        return ""
    if isinstance(d, (datetime, date)):
        return d.strftime("%d/%m/%Y")
    return str(d)


def _format_datetime(d):
    if not d:
        return ""
    if isinstance(d, datetime):
        return d.strftime("%d/%m/%Y %H:%M")
    return str(d)


def _abbreviate_amount(amount):
    """Return abbreviated AED display string: 84213 → 'AED 84K', 1250000 → 'AED 1.2M'."""
    if amount is None:
        return "AED 0"
    if amount >= 1_000_000:
        return f"AED {amount / 1_000_000:.1f}M".rstrip("0").rstrip(".")
    if amount >= 1_000:
        k = amount / 1_000
        s = f"{k:.1f}K" if k != int(k) else f"{int(k)}K"
        return f"AED {s}"
    return f"AED {int(amount)}"


def _mom_delta(current, previous):
    """Month-over-month signed percentage, or None if not calculable."""
    if not previous:
        return None
    return round((current - previous) / previous * 100, 1)


# ---------------------------------------------------------------------------
# MR (purchase.requisition) serializers
# Adjust field names to match the actual Odoo MR model (may be custom).
# ---------------------------------------------------------------------------

# MR Odoo states → mobile display states (visible label used in app)
_MR_STATE_MAP = {
    "draft": "NEW",
    "in_progress": "WAITING DEPARTMENT APPROVAL",
    "waiting_ir": "WAITING IR APPROVAL",
    "approved": "APPROVED",
    "rfq_created": "RFQ CREATED",
    "received": "RECEIVED",
    "rejected": "REJECT",
}


def _mr_state_label(odoo_state):
    return _MR_STATE_MAP.get((odoo_state or "").lower(), (odoo_state or "").upper())


def _mr_card(mr, my_employee_id):
    """Serialize one MR for the list endpoint."""
    my_role = ""
    if hasattr(mr, "requested_by") and mr.requested_by.id == my_employee_id:
        my_role = "requester"
    elif hasattr(mr, "x_task_assign_to") and mr.x_task_assign_to.id == my_employee_id:
        my_role = "assignee"

    return {
        "id": mr.id,
        "name": mr.name or "",
        "requester": mr.requested_by.name if hasattr(mr, "requested_by") and mr.requested_by else "",
        "requester_photo": (
            f"/web/image/hr.employee/{mr.requested_by.id}/image_128"
            if hasattr(mr, "requested_by") and mr.requested_by else ""
        ),
        "department": mr.department_id.name if mr.department_id else "",
        "project": (
            mr.account_analytic_id.name
            if hasattr(mr, "account_analytic_id") and mr.account_analytic_id
            else ""
        ),
        "wo_po": getattr(mr, "x_wo_po", "") or "",
        "request_date": _format_datetime(mr.date_start) if hasattr(mr, "date_start") else "",
        "deadline": _format_date(mr.date_end) if hasattr(mr, "date_end") else "",
        "state": _mr_state_label(mr.state),
        "odoo_state": mr.state or "",
        "priority": getattr(mr, "priority", "normal") or "normal",
        "my_role": my_role,
        "proposed_vendor": (
            mr.partner_id.name if hasattr(mr, "partner_id") and mr.partner_id else ""
        ),
        "project_manager": (
            mr.x_project_manager_id.name
            if hasattr(mr, "x_project_manager_id") and mr.x_project_manager_id
            else ""
        ),
    }


def _mr_line(line):
    return {
        "id": line.id,
        "product": line.product_id.name if line.product_id else "",
        "description": line.name or "",
        "qty": line.product_qty,
        "uom": line.product_uom_id.name if hasattr(line, "product_uom_id") and line.product_uom_id else "",
        "scheduled_date": _format_date(line.schedule_date) if hasattr(line, "schedule_date") else "",
    }


# ---------------------------------------------------------------------------
# PO/RFQ serializers (purchase.order)
# ---------------------------------------------------------------------------

_PO_STATE_MAP = {
    "draft": "RFQ",
    "sent": "RFQ SENT",
    "to approve": "WAITING APPROVAL",
    "purchase": "PURCHASE ORDER",
    "done": "RECEIVED",
    "cancel": "CANCELLED",
}


def _po_state_label(odoo_state):
    return _PO_STATE_MAP.get((odoo_state or "").lower(), (odoo_state or "").upper())


def _po_card(po):
    return {
        "id": po.id,
        "name": po.name or "",
        "partner_id": po.partner_id.name if po.partner_id else "",
        "client_photo": (
            f"/web/image/res.partner/{po.partner_id.id}/image_128"
            if po.partner_id else ""
        ),
        "project": getattr(po, "x_project", "") or getattr(po, "x_project_id", False) and po.x_project_id.name or "",
        "requested_by": (
            po.x_requested_by.name
            if hasattr(po, "x_requested_by") and po.x_requested_by
            else ""
        ),
        "requested_by_user_photo": (
            f"/web/image/hr.employee/{po.x_requested_by.id}/image_128"
            if hasattr(po, "x_requested_by") and po.x_requested_by
            else ""
        ),
        "requester_manager": (
            po.x_requester_manager_id.name
            if hasattr(po, "x_requester_manager_id") and po.x_requester_manager_id
            else ""
        ),
        "date_order": _format_datetime(po.date_order),
        "amount_total": po.amount_total,
        "amount_display": _abbreviate_amount(po.amount_total),
        "state": _po_state_label(po.state),
        "odoo_state": po.state or "",
        "currency": po.currency_id.name if po.currency_id else "AED",
        "department": getattr(po, "department_id", False) and po.department_id.name or "",
        "attachments": [
            {"id": a.id, "name": a.name, "url": f"/web/content/{a.id}?download=true"}
            for a in po.attachment_ids
        ] if hasattr(po, "attachment_ids") else [],
    }


# ---------------------------------------------------------------------------
# Invoice receiving serializers (account.move)
# ---------------------------------------------------------------------------

_INV_STATE_MAP = {
    "draft": "DRAFT",
    "posted": "CONFIRMED",
    "cancel": "CANCELLED",
}


def _inv_card(inv):
    lpo_no = ""
    if hasattr(inv, "invoice_origin") and inv.invoice_origin:
        lpo_no = inv.invoice_origin
    elif hasattr(inv, "purchase_id") and inv.purchase_id:
        lpo_no = inv.purchase_id.name
    return {
        "id": inv.id,
        "invoice_no": inv.ref or inv.name or "",
        "lpo_no": lpo_no,
        "invoice_date": _format_date(inv.invoice_date),
        "invoicing_date": _format_date(
            inv.invoice_date_due or inv.invoice_date
        ),
        "amount": inv.amount_total,
        "amount_display": _abbreviate_amount(inv.amount_total),
        "state": _INV_STATE_MAP.get((inv.payment_state or inv.state or "").lower(),
                                    (inv.state or "").upper()),
        "currency": inv.currency_id.name if inv.currency_id else "AED",
        "partner": inv.partner_id.name if inv.partner_id else "",
    }


# ---------------------------------------------------------------------------
# Controller
# ---------------------------------------------------------------------------

class PurchaseManagementApi(http.Controller):

    # ------------------------------------------------------------------
    # POST /api/purchase/overview
    # Returns role-scoped KPIs + available_tabs for the hub dashboard.
    # ------------------------------------------------------------------

    @http.route(
        "/api/purchase/overview",
        type="json",
        auth="user",
        methods=["POST"],
        csrf=False,
    )
    def purchase_overview(self, **kwargs):
        env = request.env
        emp = _login_employee(env)
        roles = _purchase_roles(emp)

        if roles["purchase_scope"] == "none":
            return _json_ok({"is_authorized": False, "available_tabs": []})

        # Determine available tabs
        available_tabs = []
        if roles["is_purchase_rep"] or roles["is_purchase_manager"]:
            available_tabs.append("mr")
            available_tabs.append("rfq")
        if roles["is_doc_controller"] or roles["is_purchase_manager"]:
            available_tabs.append("invoice")

        # --- MR counts ---
        MR = env.get("purchase.requisition")
        mr_counts = {}
        if MR is not None and "mr" in available_tabs:
            base_domain = _scope_domain_mr(emp, roles)
            for state_label in _MR_STATE_MAP.keys():
                cnt = MR.sudo().search_count(base_domain + [("state", "=", state_label)])
                mr_counts[_mr_state_label(state_label)] = cnt

        # --- PO/RFQ counts and amounts (current month) ---
        PO = env["purchase.order"]
        po_base = _scope_domain_po(emp, roles)
        today = date.today()
        month_start = today.replace(day=1)
        month_end = (month_start + relativedelta(months=1)) - relativedelta(days=1)
        prev_start = (month_start - relativedelta(months=1))
        prev_end = month_start - relativedelta(days=1)

        po_this_month = PO.sudo().search(
            po_base + [("date_order", ">=", datetime.combine(month_start, datetime.min.time())),
                       ("date_order", "<=", datetime.combine(month_end, datetime.max.time()))]
        )
        po_last_month = PO.sudo().search(
            po_base + [("date_order", ">=", datetime.combine(prev_start, datetime.min.time())),
                       ("date_order", "<=", datetime.combine(prev_end, datetime.max.time()))]
        )

        total_amount = sum(po.amount_total for po in po_this_month)
        last_total = sum(po.amount_total for po in po_last_month)
        pending_count = len([po for po in po_this_month if po.state in ("draft", "sent", "to approve")])
        approved_count = len([po for po in po_this_month if po.state in ("purchase", "done")])
        delta = _mom_delta(total_amount, last_total)

        # --- Invoice counts ---
        inv_counts = {}
        if "invoice" in available_tabs:
            INV = env["account.move"]
            inv_base = _scope_domain_invoice(emp, roles)
            for state in ("draft", "posted", "cancel"):
                cnt = INV.sudo().search_count(inv_base + [("state", "=", state)])
                inv_counts[_INV_STATE_MAP.get(state, state.upper())] = cnt

        month_label = today.strftime("%B %Y")
        trend_label = ""
        if delta is not None:
            direction = "▲" if delta >= 0 else "▼"
            trend_label = f"{direction} {abs(delta)}% vs {prev_start.strftime('%B')} · {_abbreviate_amount(last_total)}"

        # Audit log (write to lightweight table if model exists)
        AuditLog = env.get("purchase.mobile.access.log")
        if AuditLog is not None:
            AuditLog.sudo().create({
                "employee_id": emp.id,
                "route": "/api/purchase/overview",
                "scope": roles["purchase_scope"],
                "timestamp": datetime.utcnow(),
            })

        return _json_ok({
            "is_authorized": True,
            "available_tabs": available_tabs,
            "scope": roles["purchase_scope"],
            "month_label": month_label,
            "total_amount": total_amount,
            "total_display": _abbreviate_amount(total_amount),
            "pending_count": pending_count,
            "approved_count": approved_count,
            "trend_label": trend_label,
            "delta_percentage": delta,
            "previous_total_display": _abbreviate_amount(last_total),
            "mr_counts": mr_counts,
            "po_state_counts": {
                "rfq": len([p for p in po_this_month if p.state == "draft"]),
                "rfq_sent": len([p for p in po_this_month if p.state == "sent"]),
                "purchase_order": len([p for p in po_this_month if p.state in ("purchase", "done")]),
            },
            "invoice_counts": inv_counts,
        })

    # ------------------------------------------------------------------
    # POST /api/purchase/requisitions
    # Paginated MR list with keyword + status filter.
    # ------------------------------------------------------------------

    @http.route(
        "/api/purchase/requisitions",
        type="json",
        auth="user",
        methods=["POST"],
        csrf=False,
    )
    def purchase_requisitions(self, page=1, limit=10, keyword="", status="", **kwargs):
        env = request.env
        emp = _login_employee(env)
        roles = _purchase_roles(emp)

        if not (roles["is_purchase_rep"] or roles["is_purchase_manager"]):
            return _json_ok({"is_authorized": False, "data": [], "has_more": False})

        MR = env.get("purchase.requisition")
        if MR is None:
            return _json_ok({"is_authorized": True, "data": [], "has_more": False, "note": "purchase.requisition not installed"})

        domain = _scope_domain_mr(emp, roles)

        if keyword:
            domain += [
                "|", "|",
                ("name", "ilike", keyword),
                ("requested_by.name", "ilike", keyword),
                ("department_id.name", "ilike", keyword),
            ]

        if status:
            # status is the mobile display label; reverse-map to odoo state
            reverse_map = {v: k for k, v in _MR_STATE_MAP.items()}
            odoo_state = reverse_map.get(status.upper())
            if odoo_state:
                domain += [("state", "=", odoo_state)]

        offset = (page - 1) * limit
        total = MR.sudo().search_count(domain)
        records = MR.sudo().search(domain, limit=limit + 1, offset=offset, order="date_start desc")

        has_more = len(records) > limit
        records = records[:limit]

        return _json_ok({
            "is_authorized": True,
            "data": [_mr_card(r, emp.id) for r in records],
            "has_more": has_more,
            "total": total,
            "page": page,
        })

    # ------------------------------------------------------------------
    # POST /api/purchase/requisition_details
    # Full MR detail: header + lines + picking + attachments + approval trail.
    # ------------------------------------------------------------------

    @http.route(
        "/api/purchase/requisition_details",
        type="json",
        auth="user",
        methods=["POST"],
        csrf=False,
    )
    def purchase_requisition_details(self, mr_id=None, **kwargs):
        env = request.env
        emp = _login_employee(env)
        roles = _purchase_roles(emp)

        if not mr_id:
            return _json_err("mr_id required")

        MR = env.get("purchase.requisition")
        if MR is None:
            return _json_err("purchase.requisition not installed", 404)

        domain = _scope_domain_mr(emp, roles) + [("id", "=", int(mr_id))]
        mr = MR.sudo().search(domain, limit=1)
        if not mr:
            return _json_err("Not found or not authorized", 403)

        # Lines
        lines = [_mr_line(l) for l in (mr.line_ids if hasattr(mr, "line_ids") else [])]

        # Attachments
        attachments = []
        Attach = env["ir.attachment"]
        for a in Attach.sudo().search([("res_model", "=", "purchase.requisition"), ("res_id", "=", mr.id)]):
            attachments.append({
                "id": a.id,
                "name": a.name,
                "mimetype": a.mimetype or "",
                "url": f"/web/content/{a.id}?download=true",
            })

        # Linked RFQ/PO refs (if MR has a direct link field)
        linked_rfqs = []
        if hasattr(mr, "purchase_ids"):
            for po in mr.purchase_ids:
                linked_rfqs.append({"id": po.id, "name": po.name, "state": _po_state_label(po.state)})

        # Approval trail from tier.validation if installed
        approval_trail = []
        TierVal = env.get("tier.validation")
        if TierVal is None:
            TierReview = env.get("tier.review")
            if TierReview is not None:
                for rev in TierReview.sudo().search(
                    [("model", "=", "purchase.requisition"), ("res_id", "=", mr.id)]
                ):
                    approval_trail.append({
                        "reviewer": rev.reviewer_ids[:1].name if rev.reviewer_ids else "",
                        "status": rev.status or "",
                        "date": _format_datetime(rev.reviewed_date) if hasattr(rev, "reviewed_date") else "",
                        "comment": getattr(rev, "comment", "") or "",
                    })

        return _json_ok({
            "id": mr.id,
            "name": mr.name or "",
            "state": _mr_state_label(mr.state),
            "odoo_state": mr.state or "",
            "requester_name": mr.requested_by.name if hasattr(mr, "requested_by") and mr.requested_by else "",
            "requester_photo": (
                f"/web/image/hr.employee/{mr.requested_by.id}/image_128"
                if hasattr(mr, "requested_by") and mr.requested_by else ""
            ),
            "department": mr.department_id.name if mr.department_id else "",
            "wo_po": getattr(mr, "x_wo_po", "") or "",
            "req_ou": getattr(mr, "x_req_ou", "") or "",
            "operating_unit": getattr(mr, "x_operating_unit", "") or "",
            "req_resp": getattr(mr, "x_req_resp_id", False) and mr.x_req_resp_id.name or "",
            "mr_type": getattr(mr, "x_mr_type", "") or "",
            "request_date": _format_datetime(mr.date_start) if hasattr(mr, "date_start") else "",
            "received_date": _format_date(getattr(mr, "x_received_date", False)),
            "deadline": _format_date(mr.date_end) if hasattr(mr, "date_end") else "",
            "analytic_account": (
                mr.account_analytic_id.name
                if hasattr(mr, "account_analytic_id") and mr.account_analytic_id
                else ""
            ),
            "project_manager": (
                mr.x_project_manager_id.name
                if hasattr(mr, "x_project_manager_id") and mr.x_project_manager_id
                else ""
            ),
            "priority": getattr(mr, "priority", "normal") or "normal",
            "proposed_vendor": mr.partner_id.name if hasattr(mr, "partner_id") and mr.partner_id else "",
            "quotation_ref": getattr(mr, "x_quotation_ref", "") or "",
            "task_job_order_user": (
                mr.x_task_assign_to.name
                if hasattr(mr, "x_task_assign_to") and mr.x_task_assign_to else ""
            ),
            "delivery_address": getattr(mr, "x_delivery_address", "") or "",
            "line_common_vendor": getattr(mr, "x_line_common_vendor", "") or "",
            "requester_manager": (
                mr.x_requester_manager_id.name
                if hasattr(mr, "x_requester_manager_id") and mr.x_requester_manager_id
                else ""
            ),
            "lines": lines,
            "attachments": attachments,
            "linked_rfqs": linked_rfqs,
            "approval_trail": approval_trail,
        })

    # ------------------------------------------------------------------
    # POST /api/purchase/rfqs
    # Paginated RFQ/PO list.
    # ------------------------------------------------------------------

    @http.route(
        "/api/purchase/rfqs",
        type="json",
        auth="user",
        methods=["POST"],
        csrf=False,
    )
    def purchase_rfqs(
        self,
        page=1,
        limit=10,
        keyword="",
        status="",
        date_from="",
        date_to="",
        vendor="",
        project="",
        requested_by="",
        project_manager="",
        origin="",
        city="",
        reference="",
        order="desc",
        **kwargs,
    ):
        env = request.env
        emp = _login_employee(env)
        roles = _purchase_roles(emp)

        if roles["purchase_scope"] == "none":
            return _json_ok({"is_authorized": False, "data": [], "has_more": False})

        PO = env["purchase.order"]
        domain = _scope_domain_po(emp, roles)

        if keyword:
            domain += [
                "|", "|",
                ("name", "ilike", keyword),
                ("partner_id.name", "ilike", keyword),
                ("x_project", "ilike", keyword),
            ]

        if reference:
            domain += [("name", "ilike", reference)]
        if vendor:
            domain += [("partner_id.name", "ilike", vendor)]
        if project:
            domain += ["|", ("project_id.name", "ilike", project), ("project_id_mr.name", "ilike", project)]
        if requested_by:
            domain += [("requested_by_id.name", "ilike", requested_by)]
        if project_manager:
            domain += [("projects_manager.name", "ilike", project_manager)]
        if origin:
            domain += ["|", ("origin", "ilike", origin), ("partner_ref", "ilike", origin)]
        if city:
            domain += [("city_id.name", "ilike", city)]
        if date_from:
            domain += [("date_order", ">=", date_from)]
        if date_to:
            domain += [("date_order", "<=", f"{date_to} 23:59:59")]

        if status:
            reverse_map = {v: k for k, v in _PO_STATE_MAP.items()}
            odoo_state = reverse_map.get(status.upper())
            if odoo_state:
                domain += [("state", "=", odoo_state)]

        order_clause = "date_order desc" if str(order).lower() != "asc" else "date_order asc"
        offset = (page - 1) * limit
        records = PO.sudo().search(domain, limit=limit + 1, offset=offset, order=order_clause)
        has_more = len(records) > limit
        records = records[:limit]

        return _json_ok({
            "is_authorized": True,
            "data": [_po_card(p) for p in records],
            "has_more": has_more,
            "page": page,
        })

    # ------------------------------------------------------------------
    # POST /api/purchase/invoice_receiving
    # Paginated Invoice Receiving list (vendor bills / account.move).
    # ------------------------------------------------------------------

    @http.route(
        "/api/purchase/invoice_receiving",
        type="json",
        auth="user",
        methods=["POST"],
        csrf=False,
    )
    def purchase_invoice_receiving(self, page=1, limit=15, keyword="", status="", **kwargs):
        env = request.env
        emp = _login_employee(env)
        roles = _purchase_roles(emp)

        if not (roles["is_doc_controller"] or roles["is_purchase_manager"]):
            return _json_ok({"is_authorized": False, "data": [], "has_more": False})

        INV = env["account.move"]
        domain = _scope_domain_invoice(emp, roles)

        if keyword:
            domain += [
                "|", "|",
                ("ref", "ilike", keyword),
                ("partner_id.name", "ilike", keyword),
                ("invoice_origin", "ilike", keyword),
            ]

        if status:
            rev = {v: k for k, v in _INV_STATE_MAP.items()}
            odoo_state = rev.get(status.upper())
            if odoo_state:
                domain += [("state", "=", odoo_state)]

        offset = (page - 1) * limit
        records = INV.sudo().search(domain, limit=limit + 1, offset=offset, order="invoice_date desc, id desc")
        has_more = len(records) > limit
        records = records[:limit]

        return _json_ok({
            "is_authorized": True,
            "data": [_inv_card(i) for i in records],
            "has_more": has_more,
            "page": page,
        })

    # ------------------------------------------------------------------
    # POST /api/purchase/invoice_receiving_details
    # Full vendor bill detail.
    # ------------------------------------------------------------------

    @http.route(
        "/api/purchase/invoice_receiving_details",
        type="json",
        auth="user",
        methods=["POST"],
        csrf=False,
    )
    def purchase_invoice_receiving_details(self, invoice_id=None, **kwargs):
        env = request.env
        emp = _login_employee(env)
        roles = _purchase_roles(emp)

        if not invoice_id:
            return _json_err("invoice_id required")

        INV = env["account.move"]
        domain = _scope_domain_invoice(emp, roles) + [("id", "=", int(invoice_id))]
        inv = INV.sudo().search(domain, limit=1)
        if not inv:
            return _json_err("Not found or not authorized", 403)

        lines = []
        for line in inv.invoice_line_ids:
            lines.append({
                "id": line.id,
                "product": line.product_id.name if line.product_id else "",
                "description": line.name or "",
                "qty": line.quantity,
                "price_unit": line.price_unit,
                "subtotal": line.price_subtotal,
                "tax": sum(t.amount for t in line.tax_ids) if line.tax_ids else 0,
            })

        attachments = []
        Attach = env["ir.attachment"]
        for a in Attach.sudo().search([("res_model", "=", "account.move"), ("res_id", "=", inv.id)]):
            attachments.append({
                "id": a.id,
                "name": a.name,
                "mimetype": a.mimetype or "",
                "url": f"/web/content/{a.id}?download=true",
                "file_content_base64": a.datas.decode() if a.datas else "",
            })

        lpo_no = ""
        lpo_id = None
        if hasattr(inv, "purchase_id") and inv.purchase_id:
            lpo_no = inv.purchase_id.name
            lpo_id = inv.purchase_id.id

        return _json_ok({
            "id": inv.id,
            "invoice_no": inv.ref or inv.name or "",
            "lpo_no": lpo_no,
            "lpo_id": lpo_id,
            "invoice_date": _format_date(inv.invoice_date),
            "due_date": _format_date(inv.invoice_date_due),
            "partner": inv.partner_id.name if inv.partner_id else "",
            "partner_photo": (
                f"/web/image/res.partner/{inv.partner_id.id}/image_128"
                if inv.partner_id else ""
            ),
            "amount_untaxed": inv.amount_untaxed,
            "amount_tax": inv.amount_tax,
            "amount_total": inv.amount_total,
            "amount_display": _abbreviate_amount(inv.amount_total),
            "currency": inv.currency_id.name if inv.currency_id else "AED",
            "state": _INV_STATE_MAP.get((inv.state or "").lower(), (inv.state or "").upper()),
            "payment_state": inv.payment_state or "",
            "narration": inv.narration or "",
            "lines": lines,
            "attachments": attachments,
        })


# ---------------------------------------------------------------------------
# Login controller extension — inject purchase role flags
# ---------------------------------------------------------------------------
# Add this logic to the existing login controller after the employee is resolved
# (e.g. in elrace_backend_apis/controllers/authentication_controller.py):
#
#   from .purchase_controller import _purchase_roles, _login_employee
#
#   # After building the main login response dict:
#   emp = _login_employee(request.env)
#   purchase_roles = _purchase_roles(emp)
#   response_dict.update({
#       "is_purchase_rep": purchase_roles["is_purchase_rep"],
#       "is_purchase_manager": purchase_roles["is_purchase_manager"],
#       "is_doc_controller": purchase_roles["is_doc_controller"],
#       "purchase_scope": purchase_roles["purchase_scope"],
#   })
#   # Also merge into role_capabilities for the existing flag map:
#   existing_caps = response_dict.get("role_capabilities") or {}
#   existing_caps.update({
#       "x_is_purchase_rep": purchase_roles["is_purchase_rep"],
#       "x_is_purchase_manager": purchase_roles["is_purchase_manager"],
#       "x_is_doc_controller": purchase_roles["is_doc_controller"],
#   })
#   response_dict["role_capabilities"] = existing_caps
