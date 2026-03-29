enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeExt on MealType {
  String get label {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snack:
        return 'Snack';
    }
  }

  static MealType fromString(String s) => MealType.values
      .firstWhere((e) => e.name == s, orElse: () => MealType.breakfast);
}

class MealItem {
  String id;
  String dateKey;
  MealType mealType;
  String name;
  String note;

  MealItem({
    required this.id,
    required this.dateKey,
    required this.mealType,
    required this.name,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateKey': dateKey,
        'mealType': mealType.name,
        'name': name,
        'note': note,
      };

  factory MealItem.fromJson(Map<String, dynamic> j) => MealItem(
        id: j['id'] ?? '',
        dateKey: j['dateKey'] ?? '',
        mealType: MealTypeExt.fromString(j['mealType'] ?? 'breakfast'),
        name: j['name'] ?? '',
        note: j['note'] ?? '',
      );
}

// ── Budget ────────────────────────────────────────────────────────────────

enum BudgetCategory {
  campsite,
  lodging,
  food,
  gear,
  fuel,
  permits,
  activities,
  other
}

extension BudgetCategoryExt on BudgetCategory {
  String get label {
    switch (this) {
      case BudgetCategory.campsite:
        return 'Campsite';
      case BudgetCategory.lodging:
        return 'Lodging';
      case BudgetCategory.food:
        return 'Food';
      case BudgetCategory.gear:
        return 'Gear';
      case BudgetCategory.fuel:
        return 'Fuel';
      case BudgetCategory.permits:
        return 'Permits';
      case BudgetCategory.activities:
        return 'Activities';
      case BudgetCategory.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case BudgetCategory.campsite:
        return '🏕';
      case BudgetCategory.lodging:
        return '🏨';
      case BudgetCategory.food:
        return '🍔';
      case BudgetCategory.gear:
        return '🎒';
      case BudgetCategory.fuel:
        return '⛽';
      case BudgetCategory.permits:
        return '📜';
      case BudgetCategory.activities:
        return '🚣';
      case BudgetCategory.other:
        return '💳';
    }
  }

  static BudgetCategory fromString(String s) => BudgetCategory.values
      .firstWhere((e) => e.name == s, orElse: () => BudgetCategory.other);
}

class BudgetItem {
  String id;
  String description;
  double amount;
  BudgetCategory category;
  String date;

  BudgetItem({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    this.date = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'amount': amount,
        'category': category.name,
        'date': date,
      };

  factory BudgetItem.fromJson(Map<String, dynamic> j) => BudgetItem(
        id: j['id'] ?? '',
        description: j['description'] ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        category: BudgetCategoryExt.fromString(j['category'] ?? 'other'),
        date: j['date'] ?? '',
      );
}

// ── Emergency Contact ─────────────────────────────────────────────────────

class EmergencyContact {
  String id;
  String name;
  String phone;
  String relation;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.relation = '',
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'phone': phone, 'relation': relation};

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        relation: j['relation'] ?? '',
      );
}
