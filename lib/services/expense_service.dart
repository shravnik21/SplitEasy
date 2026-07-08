import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'supabase_client.dart';

class ExpenseService {
  SupabaseClient? get _client => getSupabaseClient();

  /// Adds an expense and its resolved per-participant splits in one call.
  Future<AppExpense> addExpense({
    required String groupId,
    required String description,
    required String category,
    required double amount,
    required String paidBy,
    required SplitType splitType,
    required List<ExpenseSplitInput> splits,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not initialized');
    }

    final uid = client.auth.currentUser!.id;

    final expenseRow = await client
        .from('expenses')
        .insert({
          'group_id': groupId,
          'description': description,
          'category': category,
          'amount': amount,
          'paid_by': paidBy,
          'split_type': splitType.dbValue,
          'created_by': uid,
        })
        .select()
        .single();

    final expenseId = expenseRow['id'] as String;

    await client
        .from('expense_splits')
        .insert(splits.map((s) => s.toInsertMap(expenseId)).toList());

    return AppExpense.fromMap(expenseRow);
  }

  /// Updates an existing expense and its associated splits.
  Future<AppExpense> updateExpense({
    required String expenseId,
    required String description,
    required String category,
    required double amount,
    required String paidBy,
    required SplitType splitType,
    required List<ExpenseSplitInput> splits,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not initialized');
    }

    // 1. Update the core expense details
    final expenseRow = await client
        .from('expenses')
        .update({
          'description': description,
          'category': category,
          'amount': amount,
          'paid_by': paidBy,
          'split_type': splitType.dbValue,
        })
        .eq('id', expenseId)
        .select()
        .single();

    // 2. Clear out the previous splits for this expense
    await client
        .from('expense_splits')
        .delete()
        .eq('expense_id', expenseId);

    // 3. Insert the fresh, newly calculated splits
    await client
        .from('expense_splits')
        .insert(splits.map((s) => s.toInsertMap(expenseId)).toList());

    return AppExpense.fromMap(expenseRow);
  }

  /// Lists expenses for a group, most recent first.
  Future<List<AppExpense>> getExpenses(String groupId, {String? category}) async {
    final client = _client;
    if (client == null) {
      return [];
    }

    var query = client.from('expenses').select().eq('group_id', groupId);

    if (category != null) {
      query = query.eq('category', category);
    }

    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((row) => AppExpense.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Gets the per-participant splits for a single expense.
  Future<List<ExpenseSplitInput>> getSplitsForExpense(String expenseId) async {
    final client = _client;
    if (client == null) {
      return [];
    }

    final rows = await client
        .from('expense_splits')
        .select()
        .eq('expense_id', expenseId);

    return (rows as List)
        .map((row) => ExpenseSplitInput(
              userId: row['user_id'] as String,
              amountOwed: (row['amount_owed'] as num).toDouble(),
            ))
        .toList();
  }

  /// Deletes an expense. RLS only allows the original creator to do this;
  /// `on delete cascade` on expense_splits removes its splits automatically.
  Future<void> deleteExpense(String expenseId) async {
    final client = _client;
    if (client == null) {
      return;
    }

    return client.from('expenses').delete().eq('id', expenseId);
  }
}