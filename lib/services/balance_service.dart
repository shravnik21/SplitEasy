import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'supabase_client.dart';

class BalanceService {
  SupabaseClient? get _client => getSupabaseClient();

  /// Calls the get-balances Edge Function, which computes net balances via
  /// the get_net_balances RPC and reduces them to the minimum number of
  /// settling transactions server-side.
  Future<List<BalanceTransaction>> getBalances(String groupId) async {
    final client = _client;
    if (client == null) {
      return [];
    }

    final res = await client.functions.invoke(
      'get-balances',
      body: {'groupId': groupId},
    );

    final data = res.data as Map<String, dynamic>;

    if (data['error'] != null) {
      throw Exception(data['error']);
    }

    final transactions = data['transactions'] as List;
    return transactions
        .map((t) => BalanceTransaction.fromMap(t as Map<String, dynamic>))
        .toList();
  }
}
