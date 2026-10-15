import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/org_chart_remote_datasource.dart';
import '../../data/models/org_chart_form_data.dart';
import '../../data/repositories/org_chart_repository_impl.dart';
import '../../domain/entities/org_chart_entity.dart';
import '../../domain/repositories/org_chart_repository.dart';

final orgChartDataSourceProvider = Provider<OrgChartRemoteDataSource>((ref) {
  return OrgChartRemoteDataSource(ref.watch(dioProvider));
});

final orgChartRepositoryProvider = Provider<OrgChartRepository>((ref) {
  return OrgChartRepositoryImpl(ref.watch(orgChartDataSourceProvider));
});

@immutable
class OrgStructureData {
  final List<OrgUnitEntity> units;
  final List<OrgPositionEntity> positions;
  const OrgStructureData({required this.units, required this.positions});
}

final orgChartProvider =
    AsyncNotifierProvider.autoDispose<OrgChartNotifier, OrgStructureData>(
  OrgChartNotifier.new,
);

class OrgChartNotifier extends AutoDisposeAsyncNotifier<OrgStructureData> {
  OrgChartRepository get _repo => ref.read(orgChartRepositoryProvider);

  @override
  Future<OrgStructureData> build() async {
    final results = await Future.wait([_repo.getUnits(), _repo.getPositions()]);
    return OrgStructureData(
      units:     results[0] as List<OrgUnitEntity>,
      positions: results[1] as List<OrgPositionEntity>,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final orgChartBranchesProvider =
    FutureProvider.autoDispose<List<OrgBranchEntity>>((ref) {
  return ref.read(orgChartRepositoryProvider).getBranches();
});

/// Active employees for the "Assign holder" picker.
final orgChartEmployeeOptionsProvider =
    FutureProvider.autoDispose<List<EmployeeOptionEntity>>((ref) {
  return ref.read(orgChartRepositoryProvider).getEmployeeOptions();
});

/// A position's placement history — fetched fresh each time its edit sheet
/// opens (matches web's per-selection fetch in OrgStructureClient).
final orgChartPlacementsProvider =
    FutureProvider.autoDispose.family<List<PlacementEntity>, String>((ref, positionId) {
  return ref.read(orgChartRepositoryProvider).getPlacements(positionId);
});

/// Free-text filter over unit name/code and position title/holder name —
/// matches web's OrgTree search box.
final orgChartSearchProvider = StateProvider.autoDispose<String>((ref) => '');

/// Selected branch id, or null for "All branches". A branch-scoped position
/// (Position.branch set) must match exactly; a company-wide position
/// (branch == null) always matches, in every filter state — see
/// OrgUnitEntity/OrgPositionEntity doc comments.
final orgChartBranchFilterProvider = StateProvider.autoDispose<int?>((ref) => null);

// ── Job Templates ("Manage job templates") ──────────────────────────────────

final orgChartJobTemplatesProvider = AsyncNotifierProvider.autoDispose<
    OrgChartJobTemplatesNotifier, List<JobTemplateEntity>>(
  OrgChartJobTemplatesNotifier.new,
);

class OrgChartJobTemplatesNotifier extends AutoDisposeAsyncNotifier<List<JobTemplateEntity>> {
  OrgChartRepository get _repo => ref.read(orgChartRepositoryProvider);

  @override
  Future<List<JobTemplateEntity>> build() => _repo.getJobTemplates();

  Future<String?> create(JobTemplateFormData form) async {
    try {
      final created = await _repo.createJobTemplate(form);
      state = AsyncData([...state.valueOrNull ?? [], created]);
      return null;
    } catch (e) {
      return userFriendlyMessage(e);
    }
  }

  Future<String?> setActive(String id, bool isActive) async {
    try {
      final updated = await _repo.setJobTemplateActive(id, isActive);
      state = AsyncData((state.valueOrNull ?? []).map((t) => t.id == id ? updated : t).toList());
      return null;
    } catch (e) {
      return userFriendlyMessage(e);
    }
  }

  Future<String?> remove(String id) async {
    try {
      await _repo.deleteJobTemplate(id);
      state = AsyncData((state.valueOrNull ?? []).where((t) => t.id != id).toList());
      return null;
    } catch (e) {
      return userFriendlyMessage(e);
    }
  }
}
