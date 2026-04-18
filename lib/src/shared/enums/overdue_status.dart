import 'package:flutter/material.dart';

/// Tracks where a milestone sits in the overdue warning pipeline.
///
/// Transitions (driven by [OverdueService.computeWarningStatus]):
/// ```
/// onTrack → warning3Days → warning1Day → finalWarning → triggered
///                                                            ↓
///                                                  auto-cancel + restrict
/// ```
/// The transition to [triggered] fires after the effective deadline has
/// passed AND the [OverdueService._gracePeriodHours] grace window expires
/// with no submission from the freelancer.
enum OverdueStatus {
  onTrack,
  warning3Days,
  warning1Day,
  finalWarning,
  triggered; // auto-enforcement has been applied

  static OverdueStatus fromString(String v) => OverdueStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => OverdueStatus.onTrack,
      );

  String get displayName => switch (this) {
        OverdueStatus.onTrack      => 'On Track',
        OverdueStatus.warning3Days => '3-Day Warning',
        OverdueStatus.warning1Day  => '1-Day Warning',
        OverdueStatus.finalWarning => 'Final Warning',
        OverdueStatus.triggered    => 'Enforcement Triggered',
      };

  Color get color => switch (this) {
        OverdueStatus.onTrack      => Colors.green,
        OverdueStatus.warning3Days => Colors.orange,
        OverdueStatus.warning1Day  => Colors.deepOrange,
        OverdueStatus.finalWarning => Colors.red,
        OverdueStatus.triggered    => const Color(0xFF8B0000), // dark red
      };

  IconData get icon => switch (this) {
        OverdueStatus.onTrack      => Icons.check_circle_outline,
        OverdueStatus.warning3Days => Icons.warning_amber_outlined,
        OverdueStatus.warning1Day  => Icons.warning_amber,
        OverdueStatus.finalWarning => Icons.error_outline,
        OverdueStatus.triggered    => Icons.cancel,
      };

  bool get isWarning =>
      this == warning3Days || this == warning1Day || this == finalWarning;
}
