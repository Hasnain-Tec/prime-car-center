import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../core/browser_notification_service.dart';
import '../core/job_notification_service.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class JobRecordsScreen extends StatefulWidget {
  final SessionController session;
  const JobRecordsScreen({super.key, required this.session});

  @override
  State<JobRecordsScreen> createState() => _JobRecordsScreenState();
}

class _JobRecordsScreenState extends State<JobRecordsScreen> {
  final _plate = TextEditingController();
  final _invoice = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  String? _status;
  List<JobModel> jobs = [];
  bool loading = true;
  final Map<int, String> _reminderState = <int, String>{};
  final Map<int, String> _browserReminderState = <int, String>{};
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    _load();

    _reminderTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted) {
          setState(() {});
          unawaited(_syncBrowserReminders());
        }
      },
    );
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    _plate.dispose();
    _invoice.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final data = await widget.session.api.get('jobs/', query: {
        'plate': _plate.text.trim(),
        'invoice': _invoice.text.trim(),
        'status': _status,
        'from': _from == null ? null : DateFormat('yyyy-MM-dd').format(_from!),
        'to': _to == null ? null : DateFormat('yyyy-MM-dd').format(_to!),
      });
      jobs = widget.session.api
          .unwrapList(data)
          .map((e) => JobModel.fromJson(e as Map<String, dynamic>))
          .toList();

      await _syncJobReminders();
      await _syncBrowserReminders();
    } catch (error) {
      showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _reminderKey({
    required DateTime? endTime,
    required String status,
    required String plateNumber,
  }) {
    return '${endTime?.toUtc().toIso8601String() ?? ''}|$status|$plateNumber';
  }

  Future<void> _syncJobReminders() async {
    try {
      await JobNotificationService.instance.initialize();

      for (final job in jobs) {
        final key = _reminderKey(
          endTime: job.endTime,
          status: job.status,
          plateNumber: job.plateNumber,
        );

        if (_reminderState[job.id] == key) {
          continue;
        }

        await JobNotificationService.instance.scheduleJobReminders(
          jobId: job.id,
          invoiceNumber: job.invoiceNumber,
          plateNumber: job.plateNumber,
          endTime: job.endTime,
          status: job.status,
        );

        _reminderState[job.id] = key;
      }
    } catch (_) {
      // Reminder failures must never block the job records screen.
    }
  }

  bool _isReminderTerminalStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'completed' || normalized == 'cancelled';
  }

  String? _jobReminderText(JobModel job) {
    if (job.endTime == null || _isReminderTerminalStatus(job.status)) {
      return null;
    }

    final now = DateTime.now();
    final endTime = job.endTime!.toLocal();
    final remaining = endTime.difference(now);

    if (remaining > const Duration(minutes: 30)) {
      return null;
    }

    if (remaining.isNegative || remaining == Duration.zero) {
      final overdue = now.difference(endTime);
      final minutes = overdue.inMinutes;

      if (minutes < 1) {
        return 'JOB TIME OVER';
      }

      if (minutes < 60) {
        return 'OVERDUE · $minutes MIN';
      }

      final hours = minutes ~/ 60;
      final extraMinutes = minutes % 60;

      if (extraMinutes == 0) {
        return 'OVERDUE · $hours HR';
      }

      return 'OVERDUE · $hours HR $extraMinutes MIN';
    }

    final minutesLeft = (remaining.inSeconds / 60).ceil();
    return 'ENDING SOON · $minutesLeft MIN LEFT';
  }

  bool _jobIsOverdue(JobModel job) {
    if (job.endTime == null || _isReminderTerminalStatus(job.status)) {
      return false;
    }

    return !job.endTime!.toLocal().isAfter(DateTime.now());
  }

  Widget _jobReminderChip(JobModel job) {
    final text = _jobReminderText(job);

    if (text == null) {
      return const SizedBox.shrink();
    }

    final overdue = _jobIsOverdue(job);
    final color = overdue ? PccColors.danger : PccColors.hazard;
    final icon = overdue
        ? Icons.notification_important_outlined
        : Icons.notifications_active_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  String? _browserReminderLevel(JobModel job) {
    if (job.endTime == null || _isReminderTerminalStatus(job.status)) {
      return null;
    }

    final remaining = job.endTime!.toLocal().difference(DateTime.now());

    if (remaining > const Duration(minutes: 30)) {
      return null;
    }

    if (remaining.isNegative || remaining == Duration.zero) {
      return 'overdue';
    }

    return 'soon';
  }

  Future<void> _syncBrowserReminders() async {
    if (!kIsWeb) {
      return;
    }

    try {
      if (!BrowserNotificationService.instance.permissionGranted) {
        return;
      }

      for (final job in jobs) {
        final level = _browserReminderLevel(job);

        if (level == null) {
          _browserReminderState.remove(job.id);
          continue;
        }

        final key =
            '${job.endTime?.toUtc().toIso8601String() ?? ''}|${job.status}|$level';

        if (_browserReminderState[job.id] == key) {
          continue;
        }

        if (level == 'overdue') {
          final endTime = job.endTime!.toLocal();
          final overdue = DateTime.now().difference(endTime);
          final overdueMinutes = overdue.inMinutes;

          await BrowserNotificationService.instance.show(
            title: 'Job Time Is Over',
            body: overdueMinutes < 1
                ? '${job.invoiceNumber} • ${job.plateNumber}\nExpected job time has ended.'
                : '${job.invoiceNumber} • ${job.plateNumber}\nOverdue by $overdueMinutes minute${overdueMinutes == 1 ? '' : 's'}.',
            tag: 'pcc-job-${job.id}-overdue',
          );
        } else {
          final remaining = job.endTime!.toLocal().difference(DateTime.now());
          var minutesLeft = (remaining.inSeconds / 60).ceil();

          if (minutesLeft < 1) {
            minutesLeft = 1;
          }

          await BrowserNotificationService.instance.show(
            title: 'Job Ending Soon',
            body:
                '${job.invoiceNumber} • ${job.plateNumber}\n$minutesLeft minute${minutesLeft == 1 ? '' : 's'} remaining.',
            tag: 'pcc-job-${job.id}-soon',
          );
        }

        _browserReminderState[job.id] = key;
      }
    } catch (_) {
      // Browser reminder failures must never block Job Records.
    }
  }

  Future<void> _enableBrowserReminders() async {
    if (!kIsWeb) {
      return;
    }

    try {
      final allowed =
          await BrowserNotificationService.instance.requestPermission();

      if (!mounted) {
        return;
      }

      if (!allowed) {
        showError(
          context,
          'Browser notifications are blocked. Allow notifications for this site in Chrome or Edge settings.',
        );
        return;
      }

      showSuccess(
        context,
        'Browser job reminders enabled.',
      );

      await _syncBrowserReminders();
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  void _reset() {
    _plate.clear();
    _invoice.clear();
    _from = null;
    _to = null;
    _status = null;
    _load();
  }

  bool _assignedFlag(JobModel job, bool Function(JobAssignmentModel a) test) =>
      job.assignments
          .where((a) => a.userId == widget.session.user!.id)
          .any(test);
  bool _canEdit(JobModel job) =>
      widget.session.can('jobs.edit_all') ||
      _assignedFlag(job, (a) => a.canEdit);
  bool _canDelete(JobModel job) =>
      widget.session.can('jobs.delete_all') ||
      _assignedFlag(job, (a) => a.canDelete);

  Future<void> _delete(JobModel job) async {
    if (!await confirmAction(
        context, 'Delete ${job.invoiceNumber} permanently?')) {
      return;
    }
    try {
      await widget.session.api.delete('jobs/${job.id}/');

      try {
        await JobNotificationService.instance.cancelJobReminders(job.id);
        _reminderState.remove(job.id);
        _browserReminderState.remove(job.id);
      } catch (_) {
        // Job deletion remains successful even if a reminder cannot be removed.
      }

      showSuccess(context, 'Job deleted.');
      _load();
    } catch (error) {
      showError(context, error);
    }
  }

  Future<void> _invoicePdf(JobModel job) async {
    try {
      final bytes = await widget.session.api.download(
        'jobs/${job.id}/invoice_pdf/',
      );

      if (bytes.isEmpty) {
        throw Exception('The invoice PDF is empty.');
      }

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(
                title: Text(job.invoiceNumber),
              ),
              body: PdfPreview(
                build: (_) async => bytes,
                pdfFileName: '${job.invoiceNumber}.pdf',
                allowPrinting: true,
                allowSharing: true,
                canChangePageFormat: false,
                canChangeOrientation: false,
              ),
            );
          },
        ),
      );
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _changeStatus(JobModel job, String status) async {
    try {
      await widget.session.api
          .post('jobs/${job.id}/change_status/', body: {'status': status});

      try {
        if (status == 'completed' || status == 'cancelled') {
          await JobNotificationService.instance.cancelJobReminders(job.id);
          _reminderState.remove(job.id);
          _browserReminderState.remove(job.id);
        } else {
          await JobNotificationService.instance.scheduleJobReminders(
            jobId: job.id,
            invoiceNumber: job.invoiceNumber,
            plateNumber: job.plateNumber,
            endTime: job.endTime,
            status: status,
          );

          _reminderState[job.id] = _reminderKey(
            endTime: job.endTime,
            status: status,
            plateNumber: job.plateNumber,
          );
        }
      } catch (_) {
        // Status update remains successful even if a reminder cannot be changed.
      }

      showSuccess(context, 'Job status updated.');
      _load();
    } catch (error) {
      showError(context, error);
    }
  }

  Future<void> _pickDate(bool from) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (selected != null) {
      setState(() {
        if (from) {
          _from = selected;
        } else {
          _to = selected;
        }
      });
    }
  }

  Future<DateTime?> _pickDateTimeValue({
    DateTime? initialValue,
    DateTime? firstAllowedDate,
  }) async {
    final now = DateTime.now();
    final firstDate = firstAllowedDate ?? DateTime(2020);
    final lastDate = now.add(const Duration(days: 730));

    var initialDate = initialValue ?? now;
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }
    if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (selectedDate == null || !mounted) {
      return null;
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialValue ?? now),
    );

    if (selectedTime == null) {
      return null;
    }

    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final pagePadding = screenWidth < 600
        ? 12.0
        : screenWidth < 1000
            ? 18.0
            : 24.0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          pagePadding,
          16,
          pagePadding,
          30,
        ),
        children: [
          _buildSearchPanel(),
          const SizedBox(height: 16),
          PccPanel(
            title: loading ? 'Job Records' : 'Job Records (${jobs.length})',
            child: loading
                ? const SizedBox(
                    height: 240,
                    child: LoadingView(),
                  )
                : jobs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 54,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off_outlined,
                              size: 48,
                              color: PccColors.inkSoft,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No job records match this search.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: PccColors.inkSoft,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth >= 980) {
                            return _desktopTable();
                          }

                          return Column(
                            children: jobs.map(_mobileCard).toList(),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    return PccPanel(
      title: 'Search Job Records',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 620;
          final fieldWidth = mobile ? constraints.maxWidth : 205.0;
          final actionWidth = mobile ? constraints.maxWidth : 145.0;

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _plate,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Plate Number',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _invoice,
                  decoration: const InputDecoration(
                    labelText: 'Invoice Number',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    DropdownMenuItem(
                      value: 'unassigned',
                      child: Text('Unassigned'),
                    ),
                    DropdownMenuItem(
                      value: 'assigned',
                      child: Text('Assigned'),
                    ),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('In Progress'),
                    ),
                    DropdownMenuItem(
                      value: 'on_hold',
                      child: Text('On Hold'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text('Cancelled'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _status = value;
                    });
                  },
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    _from == null
                        ? 'FROM DATE'
                        : DateFormat('dd MMM yyyy').format(_from!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text(
                    _to == null
                        ? 'TO DATE'
                        : DateFormat('dd MMM yyyy').format(_to!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              SizedBox(
                width: actionWidth,
                child: FilledButton.icon(
                  onPressed: loading ? null : _load,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: PccColors.hazard,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.search),
                  label: const Text('FILTER'),
                ),
              ),
              SizedBox(
                width: actionWidth,
                child: OutlinedButton.icon(
                  onPressed: loading ? null : _reset,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('RESET'),
                ),
              ),
              if (kIsWeb)
                SizedBox(
                  width: actionWidth,
                  child: OutlinedButton.icon(
                    onPressed: _enableBrowserReminders,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('REMINDERS'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _desktopTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        horizontalMargin: 14,
        columnSpacing: 22,
        headingRowHeight: 52,
        dataRowMinHeight: 72,
        dataRowMaxHeight: 86,
        headingRowColor: WidgetStateProperty.all(
          const Color(0xFFF0EFE9),
        ),
        columns: const [
          DataColumn(label: Text('PHOTO')),
          DataColumn(label: Text('JOB')),
          DataColumn(label: Text('PLATE')),
          DataColumn(label: Text('START TIME')),
          DataColumn(label: Text('END TIME')),
          DataColumn(label: Text('PRIORITY')),
          DataColumn(label: Text('TOTAL')),
          DataColumn(label: Text('STATUS')),
          DataColumn(label: Text('REMINDER')),
          DataColumn(label: Text('ACTIONS')),
        ],
        rows: jobs.map((job) {
          return DataRow(
            cells: [
              DataCell(_photo(job, size: 60)),
              DataCell(
                SizedBox(
                  width: 220,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.invoiceNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: PccColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        job.workDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PccColors.inkSoft,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(_plateChip(job.plateNumber)),
              DataCell(
                SizedBox(
                  width: 145,
                  child: Text(
                    _formatDateTime(job.startTime),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 145,
                  child: Text(
                    _formatDateTime(job.endTime),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              DataCell(_priorityChip(job.priority)),
              DataCell(
                Text(
                  money(
                    job.total,
                    widget.session.workshop.currency,
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: PccColors.hazardDark,
                  ),
                ),
              ),
              DataCell(_statusChip(job.status)),
              DataCell(_jobReminderChip(job)),
              DataCell(_actions(job)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _mobileCard(JobModel job) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(
            color: PccColors.line,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 4,
              color: _statusColor(job.status),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _photo(job, size: 76),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.invoiceNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: PccColors.charcoal,
                              ),
                            ),
                            const SizedBox(height: 7),
                            _plateChip(job.plateNumber),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _statusChip(job.status),
                                _priorityChip(job.priority),
                                if (_jobReminderText(job) != null)
                                  _jobReminderChip(job),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _actions(job),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    job.workDescription,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: PccColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF9F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: PccColors.line,
                      ),
                    ),
                    child: Column(
                      children: [
                        _mobileTimeRow(
                          icon: Icons.play_circle_outline,
                          label: 'Start time',
                          value: _formatDateTime(job.startTime),
                          color: PccColors.success,
                        ),
                        const Divider(height: 18),
                        _mobileTimeRow(
                          icon: Icons.stop_circle_outlined,
                          label: 'End time',
                          value: _formatDateTime(job.endTime),
                          color: PccColors.hazard,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Created ${_formatDate(job.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PccColors.inkSoft,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        money(
                          job.total,
                          widget.session.workshop.currency,
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: PccColors.hazardDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showDetails(job),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('VIEW COMPLETE JOB DETAILS'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileTimeRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 19,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: PccColors.inkSoft,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: PccColors.charcoal,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _photo(
    JobModel job, {
    double size = 48,
  }) {
    final height = size * 0.82;

    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: job.photoUrl == null
          ? Container(
              width: size,
              height: height,
              color: const Color(0xFFEAE8E1),
              alignment: Alignment.center,
              child: const Icon(
                Icons.directions_car_outlined,
                color: PccColors.inkSoft,
              ),
            )
          : Image.network(
              job.photoUrl!,
              width: size,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  width: size,
                  height: height,
                  color: const Color(0xFFEAE8E1),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: PccColors.inkSoft,
                  ),
                );
              },
            ),
    );
  }

  Widget _plateChip(String plate) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: PccColors.charcoal,
          width: 1.7,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        plate,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'completed' => PccColors.success,
      'cancelled' => PccColors.danger,
      'in_progress' => PccColors.hazard,
      'on_hold' => PccColors.steel,
      'assigned' => const Color(0xFF3768B5),
      _ => PccColors.inkSoft,
    };
  }

  Color _priorityColor(String priority) {
    return switch (priority) {
      'urgent' => PccColors.danger,
      'high' => PccColors.hazard,
      'low' => PccColors.success,
      _ => PccColors.steel,
    };
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Chip(
      label: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
      side: BorderSide(
        color: color.withOpacity(0.55),
      ),
      backgroundColor: color.withOpacity(0.08),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _priorityChip(String priority) {
    final color = _priorityColor(priority);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.45),
        ),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Not set';
    }

    return DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(value.toLocal());
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Not set';
    }

    return DateFormat(
      'dd MMM yyyy',
    ).format(value.toLocal());
  }

  Widget _actions(JobModel job) => PopupMenuButton<String>(
        tooltip: 'Job actions',
        onSelected: (value) async {
          if (value == 'view') await _showDetails(job);
          if (value == 'edit') await _editDialog(job);
          if (value == 'assign') await _assignmentDialog(job);
          if (value == 'invoice') await _invoicePdf(job);
          if (value == 'delete') await _delete(job);
          if (value.startsWith('status:')) {
            await _changeStatus(job, value.substring(7));
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
              value: 'view',
              child: ListTile(
                  leading: Icon(Icons.visibility_outlined),
                  title: Text('View details'))),
          if (_canEdit(job))
            const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit job'))),
          if (widget.session.can('jobs.assign'))
            const PopupMenuItem(
                value: 'assign',
                child: ListTile(
                    leading: Icon(Icons.assignment_ind_outlined),
                    title: Text('Assign users'))),
          if (widget.session.can('jobs.change_status') ||
              _assignedFlag(job, (a) => a.canChangeStatus)) ...const [
            PopupMenuItem(
                value: 'status:in_progress',
                child: ListTile(
                    leading: Icon(Icons.play_arrow),
                    title: Text('Mark in progress'))),
            PopupMenuItem(
                value: 'status:on_hold',
                child: ListTile(
                    leading: Icon(Icons.pause), title: Text('Put on hold'))),
            PopupMenuItem(
                value: 'status:completed',
                child: ListTile(
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('Mark completed'))),
          ],
          if (widget.session.can('jobs.print_invoice') ||
              _assignedFlag(job, (a) => a.canPrintInvoice))
            const PopupMenuItem(
                value: 'invoice',
                child: ListTile(
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text('Invoice PDF'))),
          if (_canDelete(job))
            const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                    leading:
                        Icon(Icons.delete_outline, color: PccColors.danger),
                    title: Text('Delete job'))),
        ],
        child: const Padding(
            padding: EdgeInsets.all(8), child: Icon(Icons.more_vert)),
      );

  Future<void> _showDetails(JobModel job) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final canPrint = widget.session.can('jobs.print_invoice') ||
            _assignedFlag(
              job,
              (assignment) => assignment.canPrintInvoice,
            );

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 820,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.92,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    15,
                    10,
                    15,
                  ),
                  color: PccColors.charcoal,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: PccColors.hazard,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'JOB DETAILS',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              job.invoiceNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDetailPhoto(job),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _plateChip(job.plateNumber),
                            _statusChip(job.status),
                            _priorityChip(job.priority),
                            if (_jobReminderText(job) != null)
                              _jobReminderChip(job),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _detailSectionTitle(
                          icon: Icons.schedule_outlined,
                          title: 'Job Timeline',
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final mobile = constraints.maxWidth < 620;
                            final width = mobile
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 10) / 2;

                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                SizedBox(
                                  width: width,
                                  child: _detailInfoCard(
                                    icon: Icons.play_circle_outline,
                                    label: 'Job Start Time',
                                    value: _formatDateTime(job.startTime),
                                    accent: PccColors.success,
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: _detailInfoCard(
                                    icon: Icons.stop_circle_outlined,
                                    label: 'Expected End Time',
                                    value: _formatDateTime(job.endTime),
                                    accent: PccColors.hazard,
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: _detailInfoCard(
                                    icon: Icons.event_outlined,
                                    label: 'Due Date',
                                    value: _formatDateTime(job.dueDate),
                                    accent: PccColors.steel,
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: _detailInfoCard(
                                    icon: Icons.add_task_outlined,
                                    label: 'Record Created',
                                    value: _formatDateTime(job.createdAt),
                                    accent: const Color(0xFF3768B5),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 22),
                        _detailSectionTitle(
                          icon: Icons.build_outlined,
                          title: 'Work Description',
                        ),
                        const SizedBox(height: 10),
                        _detailTextBox(job.workDescription),
                        const SizedBox(height: 22),
                        _detailSectionTitle(
                          icon: Icons.inventory_2_outlined,
                          title: 'Parts & Materials',
                        ),
                        const SizedBox(height: 10),
                        _buildPartsDetails(job),
                        const SizedBox(height: 22),
                        _detailSectionTitle(
                          icon: Icons.payments_outlined,
                          title: 'Financial Summary',
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF9F6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: PccColors.line,
                            ),
                          ),
                          child: Column(
                            children: [
                              _detailRow(
                                'Materials',
                                money(
                                  job.materialsTotal,
                                  widget.session.workshop.currency,
                                ),
                              ),
                              const Divider(height: 18),
                              _detailRow(
                                'Labour',
                                money(
                                  job.labourCharges,
                                  widget.session.workshop.currency,
                                ),
                              ),
                              const Divider(height: 18),
                              _detailRow(
                                'Grand Total',
                                money(
                                  job.total,
                                  widget.session.workshop.currency,
                                ),
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _detailSectionTitle(
                          icon: Icons.info_outline,
                          title: 'Additional Information',
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final mobile = constraints.maxWidth < 620;
                            final width = mobile
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 10) / 2;

                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                SizedBox(
                                  width: width,
                                  child: _detailInfoCard(
                                    icon: Icons.person_outline,
                                    label: 'Created By',
                                    value: job.createdByName.trim().isEmpty
                                        ? 'Not available'
                                        : job.createdByName,
                                    accent: PccColors.steel,
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: _detailInfoCard(
                                    icon: Icons.flag_outlined,
                                    label: 'Priority',
                                    value: job.priority
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    accent: _priorityColor(job.priority),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _detailTextBox(
                          job.internalNotes.trim().isEmpty
                              ? 'No internal instructions were added.'
                              : job.internalNotes,
                          label: 'INTERNAL INSTRUCTIONS',
                        ),
                        const SizedBox(height: 22),
                        _detailSectionTitle(
                          icon: Icons.groups_outlined,
                          title: 'Assigned Users',
                        ),
                        const SizedBox(height: 10),
                        _buildAssignedUsers(job),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    14,
                    10,
                    14,
                    14,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: PccColors.line,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (canPrint)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _invoicePdf(job),
                            icon: const Icon(
                              Icons.picture_as_pdf_outlined,
                            ),
                            label: const Text('INVOICE PDF'),
                          ),
                        ),
                      if (canPrint) const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: PccColors.hazard,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check),
                          label: const Text('CLOSE'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailPhoto(JobModel job) {
    if (job.photoUrl == null) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: PccColors.line,
          ),
        ),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 54,
              color: PccColors.inkSoft,
            ),
            SizedBox(height: 8),
            Text(
              'No vehicle photo available',
              style: TextStyle(
                color: PccColors.inkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        job.photoUrl!,
        height: 280,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            height: 180,
            color: const Color(0xFFF0F2F3),
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: PccColors.inkSoft,
            ),
          );
        },
      ),
    );
  }

  Widget _detailSectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: PccColors.hazard.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 19,
            color: PccColors.hazardDark,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: PccColors.charcoal,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: PccColors.line,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 20,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: PccColors.inkSoft,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: PccColors.charcoal,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailTextBox(
    String value, {
    String? label,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: PccColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label,
              style: const TextStyle(
                color: PccColors.inkSoft,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 7),
          ],
          Text(
            value,
            style: const TextStyle(
              color: PccColors.charcoal,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartsDetails(JobModel job) {
    if (job.parts.isEmpty) {
      return _detailTextBox(
        'No parts or materials were added to this job.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: PccColors.line,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < job.parts.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EFE9),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: PccColors.inkSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      job.parts[index].name.trim().isEmpty
                          ? 'Unnamed item'
                          : job.parts[index].name,
                      style: const TextStyle(
                        color: PccColors.charcoal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    money(
                      job.parts[index].amount,
                      widget.session.workshop.currency,
                    ),
                    style: const TextStyle(
                      color: PccColors.charcoal,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (index != job.parts.length - 1)
              const Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignedUsers(JobModel job) {
    if (job.assignments.isEmpty) {
      return _detailTextBox(
        'No users are currently assigned to this job.',
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: job.assignments.map((assignment) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF9F6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: PccColors.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 12,
                backgroundColor: PccColors.charcoal,
                child: Icon(
                  Icons.person,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                assignment.userName,
                style: const TextStyle(
                  color: PccColors.charcoal,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool bold = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: bold ? PccColors.charcoal : PccColors.inkSoft,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: bold ? PccColors.hazardDark : PccColors.charcoal,
              fontSize: bold ? 17 : 13,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editDialog(JobModel job) async {
    final plate = TextEditingController(text: job.plateNumber);
    final work = TextEditingController(text: job.workDescription);
    final labour =
        TextEditingController(text: job.labourCharges.toStringAsFixed(2));
    final notes = TextEditingController(text: job.internalNotes);
    final parts =
        job.parts.map((p) => PartItem(name: p.name, amount: p.amount)).toList();
    if (parts.isEmpty) parts.add(PartItem());
    var priority = job.priority;
    DateTime? startTime = job.startTime?.toLocal();
    DateTime? endTime = job.endTime?.toLocal();

    final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: Text('Edit ${job.invoiceNumber}'),
                  content: SizedBox(
                      width: 650,
                      child: SingleChildScrollView(
                          child: Column(children: [
                        TextField(
                            controller: plate,
                            decoration: const InputDecoration(
                                labelText: 'Plate Number')),
                        const SizedBox(height: 12),
                        TextField(
                            controller: work,
                            minLines: 3,
                            maxLines: 6,
                            decoration: const InputDecoration(
                                labelText: 'Work Description')),
                        const SizedBox(height: 12),
                        for (var i = 0; i < parts.length; i++)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(children: [
                                Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                        initialValue: parts[i].name,
                                        decoration: const InputDecoration(
                                            labelText: 'Part name'),
                                        onChanged: (v) => parts[i].name = v)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: TextFormField(
                                        initialValue:
                                            parts[i].amount.toStringAsFixed(2),
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            labelText: 'Amount'),
                                        onChanged: (v) => parts[i].amount =
                                            double.tryParse(v) ?? 0)),
                                IconButton(
                                    onPressed: () => setDialogState(() {
                                          if (parts.length > 1) {
                                            parts.removeAt(i);
                                          }
                                        }),
                                    icon: const Icon(Icons.close,
                                        color: PccColors.danger)),
                              ])),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                                onPressed: () =>
                                    setDialogState(() => parts.add(PartItem())),
                                icon: const Icon(Icons.add),
                                label: const Text('Add part'))),
                        const SizedBox(height: 12),
                        TextField(
                            controller: labour,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Labour Charges')),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                            initialValue: priority,
                            decoration:
                                const InputDecoration(labelText: 'Priority'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'low', child: Text('Low')),
                              DropdownMenuItem(
                                  value: 'normal', child: Text('Normal')),
                              DropdownMenuItem(
                                  value: 'high', child: Text('High')),
                              DropdownMenuItem(
                                  value: 'urgent', child: Text('Urgent'))
                            ],
                            onChanged: (v) =>
                                setDialogState(() => priority = v ?? 'normal')),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final mobile = constraints.maxWidth < 520;

                            final startButton = OutlinedButton.icon(
                              onPressed: () async {
                                final selected = await _pickDateTimeValue(
                                  initialValue: startTime ?? DateTime.now(),
                                  firstAllowedDate: DateTime(2020),
                                );

                                if (selected != null) {
                                  setDialogState(() {
                                    startTime = selected;
                                  });
                                }
                              },
                              icon: const Icon(Icons.play_circle_outline),
                              label: Text(
                                startTime == null
                                    ? 'SET START TIME'
                                    : _formatDateTime(startTime),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );

                            final endButton = OutlinedButton.icon(
                              onPressed: () async {
                                final firstAllowed = startTime == null
                                    ? DateTime(2020)
                                    : DateTime(
                                        startTime!.year,
                                        startTime!.month,
                                        startTime!.day,
                                      );

                                final selected = await _pickDateTimeValue(
                                  initialValue: endTime ??
                                      startTime?.add(const Duration(hours: 1)),
                                  firstAllowedDate: firstAllowed,
                                );

                                if (selected != null) {
                                  setDialogState(() {
                                    endTime = selected;
                                  });
                                }
                              },
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: Text(
                                endTime == null
                                    ? 'SET END TIME'
                                    : _formatDateTime(endTime),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );

                            if (mobile) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  startButton,
                                  const SizedBox(height: 8),
                                  endButton,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: startButton),
                                const SizedBox(width: 8),
                                Expanded(child: endButton),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                            controller: notes,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                                labelText: 'Internal Notes')),
                      ]))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        if ((startTime == null) != (endTime == null)) {
                          showError(
                            dialogContext,
                            'Select both start time and end time.',
                          );
                          return;
                        }

                        if (startTime != null &&
                            endTime != null &&
                            !endTime!.isAfter(startTime!)) {
                          showError(
                            dialogContext,
                            'End time must be after start time.',
                          );
                          return;
                        }

                        Navigator.pop(dialogContext, true);
                      },
                      child: const Text('Save Changes'),
                    ),
                  ],
                )));
    if (saved != true) return;
    try {
      await widget.session.api
          .multipart('jobs/${job.id}/', method: 'PATCH', fields: {
        'plate_number': plate.text.trim().toUpperCase(),
        'work_description': work.text.trim(),
        'labour_charges': labour.text.trim(),
        'priority': priority,
        'internal_notes': notes.text.trim(),
        if (startTime != null)
          'start_time': startTime!.toUtc().toIso8601String(),
        if (endTime != null) 'end_time': endTime!.toUtc().toIso8601String(),
        'parts_json': jsonEncode(parts.map((p) => p.toJson()).toList()),
      });

      try {
        final updatedPlate = plate.text.trim().toUpperCase();

        await JobNotificationService.instance.scheduleJobReminders(
          jobId: job.id,
          invoiceNumber: job.invoiceNumber,
          plateNumber: updatedPlate,
          endTime: endTime,
          status: job.status,
        );

        _reminderState[job.id] = _reminderKey(
          endTime: endTime,
          status: job.status,
          plateNumber: updatedPlate,
        );
      } catch (_) {
        // Job edit remains successful even if a reminder cannot be changed.
      }

      showSuccess(context, 'Job updated.');
      _load();
    } catch (error) {
      showError(context, error);
    }
  }

  Future<void> _assignmentDialog(JobModel job) async {
    try {
      final data =
          await widget.session.api.get('users/', query: {'status': 'active'});
      final users = widget.session.api
          .unwrapList(data)
          .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
          .toList();
      final selected = <int, Map<String, bool>>{};
      for (final user in users) {
        final existing =
            job.assignments.where((a) => a.userId == user.id).firstOrNull;
        if (existing != null) {
          selected[user.id] = {
            'view': existing.canView,
            'photo': existing.canViewPhoto,
            'amounts': existing.canViewAmounts,
            'print': existing.canPrintInvoice,
            'edit': existing.canEdit,
            'parts': existing.canAddParts,
            'status': existing.canChangeStatus,
            'complete': existing.canComplete,
            'delete': existing.canDelete
          };
        }
      }
      final save = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                    title: Text('Assign ${job.invoiceNumber}'),
                    content: SizedBox(
                        width: 760,
                        height: 500,
                        child: ListView.separated(
                            itemCount: users.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final enabled = selected.containsKey(user.id);
                              final flags = selected[user.id] ??
                                  {
                                    'view': true,
                                    'photo': true,
                                    'amounts': true,
                                    'print': false,
                                    'edit': false,
                                    'parts': false,
                                    'status': false,
                                    'complete': false,
                                    'delete': false
                                  };
                              return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        value: enabled,
                                        title: Text(user.fullName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800)),
                                        subtitle:
                                            Text(user.roleName ?? user.email),
                                        onChanged: (value) =>
                                            setDialogState(() {
                                              if (value == true) {
                                                selected[user.id] =
                                                    Map<String, bool>.from(
                                                        flags);
                                              } else {
                                                selected.remove(user.id);
                                              }
                                            })),
                                    if (enabled)
                                      Wrap(spacing: 6, children: [
                                        _permissionChip(
                                            'View',
                                            'view',
                                            flags,
                                            () => setDialogState(() =>
                                                selected[user.id]!['view'] =
                                                    !(flags['view'] ?? false))),
                                        _permissionChip(
                                            'Photo',
                                            'photo',
                                            flags,
                                            () => setDialogState(() =>
                                                selected[user.id]!['photo'] =
                                                    !(flags['photo'] ??
                                                        false))),
                                        _permissionChip(
                                            'Amounts',
                                            'amounts',
                                            flags,
                                            () => setDialogState(() =>
                                                selected[user.id]!['amounts'] =
                                                    !(flags['amounts'] ??
                                                        false))),
                                        _permissionChip(
                                            'Print',
                                            'print',
                                            flags,
                                            () => setDialogState(() =>
                                                selected[user.id]!['print'] =
                                                    !(flags['print'] ??
                                                        false))),
                                        _permissionChip(
                                            'Edit',
                                            'edit',
                                            flags,
                                            () => setDialogState(() =>
                                                selected[user.id]!['edit'] =
                                                    !(flags['edit'] ?? false))),
                                        _permissionChip(
                                            'Parts',
                                            'parts',
                                            flags,
                                            () => setDialogState(() =>
                                                selected[user.id]!['parts'] =
                                                    !(flags['parts'] ??
                                                        false))),
                                        _permissionChip(
                                            'Status',
                                            'status',
                                            flags,
                                            () => setDialogState(() =>
                                                selected[user.id]!['status'] =
                                                    !(flags['status'] ??
                                                        false))),
                                        _permissionChip(
                                            'Complete',
                                            'complete',
                                            flags,
                                            () => setDialogState(() =>
                                                selected[user.id]!['complete'] =
                                                    !(flags['complete'] ??
                                                        false))),
                                        _permissionChip(
                                            'Delete',
                                            'delete',
                                            flags,
                                            () => setDialogState(() =>
                                                selected[user.id]!['delete'] =
                                                    !(flags['delete'] ??
                                                        false))),
                                      ]),
                                  ]);
                            })),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Save Assignments'))
                    ],
                  )));
      if (save != true) return;
      await widget.session.api.post('jobs/${job.id}/assign/', body: {
        'assignments': selected.entries
            .map((entry) => {
                  'user': entry.key,
                  'can_view': entry.value['view'],
                  'can_view_photo': entry.value['photo'],
                  'can_view_amounts': entry.value['amounts'],
                  'can_print_invoice': entry.value['print'],
                  'can_edit': entry.value['edit'],
                  'can_add_parts': entry.value['parts'],
                  'can_change_status': entry.value['status'],
                  'can_complete': entry.value['complete'],
                  'can_delete': entry.value['delete'],
                })
            .toList()
      });
      showSuccess(context, 'Job assignments updated.');
      _load();
    } catch (error) {
      showError(context, error);
    }
  }

  Widget _permissionChip(String label, String key, Map<String, bool> flags,
          VoidCallback onTap) =>
      FilterChip(
          label: Text(label),
          selected: flags[key] ?? false,
          onSelected: (_) => onTap());
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
