import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/balance_service.dart';
import '../services/group_service.dart';
import '../services/settlement_service.dart';
import '../services/supabase_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class BalancesScreen extends StatefulWidget {
  final AppGroup group;

  const BalancesScreen({super.key, required this.group});

  @override
  State<BalancesScreen> createState() => _BalancesScreenState();
}

class _BalancesScreenState extends State<BalancesScreen> {
  final _balanceService = BalanceService();
  final _settlementService = SettlementService();
  final _groupService = GroupService();

  late Future<_BalancesData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _dataFuture = _fetchData();
  }

  Future<_BalancesData> _fetchData() async {
    final results = await Future.wait([
      _balanceService.getBalances(widget.group.id),
      _groupService.getGroupMembers(widget.group.id),
    ]);
    return _BalancesData(
      transactions: results[0] as List<BalanceTransaction>,
      members: results[1] as List<GroupMemberInfo>,
    );
  }

  Future<void> _refresh() async {
    setState(_loadData);
    await _dataFuture;
  }

  GroupMemberInfo? _memberFor(List<GroupMemberInfo> members, String userId) {
    final match = members.where((m) => m.userId == userId);
    return match.isEmpty ? null : match.first;
  }

  String _nameFor(List<GroupMemberInfo> members, String userId) {
    final m = _memberFor(members, userId);
    if (m == null) return userId;
    return m.name.isEmpty ? m.email : m.name;
  }

  String _initialFor(List<GroupMemberInfo> members, String userId) {
    final name = _nameFor(members, userId);
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _money(double amount) =>
      '${widget.group.currency} ${amount.toStringAsFixed(2)}';

  Future<void> _settleUp(BalanceTransaction t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Record settlement?'),
        content: Text('Mark ${_money(t.amount)} as paid?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // settlements.paid_by is always the current signed-in user (RLS
      // enforces paid_by = auth.uid()), so this button only appears when
      // the current user is the one who owes in this transaction.
      await _settlementService.recordSettlement(
        groupId: widget.group.id,
        paidTo: t.to,
        amount: t.amount,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recorded -- ${_money(t.amount)} settled.')),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        final message = e.toString().contains('row-level security')
            ? "You don't have permission to record that settlement."
            : 'Could not record settlement. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  /// Net amount for the current user across all simplified transactions.
  /// Positive = you're owed money overall, negative = you owe overall.
  double _netForCurrentUser(List<BalanceTransaction> transactions) {
    final uid = getSupabaseClient()?.auth.currentUser?.id;
    if (uid == null) return 0;
    double net = 0;
    for (final t in transactions) {
      if (t.to == uid) net += t.amount;
      if (t.from == uid) net -= t.amount;
    }
    return net;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balances')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_BalancesData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ScrollableCenter(
                child: _ErrorState(message: '${snapshot.error}'),
              );
            }

            final data = snapshot.data!;
            final net = _netForCurrentUser(data.transactions);
            final isOwed = net >= 0;
            final heroColor = net == 0
                ? AppColors.textPrimary
                : (isOwed ? AppColors.accentGreen : AppColors.textPrimary);
            final heroLabel = net == 0
                ? "You're all settled up"
                : (isOwed ? "You're owed overall" : 'You owe overall');
            final sign = net == 0 ? '' : (isOwed ? '+' : '-');

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                HeroAmount(
                  label: heroLabel,
                  amountText: '$sign${_money(net.abs())}',
                  color: heroColor,
                ),
                const SizedBox(height: 24),
                if (data.transactions.isEmpty)
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.celebration_outlined,
                            size: 48, color: AppColors.accentGreen),
                        SizedBox(height: 16),
                        Text(
                          'All settled up!',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'No one owes anyone anything in this group.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Balances'),
                        const SizedBox(height: 12),
                        ...List.generate(data.transactions.length, (index) {
                          final t = data.transactions[index];
                          final isLast = index == data.transactions.length - 1;
                          final currentUid = getSupabaseClient()?.auth.currentUser?.id;
                          final isCurrentUserPayer = currentUid != null && t.from == currentUid;
                          final isCurrentUserPayee = currentUid != null && t.to == currentUid;

                          final String personName;
                          final String subtitle;
                          final Color amountColor;
                          final String amountText;
                          final String avatarInitial;

                          if (isCurrentUserPayer) {
                            personName = _nameFor(data.members, t.to);
                            subtitle = 'You owe';
                            amountColor = AppColors.textPrimary;
                            amountText = '-${_money(t.amount)}';
                            avatarInitial = _initialFor(data.members, t.to);
                          } else if (isCurrentUserPayee) {
                            personName = _nameFor(data.members, t.from);
                            subtitle = 'Owes you';
                            amountColor = AppColors.accentGreen;
                            amountText = '+${_money(t.amount)}';
                            avatarInitial = _initialFor(data.members, t.from);
                          } else {
                            personName =
                                '${_nameFor(data.members, t.from)} -> ${_nameFor(data.members, t.to)}';
                            subtitle = 'Between others';
                            amountColor = AppColors.textSecondary;
                            amountText = _money(t.amount);
                            avatarInitial = _initialFor(data.members, t.from);
                          }

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    InitialAvatar(initial: avatarInitial),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            personName,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            subtitle,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          amountText,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: amountColor,
                                          ),
                                        ),
                                        if (isCurrentUserPayer) ...[
                                          const SizedBox(height: 4),
                                          PillButton(
                                            label: 'Settle up',
                                            onTap: () => _settleUp(t),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (!isLast)
                                const Divider(height: 1, color: AppColors.divider),
                            ],
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.accentRed),
          const SizedBox(height: 16),
          const Text(
            "Couldn't load balances",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Centers its child vertically while still allowing pull-to-refresh,
/// by filling the available height inside a scrollable.
class _ScrollableCenter extends StatelessWidget {
  final Widget child;

  const _ScrollableCenter({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _BalancesData {
  final List<BalanceTransaction> transactions;
  final List<GroupMemberInfo> members;

  _BalancesData({required this.transactions, required this.members});
}
