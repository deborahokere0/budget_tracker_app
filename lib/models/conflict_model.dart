/// Model representing a conflict between budgeting rules.
///
/// Used by the ConflictResolutionService to detect and report
/// overlapping or contradictory user-defined rules.
class RuleConflict {
  final String id;
  final ConflictType type;
  final ConflictSeverity severity;
  final List<String> conflictingRuleIds;
  final List<String> conflictingRuleNames;
  final String description;
  final String suggestion;
  final bool requiresUserAction;

  RuleConflict({
    required this.id,
    required this.type,
    required this.severity,
    required this.conflictingRuleIds,
    required this.conflictingRuleNames,
    required this.description,
    required this.suggestion,
    this.requiresUserAction = true,
  });

  /// Get display title based on conflict type
  String get title {
    switch (type) {
      case ConflictType.duplicateCategory:
        return 'Duplicate Category Allocation';
      case ConflictType.priorityConflict:
        return 'Priority Conflict';
      case ConflictType.overAllocation:
        return 'Over-Allocation Warning';
      case ConflictType.contradictoryActions:
        return 'Contradictory Rules';
    }
  }

  /// Get icon for conflict type
  String get iconName {
    switch (severity) {
      case ConflictSeverity.high:
        return 'error';
      case ConflictSeverity.medium:
        return 'warning';
      case ConflictSeverity.low:
        return 'info';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'severity': severity.name,
      'conflictingRuleIds': conflictingRuleIds,
      'conflictingRuleNames': conflictingRuleNames,
      'description': description,
      'suggestion': suggestion,
      'requiresUserAction': requiresUserAction,
    };
  }

  factory RuleConflict.fromMap(Map<String, dynamic> map) {
    return RuleConflict(
      id: map['id'] ?? '',
      type: ConflictType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ConflictType.duplicateCategory,
      ),
      severity: ConflictSeverity.values.firstWhere(
        (e) => e.name == map['severity'],
        orElse: () => ConflictSeverity.medium,
      ),
      conflictingRuleIds: List<String>.from(map['conflictingRuleIds'] ?? []),
      conflictingRuleNames: List<String>.from(
        map['conflictingRuleNames'] ?? [],
      ),
      description: map['description'] ?? '',
      suggestion: map['suggestion'] ?? '',
      requiresUserAction: map['requiresUserAction'] ?? true,
    );
  }
}

/// Types of conflicts that can occur between rules
enum ConflictType {
  /// Multiple rules allocating to the same category
  duplicateCategory,

  /// Rules with same priority and overlapping conditions
  priorityConflict,

  /// Total allocation exceeds 100%
  overAllocation,

  /// Rules with opposing/contradictory actions
  contradictoryActions,
}

/// Severity levels for conflicts
enum ConflictSeverity {
  /// Blocks rule creation - must be resolved
  high,

  /// Warning - user should review
  medium,

  /// Informational - may cause unexpected behavior
  low,
}
