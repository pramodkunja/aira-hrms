# AIRA HRMS — Mobile Design System

Extracted from the already-shipped Dashboard/Menu/Bottom-Navigation redesign.
This is the reference for every future screen-by-screen redesign — reach for
these tokens/components instead of re-inlining `Container(decoration: ...)`.

Nothing here changes existing APIs, providers, repositories, routes,
permissions, or data. This is a UI-layer extraction only.

## Colors — `core/theme/app_colors.dart`

All fields are live mutable statics (`AppColors.primary`, etc.) that flip
automatically on light/dark toggle — never hardcode a hex in a widget.

| Token | Meaning | Notes |
|---|---|---|
| `primary` / `primaryLight` | Brand teal | was deep blue before the Dashboard redesign |
| `primaryContainer` | Light teal tint | new — pairs with `primary` the way `successContainer` pairs with `success` |
| `secondary` / `secondaryContainer` | Brand gold | unchanged since before the redesign |
| `accentNavy` | The old deep-blue brand color | kept alive for the handful of new widgets that want a navy accent next to the new teal |
| `background` / `backgroundLow` / `backgroundMid` / `surface` | Surfaces | `surfaceVariant` is an alias for `backgroundLow` |
| `textPrimary` / `textSecondary` / `textHint` | Text | `textTertiary` is an alias for `textHint` |
| `border` | Dividers/outlines | `divider` is an alias for `border` |
| `disabled` | Alias for `textHint` | `AppButton`'s disabled *background* still uses `primaryLight` specifically — that's a deliberate, separate case |
| `success` / `warning` / `error` / `info` (+ `*Container`) | Status colors | unchanged |
| `accentPurple` / `accentPurpleContainer` | "Half day"/"incomplete" attendance accent | unchanged |

## Typography — `core/theme/app_text_styles.dart`

Base sizes (`h1`-`h4`, `body`, `bodySmall`, `label`, `labelSmall`, `caption`,
`button`) are unchanged. New semantic aliases map onto whichever of those the
Dashboard/Menu already uses for that role — use the role name, not the raw
size, in new screens:

| Alias | = | Real-world usage today |
|---|---|---|
| `display` | `h1` | rare — auth/onboarding hero numbers |
| `headline` | `h2` | |
| `title` | `h3` | |
| `screenTitle` | `h4` + w700 | `AppTopBar` page title, `DashboardHeader` greeting |
| `sectionTitle` | `h4` | `SectionCard`'s header title |
| `cardTitle` | `body` + w600 | a card's own row/item title (leave balances, action items, recent requests) |
| `cardSubtitle` | `caption` | the supporting line under a `cardTitle` |
| `moduleTitle` | `labelSmall` + w600 | `ModuleIconCard`/`QuickTile` labels |

## Spacing — `core/theme/app_spacing.dart`

`xs`=4, `sm`=8, `md`=12, `lg`=16, `xl`=20, `xxl`=24, `xxxl`=32.

## Radius — `core/theme/app_radius.dart`

Extracted from real usage, not invented: `small`=8 (inputs/buttons),
`medium`=12 (cards), `large`=16 (tiles), `extraLarge`=24 (hero cards),
`floating`=28 (sheets/bottom nav). `pill`=999 for height-independent full-round
badges/chips. `sheetTop` gives rounded-top-only corners for bottom sheets.

## Shadows — `core/theme/app_shadows.dart`

`card`/`elevated` delegate straight to the pre-existing (already theme-aware)
`AppColors.cardShadow`/`elevatedShadow` — same values, semantic names. `none`
and `subtle` are new, smaller sizes. `floating` (bottom nav / center button)
is numerically identical to `elevated` today — kept as its own name so future
code can ask for it specifically without implying it's "just a card".

## Motion — `core/theme/app_motion.dart`

`fast`=160ms (matches the notification dropdown panel), `normal`=300ms (new —
a sensible default, not yet used anywhere specific), `slow`=900ms (matches the
attendance ring fill and the loading skeleton). `standard` curve =
`Curves.easeOutCubic`, the one curve already used everywhere animated.

## Components — `shared/widgets/`

| Component | What it is | Status |
|---|---|---|
| `AppCard` | Base rounded-surface-with-shadow shell | New. `SectionCard` (`dashboard/.../dashboard_section.dart`) now builds its outer chrome from this. |
| `AppAvatar` (+ `initialsOf`) | Circular initials avatar, optional active-ring + verified badge | New. Consolidates 3 near-duplicate inline avatar blocks (Dashboard header, Menu sheet account row) plus the old `InitialsAvatar`/`StatusRingAvatar` (now thin wrappers around this, kept under their original names since other dashboard files reference them). |
| `AppStatusBadge` | Colored status pill (pending/approved/rejected/cancelled) | New. Consolidates the duplicated `(bg, fg)` switch that used to live separately in `employee_dashboard_view.dart`'s `_StatusBadge` and `home_screen.dart`'s `_RequestRow` — both now delegate to this. |
| `AppSkeleton` (+ `AppSkeletonBar`) | 2-row shimmer loading placeholder | New. Promoted out of `dashboard_section.dart`'s private `_SectionSkeleton` — `SectionMessage`'s `loading:` branch now uses this, so every one of the ~26 dashboard cards that render it gets it for free. |
| `AppSearchField` | Rounded filled search input | New. The Menu sheet's search bar now uses this instead of an inline `TextField`. |
| `AppBottomSheet` | Rounded-top, drag-handle sheet chrome (+ `showDraggable` helper) | New. The Menu sheet now builds its chrome from this. |
| `AppIconButton` | Circular icon button on an elevated chip, optional count badge | New — available for future screens. Not forced into `NotificationBellButton` (it owns its own overlay-anchoring logic) or `AppBottomNav`'s center button (already correct as-is). |
| `AppChip` | Generic tinted label pill (not status-specific) | New — available for future tag/category chips. |
| `AppBannerCard` | Tinted bordered inline banner (icon, eyebrow, title, subtitle, view/dismiss) | New — available for future real, API-backed banners. **Not yet wired into the 3 existing per-role Announcement widgets** (Employee/HR/Admin dashboards) — each binds a different provider and a couple of role-specific fields (pinned wording, category tag) that need a closer look before consolidating without changing behavior; left as a follow-up rather than risking Dashboard content in this pass. |
| `AppDialog.confirm` | Cancel/confirm dialog helper | New. `DashboardShell`'s "Exit Application?" dialog now uses this. |
| `AppButton` | filled/outline/ghost button | **Already existed** — this already covers "AppPrimaryButton"/"AppSecondaryButton"; use `variant:` instead of separate classes. |
| `AppTextField` | Labeled text input | **Already existed** — reuse as-is. |
| `AppEmptyState` / `AppErrorState` | Full-screen empty/error states | **Already existed** — full-screen only; for an inline state *inside* a dashboard card, use `SectionMessage`/`SectionError` (`dashboard_section.dart`) instead, which are a different (smaller, embedded) shape for a different context. |
| `AppLoadingWidget` / `AppLoadingOverlay` | Full-screen/overlay spinner | **Already existed** — reuse as-is. |
| `ModuleIconCard` / `ModuleGrid` (`shared/widgets/module_card.dart`) | Module tile + responsive grid | **Already existed** (built during the Menu redesign) — this *is* the "AppModuleCard"/"AppModuleIcon" the design system calls for; don't create a second one. |

## Rules for future screen redesigns

1. Colors, text styles, spacing, radius, shadows, and durations always come
   from the token files above — never a raw hex/number in a widget.
2. Before building a new "reusable" widget, check this table first — most of
   what a screen needs already exists.
3. A card gets its outer shell from `AppCard` (or `SectionCard` if it needs a
   title row). An avatar is always `AppAvatar`. A status pill is always
   `AppStatusBadge`. A loading placeholder inside a card is `AppSkeleton`
   (via `SectionMessage`); a loading full screen is `AppLoadingWidget`.
4. Preserve every existing field, provider, route, and permission on the
   screen being redesigned — this system only ever changes how something
   looks, never what it does.
5. If a screen's existing look genuinely conflicts with a token (e.g. a
   one-off radius that doesn't match `AppRadius`), that's a legitimate,
   small "fix the inconsistency" moment — but only ever change the number,
   never remove functionality to get there.
