import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class AuditScreen extends StatefulWidget {
  final SessionController session;
  const AuditScreen({super.key, required this.session});
  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  List<Map<String, dynamic>> logs = [];
  bool loading = true;
  String? module;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final data = await widget.session.api.get('audit-logs/', query: {'module': module});
      logs = widget.session.api.unwrapList(data).cast<Map<String, dynamic>>();
    } catch (error) { showError(context, error); }
    finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    PccPanel(title: 'Activity & Audit Logs', child: Wrap(spacing: 10, runSpacing: 10, children: [
      DropdownButton<String?>(value: module, hint: const Text('All modules'), items: const [
        DropdownMenuItem(value: null, child: Text('All modules')),
        DropdownMenuItem(value: 'accounts', child: Text('Accounts')),
        DropdownMenuItem(value: 'jobs', child: Text('Jobs')),
        DropdownMenuItem(value: 'expenses', child: Text('Expenses')),
        DropdownMenuItem(value: 'administration', child: Text('Administration')),
      ], onChanged: (value) { setState(() => module = value); _load(); }),
      OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('REFRESH')),
    ])),
    const SizedBox(height: 16),
    PccPanel(title: 'Recent Activity', child: loading ? const SizedBox(height: 250, child: LoadingView()) : logs.isEmpty ? const Padding(padding: EdgeInsets.all(30), child: Text('No audit records found.')) : Column(children: logs.map((log) {
      final created = DateTime.tryParse(log['created_at']?.toString() ?? '');
      return ListTile(
        leading: const CircleAvatar(backgroundColor: Color(0xFFF0EFE9), child: Icon(Icons.history, color: PccColors.hazard)),
        title: Text((log['action']?.toString() ?? '').replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${log['actor_name'] ?? 'System'} · ${log['module'] ?? ''}${log['object_id'].toString().isNotEmpty ? ' · #${log['object_id']}' : ''}'),
        trailing: Text(created == null ? '—' : DateFormat('dd MMM yy\nHH:mm').format(created.toLocal()), textAlign: TextAlign.right, style: const TextStyle(color: PccColors.inkSoft, fontSize: 12)),
      );
    }).toList())),
  ]);
}
