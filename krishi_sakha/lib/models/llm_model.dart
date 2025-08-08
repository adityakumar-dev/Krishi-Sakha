import 'package:hive/hive.dart';

part 'llm_model.g.dart';

@HiveType(typeId: 0)
class LlmModel extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String copiedPath;

  @HiveField(2)
  String lastUsed;

  @HiveField(3)
  bool isActive;

  @HiveField(4)
  DateTime createdAt;

  LlmModel({
    required this.name,
    required this.copiedPath,
    required this.lastUsed,
    this.isActive = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Mark this model as the active one
  void setActive(bool active) {
    isActive = active;
    if (active) {
      lastUsed = DateTime.now().toIso8601String();
    }
    save(); 
  }

  /// Update last used timestamp
  void updateLastUsed() {
    lastUsed = DateTime.now().toIso8601String();
    save(); // Save to Hive
  }

  /// Get formatted last used time
  String get formattedLastUsed {
    try {
      final date = DateTime.parse(lastUsed);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  String toString() {
    return 'LlmModel(name: $name, isActive: $isActive)';
  }
}