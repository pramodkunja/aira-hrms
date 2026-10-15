import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/org_chart_entity.dart';

/// One org unit's card: an always-visible header (the unit's chief position
/// — "head" — if any) and an expandable body holding its other positions
/// plus, recursively, its child units. Expansion (not rendering everything
/// up front) matters here more than it did for the old flat department
/// list — the real structure nests 3-4 levels deep with hundreds of leaf
/// positions, so a fully unrolled tree would be an unusable wall of cards.
class OrgUnitCard extends StatefulWidget {
  final OrgUnitTreeNode node;
  final Color color;
  final int depth;
  final ValueChanged<OrgPositionEntity> onTapHolder;
  final ValueChanged<OrgUnitEntity> onEditUnit;
  final ValueChanged<OrgPositionEntity> onEditPosition;

  const OrgUnitCard({
    super.key,
    required this.node,
    required this.color,
    required this.depth,
    required this.onTapHolder,
    required this.onEditUnit,
    required this.onEditPosition,
  });

  @override
  State<OrgUnitCard> createState() => _OrgUnitCardState();
}

class _OrgUnitCardState extends State<OrgUnitCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final chief = node.chief;
    final members = node.nonChiefPositions;
    final hasBody = members.isNotEmpty || node.children.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: widget.color),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeadSection(
                    unit: node.unit,
                    chief: chief,
                    color: widget.color,
                    expanded: _expanded,
                    memberCount: members.length,
                    childUnitCount: node.children.length,
                    onTapHead: chief == null || chief.isVacant
                        ? null
                        : () => widget.onTapHolder(chief),
                    onToggle: hasBody ? () => setState(() => _expanded = !_expanded) : null,
                    onEditUnit: () => widget.onEditUnit(node.unit),
                  ),
                  if (_expanded && hasBody)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (members.isNotEmpty)
                            _MembersSection(
                              members: members,
                              color: widget.color,
                              onTap: widget.onTapHolder,
                              onEdit: widget.onEditPosition,
                            ),
                          if (node.children.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 14, right: 10, top: 8),
                              child: Column(
                                children: node.children
                                    .map((child) => Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: OrgUnitCard(
                                            node: child,
                                            color: widget.color,
                                            depth: widget.depth + 1,
                                            onTapHolder: widget.onTapHolder,
                                            onEditUnit: widget.onEditUnit,
                                            onEditPosition: widget.onEditPosition,
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeadSection extends StatelessWidget {
  final OrgUnitEntity unit;
  final OrgPositionEntity? chief;
  final Color color;
  final bool expanded;
  final int memberCount;
  final int childUnitCount;
  final VoidCallback? onTapHead;
  final VoidCallback? onToggle;
  final VoidCallback onEditUnit;

  const _HeadSection({
    required this.unit,
    required this.chief,
    required this.color,
    required this.expanded,
    required this.memberCount,
    required this.childUnitCount,
    required this.onTapHead,
    required this.onToggle,
    required this.onEditUnit,
  });

  @override
  Widget build(BuildContext context) {
    final isVacant = chief == null || chief!.isVacant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            unit.name.toUpperCase(),
                            style: AppTextStyles.caption.copyWith(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (chief != null) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.workspace_premium, size: 12, color: AppColors.warning),
                        ],
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: onEditUnit,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(Icons.edit_outlined, size: 13, color: AppColors.textHint),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: onTapHead,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        isVacant ? 'Vacant' : chief!.holderName!,
                        style: AppTextStyles.h4.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: isVacant
                              ? AppColors.textHint
                              : (onTapHead != null ? AppColors.primary : null),
                        ),
                      ),
                    ),
                    if (chief != null && chief!.title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          chief!.title,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              if (onToggle != null) ...[
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textHint,
                    ),
                    Text(
                      '${memberCount + childUnitCount}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MembersSection extends StatelessWidget {
  final List<OrgPositionEntity> members;
  final Color color;
  final ValueChanged<OrgPositionEntity> onTap;
  final ValueChanged<OrgPositionEntity> onEdit;

  const _MembersSection({
    required this.members,
    required this.color,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: members
            .map((p) => _MemberRow(position: p, onTap: () => onTap(p), onEdit: () => onEdit(p)))
            .toList(),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final OrgPositionEntity position;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _MemberRow({required this.position, required this.onTap, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isVacant = position.isVacant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isVacant ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              if (isVacant)
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.textHint.withValues(alpha: 0.12),
                  child: Icon(Icons.person_off_outlined, size: 15, color: AppColors.textHint),
                )
              else
                _InitialsAvatar(name: position.holderName ?? ''),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVacant ? 'Vacant' : position.holderName!,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isVacant ? AppColors.textHint : null,
                      ),
                    ),
                    Text(
                      position.title,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!position.isActive)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.textHint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Inactive', style: AppTextStyles.caption.copyWith(fontSize: 9.5, color: AppColors.textHint)),
                ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.edit_outlined, size: 15, color: AppColors.textHint),
                ),
              ),
              if (!isVacant) Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

const _kAvatarPalette = [
  Color(0xFF1E4E8C),
  Color(0xFF219653),
  Color(0xFF7C3AED),
  Color(0xFFD4487B),
  Color(0xFFF2994A),
  Color(0xFF2D9CDB),
  Color(0xFFEB5757),
  Color(0xFF9B51E0),
  Color(0xFF0D7490),
];

class _InitialsAvatar extends StatelessWidget {
  final String name;
  const _InitialsAvatar({required this.name});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || name.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Color get _color =>
      name.isEmpty ? _kAvatarPalette[0] : _kAvatarPalette[name.codeUnitAt(0) % _kAvatarPalette.length];

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: _color.withValues(alpha: 0.15),
      child: Text(
        _initials,
        style: AppTextStyles.caption.copyWith(color: _color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
