import 'package:flutter/foundation.dart';

// Mirrors the backend's real Org Structure model (OrgUnit/Position — see
// apps/accounts) exactly, the same shape the web app's /dashboard/org-chart
// page and this app's Settings > Depts & Designations screen both already
// consume. There is no separate "org chart" shape on the backend anymore —
// the tree (root org unit -> child units, recursively -> positions) is
// built client-side from these two flat lists, the same way web's OrgTree
// component does it.

@immutable
class OrgUnitEntity {
  final String id;
  final String name;
  final String code;
  final String? parentId;
  final bool isDepartmentLevel;
  final bool isActive;

  const OrgUnitEntity({
    required this.id,
    required this.name,
    required this.code,
    required this.parentId,
    required this.isDepartmentLevel,
    required this.isActive,
  });

  factory OrgUnitEntity.fromJson(Map<String, dynamic> json) => OrgUnitEntity(
    id:                json['id'] as String,
    name:              json['name'] as String? ?? '',
    code:              json['code'] as String? ?? '',
    parentId:          json['parent'] as String?,
    isDepartmentLevel: json['is_department_level'] as bool? ?? false,
    isActive:          json['is_active'] as bool? ?? true,
  );
}

@immutable
class ReportsToEntity {
  final String positionId;
  final String title;
  final String? holderName;
  const ReportsToEntity({required this.positionId, required this.title, required this.holderName});

  factory ReportsToEntity.fromJson(Map<String, dynamic> json) => ReportsToEntity(
    positionId: json['position_id'] as String? ?? '',
    title:      json['title'] as String? ?? '',
    holderName: json['holder_name'] as String?,
  );
}

@immutable
class ScheduledPlacementEntity {
  final String placementId;
  final String employeeName;
  final String effectiveFrom;
  const ScheduledPlacementEntity({
    required this.placementId,
    required this.employeeName,
    required this.effectiveFrom,
  });

  factory ScheduledPlacementEntity.fromJson(Map<String, dynamic> json) => ScheduledPlacementEntity(
    placementId:   json['placement_id'] as String? ?? '',
    employeeName:  json['employee_name'] as String? ?? '',
    effectiveFrom: json['effective_from'] as String? ?? '',
  );
}

@immutable
class OrgPositionEntity {
  final String id;
  final String orgUnitId;
  final String orgUnitName;
  final String title;
  final String grade;
  final bool isChief;
  final bool isActive;
  final String? jobTemplateId;
  final String? jobTemplateName;
  // Position.branch — a null branch is company-wide and matches every
  // branch filter (same convention as web's OrgTree.matchesBranch()).
  final int? branch;
  final String? branchName;
  final String? holderId;         // User.id (UUID) — not used for navigation
  final String? holderEmployeeId; // User.employee_id (e.g. "EMP0001") — used to open the profile
  final String? holderName;
  final String? holderSince;
  final ScheduledPlacementEntity? scheduled;
  final ReportsToEntity? reportsTo;

  const OrgPositionEntity({
    required this.id,
    required this.orgUnitId,
    required this.orgUnitName,
    required this.title,
    required this.grade,
    required this.isChief,
    required this.isActive,
    required this.jobTemplateId,
    required this.jobTemplateName,
    required this.branch,
    required this.branchName,
    required this.holderId,
    required this.holderEmployeeId,
    required this.holderName,
    required this.holderSince,
    required this.scheduled,
    required this.reportsTo,
  });

  bool get isVacant => holderId == null;

  factory OrgPositionEntity.fromJson(Map<String, dynamic> json) => OrgPositionEntity(
    id:               json['id'] as String,
    orgUnitId:        json['org_unit'] as String? ?? '',
    orgUnitName:      json['org_unit_name'] as String? ?? '',
    title:            json['title'] as String? ?? '',
    grade:            json['grade'] as String? ?? '',
    isChief:          json['is_chief'] as bool? ?? false,
    isActive:         json['is_active'] as bool? ?? true,
    jobTemplateId:    json['job_template'] as String?,
    jobTemplateName:  json['job_template_name'] as String?,
    branch:           json['branch'] as int?,
    branchName:       json['branch_name'] as String?,
    holderId:         json['holder'] as String?,
    holderEmployeeId: json['holder_employee_id'] as String?,
    holderName:       json['holder_name'] as String?,
    holderSince:      json['holder_since'] as String?,
    scheduled: json['scheduled'] == null
        ? null
        : ScheduledPlacementEntity.fromJson(json['scheduled'] as Map<String, dynamic>),
    reportsTo: json['reports_to'] == null
        ? null
        : ReportsToEntity.fromJson(json['reports_to'] as Map<String, dynamic>),
  );
}

@immutable
class PlacementEntity {
  final String id;
  final String positionId;
  final String employeeId;
  final String employeeName;
  final String employeeEmployeeId;
  final String effectiveFrom;
  final String? effectiveTo;
  final String note;
  final String status; // 'current' | 'scheduled' | 'ended'

  const PlacementEntity({
    required this.id,
    required this.positionId,
    required this.employeeId,
    required this.employeeName,
    required this.employeeEmployeeId,
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.note,
    required this.status,
  });

  factory PlacementEntity.fromJson(Map<String, dynamic> json) => PlacementEntity(
    id:                 json['id'] as String,
    positionId:         json['position'] as String? ?? '',
    employeeId:         json['employee'] as String? ?? '',
    employeeName:       json['employee_name'] as String? ?? '',
    employeeEmployeeId: json['employee_employee_id'] as String? ?? '',
    effectiveFrom:      json['effective_from'] as String? ?? '',
    effectiveTo:        json['effective_to'] as String?,
    note:               json['note'] as String? ?? '',
    status:             json['status'] as String? ?? '',
  );
}

// An employee option for the "Assign holder" picker.
//
// Deliberately keyed on `uuid` (User.id), not the top-level `id` field the
// employee list returns (that's User.employee_id, the display code, e.g.
// "EMP0001") — POST .../placements/ does `User.objects.get(pk=employee)`,
// which needs the real UUID primary key. Position.holder (what a
// reassignment pre-fills from) is also the UUID, via Placement's raw FK
// accessor — so this is the only field that round-trips correctly both
// ways.
@immutable
class EmployeeOptionEntity {
  final String uuid;
  final String fullName;
  final String employeeId;
  const EmployeeOptionEntity({required this.uuid, required this.fullName, required this.employeeId});

  factory EmployeeOptionEntity.fromJson(Map<String, dynamic> json) => EmployeeOptionEntity(
    uuid:       json['uuid'] as String? ?? '',
    fullName:   json['full_name'] as String? ?? '',
    employeeId: json['employee_id'] as String? ?? '',
  );
}

// A reusable job title offered when adding a position (Manage Job
// Templates) — matches backend JobTemplateSerializer exactly.
@immutable
class JobTemplateEntity {
  final String id;
  final String name;
  final String band;
  final bool isActive;

  const JobTemplateEntity({
    required this.id,
    required this.name,
    required this.band,
    required this.isActive,
  });

  factory JobTemplateEntity.fromJson(Map<String, dynamic> json) => JobTemplateEntity(
    id:       json['id'] as String,
    name:     json['name'] as String? ?? '',
    band:     json['band'] as String? ?? '',
    isActive: json['is_active'] as bool? ?? true,
  );
}

// A branch option for the chart's branch filter chips — same {id, name}
// shape as web's BranchOption (OrgStructureClient.tsx).
@immutable
class OrgBranchEntity {
  final int id;
  final String name;
  const OrgBranchEntity({required this.id, required this.name});

  factory OrgBranchEntity.fromJson(Map<String, dynamic> json) => OrgBranchEntity(
    id:   json['id'] as int,
    name: json['branch_name'] as String? ?? '',
  );
}

// A node in the tree built (client-side, in the screen) from the flat
// unit/position lists above — search and branch filtering are already
// applied by the time a node exists, so every widget below just renders
// what it's given. Arbitrary depth: the real org structure nests several
// levels (e.g. Software Services -> SAP -> SAP Functional -> positions),
// not just one flat "department" layer.
@immutable
class OrgUnitTreeNode {
  final OrgUnitEntity unit;
  final List<OrgPositionEntity> positions; // this unit's own positions (branch-filtered)
  final List<OrgUnitTreeNode> children;    // child units that survived filtering

  const OrgUnitTreeNode({
    required this.unit,
    required this.positions,
    required this.children,
  });

  OrgPositionEntity? get chief {
    for (final p in positions) {
      if (p.isChief) return p;
    }
    return null;
  }

  List<OrgPositionEntity> get nonChiefPositions =>
      positions.where((p) => !p.isChief).toList();
}
