import 'package:el_race/ui/presentation/Email%20Approval/models/it_hardware_request.dart';

const neutralItHardwareRequestFixture = ItHardwareRequest(
  id: 'request-101',
  requestNumber: 'REQ/TEST/101',
  requestType: 'IT Hardware Request',
  requestDate: '16/11/2026',
  requester: 'Sample Requester',
  requesterDepartment: 'Operations',
  hardwareUser: 'Sample User',
  employeeId: 'EMP-101',
  department: 'Operations',
  currentApprover: 'Sample Approver',
  project: 'Sample Project',
  projectManager: 'Sample Project Manager',
  status: 'Open',
  imageUrl: '',
  lines: [
    ItHardwareRequestLine(
      item: 'Laptop',
      quantity: 1,
      specifications: 'Standard business configuration',
      reason: 'Replacement equipment',
    ),
  ],
);
