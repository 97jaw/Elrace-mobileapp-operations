// To parse this JSON data, do
//
//     final loginResponseModel = loginResponseModelFromJson(jsonString);

import 'dart:convert';

import 'package:el_race/core/hr_management/hr_module_manager_access.dart';

LoginResponseModel loginResponseModelFromJson(String str) =>
    LoginResponseModel.fromJson(json.decode(str));

String loginResponseModelToJson(LoginResponseModel data) =>
    json.encode(data.toJson());

class LoginResponseModel {
  final String? jsonrpc;
  final dynamic id;
  final Result? result;

  LoginResponseModel({
    this.jsonrpc,
    this.id,
    this.result,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) =>
      LoginResponseModel(
        jsonrpc: json["jsonrpc"],
        id: json["id"],
        result: json["result"] == null ? null : Result.fromJson(json["result"]),
      );

  Map<String, dynamic> toJson() => {
        "jsonrpc": jsonrpc,
        "id": id,
        "result": result?.toJson(),
      };
}

class Result {
  final String? message;
  final bool? success;
  final Data? data;
  final String? token;

  Result({
    this.message,
    this.success,
    this.data,
    this.token,
  });

  factory Result.fromJson(Map<String, dynamic> json) => Result(
        message: json["message"],
        success: json["success"],
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
        token: json["token"],
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "success": success,
        "data": data?.toJson(),
        "token": token,
      };
}

class Data {
  final int? uid;
  final bool? isSystem;
  final bool? isAdmin;
  final bool? isAttendanceManager;
  final UserContext? userContext;
  final String? db;
  final String? serverVersion;
  final List<dynamic>? serverVersionInfo;
  final String? name;
  final String? image_url;
  final String? username;
  final String? job_id;

  /// Human-readable job title when API sends it (e.g. Odoo `job_title`).
  final String? jobTitle;
  final String? designation;
  final String? emp_id;
  final String? emp_profile_id;
  final String? emp_name;
  final int? role_id;
  final int? odoo_user_id;
  final int? employee_id;
  final int? holder_id;
  final String? firebase_uid;
  final String? firebase_custom_token;
  final String? partnerDisplayName;
  final int? companyId;
  final int? branchId;
  final int? partnerId;
  final String? email;
  final String? phone;

  /// City / branch label from login (`branch` in API).
  final String? branch;
  final String? leaveBalance;
  final String? webBaseUrl;
  final UserCompanies? userCompanies;
  final UserBranches? userBranches;
  final Map<String, Currency>? currencies;
  final bool? showEffect;
  final bool? displaySwitchCompanyMenu;
  final bool? displaySwitchBranchMenu;
  final CacheHashes? cacheHashes;
  final List<dynamic>? allowedBranchIds;
  final List<String>? roles;
  final bool? qr_status;
  final Map<String, dynamic>? certificate;
  final DefaultWidgets? defaultWidgets;
  final int? default_operating_unit_id;

  /// HR Management module — SRD §1.4 (optional until backend ships flags).
  final bool? isHrManager;
  final bool? isManagement;
  final bool? isPm;
  final bool? isForeman;
  final bool? isFleet;

  /// From `/api/login/new` `hr_module_manager` — per-submodule manager UI.
  final HrModuleManagerAccess? hrModuleManager;

  /// From `/api/login/new` `role_capabilities` — raw Odoo role-line OR flags.
  final Map<String, bool>? roleCapabilities;

  /// Purchase Management module role flags (injected by login controller).
  final bool? isPurchaseRep;
  final bool? isPurchaseManager;
  final bool? isCostControlOrManagement;
  final bool? isDocController;

  /// Purchase scope: "own" | "department" | "all" | "receiving" | "none".
  final String? purchaseScope;

  /// Odoo `hr.employee` — labors assigned to this foreman (`x_labor_ids`).
  final List<dynamic>? xLaborIdsRaw;

  /// Odoo `hr.employee` — foremen under this PM (`x_foreman_ids`).
  final List<dynamic>? xForemanIdsRaw;

  Data({
    this.uid,
    this.isSystem,
    this.isAdmin,
    this.isAttendanceManager,
    this.userContext,
    this.db,
    this.serverVersion,
    this.serverVersionInfo,
    this.name,
    this.image_url,
    this.username,
    this.job_id,
    this.jobTitle,
    this.designation,
    this.emp_id,
    this.emp_profile_id,
    this.emp_name,
    this.role_id,
    this.odoo_user_id,
    this.employee_id,
    this.holder_id,
    this.firebase_uid,
    this.firebase_custom_token,
    this.partnerDisplayName,
    this.companyId,
    this.branchId,
    this.partnerId,
    this.email,
    this.phone,
    this.branch,
    this.leaveBalance,
    this.webBaseUrl,
    this.userCompanies,
    this.userBranches,
    this.currencies,
    this.showEffect,
    this.displaySwitchCompanyMenu,
    this.displaySwitchBranchMenu,
    this.cacheHashes,
    this.allowedBranchIds,
    this.roles,
    this.qr_status,
    this.certificate,
    this.defaultWidgets,
    this.default_operating_unit_id,
    this.isHrManager,
    this.isManagement,
    this.isPm,
    this.isForeman,
    this.isFleet,
    this.hrModuleManager,
    this.roleCapabilities,
    this.isPurchaseRep,
    this.isPurchaseManager,
    this.isCostControlOrManagement,
    this.isDocController,
    this.purchaseScope,
    this.xLaborIdsRaw,
    this.xForemanIdsRaw,
  });

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        uid: json["uid"],
        isSystem: json["is_system"],
        isAdmin: json["is_admin"],
        isAttendanceManager: json["is_attendance_manager"],
        userContext: json["user_context"] == null
            ? null
            : UserContext.fromJson(json["user_context"]),
        db: json["db"],
        serverVersion: json["server_version"],
        serverVersionInfo: json["server_version_info"] == null
            ? []
            : List<dynamic>.from(json["server_version_info"]!.map((x) => x)),
        name: (json["emp_name"] is String &&
                json["emp_name"].toString().isNotEmpty)
            ? json["emp_name"]
            : (json["name"] is String
                ? json["name"]
                : (json["partner_display_name"] is String
                    ? json["partner_display_name"]
                    : json["username"])),
        image_url: (json["image_url"] != null && json["image_url"] != false)
            ? json["image_url"].toString()
            : '',
        username: (json["username"] != null && json["username"] != false)
            ? json["username"].toString()
            : '',
        job_id: (json["job_id"] != null && json["job_id"] != false)
            ? json["job_id"].toString()
            : null,
        jobTitle: _stringOrNull(
          json["job_title"] ?? json["job_name"] ?? json["job"],
        ),
        designation: _stringOrNull(
          json["designation"] ?? json["job_position"] ?? json["function"],
        ),
        emp_id: (json["emp_id"] != null && json["emp_id"] != false)
            ? json["emp_id"].toString()
            : null,
        emp_profile_id:
            (json["emp_profile_id"] != null && json["emp_profile_id"] != false)
                ? json["emp_profile_id"].toString()
                : null,
        emp_name: (json["emp_name"] != null && json["emp_name"] != false)
            ? json["emp_name"].toString()
            : null,
        role_id: json["role_id"] is int
            ? json["role_id"]
            : int.tryParse(json["role_id"]?.toString() ?? ''),
        odoo_user_id: json["odoo_user_id"] is int
            ? json["odoo_user_id"]
            : (json["uid"] is int ? json["uid"] : null),
        employee_id: json["employee_id"] is int
            ? json["employee_id"]
            : (json["emp_id"] != null && json["emp_id"] != false
                ? int.tryParse(json["emp_id"].toString())
                : null),
        holder_id: json["holder_id"] is int
            ? json["holder_id"]
            : (json["holder_id"] is List &&
                    (json["holder_id"] as List).isNotEmpty &&
                    (json["holder_id"] as List).first is int)
                ? (json["holder_id"] as List).first as int
                : int.tryParse(json["holder_id"]?.toString() ?? ''),
        firebase_uid:
            (json["firebase_uid"] != null && json["firebase_uid"] != false)
                ? json["firebase_uid"].toString()
                : null,
        firebase_custom_token: (json["firebase_custom_token"] != null &&
                json["firebase_custom_token"] != false)
            ? json["firebase_custom_token"].toString()
            : null,
        partnerDisplayName: json["partner_display_name"],
        companyId: json["company_id"],
        branchId: (json["branch_id"] is int)
            ? json["branch_id"]
            : (json["branch_id"] is String
                ? int.tryParse(json["branch_id"])
                : null),
        partnerId: json["partner_id"],
        email: _stringOrNull(json["email"] ?? json["work_email"]),
        phone: _stringOrNull(
          json["phone"] ??
              json["mobile_phone"] ??
              json["mobile"] ??
              json["work_phone"],
        ),
        branch: _stringOrNull(
          json["branch"] ?? json["city_name"] ?? json["city"],
        ),
        leaveBalance: _stringOrNull(
          json["leave_balance"] ??
              json["leaveBalance"] ??
              json["balance_leave"] ??
              json["remaining_leave_days"],
        ),
        webBaseUrl: json["web.base.url"],
        userCompanies: json["user_companies"] == null
            ? null
            : UserCompanies.fromJson(json["user_companies"]),
        userBranches: json["user_branches"] == null
            ? null
            : UserBranches.fromJson(json["user_branches"]),
        currencies: json["currencies"] == null
            ? null
            : Map.from(json["currencies"]!).map(
                (k, v) => MapEntry<String, Currency>(k, Currency.fromJson(v))),
        showEffect: json["show_effect"],
        displaySwitchCompanyMenu: json["display_switch_company_menu"],
        displaySwitchBranchMenu: json["display_switch_branch_menu"],
        cacheHashes: json["cache_hashes"] == null
            ? null
            : CacheHashes.fromJson(json["cache_hashes"]),
        allowedBranchIds: json["allowed_branch_ids"] == null
            ? []
            : List<dynamic>.from(json["allowed_branch_ids"]!.map((x) => x)),
        roles: json["roles"] == null
            ? []
            : List<String>.from(json["roles"]!.map((x) => x)),
        qr_status: json["qr_status"],
        certificate: json["certificate"] is Map
            ? Map<String, dynamic>.from(json["certificate"])
            : (json["certificate"] is String
                ? _tryDecodeCertificate(json["certificate"] as String)
                : null),
        defaultWidgets: json["default_widgets"] == null
            ? null
            : DefaultWidgets.fromJson(json["default_widgets"]),
        default_operating_unit_id: json["default_operating_unit_id"],
        isHrManager: _parseBoolLoose(json["is_hr_manager"]),
        isManagement: _parseBoolLoose(json["is_management"]),
        isPm: _parseBoolLoose(json["is_pm"]),
        isForeman: _parseBoolLoose(json["is_foreman"]),
        isFleet: _parseBoolLoose(json["is_fleet"]),
        hrModuleManager: HrModuleManagerAccess.tryParse(json["hr_module_manager"]),
        roleCapabilities: _parseStringBoolMap(json["role_capabilities"]),
        isPurchaseRep: _parseBoolLoose(json["is_purchase_rep"]),
        isPurchaseManager: _parseBoolLoose(json["is_purchase_manager"]),
        isCostControlOrManagement:
            _parseBoolLoose(json["is_cost_control_or_management"]),
        isDocController: _parseBoolLoose(json["is_doc_controller"]),
        purchaseScope: json["purchase_scope"]?.toString(),
        xLaborIdsRaw: json["x_labor_ids"] ?? json["labor_ids"],
        xForemanIdsRaw: json["x_foreman_ids"] ?? json["foreman_ids"],
      );

  Map<String, dynamic> toJson() => {
        "uid": uid,
        "is_system": isSystem,
        "is_admin": isAdmin,
        "is_attendance_manager": isAttendanceManager,
        "user_context": userContext?.toJson(),
        "db": db,
        "server_version": serverVersion,
        "server_version_info": serverVersionInfo == null
            ? []
            : List<dynamic>.from(serverVersionInfo!.map((x) => x)),
        "name": name,
        "image_url": image_url,
        "username": username,
        "job_id": job_id,
        "job_title": jobTitle,
        "designation": designation,
        "emp_id": emp_id,
        "emp_profile_id": emp_profile_id,
        "emp_name": emp_name,
        "role_id": role_id,
        "odoo_user_id": odoo_user_id,
        "employee_id": employee_id,
        "holder_id": holder_id,
        "firebase_uid": firebase_uid,
        "firebase_custom_token": firebase_custom_token,
        "partner_display_name": partnerDisplayName,
        "company_id": companyId,
        "branch_id": branchId,
        "partner_id": partnerId,
        "email": email,
        "phone": phone,
        "branch": branch,
        "leave_balance": leaveBalance,
        "web.base.url": webBaseUrl,
        "user_companies": userCompanies?.toJson(),
        "user_branches": userBranches?.toJson(),
        "currencies": currencies != null
            ? Map.from(currencies!)
                .map((k, v) => MapEntry<String, dynamic>(k, v.toJson()))
            : null,
        "show_effect": showEffect,
        "display_switch_company_menu": displaySwitchCompanyMenu,
        "display_switch_branch_menu": displaySwitchBranchMenu,
        "cache_hashes": cacheHashes?.toJson(),
        "allowed_branch_ids": allowedBranchIds == null
            ? []
            : List<dynamic>.from(allowedBranchIds!.map((x) => x)),
        "roles": roles == null ? [] : List<dynamic>.from(roles!.map((x) => x)),
        "qr_status": qr_status,
        "certificate": certificate,
        "default_widgets": defaultWidgets?.toJson(),
        "default_operating_unit_id": default_operating_unit_id,
        "is_hr_manager": isHrManager,
        "is_management": isManagement,
        "is_pm": isPm,
        "is_foreman": isForeman,
        "is_fleet": isFleet,
        "hr_module_manager": hrModuleManager == null
            ? null
            : {
                "payslip": hrModuleManager!.payslip,
                "attendance": hrModuleManager!.attendance,
                "hr_request": hrModuleManager!.hrRequest,
                "recruitment": hrModuleManager!.recruitment,
                "evaluation": hrModuleManager!.evaluation,
              },
        "role_capabilities": roleCapabilities == null
            ? null
            : Map<String, dynamic>.from(roleCapabilities!),
        "is_purchase_rep": isPurchaseRep,
        "is_purchase_manager": isPurchaseManager,
        "is_cost_control_or_management": isCostControlOrManagement,
        "is_doc_controller": isDocController,
        "purchase_scope": purchaseScope,
        "x_labor_ids": xLaborIdsRaw,
        "x_foreman_ids": xForemanIdsRaw,
      };

  static Map<String, bool>? _parseStringBoolMap(dynamic raw) {
    if (raw == null || raw is! Map) return null;
    final out = <String, bool>{};
    for (final e in raw.entries) {
      final b = _parseBoolLoose(e.value);
      if (b != null) out[e.key.toString()] = b;
    }
    return out.isEmpty ? null : out;
  }

  static bool? _parseBoolLoose(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return null;
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null || value == false || value == true) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower == 'false' || lower == 'null') return null;
    return text;
  }
}

class CacheHashes {
  final String? loadMenus;
  final String? qweb;
  final String? translations;

  CacheHashes({
    this.loadMenus,
    this.qweb,
    this.translations,
  });

  factory CacheHashes.fromJson(Map<String, dynamic> json) => CacheHashes(
        loadMenus: json["load_menus"],
        qweb: json["qweb"],
        translations: json["translations"],
      );

  Map<String, dynamic> toJson() => {
        "load_menus": loadMenus,
        "qweb": qweb,
        "translations": translations,
      };
}

class Currency {
  final String? symbol;
  final String? position;
  final List<int>? digits;

  Currency({
    this.symbol,
    this.position,
    this.digits,
  });

  factory Currency.fromJson(Map<String, dynamic> json) => Currency(
        symbol: json["symbol"],
        position: json["position"],
        digits: json["digits"] == null
            ? []
            : List<int>.from(json["digits"]!.map((x) => x)),
      );

  Map<String, dynamic> toJson() => {
        "symbol": symbol,
        "position": position,
        "digits":
            digits == null ? [] : List<dynamic>.from(digits!.map((x) => x)),
      };
}

class UserBranches {
  final List<bool>? currentBranch;
  final List<dynamic>? allowedBranch;

  UserBranches({
    this.currentBranch,
    this.allowedBranch,
  });

  factory UserBranches.fromJson(Map<String, dynamic> json) => UserBranches(
        currentBranch: json["current_branch"] == null
            ? []
            : List<bool>.from(json["current_branch"]!.map((x) => x)),
        allowedBranch: json["allowed_branch"] == null
            ? []
            : List<dynamic>.from(json["allowed_branch"]!.map((x) => x)),
      );

  Map<String, dynamic> toJson() => {
        "current_branch": currentBranch == null
            ? []
            : List<dynamic>.from(currentBranch!.map((x) => x)),
        "allowed_branch": allowedBranch == null
            ? []
            : List<dynamic>.from(allowedBranch!.map((x) => x)),
      };
}

class UserCompanies {
  final List<dynamic>? currentCompany;
  final List<List<dynamic>>? allowedCompanies;

  UserCompanies({
    this.currentCompany,
    this.allowedCompanies,
  });

  factory UserCompanies.fromJson(Map<String, dynamic> json) => UserCompanies(
        currentCompany: json["current_company"] == null
            ? []
            : List<dynamic>.from(json["current_company"]!.map((x) => x)),
        allowedCompanies: json["allowed_companies"] == null
            ? []
            : List<List<dynamic>>.from(json["allowed_companies"]!
                .map((x) => List<dynamic>.from(x.map((x) => x)))),
      );

  Map<String, dynamic> toJson() => {
        "current_company": currentCompany == null
            ? []
            : List<dynamic>.from(currentCompany!.map((x) => x)),
        "allowed_companies": allowedCompanies == null
            ? []
            : List<dynamic>.from(allowedCompanies!
                .map((x) => List<dynamic>.from(x.map((x) => x)))),
      };
}

class UserContext {
  final int? mapWebsiteId;
  final int? routeMapWebsiteId;
  final int? routeStartPartnerId;
  final String? lang;
  final String? tz;
  final int? uid;

  UserContext({
    this.mapWebsiteId,
    this.routeMapWebsiteId,
    this.routeStartPartnerId,
    this.lang,
    this.tz,
    this.uid,
  });

  factory UserContext.fromJson(Map<String, dynamic> json) => UserContext(
        mapWebsiteId: json["map_website_id"],
        routeMapWebsiteId: json["route_map_website_id"],
        routeStartPartnerId: json["route_start_partner_id"],
        lang: json["lang"],
        tz: json["tz"],
        uid: json["uid"],
      );

  Map<String, dynamic> toJson() => {
        "map_website_id": mapWebsiteId,
        "route_map_website_id": routeMapWebsiteId,
        "route_start_partner_id": routeStartPartnerId,
        "lang": lang,
        "tz": tz,
        "uid": uid,
      };
}

class DefaultWidgets {
  final String? status;
  final String? message;
  final WidgetsData? data;

  DefaultWidgets({
    this.status,
    this.message,
    this.data,
  });

  factory DefaultWidgets.fromJson(Map<String, dynamic> json) => DefaultWidgets(
        status: json["status"]?.toString(),
        message: json["message"]?.toString(),
        data: json["data"] == null
            ? null
            : WidgetsData.fromJson(json["data"] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data?.toJson(),
      };
}

class WidgetsData {
  final WidgetInfo? attendanceWidget;
  final WidgetInfo? checkinWidget;
  final WidgetInfo? myRequestWidget;
  final WidgetInfo? myDocumentsWidget;
  final WidgetInfo? myProjectsWidget;
  final WidgetInfo? mediaWidget;
  final WidgetInfo? myReportsWidget;
  final WidgetInfo? timesheetWidget;
  final WidgetInfo? hrmsWidget;
  final WidgetInfo? siteManagementWidget;
  final WidgetInfo? myNotesWidget;
  final WidgetInfo? lpoWidget;
  final WidgetInfo? taskManagementWidget;
  final WidgetInfo? ticketsWidget;
  final WidgetInfo? pettyCashWidget;
  final WidgetInfo? prayerTimesWidget;
  final WidgetInfo? clientsWidget;
  final WidgetInfo? vendorsWidget;
  final WidgetInfo? subContractorsWidget;

  WidgetsData({
    this.attendanceWidget,
    this.checkinWidget,
    this.myRequestWidget,
    this.myDocumentsWidget,
    this.myProjectsWidget,
    this.mediaWidget,
    this.myReportsWidget,
    this.timesheetWidget,
    this.hrmsWidget,
    this.siteManagementWidget,
    this.myNotesWidget,
    this.lpoWidget,
    this.taskManagementWidget,
    this.ticketsWidget,
    this.pettyCashWidget,
    this.prayerTimesWidget,
    this.clientsWidget,
    this.vendorsWidget,
    this.subContractorsWidget,
  });

  factory WidgetsData.fromJson(Map<String, dynamic> json) => WidgetsData(
        attendanceWidget: json["attendance_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["attendance_widget"] as Map<String, dynamic>),
        checkinWidget: json["checkin_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["checkin_widget"] as Map<String, dynamic>),
        myRequestWidget: json["my_request_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["my_request_widget"] as Map<String, dynamic>),
        myDocumentsWidget: json["my_documents_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["my_documents_widget"] as Map<String, dynamic>),
        myProjectsWidget: json["my_projects_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["my_projects_widget"] as Map<String, dynamic>),
        mediaWidget: json["media_widget"] == null
            ? null
            : WidgetInfo.fromJson(json["media_widget"] as Map<String, dynamic>),
        myReportsWidget: json["my_reports_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["my_reports_widget"] as Map<String, dynamic>),
        timesheetWidget: json["timesheet_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["timesheet_widget"] as Map<String, dynamic>),
        hrmsWidget: json["hrms_widget"] == null
            ? null
            : WidgetInfo.fromJson(json["hrms_widget"] as Map<String, dynamic>),
        siteManagementWidget: json["site_management_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["site_management_widget"] as Map<String, dynamic>),
        myNotesWidget: json["my_notes_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["my_notes_widget"] as Map<String, dynamic>),
        lpoWidget: json["lpo_widget"] == null
            ? null
            : WidgetInfo.fromJson(json["lpo_widget"] as Map<String, dynamic>),
        taskManagementWidget: json["taskmanagement_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["taskmanagement_widget"] as Map<String, dynamic>),
        ticketsWidget: json["tickets_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["tickets_widget"] as Map<String, dynamic>),
        pettyCashWidget: json["petty_cash_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["petty_cash_widget"] as Map<String, dynamic>),
        prayerTimesWidget: json["prayer_times_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["prayer_times_widget"] as Map<String, dynamic>),
        clientsWidget: json["clients_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["clients_widget"] as Map<String, dynamic>),
        vendorsWidget: json["vendors_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["vendors_widget"] as Map<String, dynamic>),
        subContractorsWidget: json["sub_contractors_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["sub_contractors_widget"] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        "attendance_widget": attendanceWidget?.toJson(),
        "checkin_widget": checkinWidget?.toJson(),
        "my_request_widget": myRequestWidget?.toJson(),
        "my_documents_widget": myDocumentsWidget?.toJson(),
        "my_projects_widget": myProjectsWidget?.toJson(),
        "media_widget": mediaWidget?.toJson(),
        "my_reports_widget": myReportsWidget?.toJson(),
        "timesheet_widget": timesheetWidget?.toJson(),
        "hrms_widget": hrmsWidget?.toJson(),
        "site_management_widget": siteManagementWidget?.toJson(),
        "my_notes_widget": myNotesWidget?.toJson(),
        "lpo_widget": lpoWidget?.toJson(),
        "taskmanagement_widget": taskManagementWidget?.toJson(),
        "tickets_widget": ticketsWidget?.toJson(),
        "petty_cash_widget": pettyCashWidget?.toJson(),
        "prayer_times_widget": prayerTimesWidget?.toJson(),
        "clients_widget": clientsWidget?.toJson(),
        "vendors_widget": vendorsWidget?.toJson(),
        "sub_contractors_widget": subContractorsWidget?.toJson(),
      };
}

/// Represents a single dashboard widget entry.
/// [recordToShow] may be an [int] or a [Map<String, dynamic>] depending on
/// the widget type – access the typed helpers for convenience.
class WidgetInfo {
  final int? widgetNumber;
  final String? widgetName;
  final dynamic recordToShow;
  final bool? isDisabled;

  WidgetInfo({
    this.widgetNumber,
    this.widgetName,
    this.recordToShow,
    this.isDisabled,
  });

  factory WidgetInfo.fromJson(Map<String, dynamic> json) => WidgetInfo(
        widgetNumber: json["widget_number"] is int
            ? json["widget_number"]
            : int.tryParse(json["widget_number"]?.toString() ?? ''),
        widgetName: json["widget_name"]?.toString(),
        recordToShow: json["record_to_show"],
        isDisabled: json["is_disabled"] is bool
            ? json["is_disabled"]
            : (json["is_disabled"]?.toString().toLowerCase() == 'true'),
      );

  Map<String, dynamic> toJson() => {
        "widget_number": widgetNumber,
        "widget_name": widgetName,
        "record_to_show": recordToShow,
        "is_disabled": isDisabled,
      };

  // ---------- typed helpers ----------

  /// Returns the numeric value of [recordToShow] when it is a plain number.
  int? get recordCount => recordToShow is int
      ? recordToShow as int
      : int.tryParse(recordToShow?.toString() ?? '');

  /// Returns [recordToShow] as a key→value map when it is an object.
  Map<String, dynamic>? get recordMap => recordToShow is Map
      ? Map<String, dynamic>.from(recordToShow as Map)
      : null;

  TimesheetWidgetRecord? get timesheetRecord {
    final map = recordMap;
    if (map == null) return null;
    if (map.containsKey('total_hours') || map.containsKey('workers_count')) {
      return TimesheetWidgetRecord.fromMap(map);
    }
    return null;
  }

  AttendanceWidgetRecord? get attendanceRecord {
    final map = recordMap;
    if (map == null) return null;
    if (map.containsKey('present_days') ||
        map.containsKey('working_days') ||
        map.containsKey('present')) {
      return AttendanceWidgetRecord.fromMap(map);
    }
    return null;
  }

  HrmsWidgetRecord? get hrmsRecord {
    final map = recordMap;
    if (map == null) return null;
    if (map.containsKey('direct_reports_count') ||
        map.containsKey('scope') ||
        map.containsKey('headline_count')) {
      return HrmsWidgetRecord.fromMap(map);
    }
    return null;
  }

  MyProjectsWidgetRecord? get myProjectsRecord {
    final map = recordMap;
    if (map == null) return null;
    if (map.containsKey('top_projects') ||
        map.containsKey('total_active') ||
        map.containsKey('total_projects')) {
      return MyProjectsWidgetRecord.fromMap(map);
    }
    return null;
  }

  SiteManagementWidgetRecord? get siteManagementRecord {
    final map = recordMap;
    if (map == null) return null;
    if (map.containsKey('active_sites_count') ||
        map.containsKey('top_sites')) {
      return SiteManagementWidgetRecord.fromMap(map);
    }
    return null;
  }

  MyReportsWidgetRecord? get myReportsRecord {
    final map = recordMap;
    if (map == null) return null;
    if (map.containsKey('metric_type') || map.containsKey('trend_direction')) {
      return MyReportsWidgetRecord.fromMap(map);
    }
    return null;
  }

  LpoWidgetRecord? get lpoRecord {
    final map = recordMap;
    if (map == null) return null;
    if (map.containsKey('total_display') ||
        map.containsKey('pending_count') ||
        map.containsKey('is_authorized')) {
      return LpoWidgetRecord.fromMap(map);
    }
    if (map.containsKey('total') || map.containsKey('completed')) {
      return LpoWidgetRecord.fromLegacyMap(map);
    }
    return null;
  }

  NotesWidgetRecord? get notesRecord {
    final map = recordMap;
    if (map == null) return null;
    if (map.containsKey('total_count') || map.containsKey('last_note_title')) {
      return NotesWidgetRecord.fromMap(map);
    }
    if (map.containsKey('saved_count') || map.containsKey('draft_count')) {
      return NotesWidgetRecord.fromLegacyMap(map);
    }
    return null;
  }

  TaskManagementWidgetRecord? get taskManagementRecord {
    final map = recordMap;
    if (map == null) return null;
    if (map.containsKey('open_count') ||
        map.containsKey('in_progress_count') ||
        map.containsKey('done_count')) {
      return TaskManagementWidgetRecord.fromMap(map);
    }
    return null;
  }

  TicketsWidgetRecord? get ticketsRecord {
    final map = recordMap;
    if (map == null) return null;
    if (map.containsKey('total_open') ||
        map.containsKey('high_priority_count')) {
      return TicketsWidgetRecord.fromMap(map);
    }
    return null;
  }

  PettyCashWidgetRecord? get pettyCashRecord {
    final map = recordMap;
    if (map == null) return null;
    if (map.containsKey('available_display') ||
        map.containsKey('spent_display') ||
        map.containsKey('is_authorized')) {
      return PettyCashWidgetRecord.fromMap(map);
    }
    return null;
  }

  MyDocumentsWidgetRecord? get myDocumentsRecord {
    final map = recordMap;
    if (map == null) return null;
    if (map.containsKey('featured_documents') ||
        map.containsKey('total_count')) {
      return MyDocumentsWidgetRecord.fromMap(map);
    }
    return null;
  }

  MediaWidgetRecord? get mediaRecord {
    final map = recordMap;
    if (map == null) return null;
    if (map.containsKey('recent_media') ||
        map.containsKey('overflow_count')) {
      return MediaWidgetRecord.fromMap(map);
    }
    if (map.containsKey('media_count')) {
      return MediaWidgetRecord.fromLegacyMap(map);
    }
    return null;
  }

  PrayerTimesWidgetRecord? get prayerTimesRecord {
    final map = recordMap;
    if (map == null) return null;
    if (map.containsKey('prayers') || map.containsKey('location_name')) {
      return PrayerTimesWidgetRecord.fromMap(map);
    }
    return null;
  }
}

// ── Typed record helpers ──────────────────────────────────────────────────────

class AttendanceRecord {
  final int present;
  final int absent;
  const AttendanceRecord({required this.present, required this.absent});
  factory AttendanceRecord.fromMap(Map<String, dynamic> m) =>
      AttendanceRecord(present: m["present"] ?? 0, absent: m["absent"] ?? 0);
  Map<String, dynamic> toJson() => {"present": present, "absent": absent};
}

class AttendanceWidgetRecord {
  const AttendanceWidgetRecord({
    required this.presentDays,
    required this.workingDays,
    required this.percentage,
  });

  final int presentDays;
  final int workingDays;
  final int percentage;

  factory AttendanceWidgetRecord.fromMap(Map<String, dynamic> m) {
    final present = _readInt(m['present_days'] ?? m['present']);
    final working = _readInt(m['working_days']);
    final pct = _readInt(m['percentage']);
    return AttendanceWidgetRecord(
      presentDays: present,
      workingDays: working,
      percentage: pct > 0
          ? pct
          : (working > 0 ? ((present / working) * 100).round() : 0),
    );
  }
}

class HrmsWidgetRecord {
  const HrmsWidgetRecord({
    required this.isManagerScope,
    required this.headlineCount,
    required this.trendLabel,
    required this.directReportsCount,
    required this.pendingRequestsCount,
    this.departmentName,
    this.sectionName,
  });

  final bool isManagerScope;
  final int headlineCount;
  final String trendLabel;
  final int directReportsCount;
  final int pendingRequestsCount;
  final String? departmentName;
  final String? sectionName;

  factory HrmsWidgetRecord.fromMap(Map<String, dynamic> m) {
    final scope = m['scope']?.toString() ?? 'employee';
    final isManager = scope == 'manager';
    final direct = _readInt(m['direct_reports_count']);
    final pending = _readInt(m['pending_requests_count']);
    return HrmsWidgetRecord(
      isManagerScope: isManager,
      headlineCount: _readInt(m['headline_count']) > 0
          ? _readInt(m['headline_count'])
          : (isManager ? direct : pending),
      trendLabel: m['trend_label']?.toString() ??
          (isManager ? '$direct under your team' : '$pending pending requests'),
      directReportsCount: direct,
      pendingRequestsCount: pending,
      departmentName: m['department_name']?.toString(),
      sectionName: m['section_name']?.toString(),
    );
  }
}

int _readInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class MyRequestRecord {
  final int totalRequestsCount;
  final int waitingForApprovalCount;
  const MyRequestRecord(
      {required this.totalRequestsCount,
      required this.waitingForApprovalCount});
  factory MyRequestRecord.fromMap(Map<String, dynamic> m) => MyRequestRecord(
      totalRequestsCount: m["total_requests_count"] ?? 0,
      waitingForApprovalCount: m["waiting_for_approval_count"] ?? 0);
  Map<String, dynamic> toJson() => {
        "total_requests_count": totalRequestsCount,
        "waiting_for_approval_count": waitingForApprovalCount
      };
}

class MyProjectsRecord {
  final int totalProjects;
  final int delayedProjects;
  const MyProjectsRecord(
      {required this.totalProjects, required this.delayedProjects});
  factory MyProjectsRecord.fromMap(Map<String, dynamic> m) => MyProjectsRecord(
      totalProjects: m["total_projects"] ?? m["total_active"] ?? 0,
      delayedProjects: m["delayed_projects"] ?? 0);
  Map<String, dynamic> toJson() =>
      {"total_projects": totalProjects, "delayed_projects": delayedProjects};
}

class MyProjectsTopProject {
  const MyProjectsTopProject({
    required this.id,
    required this.name,
    required this.progressPct,
    required this.statusColor,
    required this.isOverdue,
  });

  final int id;
  final String name;
  final double progressPct;
  final String statusColor;
  final bool isOverdue;

  factory MyProjectsTopProject.fromMap(Map<String, dynamic> m) {
    double readDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    return MyProjectsTopProject(
      id: m['id'] is int
          ? m['id'] as int
          : int.tryParse(m['id']?.toString() ?? '') ?? 0,
      name: m['name']?.toString() ?? '',
      progressPct: readDouble(m['progress_pct']),
      statusColor: m['status_color']?.toString() ?? 'low',
      isOverdue: m['is_overdue'] == true,
    );
  }
}

class MyProjectsWidgetRecord {
  const MyProjectsWidgetRecord({
    required this.totalActive,
    required this.dueThisWeekCount,
    required this.topProjects,
    required this.moreProjectsCount,
  });

  final int totalActive;
  final int dueThisWeekCount;
  final List<MyProjectsTopProject> topProjects;
  final int moreProjectsCount;

  factory MyProjectsWidgetRecord.fromMap(Map<String, dynamic> m) {
    int readInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final rawList = m['top_projects'];
    final projects = <MyProjectsTopProject>[];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map) {
          projects.add(
            MyProjectsTopProject.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final totalActive = readInt(m['total_active'] ?? m['total_projects']);
    final moreCount = readInt(m['more_projects_count']);
    return MyProjectsWidgetRecord(
      totalActive: totalActive,
      dueThisWeekCount: readInt(m['due_this_week_count']),
      topProjects: projects,
      moreProjectsCount: moreCount > 0
          ? moreCount
          : (totalActive > projects.length
              ? totalActive - projects.length
              : 0),
    );
  }

  factory MyProjectsWidgetRecord.empty() => const MyProjectsWidgetRecord(
        totalActive: 0,
        dueThisWeekCount: 0,
        topProjects: [],
        moreProjectsCount: 0,
      );

  String get titleLine => 'My Projects · $totalActive';
}

class SiteManagementWidgetRecord {
  const SiteManagementWidgetRecord({
    required this.activeSitesCount,
    required this.totalWorkers,
    required this.topSites,
    required this.extraSitesCount,
    required this.scope,
    required this.trendLabel,
  });

  final int activeSitesCount;
  final int totalWorkers;
  final List<String> topSites;
  final int extraSitesCount;
  final String scope;
  final String trendLabel;

  factory SiteManagementWidgetRecord.fromMap(Map<String, dynamic> m) {
    int readInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final sites = <String>[];
    final raw = m['top_sites'];
    if (raw is List) {
      for (final item in raw) {
        final label = item?.toString().trim();
        if (label != null && label.isNotEmpty) sites.add(label);
      }
    }

    return SiteManagementWidgetRecord(
      activeSitesCount: readInt(m['active_sites_count']),
      totalWorkers: readInt(m['total_workers']),
      topSites: sites,
      extraSitesCount: readInt(m['extra_sites_count']),
      scope: m['scope']?.toString() ?? 'none',
      trendLabel: m['trend_label']?.toString() ?? 'No sites assigned',
    );
  }

  factory SiteManagementWidgetRecord.empty() => const SiteManagementWidgetRecord(
        activeSitesCount: 0,
        totalWorkers: 0,
        topSites: [],
        extraSitesCount: 0,
        scope: 'none',
        trendLabel: 'No sites assigned',
      );

  List<String> get locationChips {
    final chips = <String>[...topSites];
    if (extraSitesCount > 0) chips.add('+$extraSitesCount');
    return chips;
  }
}

class MyReportsWidgetRecord {
  const MyReportsWidgetRecord({
    required this.metricLabel,
    required this.value,
    required this.trendDirection,
    required this.trendLabel,
    required this.previousPeriodLabel,
    required this.updatedAt,
    required this.metricType,
  });

  final String metricLabel;
  final String value;
  final String trendDirection;
  final String trendLabel;
  final String previousPeriodLabel;
  final String updatedAt;
  final String metricType;

  factory MyReportsWidgetRecord.fromMap(Map<String, dynamic> m) {
    final direction = m['trend_direction']?.toString() ?? 'neutral';
    final period =
        m['previous_period_label']?.toString() ?? 'last month';
    final rawTrend = m['trend_label']?.toString();
    return MyReportsWidgetRecord(
      metricLabel: m['metric_label']?.toString() ?? 'Performance',
      value: m['value']?.toString() ?? '—',
      trendDirection: direction,
      trendLabel: rawTrend?.isNotEmpty == true
          ? rawTrend!
          : _fallbackTrendLabel(direction, period),
      previousPeriodLabel: period,
      updatedAt: m['updated_at']?.toString() ?? 'Just now',
      metricType: m['metric_type']?.toString() ?? 'personal',
    );
  }

  factory MyReportsWidgetRecord.empty() => const MyReportsWidgetRecord(
        metricLabel: 'Performance',
        value: '—',
        trendDirection: 'neutral',
        trendLabel: 'Awaiting first report',
        previousPeriodLabel: 'last month',
        updatedAt: 'Just now',
        metricType: 'personal',
      );

  bool get isAwaitingData => value == '—' && trendDirection == 'neutral';
}

String _fallbackTrendLabel(String direction, String period) {
  if (direction == 'new') return 'New this period';
  if (direction == 'neutral') return 'Awaiting first report';
  final arrow = direction == 'down' ? '▼' : '▲';
  return '$arrow vs $period';
}

class MediaRecord {
  final int mediaCount;
  final int files;
  const MediaRecord({required this.mediaCount, required this.files});
  factory MediaRecord.fromMap(Map<String, dynamic> m) =>
      MediaRecord(mediaCount: m["media_count"] ?? 0, files: m["files"] ?? 0);
  Map<String, dynamic> toJson() => {"media_count": mediaCount, "files": files};
}

class MyNotesRecord {
  final int savedCount;
  final int draftCount;
  const MyNotesRecord({required this.savedCount, required this.draftCount});
  factory MyNotesRecord.fromMap(Map<String, dynamic> m) => MyNotesRecord(
      savedCount: m["saved_count"] ?? 0, draftCount: m["draft_count"] ?? 0);
  Map<String, dynamic> toJson() =>
      {"saved_count": savedCount, "draft_count": draftCount};
}

class NotesWidgetRecord {
  const NotesWidgetRecord({
    required this.totalCount,
    required this.lastNoteTitle,
    required this.lastNoteId,
    required this.lastUpdatedAt,
  });

  final int totalCount;
  final String? lastNoteTitle;
  final int? lastNoteId;
  final String? lastUpdatedAt;

  factory NotesWidgetRecord.fromMap(Map<String, dynamic> m) {
    int readInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final lastId = m['last_note_id'];
    return NotesWidgetRecord(
      totalCount: readInt(m['total_count']),
      lastNoteTitle: m['last_note_title']?.toString(),
      lastNoteId: lastId is int ? lastId : int.tryParse('$lastId'),
      lastUpdatedAt: m['last_updated_at']?.toString(),
    );
  }

  factory NotesWidgetRecord.fromLegacyMap(Map<String, dynamic> m) {
    final saved = m['saved_count'] is int
        ? m['saved_count'] as int
        : int.tryParse(m['saved_count']?.toString() ?? '') ?? 0;
    return NotesWidgetRecord(
      totalCount: saved,
      lastNoteTitle: null,
      lastNoteId: null,
      lastUpdatedAt: null,
    );
  }

  factory NotesWidgetRecord.empty() => const NotesWidgetRecord(
        totalCount: 0,
        lastNoteTitle: null,
        lastNoteId: null,
        lastUpdatedAt: null,
      );

  String get trendLabel {
    final title = lastNoteTitle?.trim();
    if (title == null || title.isEmpty) return 'No notes yet';
    return 'Last: $title';
  }
}

class TaskManagementWidgetRecord {
  const TaskManagementWidgetRecord({
    required this.openCount,
    required this.inProgressCount,
    required this.doneCount,
    required this.dueTodayCount,
    required this.dueTodayMessage,
  });

  final int openCount;
  final int inProgressCount;
  final int doneCount;
  final int dueTodayCount;
  final String dueTodayMessage;

  factory TaskManagementWidgetRecord.fromMap(Map<String, dynamic> m) {
    int readInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return TaskManagementWidgetRecord(
      openCount: readInt(m['open_count']),
      inProgressCount: readInt(m['in_progress_count']),
      doneCount: readInt(m['done_count']),
      dueTodayCount: readInt(m['due_today_count']),
      dueTodayMessage:
          m['due_today_message']?.toString() ?? 'No tasks due today',
    );
  }

  factory TaskManagementWidgetRecord.empty() => const TaskManagementWidgetRecord(
        openCount: 0,
        inProgressCount: 0,
        doneCount: 0,
        dueTodayCount: 0,
        dueTodayMessage: 'No tasks due today',
      );
}

class TicketsWidgetRecord {
  const TicketsWidgetRecord({
    required this.totalOpen,
    required this.highPriorityCount,
    required this.trendMessage,
    required this.trendColor,
  });

  final int totalOpen;
  final int highPriorityCount;
  final String trendMessage;
  final String trendColor;

  factory TicketsWidgetRecord.fromMap(Map<String, dynamic> m) {
    int readInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return TicketsWidgetRecord(
      totalOpen: readInt(m['total_open']),
      highPriorityCount: readInt(m['high_priority_count']),
      trendMessage: m['trend_message']?.toString() ?? '',
      trendColor: m['trend_color']?.toString() ?? 'neutral',
    );
  }

  factory TicketsWidgetRecord.empty() => const TicketsWidgetRecord(
        totalOpen: 0,
        highPriorityCount: 0,
        trendMessage: '',
        trendColor: 'neutral',
      );
}

class PettyCashWidgetRecord {
  const PettyCashWidgetRecord({
    required this.isAuthorized,
    required this.availableAmount,
    required this.availableDisplay,
    required this.spentAmount,
    required this.spentDisplay,
    required this.utilizationPct,
    required this.pendingRequestsCount,
    required this.statusFlag,
    required this.scope,
    required this.trendLabel,
    required this.pendingLabel,
  });

  final bool isAuthorized;
  final double availableAmount;
  final String availableDisplay;
  final double spentAmount;
  final String spentDisplay;
  final int utilizationPct;
  final int pendingRequestsCount;
  final String statusFlag;
  final String scope;
  final String trendLabel;
  final String pendingLabel;

  factory PettyCashWidgetRecord.fromMap(Map<String, dynamic> m) {
    double readDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    int readInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return PettyCashWidgetRecord(
      isAuthorized: m['is_authorized'] != false,
      availableAmount: readDouble(m['available_amount']),
      availableDisplay: m['available_display']?.toString() ?? 'AED 0',
      spentAmount: readDouble(m['spent_amount']),
      spentDisplay: m['spent_display']?.toString() ?? 'AED 0',
      utilizationPct: readInt(m['utilization_pct']),
      pendingRequestsCount: readInt(m['pending_requests_count']),
      statusFlag: m['status_flag']?.toString() ?? 'normal',
      scope: m['scope']?.toString() ?? 'personal',
      trendLabel: m['trend_label']?.toString() ?? '',
      pendingLabel: m['pending_label']?.toString() ?? '',
    );
  }

  factory PettyCashWidgetRecord.empty() => const PettyCashWidgetRecord(
        isAuthorized: true,
        availableAmount: 0,
        availableDisplay: 'AED 0',
        spentAmount: 0,
        spentDisplay: 'AED 0',
        utilizationPct: 0,
        pendingRequestsCount: 0,
        statusFlag: 'empty',
        scope: 'none',
        trendLabel: 'No allocation set',
        pendingLabel: '',
      );

  bool get isOverspent => statusFlag == 'overspent' || availableAmount < 0;
}

class FeaturedDocumentEntry {
  const FeaturedDocumentEntry({
    required this.typeCode,
    required this.name,
    required this.isUploaded,
    this.expiryDate,
    this.documentId,
  });

  final String typeCode;
  final String name;
  final bool isUploaded;
  final String? expiryDate;
  final int? documentId;

  factory FeaturedDocumentEntry.fromMap(Map<String, dynamic> m) {
    return FeaturedDocumentEntry(
      typeCode: m['type_code']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      isUploaded: m['is_uploaded'] == true,
      expiryDate: m['expiry_date']?.toString(),
      documentId: m['document_id'] is int
          ? m['document_id'] as int
          : int.tryParse(m['document_id']?.toString() ?? ''),
    );
  }
}

class MyDocumentsWidgetRecord {
  const MyDocumentsWidgetRecord({
    required this.totalCount,
    required this.expiringSoonCount,
    required this.expiredCount,
    required this.trendMessage,
    required this.trendColor,
    required this.featuredDocuments,
  });

  final int totalCount;
  final int expiringSoonCount;
  final int expiredCount;
  final String trendMessage;
  final String trendColor;
  final List<FeaturedDocumentEntry> featuredDocuments;

  factory MyDocumentsWidgetRecord.fromMap(Map<String, dynamic> m) {
    final featured = (m['featured_documents'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => FeaturedDocumentEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return MyDocumentsWidgetRecord(
      totalCount: _readInt(m['total_count']),
      expiringSoonCount: _readInt(m['expiring_soon_count']),
      expiredCount: _readInt(m['expired_count']),
      trendMessage: m['trend_message']?.toString() ?? '',
      trendColor: m['trend_color']?.toString() ?? 'green',
      featuredDocuments: featured,
    );
  }

  factory MyDocumentsWidgetRecord.empty() => const MyDocumentsWidgetRecord(
        totalCount: 0,
        expiringSoonCount: 0,
        expiredCount: 0,
        trendMessage: 'All up to date',
        trendColor: 'green',
        featuredDocuments: [],
      );
}

class MediaPreviewEntry {
  const MediaPreviewEntry({
    required this.id,
    required this.thumbnailUrl,
    required this.mediaType,
  });

  final int id;
  final String thumbnailUrl;
  final String mediaType;

  factory MediaPreviewEntry.fromMap(Map<String, dynamic> m) {
    return MediaPreviewEntry(
      id: _readInt(m['id']),
      thumbnailUrl: m['thumbnail_url']?.toString() ?? '',
      mediaType: m['media_type']?.toString() ?? 'photo',
    );
  }
}

class MediaWidgetRecord {
  const MediaWidgetRecord({
    required this.totalCount,
    required this.newTodayCount,
    required this.trendMessage,
    required this.recentMedia,
    required this.overflowCount,
  });

  final int totalCount;
  final int newTodayCount;
  final String trendMessage;
  final List<MediaPreviewEntry> recentMedia;
  final int overflowCount;

  factory MediaWidgetRecord.fromMap(Map<String, dynamic> m) {
    final recent = (m['recent_media'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => MediaPreviewEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return MediaWidgetRecord(
      totalCount: _readInt(m['total_count']),
      newTodayCount: _readInt(m['new_today_count']),
      trendMessage: m['trend_message']?.toString() ?? '',
      recentMedia: recent,
      overflowCount: _readInt(m['overflow_count']),
    );
  }

  factory MediaWidgetRecord.fromLegacyMap(Map<String, dynamic> m) {
    final count = _readInt(m['media_count'] ?? m['files']);
    return MediaWidgetRecord(
      totalCount: count,
      newTodayCount: 0,
      trendMessage: count == 0 ? 'No media yet' : '',
      recentMedia: const [],
      overflowCount: count > 3 ? count - 3 : 0,
    );
  }

  factory MediaWidgetRecord.empty() => const MediaWidgetRecord(
        totalCount: 0,
        newTodayCount: 0,
        trendMessage: 'No media yet',
        recentMedia: [],
        overflowCount: 0,
      );
}

class PrayerTimeEntry {
  const PrayerTimeEntry({
    required this.name,
    required this.timeDisplay,
    required this.isActive,
    required this.isNext,
  });

  final String name;
  final String timeDisplay;
  final bool isActive;
  final bool isNext;

  factory PrayerTimeEntry.fromMap(Map<String, dynamic> m) {
    return PrayerTimeEntry(
      name: m['name']?.toString() ?? '',
      timeDisplay: m['time_display']?.toString() ?? '',
      isActive: m['is_active'] == true,
      isNext: m['is_next'] == true,
    );
  }
}

class PrayerTimesWidgetRecord {
  const PrayerTimesWidgetRecord({
    required this.locationName,
    required this.prayers,
    required this.nextPrayerName,
    required this.nextPrayerCountdownDisplay,
    required this.nextPrayerCountdownSeconds,
    required this.dataStale,
    required this.subtitle,
  });

  final String locationName;
  final List<PrayerTimeEntry> prayers;
  final String nextPrayerName;
  final String nextPrayerCountdownDisplay;
  final int nextPrayerCountdownSeconds;
  final bool dataStale;
  final String subtitle;

  factory PrayerTimesWidgetRecord.fromMap(Map<String, dynamic> m) {
    final prayers = (m['prayers'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => PrayerTimeEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return PrayerTimesWidgetRecord(
      locationName: m['location_name']?.toString() ?? 'Al Ain',
      prayers: prayers,
      nextPrayerName: m['next_prayer_name']?.toString() ?? '',
      nextPrayerCountdownDisplay:
          m['next_prayer_countdown_display']?.toString() ?? '',
      nextPrayerCountdownSeconds:
          _readInt(m['next_prayer_countdown_seconds']),
      dataStale: m['data_stale'] == true,
      subtitle: m['subtitle']?.toString() ?? '',
    );
  }

  factory PrayerTimesWidgetRecord.empty() => const PrayerTimesWidgetRecord(
        locationName: 'Al Ain',
        prayers: [],
        nextPrayerName: '',
        nextPrayerCountdownDisplay: '',
        nextPrayerCountdownSeconds: 0,
        dataStale: false,
        subtitle: '',
      );
}

class LpoWidgetRecord {
  const LpoWidgetRecord({
    required this.isAuthorized,
    required this.totalAmount,
    required this.totalDisplay,
    required this.pendingCount,
    required this.approvedCount,
    required this.monthLabel,
    required this.titleLine,
    required this.deltaPercentage,
    required this.deltaDirection,
    required this.previousTotalDisplay,
    required this.scope,
    required this.trendLabel,
  });

  final bool isAuthorized;
  final double totalAmount;
  final String totalDisplay;
  final int pendingCount;
  final int approvedCount;
  final String monthLabel;
  final String titleLine;
  final double? deltaPercentage;
  final String deltaDirection;
  final String previousTotalDisplay;
  final String scope;
  final String trendLabel;

  factory LpoWidgetRecord.fromMap(Map<String, dynamic> m) {
    double readDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    int readInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return LpoWidgetRecord(
      isAuthorized: m['is_authorized'] != false,
      totalAmount: readDouble(m['total_amount']),
      totalDisplay: m['total_display']?.toString() ?? 'AED 0',
      pendingCount: readInt(m['pending_count']),
      approvedCount: readInt(m['approved_count']),
      monthLabel: m['month_label']?.toString() ?? '',
      titleLine: m['title_line']?.toString() ?? 'LPO',
      deltaPercentage: m['delta_percentage'] == null
          ? null
          : readDouble(m['delta_percentage']),
      deltaDirection: m['delta_direction']?.toString() ?? 'none',
      previousTotalDisplay:
          m['previous_total_display']?.toString() ?? '0',
      scope: m['scope']?.toString() ?? 'none',
      trendLabel: m['trend_label']?.toString() ?? '',
    );
  }

  factory LpoWidgetRecord.fromLegacyMap(Map<String, dynamic> m) {
    final total = m['total'] is int
        ? m['total'] as int
        : int.tryParse(m['total']?.toString() ?? '') ?? 0;
    final completed = m['completed'] is int
        ? m['completed'] as int
        : int.tryParse(m['completed']?.toString() ?? '') ?? 0;
    return LpoWidgetRecord(
      isAuthorized: true,
      totalAmount: total.toDouble(),
      totalDisplay: 'AED $total',
      pendingCount: (total - completed).clamp(0, total),
      approvedCount: completed,
      monthLabel: '',
      titleLine: 'LPO',
      deltaPercentage: null,
      deltaDirection: 'none',
      previousTotalDisplay: '0',
      scope: 'personal',
      trendLabel: '',
    );
  }

  factory LpoWidgetRecord.empty() => const LpoWidgetRecord(
        isAuthorized: true,
        totalAmount: 0,
        totalDisplay: 'AED 0',
        pendingCount: 0,
        approvedCount: 0,
        monthLabel: '',
        titleLine: 'LPO',
        deltaPercentage: null,
        deltaDirection: 'none',
        previousTotalDisplay: '0',
        scope: 'none',
        trendLabel: '',
      );

  String get pendingLabel => '$pendingCount';
  String get approvedLabel => '$approvedCount';
}

class TimesheetWidgetRecord {
  final double totalHours;
  final double overtimeHours;
  final double avgPerWorker;
  final int workersCount;
  final int recordsCount;
  final int projectsCount;
  final String weekLabel;
  final String teamLabel;
  final double deltaVsLastWeek;
  final String scope;

  const TimesheetWidgetRecord({
    required this.totalHours,
    required this.overtimeHours,
    required this.avgPerWorker,
    required this.workersCount,
    required this.recordsCount,
    required this.projectsCount,
    required this.weekLabel,
    required this.teamLabel,
    required this.deltaVsLastWeek,
    required this.scope,
  });

  factory TimesheetWidgetRecord.fromMap(Map<String, dynamic> m) {
    double readDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    int readInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return TimesheetWidgetRecord(
      totalHours: readDouble(m['total_hours']),
      overtimeHours: readDouble(m['overtime_hours']),
      avgPerWorker: readDouble(m['avg_per_worker']),
      workersCount: readInt(m['workers_count']),
      recordsCount: readInt(m['records_count']),
      projectsCount: readInt(m['projects_count']),
      weekLabel: m['week_label']?.toString() ?? 'This Week',
      teamLabel: m['team_label']?.toString() ?? 'Workers',
      deltaVsLastWeek: readDouble(m['delta_vs_last_week']),
      scope: m['scope']?.toString() ?? 'self',
    );
  }

  bool get isProjectScope =>
      scope == 'pm_projects' ||
      scope == 'foreman_projects' ||
      scope == 'pm_foremen' ||
      scope == 'foreman_labors';

  String get titleLine {
    if (isProjectScope) {
      if (recordsCount > 0) {
        final label = recordsCount == 1 ? 'Record' : 'Records';
        return '$weekLabel · $recordsCount $label';
      }
      if (projectsCount > 0) {
        final label = projectsCount == 1 ? 'Project' : 'Projects';
        return '$weekLabel · $projectsCount $label';
      }
    }
    if (workersCount > 0) {
      return '$weekLabel · $workersCount $teamLabel';
    }
    return weekLabel;
  }

  String get deltaTrendLabel {
    final abs = deltaVsLastWeek.abs();
    final formatted = abs % 1 == 0
        ? abs.toStringAsFixed(0)
        : abs.toStringAsFixed(1);
    if (deltaVsLastWeek > 0) return '▲ ${formatted}h vs last week';
    if (deltaVsLastWeek < 0) return '▼ ${formatted}h vs last week';
    return 'No change vs last week';
  }
}

Map<String, dynamic>? _tryDecodeCertificate(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    // ignore malformed certificate payloads
  }
  return null;
}
