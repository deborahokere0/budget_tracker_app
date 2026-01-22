import '../models/rule_model.dart';
import '../models/conflict_model.dart';

/// Service for detecting and resolving conflicts between user-defined budgeting rules.
///
/// Implements the Conflict Resolution Protocol as specified in the system documentation:
/// - Detects duplicate category allocations
/// - Detects priority conflicts
/// - Generates automated suggestions for resolution
/// - Provides actionable notifications for unresolved conflicts
class ConflictResolutionService {
  /// Detect all conflicts in a list of rules
  ///
  /// Returns a list of [RuleConflict] objects describing any detected conflicts.
  List<RuleConflict> detectAllConflicts(List<RuleModel> rules) {
    final conflicts = <RuleConflict>[];

    // Only check active rules
    final activeRules = rules.where((r) => r.isActive).toList();

    // Check for duplicate category conflicts
    conflicts.addAll(_detectDuplicateCategoryConflicts(activeRules));

    // Check for priority conflicts
    conflicts.addAll(_detectPriorityConflicts(activeRules));

    // Check for over-allocation
    final overAllocation = _detectOverAllocation(activeRules);
    if (overAllocation != null) {
      conflicts.add(overAllocation);
    }

    return conflicts;
  }

  /// Check if adding/updating a rule would create conflicts
  ///
  /// Returns list of conflicts that would be created if the rule is saved.
  /// Used to block conflicting rule creation.
  List<RuleConflict> checkRuleForConflicts(
    RuleModel newRule,
    List<RuleModel> existingRules,
  ) {
    final conflicts = <RuleConflict>[];

    // Get active existing rules (exclude the rule being edited)
    final otherRules = existingRules
        .where((r) => r.isActive && r.id != newRule.id)
        .toList();

    // Check for duplicate category conflict
    final duplicateConflict = _checkDuplicateCategoryForRule(
      newRule,
      otherRules,
    );
    if (duplicateConflict != null) {
      conflicts.add(duplicateConflict);
    }

    // Check for priority conflict
    final priorityConflict = _checkPriorityConflictForRule(newRule, otherRules);
    if (priorityConflict != null) {
      conflicts.add(priorityConflict);
    }

    // Check if this would cause over-allocation
    final allRulesWithNew = [...otherRules, newRule];
    final overAllocation = _detectOverAllocation(allRulesWithNew);
    if (overAllocation != null) {
      conflicts.add(overAllocation);
    }

    return conflicts;
  }

  /// Detect duplicate category allocation conflicts
  List<RuleConflict> _detectDuplicateCategoryConflicts(List<RuleModel> rules) {
    final conflicts = <RuleConflict>[];

    // Filter to allocation-type rules
    final allocationRules = rules
        .where((r) => r.type == 'allocation' || r.type == 'income_allocation')
        .toList();

    // Group by target category
    final categoryGroups = <String, List<RuleModel>>{};
    for (final rule in allocationRules) {
      final category =
          rule.targetCategory ?? rule.actions['category'] as String?;
      if (category != null && category.isNotEmpty) {
        categoryGroups.putIfAbsent(category, () => []);
        categoryGroups[category]!.add(rule);
      }
    }

    // Find categories with multiple rules
    for (final entry in categoryGroups.entries) {
      if (entry.value.length > 1) {
        conflicts.add(
          RuleConflict(
            id: 'dup_cat_${entry.key}',
            type: ConflictType.duplicateCategory,
            severity: ConflictSeverity.high,
            conflictingRuleIds: entry.value.map((r) => r.id).toList(),
            conflictingRuleNames: entry.value.map((r) => r.name).toList(),
            description:
                'Multiple rules are allocating to "${entry.key}" category. '
                'This may cause unexpected budget behavior.',
            suggestion: _generateDuplicateCategorySuggestion(entry.value),
          ),
        );
      }
    }

    return conflicts;
  }

  /// Check if a specific rule would create a duplicate category conflict
  RuleConflict? _checkDuplicateCategoryForRule(
    RuleModel newRule,
    List<RuleModel> existingRules,
  ) {
    if (newRule.type != 'allocation' && newRule.type != 'income_allocation') {
      return null;
    }

    final newCategory =
        newRule.targetCategory ?? newRule.actions['category'] as String?;
    if (newCategory == null || newCategory.isEmpty) return null;

    // Find existing rules with same category
    final conflictingRules = existingRules.where((r) {
      if (r.type != 'allocation' && r.type != 'income_allocation') return false;
      final category = r.targetCategory ?? r.actions['category'] as String?;
      return category == newCategory;
    }).toList();

    if (conflictingRules.isNotEmpty) {
      return RuleConflict(
        id: 'dup_cat_check_$newCategory',
        type: ConflictType.duplicateCategory,
        severity: ConflictSeverity.high,
        conflictingRuleIds: [newRule.id, ...conflictingRules.map((r) => r.id)],
        conflictingRuleNames: [
          newRule.name,
          ...conflictingRules.map((r) => r.name),
        ],
        description:
            'An allocation rule for "$newCategory" already exists: '
            '"${conflictingRules.first.name}". '
            'Creating another rule for the same category may cause conflicts.',
        suggestion:
            'Consider editing the existing "${conflictingRules.first.name}" '
            'rule instead, or choose a different category for this allocation.',
      );
    }

    return null;
  }

  /// Detect priority conflicts (same priority, overlapping conditions)
  List<RuleConflict> _detectPriorityConflicts(List<RuleModel> rules) {
    final conflicts = <RuleConflict>[];

    // Group rules by priority
    final priorityGroups = <int, List<RuleModel>>{};
    for (final rule in rules) {
      priorityGroups.putIfAbsent(rule.priority, () => []);
      priorityGroups[rule.priority]!.add(rule);
    }

    // Check each priority group for overlapping rules of same type
    for (final entry in priorityGroups.entries) {
      if (entry.value.length > 1) {
        // Group by type within same priority
        final typeGroups = <String, List<RuleModel>>{};
        for (final rule in entry.value) {
          typeGroups.putIfAbsent(rule.type, () => []);
          typeGroups[rule.type]!.add(rule);
        }

        // Flag if same type has multiple rules at same priority
        for (final typeEntry in typeGroups.entries) {
          if (typeEntry.value.length > 1) {
            conflicts.add(
              RuleConflict(
                id: 'priority_${entry.key}_${typeEntry.key}',
                type: ConflictType.priorityConflict,
                severity: ConflictSeverity.medium,
                conflictingRuleIds: typeEntry.value.map((r) => r.id).toList(),
                conflictingRuleNames: typeEntry.value
                    .map((r) => r.name)
                    .toList(),
                description:
                    '${typeEntry.value.length} ${typeEntry.key} rules have '
                    'the same priority (${entry.key}). The execution order may be unpredictable.',
                suggestion: _generatePrioritySuggestion(
                  typeEntry.value,
                  entry.key,
                ),
              ),
            );
          }
        }
      }
    }

    return conflicts;
  }

  /// Check if a specific rule would create a priority conflict
  RuleConflict? _checkPriorityConflictForRule(
    RuleModel newRule,
    List<RuleModel> existingRules,
  ) {
    // Find existing rules with same priority and type
    final conflictingRules = existingRules
        .where((r) => r.priority == newRule.priority && r.type == newRule.type)
        .toList();

    if (conflictingRules.isNotEmpty) {
      return RuleConflict(
        id: 'priority_check_${newRule.priority}_${newRule.type}',
        type: ConflictType.priorityConflict,
        severity: ConflictSeverity.medium,
        conflictingRuleIds: [newRule.id, ...conflictingRules.map((r) => r.id)],
        conflictingRuleNames: [
          newRule.name,
          ...conflictingRules.map((r) => r.name),
        ],
        description:
            'This rule has the same priority (${newRule.priority}) as '
            '"${conflictingRules.first.name}". Both are ${newRule.type} rules, '
            'which may cause unpredictable execution order.',
        suggestion:
            'Consider changing the priority to ${_suggestNewPriority(newRule.priority, existingRules)} '
            'to ensure consistent rule execution order.',
      );
    }

    return null;
  }

  /// Detect over-allocation (percentage allocations exceeding 100%)
  RuleConflict? _detectOverAllocation(List<RuleModel> rules) {
    double totalPercentage = 0;
    final percentageRules = <RuleModel>[];

    for (final rule in rules) {
      if (rule.type == 'allocation' || rule.type == 'income_allocation') {
        if (rule.allocationType == 'percentage' &&
            rule.allocationValue != null) {
          totalPercentage += rule.allocationValue!;
          percentageRules.add(rule);
        }
      }
    }

    if (totalPercentage > 100 && percentageRules.isNotEmpty) {
      return RuleConflict(
        id: 'over_allocation',
        type: ConflictType.overAllocation,
        severity: ConflictSeverity.high,
        conflictingRuleIds: percentageRules.map((r) => r.id).toList(),
        conflictingRuleNames: percentageRules.map((r) => r.name).toList(),
        description:
            'Total percentage allocation is ${totalPercentage.toStringAsFixed(1)}%, '
            'which exceeds 100% of your income.',
        suggestion:
            'Reduce allocations by ${(totalPercentage - 100).toStringAsFixed(1)}% '
            'or convert some rules to fixed amounts instead of percentages.',
      );
    }

    return null;
  }

  /// Generate suggestion for duplicate category conflicts
  String _generateDuplicateCategorySuggestion(List<RuleModel> rules) {
    if (rules.length == 2) {
      return 'Merge "${rules[0].name}" and "${rules[1].name}" into a single rule, '
          'or modify one to target a different category.';
    }
    return 'Consider consolidating these ${rules.length} rules into fewer rules, '
        'or ensure each targets a unique category.';
  }

  /// Generate suggestion for priority conflicts
  String _generatePrioritySuggestion(
    List<RuleModel> rules,
    int currentPriority,
  ) {
    final suggestions = <String>[];
    for (int i = 0; i < rules.length; i++) {
      final newPriority = (currentPriority + i).clamp(1, 5);
      if (newPriority != currentPriority) {
        suggestions.add('Set "${rules[i].name}" to priority $newPriority');
      }
    }

    if (suggestions.isEmpty) {
      return 'Consider adjusting priorities to ensure predictable rule execution.';
    }
    return suggestions.join(', or ') + '.';
  }

  /// Suggest a new priority that doesn't conflict
  int _suggestNewPriority(int currentPriority, List<RuleModel> existingRules) {
    final usedPriorities = existingRules.map((r) => r.priority).toSet();

    // Try higher priority first
    for (int p = currentPriority + 1; p <= 5; p++) {
      if (!usedPriorities.contains(p)) return p;
    }

    // Then try lower
    for (int p = currentPriority - 1; p >= 1; p--) {
      if (!usedPriorities.contains(p)) return p;
    }

    // Return adjacent priority if all used
    return currentPriority < 5 ? currentPriority + 1 : currentPriority - 1;
  }

  /// Get conflict severity label
  static String getSeverityLabel(ConflictSeverity severity) {
    switch (severity) {
      case ConflictSeverity.high:
        return 'Blocking';
      case ConflictSeverity.medium:
        return 'Warning';
      case ConflictSeverity.low:
        return 'Info';
    }
  }

  /// Check if any conflicts would block rule creation
  bool hasBlockingConflicts(List<RuleConflict> conflicts) {
    return conflicts.any((c) => c.severity == ConflictSeverity.high);
  }
}
