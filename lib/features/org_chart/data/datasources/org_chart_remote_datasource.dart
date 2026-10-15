import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../domain/entities/org_chart_entity.dart';
import '../models/org_chart_form_data.dart';

class OrgChartRemoteDataSource {
  final Dio _dio;
  OrgChartRemoteDataSource(this._dio);

  /// The whole org-unit tree in one shot (matches web's OrgStructureClient,
  /// which fetches ?page_size=1000 for the same reason: the client builds
  /// parent/child relationships itself and can't do that against a
  /// truncated page).
  Future<List<OrgUnitEntity>> fetchUnits() async {
    final res = await _dio.get(
      ApiConstants.orgStructureUnits,
      queryParameters: {'page_size': 1000},
    );
    return _toList(_unwrap(res.data))
        .cast<Map<String, dynamic>>()
        .map(OrgUnitEntity.fromJson)
        .toList();
  }

  Future<List<OrgPositionEntity>> fetchPositions() async {
    final res = await _dio.get(
      ApiConstants.orgStructurePositions,
      queryParameters: {'page_size': 1000},
    );
    return _toList(_unwrap(res.data))
        .cast<Map<String, dynamic>>()
        .map(OrgPositionEntity.fromJson)
        .toList();
  }

  /// Branch options for the chart's branch filter — same source as every
  /// other branch dropdown in the app.
  Future<List<OrgBranchEntity>> fetchBranches() async {
    final res = await _dio.get(
      ApiConstants.branches,
      queryParameters: {'page_size': 200},
    );
    return _toList(_unwrap(res.data))
        .cast<Map<String, dynamic>>()
        .map(OrgBranchEntity.fromJson)
        .toList();
  }

  /// "Add org unit" — you don't assign a head here; add a position under
  /// the new unit next, then mark it chief (matches AddUnitModal exactly).
  Future<OrgUnitEntity> createUnit(OrgUnitFormData form) async {
    final res = await _dio.post(ApiConstants.orgStructureUnits, data: form.toJson());
    return OrgUnitEntity.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  /// Partial field update (name/code/parent/cost_center/is_department_level)
  /// — matches web's per-field onUnitField PUT. Turning off
  /// is_department_level can 409 with an "N employees affected" message;
  /// the caller resubmits with `confirm_department_change: true` in [patch]
  /// once the user has confirmed, same as OrgStructureClient.tsx.
  Future<OrgUnitEntity> updateUnit(String id, Map<String, dynamic> patch) async {
    final res = await _dio.put(ApiConstants.orgStructureUnitDetail(id), data: patch);
    return OrgUnitEntity.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  /// Hard delete — the backend 409s (with a clear message) if the unit has
  /// sub-units or any position ever held by someone; deactivate instead in
  /// that case (there's no reactivate for a unit, only for a position).
  Future<void> deleteUnit(String id) async {
    await _dio.delete(ApiConstants.orgStructureUnitDetail(id));
  }

  // ── Positions ────────────────────────────────────────────────────────────

  /// "Add position" — created vacant; assign a holder separately once
  /// someone is hired (matches AddPositionModal exactly).
  Future<OrgPositionEntity> createPosition(Map<String, dynamic> payload) async {
    final res = await _dio.post(ApiConstants.orgStructurePositions, data: payload);
    return OrgPositionEntity.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  /// Partial field update (title/grade/org_unit/job_template/branch/is_chief)
  /// — matches web's per-field onPositionField PUT / onToggleChief.
  Future<OrgPositionEntity> updatePosition(String id, Map<String, dynamic> patch) async {
    final res = await _dio.put(ApiConstants.orgStructurePositionDetail(id), data: patch);
    return OrgPositionEntity.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  /// Hard delete — 409s if it has ever had a holder; deactivate instead.
  Future<void> deletePosition(String id) async {
    await _dio.delete(ApiConstants.orgStructurePositionDetail(id));
  }

  Future<OrgPositionEntity> deactivatePosition(String id) async {
    final res = await _dio.post(ApiConstants.orgStructurePositionDeactivate(id));
    return OrgPositionEntity.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<OrgPositionEntity> activatePosition(String id) async {
    final res = await _dio.post(ApiConstants.orgStructurePositionActivate(id));
    return OrgPositionEntity.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  // ── Placements (assign / reassign / vacate / cancel) ───────────────────────

  Future<List<PlacementEntity>> fetchPlacements(String positionId) async {
    final res = await _dio.get(ApiConstants.orgStructurePositionPlacements(positionId));
    return _toList(_unwrap(res.data))
        .cast<Map<String, dynamic>>()
        .map(PlacementEntity.fromJson)
        .toList();
  }

  /// Assigns (or reassigns) a holder — [employeeUuid] must be the User's
  /// real UUID, see EmployeeOptionEntity's doc comment.
  Future<OrgPositionEntity> assignHolder(
    String positionId, {
    required String employeeUuid,
    required String effectiveFrom,
    String? effectiveTo,
  }) async {
    final res = await _dio.post(
      ApiConstants.orgStructurePositionPlacements(positionId),
      data: {
        'employee': employeeUuid,
        'effective_from': effectiveFrom,
        'effective_to': effectiveTo,
      },
    );
    return OrgPositionEntity.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<OrgPositionEntity> endPlacement(String positionId, {required String effectiveTo}) async {
    final res = await _dio.post(
      ApiConstants.orgStructurePositionPlacementsEnd(positionId),
      data: {'effective_to': effectiveTo},
    );
    return OrgPositionEntity.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  /// Cancels a scheduled (future-dated) placement outright.
  Future<void> cancelPlacement(String placementId) async {
    await _dio.delete(ApiConstants.orgStructurePlacementDetail(placementId));
  }

  /// Active employees for the "Assign holder" picker — same source and
  /// filters as web's OrgStructureClient.
  Future<List<EmployeeOptionEntity>> fetchEmployeeOptions() async {
    final res = await _dio.get(
      ApiConstants.employees,
      queryParameters: {'page_size': 200, 'status': 'active'},
    );
    return _toList(_unwrap(res.data))
        .cast<Map<String, dynamic>>()
        .map(EmployeeOptionEntity.fromJson)
        .toList();
  }

  // ── Job Templates ("Manage job templates") ──────────────────────────────
  // Reusable job titles offered when adding a position — deactivating one
  // stops it being offered for new positions without touching history on
  // positions that already use it (see JobTemplateDetailView.delete()'s
  // 409 for the same "don't destroy history" rule as units/positions).

  Future<List<JobTemplateEntity>> fetchJobTemplates() async {
    final res = await _dio.get(ApiConstants.orgStructureJobTemplates);
    return _toList(_unwrap(res.data))
        .cast<Map<String, dynamic>>()
        .map(JobTemplateEntity.fromJson)
        .toList();
  }

  Future<JobTemplateEntity> createJobTemplate(JobTemplateFormData form) async {
    final res = await _dio.post(ApiConstants.orgStructureJobTemplates, data: form.toJson());
    return JobTemplateEntity.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<JobTemplateEntity> patchJobTemplate(String id, Map<String, dynamic> patch) async {
    final res = await _dio.patch(ApiConstants.orgStructureJobTemplateDetail(id), data: patch);
    return JobTemplateEntity.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> deleteJobTemplate(String id) async {
    await _dio.delete(ApiConstants.orgStructureJobTemplateDetail(id));
  }

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  List<dynamic> _toList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) return data['results'] as List<dynamic>? ?? [];
    return const [];
  }
}
