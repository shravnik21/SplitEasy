import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/expense_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class AddExpenseScreen extends StatefulWidget {
  final AppGroup group;
  final List<GroupMemberInfo> members;
  final AppExpense? expense; // Added to support editing mode

  const AddExpenseScreen({
    super.key, 
    required this.group, 
    required this.members,
    this.expense,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _expenseService = ExpenseService();

  static const _categories = ['Food', 'Rent', 'Travel', 'Utilities', 'Other'];
  String _category = 'Food';
  String? _paidBy;
  SplitType _splitType = SplitType.equal;

  // Per-member state.
  final Map<String, bool> _selected = {};
  final Map<String, TextEditingController> _exactControllers = {};
  final Map<String, TextEditingController> _percentControllers = {};
  final Map<String, TextEditingController> _sharesControllers = {};

  bool _loading = false;
  String? _error;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();

    // 1. Initialize standard structures for all members safely first
    for (final m in widget.members) {
      _selected[m.userId] = false;
      _exactControllers[m.userId] = TextEditingController();
      _percentControllers[m.userId] = TextEditingController();
      _sharesControllers[m.userId] = TextEditingController(text: '1');
    }

    if (_isEditing) {
      _loadEditingExpense();
    } else {
      // Default fallback values for "Add" mode
      _paidBy = widget.members.isNotEmpty ? widget.members.first.userId : null;
      for (final m in widget.members) {
        _selected[m.userId] = true;
      }
    }
  }

  Future<void> _loadEditingExpense() async {
    final exp = widget.expense!;
    _descriptionController.text = exp.description;
    _amountController.text = exp.amount.toString();
    _category = _categories.contains(exp.category) ? exp.category : 'Other';
    _paidBy = exp.paidBy;
    _splitType = SplitTypeX.fromDbValue(exp.splitType);

    final splits = await _expenseService.getSplitsForExpense(exp.id);
    if (!mounted) return;

    setState(() {
      for (final split in splits) {
        _selected[split.userId] = true;

        switch (_splitType) {
          case SplitType.exact:
            _exactControllers[split.userId]!.text = split.amountOwed.toStringAsFixed(2);
            break;
          case SplitType.percentage:
            if (exp.amount > 0) {
              final pct = (split.amountOwed / exp.amount) * 100;
              _percentControllers[split.userId]!.text = pct.toStringAsFixed(1);
            }
            break;
          case SplitType.shares:
            _sharesControllers[split.userId]!.text = '1';
            break;
          case SplitType.equal:
            break;
        }
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    for (final c in _exactControllers.values) {
      c.dispose();
    }
    for (final c in _percentControllers.values) {
      c.dispose();
    }
    for (final c in _sharesControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<GroupMemberInfo> get _participants =>
      widget.members.where((m) => _selected[m.userId] == true).toList();

  List<ExpenseSplitInput> _resolveSplits(double totalAmount) {
    final participants = _participants;
    if (participants.isEmpty) {
      throw 'Select at least one participant.';
    }

    switch (_splitType) {
      case SplitType.equal:
        final share = totalAmount / participants.length;
        return participants
            .map((m) => ExpenseSplitInput(
                userId: m.userId, amountOwed: double.parse(share.toStringAsFixed(2))))
            .toList();

      case SplitType.exact:
        final splits = <ExpenseSplitInput>[];
        double sum = 0;
        for (final m in participants) {
          final val = double.tryParse(_exactControllers[m.userId]!.text.trim());
          if (val == null) throw 'Enter an amount for ${m.name}.';
          splits.add(ExpenseSplitInput(userId: m.userId, amountOwed: val));
          sum += val;
        }
        if ((sum - totalAmount).abs() > 0.01) {
          throw 'Exact amounts (${sum.toStringAsFixed(2)}) must add up to the total (${totalAmount.toStringAsFixed(2)}).';
        }
        return splits;

      case SplitType.percentage:
        final splits = <ExpenseSplitInput>[];
        double sumPct = 0;
        for (final m in participants) {
          final val = double.tryParse(_percentControllers[m.userId]!.text.trim());
          if (val == null) throw 'Enter a percentage for ${m.name}.';
          sumPct += val;
          splits.add(ExpenseSplitInput(
            userId: m.userId,
            amountOwed: double.parse((totalAmount * val / 100).toStringAsFixed(2)),
          ));
        }
        if ((sumPct - 100).abs() > 0.5) {
          throw 'Percentages (${sumPct.toStringAsFixed(1)}%) must add up to 100%.';
        }
        return splits;

      case SplitType.shares:
        final shares = <String, double>{};
        double totalShares = 0;
        for (final m in participants) {
          final val = double.tryParse(_sharesControllers[m.userId]!.text.trim());
          if (val == null || val <= 0) throw 'Enter valid shares for ${m.name}.';
          shares[m.userId] = val;
          totalShares += val;
        }
        return participants
            .map((m) => ExpenseSplitInput(
                  userId: m.userId,
                  amountOwed: double.parse(
                      (totalAmount * shares[m.userId]! / totalShares).toStringAsFixed(2)),
                ))
            .toList();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidBy == null) {
      setState(() => _error = 'Select who paid.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final amount = double.parse(_amountController.text.trim());
      final splits = _resolveSplits(amount);

      if (_isEditing) {
        // Fallback update interface route handling
        await _expenseService.updateExpense(
          expenseId: widget.expense!.id,
          description: _descriptionController.text.trim(),
          category: _category,
          amount: amount,
          paidBy: _paidBy!,
          splitType: _splitType,
          splits: splits,
        );
      } else {
        await _expenseService.addExpense(
          groupId: widget.group.id,
          description: _descriptionController.text.trim(),
          category: _category,
          amount: amount,
          paidBy: _paidBy!,
          splitType: _splitType,
          splits: splits,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e is String ? e : 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildParticipantRow(GroupMemberInfo m) {
    Widget? trailingField;
    switch (_splitType) {
      case SplitType.equal:
        trailingField = null;
        break;
      case SplitType.exact:
        trailingField = SizedBox(
          width: 90,
          child: TextField(
            controller: _exactControllers[m.userId],
            enabled: _selected[m.userId] == true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              prefixText: '\$ ',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        );
        break;
      case SplitType.percentage:
        trailingField = SizedBox(
          width: 90,
          child: TextField(
            controller: _percentControllers[m.userId],
            enabled: _selected[m.userId] == true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              suffixText: '%',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        );
        break;
      case SplitType.shares:
        trailingField = SizedBox(
          width: 70,
          child: TextField(
            controller: _sharesControllers[m.userId],
            enabled: _selected[m.userId] == true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        );
        break;
    }

    return CheckboxListTile(
      value: _selected[m.userId] ?? false,
      onChanged: (v) => setState(() => _selected[m.userId] = v ?? false),
      title: Text(
        m.name.isEmpty ? m.email : m.name,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      secondary: trailingField,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.accentPink,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit expense' : 'Add expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    decoration:
                        InputDecoration(labelText: 'Amount (${widget.group.currency})'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final val = double.tryParse(v ?? '');
                      if (val == null || val <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v ?? 'Other'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _paidBy,
                    decoration: const InputDecoration(labelText: 'Paid by'),
                    items: widget.members
                        .map((m) => DropdownMenuItem(
                              value: m.userId,
                              child: Text(m.name.isEmpty ? m.email : m.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _paidBy = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Split type',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  OptionGrid<SplitType>(
                    values: SplitType.values,
                    labelBuilder: (t) => t.label,
                    selected: _splitType,
                    onChanged: (t) => setState(() => _splitType = t),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Split among',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  ...widget.members.map(_buildParticipantRow),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppColors.accentRed)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save expense'),
            ),
          ],
        ),
      ),
    );
  }
}