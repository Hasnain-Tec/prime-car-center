import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class FinancialScreen extends StatefulWidget {
  final SessionController session;

  const FinancialScreen({
    super.key,
    required this.session,
  });

  @override
  State<FinancialScreen> createState() => _FinancialScreenState();
}

class _FinancialScreenState extends State<FinancialScreen> {
  DateTime? from;
  DateTime? to;
  Map<String, dynamic>? data;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, String?> get query => {
        'from': from == null ? null : DateFormat('yyyy-MM-dd').format(from!),
        'to': to == null ? null : DateFormat('yyyy-MM-dd').format(to!),
      };

  Future<void> _load() async {
    setState(() {
      loading = true;
    });

    try {
      data = await widget.session.api.get(
        'financial-summary/',
        query: query,
      ) as Map<String, dynamic>;
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

  double _n(String key) {
    return double.tryParse(
          data?[key]?.toString() ?? '',
        ) ??
        0;
  }

  double get materialsTotal => _n('materials');

  double get labourTotal => _n('labour');

  double get approvedExpenses => _n('expenses');

  /// Revenue is calculated directly from the job amounts.
  double get revenueTotal => materialsTotal + labourTotal;

  /// Profit / Loss is always calculated from revenue minus
  /// approved expenses instead of trusting an incorrect net value
  /// returned by the API.
  double get netProfit => revenueTotal - approvedExpenses;

  int get jobsCount {
    final value = data?['jobs'];

    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _selectFromDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: from ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: to ?? DateTime.now(),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      from = selected;
    });
  }

  Future<void> _selectToDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: to ?? now,
      firstDate: from ?? DateTime(2020),
      lastDate: now,
    );

    if (selected == null) {
      return;
    }

    setState(() {
      to = selected;
    });
  }

  Future<void> _pdf() async {
    try {
      final bytes = await widget.session.api.download(
        'financial-summary/pdf/',
        query: query,
      );

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'financial-summary.pdf',
      );
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  void _resetDates() {
    setState(() {
      from = null;
      to = null;
    });

    _load();
  }

  String get _rangeText {
    if (from == null && to == null) {
      return 'All workshop records';
    }

    if (from != null && to != null) {
      return '${DateFormat('dd MMM yyyy').format(from!)}'
          '  —  '
          '${DateFormat('dd MMM yyyy').format(to!)}';
    }

    if (from != null) {
      return 'From ${DateFormat('dd MMM yyyy').format(from!)}';
    }

    return 'Up to ${DateFormat('dd MMM yyyy').format(to!)}';
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PccColors.charcoal,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 600;

          final titleSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: Colors.white,
                    size: 25,
                  ),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Financial Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                _rangeText,
                style: const TextStyle(
                  color: Color(0xFFD4D4D4),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );

          final badge = Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF3C3C3C),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFF666666),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'ADMIN ONLY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          );

          if (mobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleSection,
                const SizedBox(height: 14),
                badge,
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: titleSection,
              ),
              const SizedBox(width: 15),
              badge,
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterPanel() {
    return PccPanel(
      title: 'Report Period',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 650;

          final fromButton = OutlinedButton.icon(
            onPressed: loading ? null : _selectFromDate,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(
              Icons.calendar_today_outlined,
            ),
            label: Text(
              from == null
                  ? 'FROM DATE'
                  : DateFormat('dd MMM yyyy').format(from!),
              overflow: TextOverflow.ellipsis,
            ),
          );

          final toButton = OutlinedButton.icon(
            onPressed: loading ? null : _selectToDate,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(
              Icons.event_outlined,
            ),
            label: Text(
              to == null ? 'TO DATE' : DateFormat('dd MMM yyyy').format(to!),
              overflow: TextOverflow.ellipsis,
            ),
          );

          final applyButton = FilledButton.icon(
            onPressed: loading ? null : _load,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: PccColors.hazard,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(
              Icons.filter_alt_outlined,
            ),
            label: const Text(
              'APPLY',
            ),
          );

          final allTimeButton = OutlinedButton.icon(
            onPressed: loading ? null : _resetDates,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(
              Icons.all_inclusive,
            ),
            label: const Text(
              'ALL TIME',
            ),
          );

          final pdfButton = OutlinedButton.icon(
            onPressed: loading ? null : _pdf,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: PccColors.danger,
            ),
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
            ),
            label: const Text(
              'PDF REPORT',
            ),
          );

          if (mobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                fromButton,
                const SizedBox(height: 10),
                toButton,
                const SizedBox(height: 10),
                applyButton,
                const SizedBox(height: 10),
                allTimeButton,
                if (widget.session.can('finance.export')) ...[
                  const SizedBox(height: 10),
                  pdfButton,
                ],
              ],
            );
          }

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 190,
                child: fromButton,
              ),
              SizedBox(
                width: 190,
                child: toButton,
              ),
              SizedBox(
                width: 130,
                child: applyButton,
              ),
              SizedBox(
                width: 145,
                child: allTimeButton,
              ),
              if (widget.session.can('finance.export'))
                SizedBox(
                  width: 170,
                  child: pdfButton,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    Color? accent,
    String? subtitle,
  }) {
    final cardAccent = accent ?? PccColors.charcoal;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: PccColors.line,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cardAccent.withValues(
                alpha: 0.10,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: cardAccent,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PccColors.inkSoft,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cardAccent,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PccColors.inkSoft,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int columns;

        if (width >= 1050) {
          columns = 3;
        } else if (width >= 620) {
          columns = 2;
        } else {
          columns = 1;
        }

        final ratio = columns == 1
            ? 3.15
            : columns == 2
                ? 2.55
                : 2.35;

        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: ratio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _metricCard(
              title: 'Completed Jobs',
              value: '$jobsCount',
              icon: Icons.task_alt_outlined,
              subtitle: 'Jobs included in this report',
            ),
            _metricCard(
              title: 'Materials Total',
              value: money(
                materialsTotal,
                widget.session.workshop.currency,
              ),
              icon: Icons.inventory_2_outlined,
            ),
            _metricCard(
              title: 'Labour Total',
              value: money(
                labourTotal,
                widget.session.workshop.currency,
              ),
              icon: Icons.engineering_outlined,
            ),
            _metricCard(
              title: 'Total Revenue',
              value: money(
                revenueTotal,
                widget.session.workshop.currency,
              ),
              icon: Icons.payments_outlined,
              accent: PccColors.success,
              subtitle: 'Materials + labour',
            ),
            _metricCard(
              title: 'Approved Expenses',
              value: money(
                approvedExpenses,
                widget.session.workshop.currency,
              ),
              icon: Icons.receipt_long_outlined,
              accent: PccColors.danger,
              subtitle: 'Deducted from revenue',
            ),
            _metricCard(
              title: netProfit >= 0 ? 'Net Profit' : 'Net Loss',
              value: money(
                netProfit,
                widget.session.workshop.currency,
              ),
              icon: netProfit >= 0 ? Icons.trending_up : Icons.trending_down,
              accent: netProfit >= 0 ? PccColors.success : PccColors.danger,
              subtitle: 'Revenue − approved expenses',
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfitPanel() {
    final positive = netProfit >= 0;
    final accent = positive ? PccColors.success : PccColors.danger;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(
            alpha: 0.35,
          ),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 620;

          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: accent.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      positive
                          ? Icons.account_balance_wallet_outlined
                          : Icons.warning_amber_rounded,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      positive ? 'Workshop Net Profit' : 'Workshop Net Loss',
                      style: const TextStyle(
                        color: PccColors.charcoal,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Calculated after deducting approved expenses from total job revenue.',
                style: TextStyle(
                  color: PccColors.inkSoft,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          );

          final amount = Text(
            money(
              netProfit,
              widget.session.workshop.currency,
            ),
            textAlign: mobile ? TextAlign.left : TextAlign.right,
            style: TextStyle(
              color: accent,
              fontSize: mobile ? 27 : 31,
              fontWeight: FontWeight.w900,
            ),
          );

          if (mobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const Divider(height: 28),
                amount,
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: heading,
              ),
              const SizedBox(width: 20),
              amount,
            ],
          );
        },
      ),
    );
  }

  Widget _calculationRow({
    required String label,
    required double amount,
    bool subtract = false,
    bool total = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: total ? 11 : 8,
      ),
      child: Row(
        children: [
          if (subtract)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.remove_circle_outline,
                color: PccColors.danger,
                size: 18,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.add_circle_outline,
                color: PccColors.success,
                size: 18,
              ),
            ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: PccColors.charcoal,
                fontWeight: total ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              money(
                amount,
                widget.session.workshop.currency,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: total
                    ? (netProfit >= 0 ? PccColors.success : PccColors.danger)
                    : PccColors.charcoal,
                fontWeight: total ? FontWeight.w900 : FontWeight.w700,
                fontSize: total ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationPanel() {
    return PccPanel(
      title: 'Profit Calculation',
      child: Column(
        children: [
          _calculationRow(
            label: 'Materials Revenue',
            amount: materialsTotal,
          ),
          _calculationRow(
            label: 'Labour Revenue',
            amount: labourTotal,
          ),
          const Divider(),
          _calculationRow(
            label: 'Total Revenue',
            amount: revenueTotal,
          ),
          _calculationRow(
            label: 'Approved Expenses',
            amount: approvedExpenses,
            subtract: true,
          ),
          const Divider(),
          _calculationRow(
            label: netProfit >= 0 ? 'NET PROFIT' : 'NET LOSS',
            amount: netProfit,
            total: true,
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F6),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: PccColors.line,
              ),
            ),
            child: const Text(
              'Only approved expenses should be deducted from revenue. '
              'Submitted or rejected expenses should not reduce profit.',
              style: TextStyle(
                color: PccColors.inkSoft,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final padding = screenWidth < 600
        ? 12.0
        : screenWidth < 1000
            ? 18.0
            : 24.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        padding,
        16,
        padding,
        30,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1250,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildFilterPanel(),
                const SizedBox(height: 16),
                if (loading)
                  const SizedBox(
                    height: 300,
                    child: LoadingView(),
                  )
                else ...[
                  _buildMetrics(),
                  const SizedBox(height: 16),
                  _buildProfitPanel(),
                  const SizedBox(height: 16),
                  _buildCalculationPanel(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
