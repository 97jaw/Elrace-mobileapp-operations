/// One row from Odoo `request.type` (mobile filter catalog).
class HrRequestTypeOption {
  const HrRequestTypeOption({
    required this.id,
    required this.name,
    required this.label,
    required this.code,
  });

  final String id;
  final String name;
  final String label;
  final String code;

  factory HrRequestTypeOption.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString().trim();
    final labelRaw = (json['label'] ?? '').toString().trim();
    final label = labelRaw.isNotEmpty
        ? labelRaw
        : (name.contains('-') ? name.split('-').first.trim() : name);
    return HrRequestTypeOption(
      id: (json['id'] ?? '').toString(),
      name: name,
      label: label.isNotEmpty ? label : 'Request',
      code: (json['code'] ?? '').toString().trim(),
    );
  }
}
