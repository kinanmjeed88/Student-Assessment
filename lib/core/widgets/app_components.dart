import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

abstract final class AppSpacing {
  static const page = AppTokens.pagePadding;
  static const contentList = EdgeInsets.fromLTRB(20, 0, 20, 100);
  static const emptyState = EdgeInsets.symmetric(vertical: 80);
  static const section = SizedBox(height: AppTokens.sectionGap);
  static const compact = SizedBox(height: AppTokens.compactGap);
  static const item = SizedBox(height: AppTokens.itemGap);
}

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({required this.title, this.subtitle, this.actions = const [], super.key});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppTokens.compactGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: AppTokens.compactGap),
            Flexible(child: Wrap(spacing: 4, children: actions)),
          ],
        ],
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({required this.title, this.subtitle, this.action, super.key});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap, super.key});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: color,
      child: Padding(padding: padding, child: child),
    );
    return onTap == null ? card : InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.largeRadius),
      child: card,
    );
  }
}

class AppStatusPill extends StatelessWidget {
  const AppStatusPill({required this.label, required this.icon, this.tone = AppStatusTone.neutral, this.compact = false, this.prominent = false, super.key});

  final String label;
  final IconData icon;
  final AppStatusTone tone;
  final bool compact;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      AppStatusTone.success => (scheme.primaryContainer, scheme.onPrimaryContainer),
      AppStatusTone.warning => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      AppStatusTone.error => (scheme.errorContainer, scheme.onErrorContainer),
      AppStatusTone.neutral => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: prominent ? AppTokens.prominentPillPadding : compact ? AppTokens.compactPillPadding : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: prominent ? 18 : compact ? 15 : 16, color: foreground),
          SizedBox(width: compact ? AppTokens.tightGap : 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (prominent ? Theme.of(context).textTheme.labelMedium : compact ? Theme.of(context).textTheme.labelSmall : Theme.of(context).textTheme.labelMedium)?.copyWith(color: foreground, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

enum AppStatusTone { neutral, success, warning, error }

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({required this.icon, required this.title, required this.message, this.action, super.key});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppSurfaceCard(
      padding: const EdgeInsets.all(AppTokens.cardPadding * 1.75),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: Icon(icon, size: 28),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(message),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class AppResponsiveContent extends StatelessWidget {
  const AppResponsiveContent({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth >= AppTokens.contentMaxWidth
            ? AppTokens.contentMaxWidth
            : constraints.maxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth.clamp(0.0, AppTokens.contentMaxWidth).toDouble(),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class AppMetricTile extends StatelessWidget {
  const AppMetricTile({required this.label, required this.value, required this.icon, this.tone = AppStatusTone.neutral, this.compact = false, super.key});

  final String label;
  final String value;
  final IconData icon;
  final AppStatusTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      AppStatusTone.success => (scheme.primaryContainer, scheme.onPrimaryContainer),
      AppStatusTone.warning => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      AppStatusTone.error => (scheme.errorContainer, scheme.onErrorContainer),
      AppStatusTone.neutral => (scheme.secondaryContainer, scheme.onSecondaryContainer),
    };
    final textTheme = Theme.of(context).textTheme;
    return AppSurfaceCard(
      padding: EdgeInsets.all(compact ? AppTokens.compactGap : AppTokens.cardPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: compact ? 14 : 18,
            backgroundColor: background,
            foregroundColor: foreground,
            child: Icon(icon, size: compact ? 16 : 19),
          ),
          SizedBox(height: compact ? 4 : 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: (compact ? textTheme.titleMedium : textTheme.titleLarge)?.copyWith(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 2),
          Text(label, maxLines: compact ? 2 : 2, overflow: TextOverflow.ellipsis, style: (compact ? textTheme.labelSmall : textTheme.labelMedium)?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}


class AppFormSheet extends StatelessWidget {
  const AppFormSheet({required this.title, required this.child, required this.actions, this.subtitle, super.key});

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final maxHeight = MediaQuery.sizeOf(context).height * .88;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: AppTokens.formPadding.add(EdgeInsetsDirectional.only(bottom: viewInsets.bottom)),
          child: AppResponsiveContent(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                          if (subtitle != null) ...[const SizedBox(height: 5), Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium)],
                        ],
                      ),
                    ),
                    IconButton(tooltip: 'إغلاق', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 18),
                Flexible(child: SingleChildScrollView(child: child)),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var index = 0; index < actions.length; index++) ...[if (index > 0) const SizedBox(width: AppTokens.compactGap), actions[index]],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showAppFormSheet<T>({required BuildContext context, required String title, String? subtitle, required Widget child, required List<Widget> actions}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => AppFormSheet(title: title, subtitle: subtitle, actions: actions, child: child),
  );
}
