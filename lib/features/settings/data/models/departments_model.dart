import 'package:flutter/foundation.dart';

// Backed by the Org Structure API — see ApiConstants.departments' doc
// comment. A "Department" here is an OrgUnit with is_department_level=true;
// a "Designation" is a Position that belongs to one.
@immutable
class DepartmentModel {
  final String id;
  final String name;
  final String? code;
  final bool isActive;
  final int designationCount; // OrgUnit.position_count
  final int childCount;       // OrgUnit.child_count

  const DepartmentModel({
    required this.id,
    required this.name,
    this.code,
    required this.isActive,
    required this.designationCount,
    required this.childCount,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) => DepartmentModel(
    id:               json['id'] as String,
    name:             json['name'] as String? ?? '',
    code:             json['code'] as String?,
    isActive:         json['is_active'] as bool? ?? true,
    designationCount: json['position_count'] as int? ?? 0,
    childCount:       json['child_count'] as int? ?? 0,
  );
}

@immutable
class DesignationModel {
  final String id;
  final String name;         // Position.title
  final String departmentId; // Position.org_unit
  final String? departmentName;
  final bool isActive;

  const DesignationModel({
    required this.id,
    required this.name,
    required this.departmentId,
    this.departmentName,
    required this.isActive,
  });

  factory DesignationModel.fromJson(Map<String, dynamic> json) => DesignationModel(
    id:             json['id'] as String,
    name:           json['title'] as String? ?? '',
    departmentId:   json['org_unit'] as String? ?? '',
    departmentName: json['org_unit_name'] as String?,
    isActive:       json['is_active'] as bool? ?? true,
  );
}

class DeptFormData {
  String name;
  String code;

  DeptFormData({this.name = '', this.code = ''});

  factory DeptFormData.fromModel(DepartmentModel model) => DeptFormData(
    name: model.name,
    code: model.code ?? '',
  );

  // is_department_level is always sent true — this form only ever creates
  // department-level units, never an arbitrary org-tree node. is_active
  // isn't included: OrgUnitSerializer marks it read-only, changeable only
  // via the dedicated deactivate action, not a generic field update.
  Map<String, dynamic> toJson() => {
    'name': name,
    if (code.trim().isNotEmpty) 'code': code.trim(),
    'is_department_level': true,
  };

  String? validate() {
    if (name.trim().isEmpty) return 'Department name is required';
    return null;
  }
}

class DesignationFormData {
  String name;
  String? departmentId;

  DesignationFormData({this.name = '', this.departmentId});

  factory DesignationFormData.fromModel(DesignationModel model) => DesignationFormData(
    name:         model.name,
    departmentId: model.departmentId,
  );

  // is_active isn't included: PositionSerializer marks it read-only,
  // changeable only via the dedicated activate/deactivate actions.
  Map<String, dynamic> toJson() => {
    'title':    name,
    'org_unit': departmentId,
  };

  Map<String, String?> validate() {
    final errors = <String, String?>{};
    if (name.trim().isEmpty)                    errors['name']         = 'Designation name is required';
    if (departmentId == null || departmentId!.isEmpty) errors['departmentId'] = 'Department is required';
    return errors;
  }
}
