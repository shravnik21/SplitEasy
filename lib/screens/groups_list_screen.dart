import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../services/supabase_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

class GroupsListScreen extends StatefulWidget {
  const GroupsListScreen({super.key});

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  final _groupService = GroupService();
  final _authService = AuthService();
  late Future<List<AppGroup>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  void _loadGroups() {
    _groupsFuture = _groupService.getMyGroups();
  }

  Future<void> _refresh() async {
    setState(_loadGroups);
    await _groupsFuture;
  }

  String get _displayName {
    final user = getSupabaseClient()?.auth.currentUser;
    final metaName = user?.userMetadata?['name'] as String?;
    if (metaName != null && metaName.isNotEmpty) return metaName;
    return user?.email?.split('@').first ?? 'there';
  }

  Future<void> _createGroup() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );
    if (created == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      UserAvatar(initial: _displayName[0].toUpperCase()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome back',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              _displayName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: AppColors.textSecondary),
                        tooltip: 'Sign out',
                        onPressed: () => _authService.signOut(),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Your groups',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                      ),
                      HeaderPillButton(
                        label: 'New',
                        icon: Icons.add,
                        onTap: _createGroup,
                      ),
                    ],
                  ),
                ),
              ),
              FutureBuilder<List<AppGroup>>(
                future: _groupsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: Center(child: Text('Error: ${snapshot.error}')),
                    );
                  }

                  final groups = snapshot.data ?? [];
                  if (groups.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.group_outlined, size: 44, color: AppColors.textMuted),
                              SizedBox(height: 16),
                              Text(
                                'No groups yet',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Tap New to create your first group.',
                                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList.separated(
                      itemCount: groups.length,
                      separatorBuilder: (context, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return AppCard(
                          padding: const EdgeInsets.all(16),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GroupDetailScreen(group: group),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              InitialAvatar(
                                initial:
                                    group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                                radius: 24,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      group.currency,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.textMuted),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
