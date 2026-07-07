# Add to elrace_backend_apis/controllers/timesheet_controller.py (or new file + import in __init__.py)
#
# Routes:
#   POST /api/timesheet/my_hr_scope
#   POST /api/timesheet/site_projects  params: role=foreman|pm, status=in_progress|completed|all

from odoo import http
from odoo.http import request


def _json_ok(payload):
    return {"success": True, **payload}


def _login_employee(env):
    uid = request.session.uid
    if not uid:
        return env["hr.employee"].browse()
    user = env["res.users"].sudo().browse(uid)
    emp = user.employee_id
    if not emp:
        emp = env["hr.employee"].sudo().search([("user_id", "=", uid)], limit=1)
    return emp


def _employee_card(emp):
    file_id = (
        getattr(emp, "emp_profile_id", False)
        or getattr(emp, "emp_code", False)
        or getattr(emp, "employee_code", False)
        or str(emp.id)
    )
    image = False
    if hasattr(emp, "image_1920") and emp.image_1920:
        image = f"/web/image/hr.employee/{emp.id}/image_1920"
    return {
        "employee_id": emp.id,
        "name": emp.name,
        "file_id": file_id,
        "image_url": image,
        "job_position": emp.job_id.name if emp.job_id else "",
    }


def _m2m_ids(record, field_name):
    field = getattr(record, field_name, False)
    if not field:
        return []
    return field.ids


class TimesheetSiteApi(http.Controller):

    # POST /api/timesheet/labor_list — see timesheet_controller.py (labor report picker)

    @http.route(
        "/api/timesheet/my_hr_scope",
        type="json",
        auth="user",
        methods=["POST"],
        csrf=False,
    )
    def my_hr_scope(self, **kwargs):
        emp = _login_employee(request.env)
        if not emp:
            return _json_ok(
                {
                    "employee_id": False,
                    "x_labor_ids": [],
                    "x_foreman_ids": [],
                }
            )

        labor_ids = _m2m_ids(emp, "x_labor_ids")
        foreman_ids = _m2m_ids(emp, "x_foreman_ids")
        Employee = request.env["hr.employee"].sudo()

        return _json_ok(
            {
                "employee_id": emp.id,
                "x_labor_ids": [
                    _employee_card(Employee.browse(i)) for i in labor_ids
                ],
                "x_foreman_ids": [
                    _employee_card(Employee.browse(i)) for i in foreman_ids
                ],
            }
        )

    def _project_visible(self, project, employee, role):
        role = (role or "foreman").lower()
        if role == "foreman":
            supervisor_ids = _m2m_ids(project, "supervisor_ids")
            if not supervisor_ids:
                # legacy JSON supervisors on custom project model
                for sup in project.supervisors or []:
                    if sup.employee_id.id == employee.id:
                        return True
                return employee.id in supervisor_ids
            return employee.id in supervisor_ids

        if role == "pm":
            StaffLine = request.env.get("project.staff.line")
            if StaffLine is not None:
                lines = StaffLine.sudo().search(
                    [
                        ("project_id", "=", project.id),
                        ("employee_id", "=", employee.id),
                    ]
                )
                for line in lines:
                    access = (getattr(line, "access", "") or "").lower()
                    if access in ("project", "pm", "manager"):
                        return True
                return False
            # fallback one2many on project if defined
            for line in getattr(project, "staff_line_ids", []):
                if line.employee_id.id == employee.id and (
                    getattr(line, "access", "project").lower() == "project"
                ):
                    return True
            return False

        return False

    def _status_bucket(self, project, status):
        status = (status or "in_progress").lower()
        state = (
            getattr(project, "project_status", False)
            or getattr(project, "state", False)
            or ""
        )
        label = str(state).lower()
        completed = any(
            x in label for x in ("complete", "done", "closed", "cancel")
        )
        if status == "all":
            return True
        if status == "completed":
            return completed
        # in_progress default
        return not completed

    def _serialize_project(self, project):
        partner = getattr(project, "partner_id", False)
        client_image = False
        if partner and partner.image_1920:
            client_image = f"/web/image/res.partner/{partner.id}/image_1920"
        write_date = project.write_date or project.create_date
        return {
            "project_id": project.id,
            "id": str(project.id),
            "name": project.name,
            "wo_ref_no": getattr(project, "wo_ref_no", "") or "",
            "project_status": getattr(project, "project_status", "")
            or getattr(project, "state", ""),
            "client": partner.name if partner else "",
            "client_image_url": client_image,
            "address": getattr(project, "x_pr_address", "")
            or getattr(project, "address", "")
            or "",
            "last_update": write_date.isoformat() if write_date else "",
            "progress_pct": getattr(project, "total_progress", 0) or 0,
            "budget_min": 0,
            "budget_max": getattr(project, "wo_amount", 0) or 0,
        }

    @http.route(
        "/api/timesheet/site_projects",
        type="json",
        auth="user",
        methods=["POST"],
        csrf=False,
    )
    def site_projects(self, role="foreman", status="in_progress", **kwargs):
        emp = _login_employee(request.env)
        if not emp:
            return _json_ok({"projects": []})

        Project = request.env["project.project"].sudo()
        candidates = Project.search([("active", "=", True)])
        rows = []
        for project in candidates:
            if not self._project_visible(project, emp, role):
                continue
            if not self._status_bucket(project, status):
                continue
            rows.append(self._serialize_project(project))

        return _json_ok({"projects": rows})
