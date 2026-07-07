/// Employee pick-list for manager new evaluation.
class PerformanceEmployeeOption {
  const PerformanceEmployeeOption({
    required this.id,
    required this.employeeName,
    required this.employeeNumber,
    this.jobPosition = '',
    this.department = '',
  });

  final String id;
  final String employeeName;
  final String employeeNumber;
  final String jobPosition;
  final String department;
}
