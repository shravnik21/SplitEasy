import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'supabase_client.dart';

class SettlementService {
  SupabaseClient? get _client => getSupabaseClient();

  /// Records a settlement — e.g. "I paid Alex $20" — which updates net
  /// balances without being treated as an expense.
  Future<Settlement> recordSettlement({
    required String groupId,
    required String paidTo,
    required double amount,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not initialized');
    }

    final uid = client.auth.currentUser!.id;

    final row = await client
        .from('settlements')
        .insert({
          'group_id': groupId,
          'paid_by': uid,
          'paid_to': paidTo,
          'amount': amount,
        })
        .select()
        .single();

    return Settlement.fromMap(row);
  }

  Future<List<Settlement>> getSettlements(String groupId) async {
    final client = _client;
    if (client == null) {
      return [];
    }

    final rows = await client
        .from('settlements')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => Settlement.fromMap(row as Map<String, dynamic>))
        .toList();
  }
}
