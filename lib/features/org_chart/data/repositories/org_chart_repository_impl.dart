import '../../domain/entities/org_chart_entity.dart';
import '../../domain/repositories/org_chart_repository.dart';
import '../datasources/org_chart_remote_datasource.dart';
import '../models/org_chart_form_data.dart';

class OrgChartRepositoryImpl implements OrgChartRepository {
  final OrgChartRemoteDataSource _ds;
  OrgChartRepositoryImpl(this._ds);

  @override
  Future<List<OrgUnitEntity>> getUnits() => _ds.fetchUnits();

  @override
  Future<List<OrgPositionEntity>> getPositions() => _ds.fetchPositions();

  @override
  Future<List<OrgBranchEntity>> getBranches() => _ds.fetchBranches();

  @override
  Future<OrgUnitEntity> createUnit(OrgUnitFormData form) => _ds.createUnit(form);

  @override
  Future<OrgUnitEntity> updateUnit(String id, Map<String, dynamic> patch) => _ds.updateUnit(id, patch);

  @override
  Future<void> deleteUnit(String id) => _ds.deleteUnit(id);

  @override
  Future<OrgPositionEntity> createPosition(Map<String, dynamic> payload) => _ds.createPosition(payload);

  @override
  Future<OrgPositionEntity> updatePosition(String id, Map<String, dynamic> patch) =>
      _ds.updatePosition(id, patch);

  @override
  Future<void> deletePosition(String id) => _ds.deletePosition(id);

  @override
  Future<OrgPositionEntity> deactivatePosition(String id) => _ds.deactivatePosition(id);

  @override
  Future<OrgPositionEntity> activatePosition(String id) => _ds.activatePosition(id);

  @override
  Future<List<PlacementEntity>> getPlacements(String positionId) => _ds.fetchPlacements(positionId);

  @override
  Future<OrgPositionEntity> assignHolder(
    String positionId, {
    required String employeeUuid,
    required String effectiveFrom,
    String? effectiveTo,
  }) =>
      _ds.assignHolder(
        positionId,
        employeeUuid: employeeUuid,
        effectiveFrom: effectiveFrom,
        effectiveTo: effectiveTo,
      );

  @override
  Future<OrgPositionEntity> endPlacement(String positionId, {required String effectiveTo}) =>
      _ds.endPlacement(positionId, effectiveTo: effectiveTo);

  @override
  Future<void> cancelPlacement(String placementId) => _ds.cancelPlacement(placementId);

  @override
  Future<List<EmployeeOptionEntity>> getEmployeeOptions() => _ds.fetchEmployeeOptions();

  @override
  Future<List<JobTemplateEntity>> getJobTemplates() => _ds.fetchJobTemplates();

  @override
  Future<JobTemplateEntity> createJobTemplate(JobTemplateFormData form) =>
      _ds.createJobTemplate(form);

  @override
  Future<JobTemplateEntity> setJobTemplateActive(String id, bool isActive) =>
      _ds.patchJobTemplate(id, {'is_active': isActive});

  @override
  Future<void> deleteJobTemplate(String id) => _ds.deleteJobTemplate(id);
}
