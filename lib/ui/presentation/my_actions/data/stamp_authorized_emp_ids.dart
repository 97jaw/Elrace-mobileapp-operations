/// `hr.employee.emp_id` values authorized for stamp (same set as Odoo SQL).
///
/// Used as a **fallback** when `/api/login` does not yet return `x_stamp_user`
/// and when other stamp users have not re-logged so Firestore has no flag.
/// Prefer login/`x_stamp_user` once the backend injects it.
const Set<String> kStampAuthorizedEmpIds = {
  '2784',
  '105',
  '407',
  '159',
  '1008',
  '1599',
  '1076',
  '920',
  '2961',
  '2827',
  '26',
  '16',
  '301',
  '1115',
  '2847',
  '2105',
  '1762',
  '513',
  '2189',
  '80',
  '2511',
  '19',
  '1588',
  '2632',
  '3139',
};
