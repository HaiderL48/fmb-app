/// Matches the `daily_menus` table and the `MenuItem` interface from mockData.ts
class MenuModel {
  final String id;
  final DateTime menuDate;
  final String dayLabel;
  final String? title;
  final List<String> items;
  final String? notes;
  final bool isPublished;

  const MenuModel({
    required this.id,
    required this.menuDate,
    required this.dayLabel,
    this.title,
    required this.items,
    this.notes,
    this.isPublished = true,
  });

  factory MenuModel.fromJson(Map<String, dynamic> json) {
    final dateStr =
        json['menuDate'] as String? ??
        json['date'] as String? ??
        DateTime.now().toIso8601String();
    final date = DateTime.parse(dateStr);

    return MenuModel(
      id: json['id'] as String,
      menuDate: date,
      dayLabel: json['dayLabel'] as String? ?? json['day'] as String? ?? '',
      title: json['title'] as String?,
      items: List<String>.from(json['items'] as List? ?? []),
      notes: json['notes'] as String?,
      isPublished: json['isPublished'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'menuDate': menuDate.toIso8601String().split('T').first,
    'dayLabel': dayLabel,
    'title': title,
    'items': items,
    'notes': notes,
    'isPublished': isPublished,
  };

  MenuModel copyWith({
    String? id,
    DateTime? menuDate,
    String? dayLabel,
    String? title,
    List<String>? items,
    String? notes,
    bool? isPublished,
  }) {
    return MenuModel(
      id: id ?? this.id,
      menuDate: menuDate ?? this.menuDate,
      dayLabel: dayLabel ?? this.dayLabel,
      title: title ?? this.title,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      isPublished: isPublished ?? this.isPublished,
    );
  }
}
