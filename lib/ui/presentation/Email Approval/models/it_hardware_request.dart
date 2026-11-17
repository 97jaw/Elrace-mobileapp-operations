class ItHardwareRequest {
  const ItHardwareRequest({
    required this.id,
    required this.requestNumber,
    required this.requestType,
    required this.requestDate,
    required this.requester,
    required this.requesterDepartment,
    required this.hardwareUser,
    required this.employeeId,
    required this.department,
    required this.currentApprover,
    required this.project,
    required this.projectManager,
    required this.status,
    required this.imageUrl,
    required this.lines,
  });

  final String id;
  final String requestNumber;
  final String requestType;
  final String requestDate;
  final String requester;
  final String requesterDepartment;
  final String hardwareUser;
  final String employeeId;
  final String department;
  final String currentApprover;
  final String project;
  final String projectManager;
  final String status;
  final String imageUrl;
  final List<ItHardwareRequestLine> lines;
}

class ItHardwareRequestLine {
  const ItHardwareRequestLine({
    required this.item,
    required this.quantity,
    required this.specifications,
    required this.reason,
  });

  final String item;
  final num quantity;
  final String specifications;
  final String reason;
}
