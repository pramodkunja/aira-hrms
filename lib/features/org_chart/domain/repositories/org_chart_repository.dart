import '../../data/models/org_chart_form_data.dart';
import '../entities/org_chart_entity.dart';

abstract class OrgChartRepository {
  /// The whole org-unit tree, flat (parent/child relationships are built by
  /// the presentation layer, same as web's OrgTree — see that component's
  /// doc comment for why this lives client-side rather than being fetched
  /// pre-nested).
  Future<List<OrgUnitEntity>> getUnits();

  /// Every position across every unit, flat.
  Future<List<OrgPositionEntity>> getPositions();

  /// Branch options for the chart's branch filter chips / position forms.
  Future<List<OrgBranchEntity>> getBranches();

  Future<OrgUnitEntity> createUnit(OrgUnitFormData form);
  Future<OrgUnitEntity> updateUnit(String id, Map<String, dynamic> patch);
  Future<void> deleteUnit(String id);

  Future<OrgPositionEntity> createPosition(Map<String, dynamic> payload);
  Future<OrgPositionEntity> updatePosition(String id, Map<String, dynamic> patch);
  Future<void> deletePosition(String id);
  Future<OrgPositionEntity> deactivatePosition(String id);
  Future<OrgPositionEntity> activatePosition(String id);

  Future<List<PlacementEntity>> getPlacements(String positionId);
  Future<OrgPositionEntity> assignHolder(
    String positionId, {
    required String employeeUuid,
    required String effectiveFrom,
    String? effectiveTo,
  });
  Future<OrgPositionEntity> endPlacement(String positionId, {required String effectiveTo});
  Future<void> cancelPlacement(String placementId);
  Future<List<EmployeeOptionEntity>> getEmployeeOptions();

  Future<List<JobTemplateEntity>> getJobTemplates();
  Future<JobTemplateEntity> createJobTemplate(JobTemplateFormData form);
  Future<JobTemplateEntity> setJobTemplateActive(String id, bool isActive);
  Future<void> deleteJobTemplate(String id);
}
