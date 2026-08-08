import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatefulWidget {
  final SessionController session;
  const DashboardScreen({super.key, required this.session});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? data;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await widget.session.api.get('dashboard/');
      if (mounted) setState(() => data = response as Map<String, dynamic>);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data == null && error == null) return const LoadingView();
    if (error != null) {
      return Center(
          child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(error.toString())));
    }
    final values = data!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text('Welcome, ${widget.session.user!.fullName}',
              style:
                  const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(
              '${widget.session.user!.roleName ?? 'User'} · ${widget.session.workshop.name}',
              style: const TextStyle(color: PccColors.inkSoft)),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            final count = width >= 1000
                ? 4
                : width >= 600
                    ? 2
                    : 1;
            return GridView.count(
              crossAxisCount: count,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: width >= 600 ? 2.2 : 3.4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                MetricCard(
                    label: 'Visible Jobs',
                    value: '${values['jobs_total'] ?? 0}'),
                MetricCard(
                    label: 'Unassigned',
                    value: '${values['jobs_unassigned'] ?? 0}',
                    accent: PccColors.steelLight),
                MetricCard(
                    label: 'In Progress',
                    value: '${values['jobs_in_progress'] ?? 0}',
                    accent: PccColors.hazard),
                MetricCard(
                    label: 'Completed',
                    value: '${values['jobs_completed'] ?? 0}',
                    accent: PccColors.success),
                if (values.containsKey('pending_users'))
                  MetricCard(
                      label: 'Pending Users',
                      value: '${values['pending_users']}',
                      accent: PccColors.danger),
                if (values.containsKey('active_users'))
                  MetricCard(
                      label: 'Active Users',
                      value: '${values['active_users']}',
                      accent: PccColors.success),
              ],
            );
          }),
          const SizedBox(height: 18),
          PccPanel(
            title: 'Access Summary',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.session.user!.permissions
                  .map((permission) => Chip(
                      label: Text(permission),
                      side: const BorderSide(color: PccColors.line),
                      backgroundColor: const Color(0xFFF7F6F2)))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
