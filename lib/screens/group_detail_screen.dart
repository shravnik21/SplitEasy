import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/expense_service.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'add_expense_screen.dart';
import 'balances_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final AppGroup group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _expenseService = ExpenseService();
  final _groupService = GroupService();

  late Future<List<AppExpense>> _expensesFuture;
  late Future<List<GroupMemberInfo>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    _expensesFuture = _expenseService.getExpenses(widget.group.id);
    _membersFuture = _groupService.getGroupMembers(widget.group.id);
  }

  Future<void> _refresh() async {
    setState(_loadAll);
    await Future.wait([_expensesFuture, _membersFuture]);
  }

  Future<void> _addExpense() async {
    final members = await _membersFuture;
    if (!mounted) return;
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(group: widget.group, members: members),
      ),
    );
    if (added == true) _refresh();
  }

  void _openBalances() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BalancesScreen(group: widget.group)),
    );
  }

  // Deletes an entire group from Supabase
  Future<void> _confirmDeleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Group?'),
        content: const Text(
          'Are you absolutely sure? This will permanently delete this group, all expenses, and all balances from Supabase. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _groupService.deleteGroup(widget.group.id);
        if (mounted) {
          Navigator.of(context).pop(true); // Return back to list screen & trigger reload
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete group: $e')),
          );
        }
      }
    }
  }

  // View, Edit, and Delete bottom sheet view
  void _showExpenseOptions(AppExpense expense) async {
    final members = await _membersFuture;
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  expense.description,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Category: ${expense.category}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                Text(
                  '${widget.group.currency} ${expense.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
                  title: const Text('Edit Expense', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.of(context).pop(); // Close bottom sheet
                    final updated = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => AddExpenseScreen(
                          group: widget.group,
                          members: members,
                          expense: expense, 
                        ),
                      ),
                    );
                    if (updated == true) _refresh();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Delete Expense', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.of(context).pop(); // Close bottom sheet
                    _confirmDeleteExpense(expense);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteExpense(AppExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete expense?'),
        content: Text('Are you sure you want to remove "${expense.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _expenseService.deleteExpense(expense.id);
      _refresh();
    }
  }

  Future<void> _inviteMember() async {
    final emailController = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Invite by email'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(emailController.text.trim()),
            child: const Text('Invite'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty || !mounted) return;

    try {
      final profile = await _groupService.findUserByEmail(email);
      if (profile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No account with that email yet -- they need to register first.'),
            ),
          );
        }
        return;
      }
      await _groupService.addMember(groupId: widget.group.id, userId: profile.id);
      _refresh();
    } catch (e) {
      if (mounted) {
        final message = e.toString().contains('row-level security')
            ? 'Only the group creator can add members.'
            : 'Could not add member. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDeleteGroup();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text('Delete Group', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            FutureBuilder<List<AppExpense>>(
              future: _expensesFuture,
              builder: (context, snapshot) {
                final total = (snapshot.data ?? [])
                    .fold<double>(0, (sum, e) => sum + e.amount);
                return HeroAmount(
                  label: 'Group total spent',
                  amountText: '${widget.group.currency} ${total.toStringAsFixed(2)}',
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconActionButton(
                  icon: Icons.add,
                  label: 'Add expense',
                  onTap: _addExpense,
                ),
                IconActionButton(
                  icon: Icons.pie_chart_outline,
                  label: 'Balances',
                  onTap: _openBalances,
                ),
                IconActionButton(
                  icon: Icons.person_add_alt,
                  label: 'Invite',
                  onTap: _inviteMember,
                  background: AppColors.avatarBackground,
                  foreground: AppColors.textPrimary,
                ),
              ],
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<GroupMemberInfo>>(
              future: _membersFuture,
              builder: (context, snapshot) {
                final members = snapshot.data ?? [];
                if (members.isEmpty) return const SizedBox.shrink();
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: members
                      .map((m) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              m.name.isEmpty ? m.email : m.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Expenses'),
            const SizedBox(height: 12),
            FutureBuilder<List<AppExpense>>(
              future: _expensesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final expenses = snapshot.data ?? [];
                if (expenses.isEmpty) {
                  return AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 40, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text(
                          'No expenses yet',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add one with the button above.',
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  );
                }

                return AppCard(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Column(
                    children: List.generate(expenses.length, (index) {
                      final e = expenses[index];
                      final isLast = index == expenses.length - 1;
                      return Column(
                        children: [
                          InkWell(
                            onTap: () => _showExpenseOptions(e),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  InitialAvatar(
                                    initial:
                                        e.category.isNotEmpty ? e.category[0] : '?',
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e.description,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          e.category,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${widget.group.currency} ${e.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!isLast)
                            const Divider(height: 1, color: AppColors.divider),
                        ],
                      );
                    }),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}