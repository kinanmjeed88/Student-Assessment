import 'package:flutter/material.dart';

/// Shared visual tokens keep layout decisions consistent across the app.
abstract final class AppTokens {
  static const pagePadding = EdgeInsetsDirectional.fromSTEB(20, 16, 20, 32);
  static const compactPagePadding = EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24);
  static const formPadding = EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16);

  static const sectionGap = 24.0;
  static const compactGap = 12.0;
  static const tightGap = 4.0;
  static const itemGap = 10.0;
  static const fieldGap = 12.0;
  static const cardPadding = 16.0;
  static const denseCardPadding = 12.0;
  static const compactPillPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 5);
  static const largePillPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 6);

  static const smallRadius = 12.0;
  static const mediumRadius = 16.0;
  static const largeRadius = 20.0;
  static const pillRadius = 999.0;

  static const minTouchTarget = 48.0;
  static const contentMaxWidth = 1080.0;
  static const motionDuration = Duration(milliseconds: 220);
  static const motionCurve = Curves.easeOutCubic;
}

abstract final class AppBreakpoints {
  static const compact = 360.0;
  static const medium = 600.0;
  static const expanded = 900.0;
}

extension AppConstraintX on BoxConstraints {
  bool get isCompact => maxWidth < AppBreakpoints.compact;
  bool get isMedium => maxWidth >= AppBreakpoints.compact && maxWidth < AppBreakpoints.expanded;
  bool get isExpanded => maxWidth >= AppBreakpoints.expanded;
}
