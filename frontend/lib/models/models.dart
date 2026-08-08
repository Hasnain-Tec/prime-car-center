class AppUser {
  final int id;
  final String email;
  final String fullName;
  final String phone;
  final String status;
  final int? roleId;
  final String? roleName;
  final Set<String> permissions;
  final Set<int> allowPermissionIds;
  final Set<int> denyPermissionIds;
  final String? createdAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.status,
    required this.permissions,
    this.allowPermissionIds = const {},
    this.denyPermissionIds = const {},
    this.roleId,
    this.roleName,
    this.createdAt,
  });

  bool can(String code) => permissions.contains(code);

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      roleId: json['role'] as int?,
      roleName: json['role_name']?.toString(),
      permissions: ((json['effective_permissions'] as List?) ?? const [])
          .map(
            (item) => item.toString(),
          )
          .toSet(),
      allowPermissionIds: ((json['allow_permission_ids'] as List?) ?? const [])
          .map(
            (item) => item as int,
          )
          .toSet(),
      denyPermissionIds: ((json['deny_permission_ids'] as List?) ?? const [])
          .map(
            (item) => item as int,
          )
          .toSet(),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'status': status,
      'role': roleId,
      'role_name': roleName,
      'effective_permissions': permissions.toList(),
      'allow_permission_ids': allowPermissionIds.toList(),
      'deny_permission_ids': denyPermissionIds.toList(),
      'created_at': createdAt,
    };
  }
}

class RoleModel {
  final int id;
  final String name;
  final String description;
  final bool isSystem;
  final List<int> permissionIds;

  const RoleModel({
    required this.id,
    required this.name,
    required this.description,
    required this.isSystem,
    required this.permissionIds,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isSystem: json['is_system'] == true,
      permissionIds: ((json['permissions'] as List?) ?? const [])
          .map(
            (item) => (item as Map<String, dynamic>)['id'] as int,
          )
          .toList(),
    );
  }
}

class PermissionModel {
  final int id;
  final String code;
  final String name;
  final String module;

  const PermissionModel({
    required this.id,
    required this.code,
    required this.name,
    required this.module,
  });

  factory PermissionModel.fromJson(Map<String, dynamic> json) {
    return PermissionModel(
      id: json['id'] as int,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      module: json['module']?.toString() ?? '',
    );
  }
}

class PartItem {
  String name;
  double amount;

  PartItem({
    this.name = '',
    this.amount = 0,
  });

  factory PartItem.fromJson(Map<String, dynamic> json) {
    return PartItem(
      name: json['name']?.toString() ?? '',
      amount: double.tryParse(
            json['amount']?.toString() ?? '',
          ) ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
    };
  }
}

class JobAssignmentModel {
  final int id;
  final int userId;
  final String userName;

  final bool canView;
  final bool canViewPhoto;
  final bool canViewAmounts;
  final bool canPrintInvoice;
  final bool canEdit;
  final bool canAddParts;
  final bool canChangeStatus;
  final bool canComplete;
  final bool canDelete;

  const JobAssignmentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.canView,
    required this.canViewPhoto,
    required this.canViewAmounts,
    required this.canPrintInvoice,
    required this.canEdit,
    required this.canAddParts,
    required this.canChangeStatus,
    required this.canComplete,
    required this.canDelete,
  });

  factory JobAssignmentModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return JobAssignmentModel(
      id: json['id'] as int,
      userId: json['user'] as int,
      userName: json['user_name']?.toString() ?? '',
      canView: json['can_view'] == true,
      canViewPhoto: json['can_view_photo'] == true,
      canViewAmounts: json['can_view_amounts'] == true,
      canPrintInvoice: json['can_print_invoice'] == true,
      canEdit: json['can_edit'] == true,
      canAddParts: json['can_add_parts'] == true,
      canChangeStatus: json['can_change_status'] == true,
      canComplete: json['can_complete'] == true,
      canDelete: json['can_delete'] == true,
    );
  }
}

class JobModel {
  final int id;
  final String invoiceNumber;
  final String plateNumber;
  final String workDescription;

  final List<PartItem> parts;

  final double materialsTotal;
  final double labourCharges;
  final double total;

  final String? photoUrl;

  final String status;
  final String priority;

  final DateTime? dueDate;

  // Job start and expected end time.
  final DateTime? startTime;
  final DateTime? endTime;

  final String internalNotes;
  final String createdByName;

  final DateTime createdAt;

  final List<JobAssignmentModel> assignments;

  const JobModel({
    required this.id,
    required this.invoiceNumber,
    required this.plateNumber,
    required this.workDescription,
    required this.parts,
    required this.materialsTotal,
    required this.labourCharges,
    required this.total,
    required this.status,
    required this.priority,
    required this.internalNotes,
    required this.createdByName,
    required this.createdAt,
    required this.assignments,
    this.photoUrl,
    this.dueDate,
    this.startTime,
    this.endTime,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    return JobModel(
      id: json['id'] as int,
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      plateNumber: json['plate_number']?.toString() ?? '',
      workDescription: json['work_description']?.toString() ?? '',
      parts: ((json['parts'] as List?) ?? const [])
          .map(
            (item) => PartItem.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      materialsTotal: double.tryParse(
            json['materials_total']?.toString() ?? '',
          ) ??
          0,
      labourCharges: double.tryParse(
            json['labour_charges']?.toString() ?? '',
          ) ??
          0,
      total: double.tryParse(
            json['total']?.toString() ?? '',
          ) ??
          0,
      photoUrl: json['photo_url']?.toString(),
      status: json['status']?.toString() ?? 'unassigned',
      priority: json['priority']?.toString() ?? 'normal',
      dueDate: json['due_date'] == null
          ? null
          : DateTime.tryParse(
              json['due_date'].toString(),
            ),
      startTime: json['start_time'] == null
          ? null
          : DateTime.tryParse(
              json['start_time'].toString(),
            ),
      endTime: json['end_time'] == null
          ? null
          : DateTime.tryParse(
              json['end_time'].toString(),
            ),
      internalNotes: json['internal_notes']?.toString() ?? '',
      createdByName: json['created_by_name']?.toString() ?? '',
      createdAt: DateTime.tryParse(
            json['created_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
      assignments: ((json['assignments'] as List?) ?? const [])
          .map(
            (item) => JobAssignmentModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class ExpenseModel {
  final int id;
  final double amount;
  final String description;
  final String category;
  final String status;
  final String submittedByName;
  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.status,
    required this.submittedByName,
    required this.createdAt,
  });

  factory ExpenseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ExpenseModel(
      id: json['id'] as int,
      amount: double.tryParse(
            json['amount']?.toString() ?? '',
          ) ??
          0,
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      status: json['status']?.toString() ?? 'submitted',
      submittedByName: json['submitted_by_name']?.toString() ?? '',
      createdAt: DateTime.tryParse(
            json['created_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class WorkshopInfo {
  final String name;
  final String address;
  final String phone;
  final String email;
  final String licenseNumber;

  final String currency;
  final String invoicePrefix;
  final String invoiceFooter;

  final bool requireVehiclePhoto;
  final bool allowGalleryUpload;

  // URL of workshop logo returned by Django.
  final String? logoUrl;

  const WorkshopInfo({
    this.name = 'Prime Car Center',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.licenseNumber = '',
    this.currency = 'AED',
    this.invoicePrefix = 'PCC-INV-',
    this.invoiceFooter = 'Thank you for choosing Prime Car Center',
    this.requireVehiclePhoto = false,
    this.allowGalleryUpload = true,
    this.logoUrl,
  });

  factory WorkshopInfo.fromJson(
    Map<String, dynamic> json,
  ) {
    return WorkshopInfo(
      name: json['name']?.toString() ?? 'Prime Car Center',

      address: json['address']?.toString() ?? '',

      phone: json['phone']?.toString() ?? '',

      email: json['email']?.toString() ?? '',

      licenseNumber: json['license_number']?.toString() ?? '',

      currency: json['currency']?.toString() ?? 'AED',

      invoicePrefix: json['invoice_prefix']?.toString() ?? 'PCC-INV-',

      invoiceFooter: json['invoice_footer']?.toString() ?? '',

      requireVehiclePhoto: json['require_vehicle_photo'] == true,

      allowGalleryUpload: json['allow_gallery_upload'] != false,

      // NEW: workshop/company logo.
      logoUrl: json['logo_url']?.toString(),
    );
  }
}
