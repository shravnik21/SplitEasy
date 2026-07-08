/// A user's profile row (mirrors public.profiles).
class Profile {
  final String id;
  final String name;
  final String email;

  Profile({required this.id, required this.name, required this.email});

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
    );
  }
}

/// A group (mirrors public.groups).
class AppGroup {
  final String id;
  final String name;
  final String currency;
  final String createdBy;
  final DateTime createdAt;

  AppGroup({
    required this.id,
    required this.name,
    required this.currency,
    required this.createdBy,
    required this.createdAt,
  });

  factory AppGroup.fromMap(Map<String, dynamic> map) {
    return AppGroup(
      id: map['id'] as String,
      name: map['name'] as String,
      currency: map['currency'] as String? ?? 'USD',
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// A member of a group, joined with their profile info.
class GroupMemberInfo {
  final String userId;
  final String name;
  final String email;

  GroupMemberInfo({required this.userId, required this.name, required this.email});

  factory GroupMemberInfo.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return GroupMemberInfo(
      userId: map['user_id'] as String,
      name: profile?['name'] as String? ?? 'Unknown',
      email: profile?['email'] as String? ?? '',
    );
  }
}

enum SplitType { equal, exact, percentage, shares }

extension SplitTypeX on SplitType {
  String get dbValue {
    switch (this) {
      case SplitType.equal:
        return 'EQUAL';
      case SplitType.exact:
        return 'EXACT';
      case SplitType.percentage:
        return 'PERCENTAGE';
      case SplitType.shares:
        return 'SHARES';
    }
  }

  static SplitType fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'EXACT':
        return SplitType.exact;
      case 'PERCENTAGE':
        return SplitType.percentage;
      case 'SHARES':
        return SplitType.shares;
      case 'EQUAL':
      default:
        return SplitType.equal;
    }
  }

  String get label {
    switch (this) {
      case SplitType.equal:
        return 'Equal';
      case SplitType.exact:
        return 'Exact amounts';
      case SplitType.percentage:
        return 'Percentage';
      case SplitType.shares:
        return 'Shares';
    }
  }
}

/// An expense (mirrors public.expenses).
class AppExpense {
  final String id;
  final String groupId;
  final String description;
  final String category;
  final double amount;
  final String paidBy;
  final String splitType;
  final String createdBy;
  final DateTime createdAt;

  AppExpense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.category,
    required this.amount,
    required this.paidBy,
    required this.splitType,
    required this.createdBy,
    required this.createdAt,
  });

  factory AppExpense.fromMap(Map<String, dynamic> map) {
    return AppExpense(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      description: map['description'] as String,
      category: map['category'] as String? ?? 'Other',
      amount: (map['amount'] as num).toDouble(),
      paidBy: map['paid_by'] as String,
      splitType: map['split_type'] as String,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// One participant's resolved share of an expense (mirrors expense_splits row,
/// pre-insert).
class ExpenseSplitInput {
  final String userId;
  final double amountOwed;

  ExpenseSplitInput({required this.userId, required this.amountOwed});

  Map<String, dynamic> toInsertMap(String expenseId) => {
        'expense_id': expenseId,
        'user_id': userId,
        'amount_owed': amountOwed,
      };
}

/// One simplified "who owes whom" transaction returned by the
/// get-balances Edge Function.
class BalanceTransaction {
  final String from;
  final String to;
  final double amount;

  BalanceTransaction({required this.from, required this.to, required this.amount});

  factory BalanceTransaction.fromMap(Map<String, dynamic> map) {
    return BalanceTransaction(
      from: map['from'] as String,
      to: map['to'] as String,
      amount: (map['amount'] as num).toDouble(),
    );
  }
}

/// A settlement record (mirrors public.settlements).
class Settlement {
  final String id;
  final String groupId;
  final String paidBy;
  final String paidTo;
  final double amount;
  final DateTime createdAt;

  Settlement({
    required this.id,
    required this.groupId,
    required this.paidBy,
    required this.paidTo,
    required this.amount,
    required this.createdAt,
  });

  factory Settlement.fromMap(Map<String, dynamic> map) {
    return Settlement(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      paidBy: map['paid_by'] as String,
      paidTo: map['paid_to'] as String,
      amount: (map['amount'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
