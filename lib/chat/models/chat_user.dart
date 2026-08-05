import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user profile in the chat system.
/// Stored in Firestore at: users/{uid}
class ChatUser {
  final String uid;
  final int odooUserId;
  final int? employeeId;
  final String name;
  final String? email;
  final String? roleName;
  final String? jobTitle;
  final String? phoneNumber;
  final int roleId;
  final int? branchId;
  final int companyId;
  final String? avatarUrl;
  final DateTime? lastSeenAt;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> searchKeywords;

  /// Odoo `res.users.x_stamp_user` — may stamp documents when required.
  final bool xStampUser;

  ChatUser({
    required this.uid,
    required this.odooUserId,
    this.employeeId,
    required this.name,
    this.email,
    this.roleName,
    this.jobTitle,
    this.phoneNumber,
    required this.roleId,
    this.branchId,
    required this.companyId,
    this.avatarUrl,
    this.lastSeenAt,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
    this.searchKeywords = const [],
    this.xStampUser = false,
  });

  /// Generate search keywords from name and email for prefix search.
  static List<String> buildSearchKeywords(String name, String? email) {
    final keywords = <String>{};

    // Process name tokens
    final nameTokens = name.toLowerCase().split(RegExp(r'\s+'));
    for (final token in nameTokens) {
      if (token.isEmpty) continue;
      // Add full token and prefixes (min 2 chars)
      keywords.add(token);
      for (int i = 2; i < token.length; i++) {
        keywords.add(token.substring(0, i));
      }
    }

    // Process email if present
    if (email != null && email.isNotEmpty) {
      final emailLower = email.toLowerCase();
      keywords.add(emailLower);

      // Extract username part (before @)
      final atIndex = emailLower.indexOf('@');
      if (atIndex > 0) {
        final username = emailLower.substring(0, atIndex);
        keywords.add(username);
        for (int i = 2; i < username.length; i++) {
          keywords.add(username.substring(0, i));
        }
      }
    }

    return keywords.toList();
  }

  factory ChatUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final resolvedEmail = _readString(data, const [
      'email',
      'work_email',
      'personal_email',
      'official_email',
      'mail',
      'username',
    ]);
    final resolvedJobTitle = _readString(data, const [
      'job_title',
      'job_position',
      'job',
      'designation',
      'position',
      'title',
    ]);
    final resolvedPhone = _readString(data, const [
      'phone',
      'phone_number',
      'mobile_phone',
      'mobile',
      'mobile_number',
      'work_phone',
      'emp_phone',
      'telephone',
    ]);

    if (resolvedEmail == null || resolvedPhone == null) {
      print('👤 ChatUser.fromFirestore: uid=${doc.id} missingFields '
          'email=${resolvedEmail ?? 'null'} phone=${resolvedPhone ?? 'null'}');
      print('👤 ChatUser.fromFirestore: available keys=${data.keys.toList()}');
      print('👤 ChatUser.fromFirestore: email candidates -> '
          'email=${data['email']} work_email=${data['work_email']} '
          'personal_email=${data['personal_email']} official_email=${data['official_email']} '
          'mail=${data['mail']} username=${data['username']}');
      print('👤 ChatUser.fromFirestore: phone candidates -> '
          'phone=${data['phone']} phone_number=${data['phone_number']} '
          'mobile_phone=${data['mobile_phone']} mobile=${data['mobile']} '
          'mobile_number=${data['mobile_number']} work_phone=${data['work_phone']} '
          'emp_phone=${data['emp_phone']} telephone=${data['telephone']}');
    }

    return ChatUser(
      uid: doc.id,
      odooUserId: _asInt(data['odoo_user_id']) ?? 0,
      employeeId: _asInt(data['employee_id']),
      name: data['name']?.toString() ?? '',
      email: resolvedEmail,
      roleName: data['role_name']?.toString(),
      jobTitle: resolvedJobTitle,
      phoneNumber: resolvedPhone,
      roleId: _asInt(data['role_id']) ?? 0,
      branchId: _asInt(data['branch_id']),
      companyId: _asInt(data['company_id']) ?? 0,
      avatarUrl: data['avatar_url']?.toString(),
      lastSeenAt: _asDate(data['last_seen_at']),
      lastLoginAt: _asDate(data['last_login_at']),
      createdAt: _asDate(data['created_at']) ?? DateTime.now(),
      updatedAt: _asDate(data['updated_at']) ?? DateTime.now(),
      searchKeywords: _asStringList(data['search_keywords']),
      xStampUser: _asBool(data['x_stamp_user']),
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null || value == false) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null || value == false) continue;
      final text = value.toString().trim();
      if (text.isEmpty) continue;
      final lower = text.toLowerCase();
      if (lower == 'null' ||
          lower == 'false' ||
          lower == 'n/a' ||
          lower == '-') {
        continue;
      }
      return text;
    }
    return null;
  }

  static bool _asBool(dynamic value) {
    if (value == true) return true;
    if (value == false || value == null) return false;
    if (value is num) return value != 0;
    final s = value.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  Map<String, dynamic> toFirestore({bool isUpdate = false}) {
    final map = <String, dynamic>{
      'odoo_user_id': odooUserId,
      'employee_id': employeeId,
      'name': name,
      'email': email,
      'role_name': roleName,
      'job_title': jobTitle,
      'phone': phoneNumber,
      'role_id': roleId,
      'branch_id': branchId,
      'company_id': companyId,
      'avatar_url': avatarUrl,
      'last_login_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'search_keywords': searchKeywords,
      'x_stamp_user': xStampUser,
    };

    if (!isUpdate) {
      map['created_at'] = FieldValue.serverTimestamp();
    }

    return map;
  }

  ChatUser copyWith({
    String? uid,
    int? odooUserId,
    int? employeeId,
    String? name,
    String? email,
    String? roleName,
    String? jobTitle,
    String? phoneNumber,
    int? roleId,
    int? branchId,
    int? companyId,
    String? avatarUrl,
    DateTime? lastSeenAt,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? searchKeywords,
    bool? xStampUser,
  }) {
    return ChatUser(
      uid: uid ?? this.uid,
      odooUserId: odooUserId ?? this.odooUserId,
      employeeId: employeeId ?? this.employeeId,
      name: name ?? this.name,
      email: email ?? this.email,
      roleName: roleName ?? this.roleName,
      jobTitle: jobTitle ?? this.jobTitle,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      roleId: roleId ?? this.roleId,
      branchId: branchId ?? this.branchId,
      companyId: companyId ?? this.companyId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      xStampUser: xStampUser ?? this.xStampUser,
    );
  }

  @override
  String toString() => 'ChatUser(uid: $uid, name: $name, email: $email)';
}
