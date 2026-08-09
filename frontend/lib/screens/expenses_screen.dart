import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/session.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class ExpensesScreen extends StatefulWidget {
  final SessionController session;

  const ExpensesScreen({
    super.key,
    required this.session,
  });

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _amount = TextEditingController(text: '0');
  final _description = TextEditingController();

  DateTime? _from;
  DateTime? _to;
  List<ExpenseModel> expenses = [];

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final data = await widget.session.api.get(
        'expenses/',
        query: {
          'from':
              _from == null ? null : DateFormat('yyyy-MM-dd').format(_from!),
          'to': _to == null ? null : DateFormat('yyyy-MM-dd').format(_to!),
        },
      );

      final loadedExpenses = widget.session.api
          .unwrapList(data)
          .map(
            (item) => ExpenseModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();

      if (mounted) {
        setState(() {
          expenses = loadedExpenses;
        });
      }
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _add() async {
    final amount = double.tryParse(_amount.text) ?? 0;
    final description = _description.text.trim();

    if (amount <= 0 || description.isEmpty) {
      showError(
        context,
        'Enter a valid amount and description.',
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await widget.session.api.post(
        'expenses/',
        body: {
          'amount': amount,
          'description': description,
        },
      );

      _amount.text = '0';
      _description.clear();

      if (!mounted) {
        return;
      }

      showSuccess(
        context,
        'Expense added successfully.',
      );

      await _load();
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> _delete(ExpenseModel expense) async {
    final confirmed = await confirmAction(
      context,
      'Delete this expense permanently?',
    );

    if (!confirmed) {
      return;
    }

    try {
      await widget.session.api.delete(
        'expenses/${expense.id}/',
      );

      if (!mounted) {
        return;
      }

      showSuccess(
        context,
        'Expense deleted.',
      );

      await _load();
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _selectFromDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected != null) {
      setState(() {
        _from = selected;

        if (_to != null && _to!.isBefore(selected)) {
          _to = selected;
        }
      });
    }
  }

  Future<void> _selectToDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _to ?? _from ?? DateTime.now(),
      firstDate: _from ?? DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected != null) {
      setState(() {
        _to = selected;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _from = null;
      _to = null;
    });

    _load();
  }

  Widget _buildAddExpensePanel() {
    return PccPanel(
      title: 'Add Expense',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 520;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount (${widget.session.workshop.currency})',
                  prefixIcon: const Icon(
                    Icons.payments_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter complete expense details',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: mobile ? double.infinity : null,
                child: FilledButton.icon(
                  onPressed: saving ? null : _add,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: PccColors.hazard,
                    foregroundColor: Colors.white,
                  ),
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.add_card,
                        ),
                  label: Text(
                    saving ? 'SUBMITTING...' : 'ADD EXPENSE',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchPanel() {
    return PccPanel(
      title: 'Search Expenses',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 560;

          final fromButton = OutlinedButton.icon(
            onPressed: _selectFromDate,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(
              Icons.date_range,
            ),
            label: Text(
              _from == null
                  ? 'FROM DATE'
                  : DateFormat('dd MMM yyyy').format(_from!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );

          final toButton = OutlinedButton.icon(
            onPressed: _selectToDate,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(
              Icons.event,
            ),
            label: Text(
              _to == null ? 'TO DATE' : DateFormat('dd MMM yyyy').format(_to!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );

          final filterButton = FilledButton.icon(
            onPressed: loading ? null : _load,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(
              Icons.filter_alt_outlined,
            ),
            label: const Text(
              'FILTER',
            ),
          );

          final resetButton = OutlinedButton.icon(
            onPressed: loading ? null : _resetFilters,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(
              Icons.restart_alt,
            ),
            label: const Text(
              'RESET',
            ),
          );

          if (mobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                fromButton,
                const SizedBox(height: 11),
                toButton,
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: filterButton,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: resetButton,
                    ),
                  ],
                ),
              ],
            );
          }

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 185,
                child: fromButton,
              ),
              SizedBox(
                width: 185,
                child: toButton,
              ),
              filterButton,
              resetButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildExpenseActions(ExpenseModel expense) {
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      alignment: WrapAlignment.end,
      children: [
        if (widget.session.can('expenses.delete'))
          IconButton(
            tooltip: 'Delete',
            onPressed: () {
              _delete(expense);
            },
            style: IconButton.styleFrom(
              backgroundColor: PccColors.danger.withValues(alpha: 0.08),
            ),
            icon: const Icon(
              Icons.delete_outline,
              color: PccColors.danger,
            ),
          ),
      ],
    );
  }

  Widget _buildExpenseCard(ExpenseModel expense) {
    final submittedBy = expense.submittedByName.trim().isEmpty
        ? 'Unknown user'
        : expense.submittedByName.trim();

    final date = DateFormat('dd MMM yyyy').format(expense.createdAt.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mobile = constraints.maxWidth < 700;

            final avatar = CircleAvatar(
              radius: mobile ? 22 : 24,
              backgroundColor: PccColors.hazard.withValues(alpha: 0.12),
              child: Icon(
                Icons.receipt_long,
                color: PccColors.hazard,
              ),
            );

            final descriptionArea = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  maxLines: mobile ? 5 : 3,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    color: PccColors.charcoal,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  children: [
                    _ExpenseMeta(
                      icon: Icons.person_outline,
                      text: submittedBy,
                    ),
                    _ExpenseMeta(
                      icon: Icons.calendar_today_outlined,
                      text: date,
                    ),
                  ],
                ),
              ],
            );

            final amountText = Text(
              money(
                expense.amount,
                widget.session.workshop.currency,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: mobile ? TextAlign.left : TextAlign.right,
              style: const TextStyle(
                color: PccColors.hazardDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            );

            if (mobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      avatar,
                      const SizedBox(width: 11),
                      Expanded(
                        child: descriptionArea,
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF9F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: PccColors.line,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: amountText,
                        ),
                      ],
                    ),
                  ),
                  if (widget.session.can('expenses.delete')) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildExpenseActions(expense),
                    ),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                avatar,
                const SizedBox(width: 13),
                Expanded(
                  child: descriptionArea,
                ),
                const SizedBox(width: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 110,
                    maxWidth: 155,
                  ),
                  child: amountText,
                ),
                if (widget.session.can('expenses.delete')) ...[
                  const SizedBox(width: 7),
                  _buildExpenseActions(expense),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTotalBar(double total) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 430;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 15,
          ),
          decoration: BoxDecoration(
            color: PccColors.charcoal,
            borderRadius: BorderRadius.circular(10),
            border: const Border(
              bottom: BorderSide(
                color: PccColors.hazard,
                width: 3,
              ),
            ),
          ),
          child: mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL IN CURRENT VIEW',
                      style: TextStyle(
                        color: Color(0xFFB9C2CC),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      money(
                        total,
                        widget.session.workshop.currency,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'TOTAL IN CURRENT VIEW',
                        style: TextStyle(
                          color: Color(0xFFB9C2CC),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        money(
                          total,
                          widget.session.workshop.currency,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildExpenseRecordsPanel(double total) {
    return PccPanel(
      title: 'Expense Records',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading)
            const SizedBox(
              height: 220,
              child: LoadingView(),
            )
          else if (expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 42,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 46,
                    color: PccColors.inkSoft,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No expenses match this search.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: PccColors.inkSoft,
                    ),
                  ),
                ],
              ),
            )
          else
            for (final expense in expenses) _buildExpenseCard(expense),
          if (!loading) ...[
            const SizedBox(height: 5),
            _buildTotalBar(total),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = expenses.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    final screenWidth = MediaQuery.sizeOf(context).width;

    final pagePadding = screenWidth < 600
        ? 12.0
        : screenWidth < 1000
            ? 18.0
            : 24.0;

    final canCreate = widget.session.can('expenses.create');

    return ListView(
      padding: EdgeInsets.fromLTRB(
        pagePadding,
        16,
        pagePadding,
        30,
      ),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 900;

            if (!desktop) {
              return Column(
                children: [
                  if (canCreate) ...[
                    _buildAddExpensePanel(),
                    const SizedBox(height: 14),
                  ],
                  _buildSearchPanel(),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canCreate) ...[
                  Expanded(
                    child: _buildAddExpensePanel(),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: _buildSearchPanel(),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _buildExpenseRecordsPanel(total),
      ],
    );
  }
}

class _ExpenseMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ExpenseMeta({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 220,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: PccColors.inkSoft,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PccColors.inkSoft,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
