import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'supabase_client.dart';

class GroupService {
  SupabaseClient? get _client => getSupabaseClient();

  /// Creates a group and adds the current user as its first member.
  Future<AppGroup> createGroup({
    required String name,
    required String currency,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not initialized');
    }

    final uid = client.auth.currentUser!.id;

    final groupRow = await client
        .from('groups')
        .insert({
          'name': name,
          'currency': currency,
          'created_by': uid,
        })
        .select()
        .single();

    await client.from('group_members').insert({
      'group_id': groupRow['id'],
      'user_id': uid,
    });

    return AppGroup.fromMap(groupRow);
  }

  /// Lists every group the current user belongs to.
  /// RLS ensures this only ever returns groups they're actually a member of.
  Future<List<AppGroup>> getMyGroups() async {
    final client = _client;
    if (client == null) {
      return [];
    }

    final uid = client.auth.currentUser!.id;

    final rows = await client
        .from('group_members')
        .select('groups(*)')
        .eq('user_id', uid);

    return (rows as List)
        .map((row) => AppGroup.fromMap(row['groups'] as Map<String, dynamic>))
        .toList();
  }

  /// Fetches a single group's details.
  Future<AppGroup> getGroup(String groupId) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not initialized');
    }

    final row =
        await client.from('groups').select().eq('id', groupId).single();
    return AppGroup.fromMap(row);
  }

  /// Lists members of a group along with their profile info (name/email).
  Future<List<GroupMemberInfo>> getGroupMembers(String groupId) async {
    final client = _client;
    if (client == null) {
      return [];
    }

    final rows = await client
        .from('group_members')
        .select('user_id, profiles(name, email)')
        .eq('group_id', groupId);

    return (rows as List)
        .map((row) => GroupMemberInfo.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Looks up a user by email so they can be invited to a group.
  /// Returns null if no profile matches (they need to register first).
  Future<Profile?> findUserByEmail(String email) async {
    final client = _client;
    if (client == null) {
      return null;
    }

    final row = await client
        .from('profiles')
        .select()
        .eq('email', email)
        .maybeSingle();

    if (row == null) return null;
    return Profile.fromMap(row);
  }

  /// Adds an existing user (by id) to a group.
  Future<void> addMember({required String groupId, required String userId}) async {
    final client = _client;
    if (client == null) {
      return;
    }

    return client.from('group_members').insert({
      'group_id': groupId,
      'user_id': userId,
    });
  }

  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    final client = _client;
    if (client == null) {
      return;
    }

    return client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  /// Deletes a group entirely from Supabase. 
/// Foreign key ON DELETE CASCADE will automatically wipe out related expenses/splits.
Future<void> deleteGroup(String groupId) async {
  final client = _client;
  if (client == null) {
    return;
  }

  await client.from('groups').delete().eq('id', groupId);
  }
}
