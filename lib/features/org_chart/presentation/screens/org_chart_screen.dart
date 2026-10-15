import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../domain/entities/org_chart_entity.dart';
import '../providers/org_chart_providers.dart';
import '../widgets/add_unit_sheet.dart';
import '../widgets/manage_job_templates_sheet.dart';
import '../widgets/org_dialog_header.dart';
import '../widgets/org_root_card.dart';
import '../widgets/org_unit_card.dart';
import '../widgets/position_edit_sheet.dart';
import '../widgets/unit_edit_sheet.dart';

const _kDeptPalette = [
  Color(0xFFE65100),
  Color(0xFF1565C0),
  Color(0xFF2E7D32),
  Color(0xFF6A1B9A),
  Color(0xFF00838F),
  Color(0xFFAD1457),
  Color(0xFF37474F),
  Color(0xFFC62828),
];

// Builds the unit tree client-side from the flat units/positions lists —
// same traversal web's OrgTree.tsx does (childUnits/posInUnit/matchUnit),
// with search and branch filtering already applied so every widget below
// this point just renders what it's given. See OrgUnitTreeNode's doc
// comment for why this can't be pre-nested server-side.
List<OrgUnitTreeNode> _buildTree(
  List<OrgUnitEntity> units,
  List<OrgPositionEntity> positions,
  String query,
  int? branchFilter,
) {
  final q = query.trim().toLowerCase();

  List<OrgUnitEntity> childUnits(String? parentId) =>
      units.where((u) => u.parentId == parentId).toList();

  // A branch-scoped position must match exactly; a company-wide position
  // (branch == null) always shows. Once a branch is actually selected, only
  // vacant positions show — narrowing to "what's open here" (hiring into
  // that branch), matching web's OrgTree.matchesBranch() exactly (a filled
  // seat elsewhere isn't something you'd be assigning into anyway).
  bool matchesBranch(OrgPositionEntity p) {
    if (branchFilter == null) return true;
    if (p.branch != null && p.branch != branchFilter) return false;
    return p.isVacant;
  }

  List<OrgPositionEntity> posInUnit(String unitId) =>
      positions.where((p) => p.orgUnitId == unitId && matchesBranch(p)).toList();

  bool matchesSearch(OrgUnitEntity u) {
    if (q.isEmpty) return true;
    if (u.name.toLowerCase().contains(q) || u.code.toLowerCase().contains(q)) return true;
    if (posInUnit(u.id).any((p) =>
        p.title.toLowerCase().contains(q) || (p.holderName ?? '').toLowerCase().contains(q))) {
      return true;
    }
    return childUnits(u.id).any(matchesSearch);
  }

  bool hasBranchMatch(OrgUnitEntity u) {
    if (branchFilter == null) return true;
    if (posInUnit(u.id).isNotEmpty) return true;
    return childUnits(u.id).any(hasBranchMatch);
  }

  bool matchUnit(OrgUnitEntity u) => matchesSearch(u) && hasBranchMatch(u);

  OrgUnitTreeNode? build(OrgUnitEntity u) {
    if (!matchUnit(u)) return null;
    final children = childUnits(u.id).map(build).whereType<OrgUnitTreeNode>().toList();
    return OrgUnitTreeNode(unit: u, positions: posInUnit(u.id), children: children);
  }

  return childUnits(null).map(build).whereType<OrgUnitTreeNode>().toList();
}

class OrgChartScreen extends ConsumerWidget {
  const OrgChartScreen({super.key});

  void _openProfile(BuildContext context, OrgPositionEntity position) {
    final employeeId = position.holderEmployeeId;
    if (employeeId == null || employeeId.isEmpty) return;
    context.push(AppRoutes.employeeProfilePath(employeeId));
  }

  Future<void> _openAddUnit(BuildContext context) {
    return showOrgDialog(context, const AddUnitSheet());
  }

  Future<void> _openUnit(BuildContext context, OrgUnitEntity unit) {
    return showOrgDialog(context, UnitEditSheet(unitId: unit.id));
  }

  Future<void> _openPosition(BuildContext context, OrgPositionEntity position) {
    return showOrgDialog(context, PositionEditSheet(positionId: position.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final structureAsync = ref.watch(orgChartProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddUnit(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Org Unit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(orgChartProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _Header()),
            structureAsync.when(
              loading: () => SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
              error: (e, _) => SliverFillRemaining(
                child: AppErrorState(
                  message: userFriendlyMessage(e),
                  title: 'Failed to load org chart',
                  onRetry: () => ref.invalidate(orgChartProvider),
                ),
              ),
              data: (structure) => structure.units.isEmpty
                  ? const SliverFillRemaining(
                      child: AppEmptyState(
                        icon: Icons.account_tree_outlined,
                        title: 'No organisation structure yet',
                        message: 'No org units have been set up yet.',
                      ),
                    )
                  : SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(child: _StatsRow(structure: structure)),
                        _OrgTreeBody(
                          structure: structure,
                          onTapHolder: (p) => _openProfile(context, p),
                          onEditUnit: (u) => _openUnit(context, u),
                          onEditPosition: (p) => _openPosition(context, p),
                        ),
                      ],
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ── Stats row — matches web's OrgStructureClient stat cards exactly ────────

class _StatsRow extends StatelessWidget {
  final OrgStructureData structure;
  const _StatsRow({required this.structure});

  @override
  Widget build(BuildContext context) {
    final vacant = structure.positions.where((p) => p.isVacant).length;
    final placed = structure.positions.where((p) => !p.isVacant).map((p) => p.holderId).toSet().length;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: StatCardRow(cards: [
        StatCard(
          icon: Icons.account_tree_outlined,
          count: structure.units.length,
          label: 'Org Units',
          color: AppColors.primary,
        ),
        StatCard(
          icon: Icons.badge_outlined,
          count: structure.positions.length,
          label: 'Positions',
          color: AppColors.primary,
        ),
        StatCard(
          icon: Icons.person_search_outlined,
          count: vacant,
          label: 'Vacant Positions',
          color: AppColors.warning,
        ),
        StatCard(
          icon: Icons.groups_outlined,
          count: placed,
          label: 'People Placed',
          color: const Color(0xFF7C3AED),
        ),
      ]),
    );
  }
}

// ── Header (title + search + branch chips) ─────────────────────────────────

class _Header extends ConsumerStatefulWidget {
  const _Header();

  @override
  ConsumerState<_Header> createState() => _HeaderState();
}

class _HeaderState extends ConsumerState<_Header> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openManageTemplates(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 80),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ManageJobTemplatesSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlueHeroBanner(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Organisation Chart', style: AppTextStyles.h4.copyWith(color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(
                      'Org units, positions, and who holds each seat',
                      style: AppTextStyles.caption.copyWith(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ManageTemplatesButton(onTap: () => _openManageTemplates(context)),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => ref.read(orgChartSearchProvider.notifier).state = v,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Find unit, position or person',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
              prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.85), size: 18),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.15),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          const _BranchPicker(),
        ],
      ),
    );
  }
}

class _ManageTemplatesButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ManageTemplatesButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Manage job templates',
      child: Material(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: const Padding(
            padding: EdgeInsets.all(9),
            child: Icon(Icons.work_outline, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

class _BranchPicker extends ConsumerWidget {
  const _BranchPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(orgChartBranchesProvider);
    final selected = ref.watch(orgChartBranchFilterProvider);
    return branchesAsync.when(
      loading: () => const SizedBox(height: 32),
      error: (_, __) => const SizedBox.shrink(),
      data: (branches) {
        if (branches.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _BranchChip(
                label: 'All Branches',
                selected: selected == null,
                onTap: () => ref.read(orgChartBranchFilterProvider.notifier).state = null,
              ),
              const SizedBox(width: 8),
              for (final b in branches) ...[
                _BranchChip(
                  label: b.name,
                  selected: selected == b.id,
                  onTap: () => ref.read(orgChartBranchFilterProvider.notifier).state = b.id,
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BranchChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _BranchChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tree body ────────────────────────────────────────────────────────────

class _OrgTreeBody extends ConsumerWidget {
  final OrgStructureData structure;
  final ValueChanged<OrgPositionEntity> onTapHolder;
  final ValueChanged<OrgUnitEntity> onEditUnit;
  final ValueChanged<OrgPositionEntity> onEditPosition;
  const _OrgTreeBody({
    required this.structure,
    required this.onTapHolder,
    required this.onEditUnit,
    required this.onEditPosition,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(orgChartSearchProvider);
    final branchFilter = ref.watch(orgChartBranchFilterProvider);
    final roots = _buildTree(structure.units, structure.positions, query, branchFilter);

    if (roots.isEmpty) {
      return const SliverFillRemaining(
        child: AppEmptyState(
          icon: Icons.search_off,
          title: 'Nothing matches',
          message: 'Try a different search term or branch.',
        ),
      );
    }

    var colorIndex = 0;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      sliver: SliverList.list(
        children: [
          for (final root in roots) ...[
            _RootGroup(
              root: root,
              color: _kDeptPalette[colorIndex++ % _kDeptPalette.length],
              onTapHolder: onTapHolder,
              onEditUnit: onEditUnit,
              onEditPosition: onEditPosition,
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

class _RootGroup extends StatelessWidget {
  final OrgUnitTreeNode root;
  final Color color;
  final ValueChanged<OrgPositionEntity> onTapHolder;
  final ValueChanged<OrgUnitEntity> onEditUnit;
  final ValueChanged<OrgPositionEntity> onEditPosition;
  const _RootGroup({
    required this.root,
    required this.color,
    required this.onTapHolder,
    required this.onEditUnit,
    required this.onEditPosition,
  });

  @override
  Widget build(BuildContext context) {
    final chief = root.chief;
    return Column(
      children: [
        OrgRootCard(
          unitName: root.unit.name,
          title: chief?.title,
          holderName: chief?.holderName,
          onTap: chief == null ? null : () => onTapHolder(chief),
          onEditUnit: () => onEditUnit(root.unit),
        ),
        if (root.nonChiefPositions.isNotEmpty || root.children.isNotEmpty) ...[
          Center(child: Container(width: 1.5, height: 32, color: AppColors.border)),
          if (root.nonChiefPositions.isNotEmpty)
            _RootPositions(positions: root.nonChiefPositions, onTap: onTapHolder, onEdit: onEditPosition),
          ...root.children.asMap().entries.map((entry) {
            final isLast = entry.key == root.children.length - 1;
            return _BranchRow(
              node: entry.value,
              isLast: isLast,
              color: color,
              onTapHolder: onTapHolder,
              onEditUnit: onEditUnit,
              onEditPosition: onEditPosition,
            );
          }),
        ],
      ],
    );
  }
}

// The root unit's own non-chief positions are rare in real data (the top
// unit usually has exactly one chief seat and nothing else) but not
// impossible — shown as a plain member list rather than silently dropped.
class _RootPositions extends StatelessWidget {
  final List<OrgPositionEntity> positions;
  final ValueChanged<OrgPositionEntity> onTap;
  final ValueChanged<OrgPositionEntity> onEdit;
  const _RootPositions({required this.positions, required this.onTap, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: positions
            .map((p) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.isVacant ? 'Vacant' : (p.holderName ?? ''), style: AppTextStyles.bodySmall),
                  subtitle: Text(p.title, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  onTap: p.isVacant ? null : () => onTap(p),
                  trailing: InkWell(
                    onTap: () => onEdit(p),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined, size: 15, color: AppColors.textHint),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _BranchRow extends StatelessWidget {
  final OrgUnitTreeNode node;
  final bool isLast;
  final Color color;
  final ValueChanged<OrgPositionEntity> onTapHolder;
  final ValueChanged<OrgUnitEntity> onEditUnit;
  final ValueChanged<OrgPositionEntity> onEditPosition;
  const _BranchRow({
    required this.node,
    required this.isLast,
    required this.color,
    required this.onTapHolder,
    required this.onEditUnit,
    required this.onEditPosition,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 24, child: CustomPaint(painter: _BranchPainter(isLast: isLast, color: AppColors.border))),
            const SizedBox(width: 6),
            Expanded(
              child: OrgUnitCard(
                node: node,
                color: color,
                depth: 1,
                onTapHolder: onTapHolder,
                onEditUnit: onEditUnit,
                onEditPosition: onEditPosition,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchPainter extends CustomPainter {
  final bool isLast;
  final Color color;
  const _BranchPainter({required this.isLast, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const branchY = 32.0;
    final cx = size.width / 2;
    canvas.drawLine(Offset(cx, 0), Offset(cx, branchY), paint);
    if (!isLast) canvas.drawLine(Offset(cx, branchY), Offset(cx, size.height), paint);
    canvas.drawLine(Offset(cx, branchY), Offset(size.width, branchY), paint);
  }

  @override
  bool shouldRepaint(_BranchPainter old) => old.isLast != isLast || old.color != color;
}
