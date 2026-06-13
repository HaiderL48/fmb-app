/// Matches the `MenuFeedback` interface from mockData.ts
class MenuFeedbackModel {
  final String id;
  final String userId;
  final String menuId;
  final int rating; // 1–5
  final String comment;
  final DateTime date;

  const MenuFeedbackModel({
    required this.id,
    required this.userId,
    required this.menuId,
    required this.rating,
    required this.comment,
    required this.date,
  });

  factory MenuFeedbackModel.fromJson(Map<String, dynamic> json) {
    return MenuFeedbackModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      menuId: json['menuId'] as String,
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String? ?? '',
      date: DateTime.parse(
        json['date'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'menuId': menuId,
    'rating': rating,
    'comment': comment,
    'date': date.toIso8601String().split('T').first,
  };

  MenuFeedbackModel copyWith({
    String? id,
    String? userId,
    String? menuId,
    int? rating,
    String? comment,
    DateTime? date,
  }) {
    return MenuFeedbackModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      menuId: menuId ?? this.menuId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      date: date ?? this.date,
    );
  }
}
