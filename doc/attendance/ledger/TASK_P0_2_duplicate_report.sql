-- TASK P0_2 — Duplicate attendance report (READ-ONLY, safe on production)
-- Run in psql or pgAdmin against the Odoo database. Nothing is written.
-- Staff only (is_labor = false), last 6 months. Change the date if needed.

-- 1) Size: how many employee-days have more than one hr.attendance row
SELECT COUNT(*)                         AS duplicate_days,
       SUM(cnt - 1)                     AS extra_rows,
       COUNT(DISTINCT employee_id)      AS employees_affected
FROM (
    SELECT a.employee_id, a.check_date, COUNT(*) AS cnt
    FROM hr_attendance a
    JOIN hr_employee e ON e.id = a.employee_id
    WHERE COALESCE(e.is_labor, false) = false
      AND a.check_date >= (CURRENT_DATE - INTERVAL '6 months')
    GROUP BY a.employee_id, a.check_date
    HAVING COUNT(*) > 1
) d;

-- 2) Which type combinations cause them (e.g. "jm_morning,normal", "mobile,normal")
SELECT types, COUNT(*) AS days
FROM (
    SELECT a.employee_id, a.check_date,
           STRING_AGG(COALESCE(a.x_attendance_type, 'NULL'), ',' ORDER BY a.x_attendance_type) AS types
    FROM hr_attendance a
    JOIN hr_employee e ON e.id = a.employee_id
    WHERE COALESCE(e.is_labor, false) = false
      AND a.check_date >= (CURRENT_DATE - INTERVAL '6 months')
    GROUP BY a.employee_id, a.check_date
    HAVING COUNT(*) > 1
) d
GROUP BY types
ORDER BY days DESC;

-- 3) Per month, to see if it is getting worse
SELECT DATE_TRUNC('month', check_date)::date AS month, COUNT(*) AS duplicate_days
FROM (
    SELECT a.employee_id, a.check_date
    FROM hr_attendance a
    JOIN hr_employee e ON e.id = a.employee_id
    WHERE COALESCE(e.is_labor, false) = false
      AND a.check_date >= (CURRENT_DATE - INTERVAL '6 months')
    GROUP BY a.employee_id, a.check_date
    HAVING COUNT(*) > 1
) d
GROUP BY 1
ORDER BY 1;

-- 4) Rows with no check_date at all (invisible to payroll)
SELECT COUNT(*) AS rows_without_check_date
FROM hr_attendance a
JOIN hr_employee e ON e.id = a.employee_id
WHERE COALESCE(e.is_labor, false) = false
  AND a.check_date IS NULL;
