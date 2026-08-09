import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../core/session.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class NewJobScreen extends StatefulWidget {
  final SessionController session;

  const NewJobScreen({
    super.key,
    required this.session,
  });

  @override
  State<NewJobScreen> createState() => _NewJobScreenState();
}

class _PartControllers {
  final name = TextEditingController();
  final amount = TextEditingController(text: '0');

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _NewJobScreenState extends State<NewJobScreen> {
  final _formKey = GlobalKey<FormState>();

  final _plate = TextEditingController();
  final _work = TextEditingController();
  final _labour = TextEditingController(text: '0');
  final _notes = TextEditingController();

  final _picker = ImagePicker();

  final List<_PartControllers> _parts = [
    _PartControllers(),
  ];

  Uint8List? _photo;
  String? _photoName;

  bool _skipPhoto = false;
  bool _busy = false;
  bool _photoBusy = false;

  String _priority = 'normal';
  DateTime? _dueDate;
  DateTime? _startTime;
  DateTime? _endTime;

  List<AppUser> _users = [];
  final Set<int> _assignedUsers = {};

  @override
  void initState() {
    super.initState();

    if (widget.session.can('jobs.assign')) {
      _loadUsers();
    }
  }

  @override
  void dispose() {
    _plate.dispose();
    _work.dispose();
    _labour.dispose();
    _notes.dispose();

    for (final part in _parts) {
      part.dispose();
    }

    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final data = await widget.session.api.get(
        'users/',
        query: {
          'status': 'active',
        },
      );

      final users = widget.session.api
          .unwrapList(data)
          .map(
            (item) => AppUser.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();

      if (mounted) {
        setState(() {
          _users = users;
        });
      }
    } catch (_) {
      // User assignment is optional.
    }
  }

  double get materialsTotal {
    return _parts.fold(
      0,
      (sum, row) {
        return sum + (double.tryParse(row.amount.text) ?? 0);
      },
    );
  }

  double get total {
    return materialsTotal + (double.tryParse(_labour.text) ?? 0);
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy || _photoBusy) {
      return;
    }

    setState(() {
      _photoBusy = true;
    });

    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
      );

      if (file == null) {
        return;
      }

      final capturedAt = DateTime.now();

      final bytes = await file.readAsBytes();
      final stampedPhoto = await _stampPhoto(
        bytes,
        capturedAt,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _photo = stampedPhoto;
        _photoName = '${file.name.split('.').first}-timestamped.png';
        _skipPhoto = false;
        _startTime = capturedAt;
      });
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _photoBusy = false;
        });
      }
    }
  }

  Future<Uint8List> _stampPhoto(
    Uint8List bytes,
    DateTime capturedAt,
  ) async {
    const maxPhotoBytes = 300 * 1024;

    const targetWidths = <int>[
      1000,
      900,
      800,
      700,
      600,
      520,
      440,
      360,
      300,
      240,
      180,
    ];

    Uint8List? lastResult;

    for (final targetWidth in targetWidths) {
      final result = await _renderStampedPhoto(
        bytes,
        capturedAt,
        targetWidth,
      );

      lastResult = result;

      if (result.lengthInBytes <= maxPhotoBytes) {
        return result;
      }
    }

    return lastResult!;
  }

  Future<Uint8List> _renderStampedPhoto(
    Uint8List bytes,
    DateTime capturedAt,
    int targetWidth,
  ) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
      allowUpscaling: false,
    );

    final frame = await codec.getNextFrame();
    final source = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(
      source,
      Offset.zero,
      Paint(),
    );

    final stamp =
        'PCC WORKSHOP · ${DateFormat('dd-MM-yyyy HH:mm:ss').format(capturedAt)}';

    final fontSize = (source.width * 0.026).clamp(16.0, 34.0).toDouble();

    final painter = TextPainter(
      text: TextSpan(
        text: stamp,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(
        maxWidth: source.width * 0.88,
      );

    final padding = fontSize * 0.65;
    final left = source.width * 0.025;

    final top =
        source.height - painter.height - padding * 2 - source.height * 0.025;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left,
          top,
          painter.width + padding * 2,
          painter.height + padding * 2,
        ),
        Radius.circular(fontSize * 0.2),
      ),
      Paint()..color = const Color(0xAA000000),
    );

    canvas.drawRect(
      Rect.fromLTWH(
        left,
        top,
        5,
        painter.height + padding * 2,
      ),
      Paint()..color = PccColors.hazard,
    );

    painter.paint(
      canvas,
      Offset(
        left + padding,
        top + padding,
      ),
    );

    final output = await recorder.endRecording().toImage(
          source.width,
          source.height,
        );

    final data = await output.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return data!.buffer.asUint8List();
  }

  void _removePhoto() {
    setState(() {
      _photo = null;
      _photoName = null;
    });
  }

  void _addPart() {
    setState(() {
      _parts.add(_PartControllers());
    });
  }

  void _removePart(int index) {
    if (_parts.length == 1) {
      _parts.first.name.clear();
      _parts.first.amount.text = '0';

      setState(() {});
      return;
    }

    final removed = _parts.removeAt(index);
    removed.dispose();

    setState(() {});
  }

  Future<void> _selectDueDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 730),
      ),
    );

    if (selectedDate != null) {
      setState(() {
        _dueDate = selectedDate;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final now = DateTime.now();
    final initialValue =
        _endTime ?? _startTime?.add(const Duration(hours: 1)) ?? now;
    final firstAllowedDate = _startTime ?? now;
    final firstDate = DateTime(
      firstAllowedDate.year,
      firstAllowedDate.month,
      firstAllowedDate.day,
    );

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialValue.isBefore(firstDate) ? firstDate : initialValue,
      firstDate: firstDate,
      lastDate: firstDate.add(
        const Duration(days: 730),
      ),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    final selectedClockTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialValue),
    );

    if (selectedClockTime == null || !mounted) {
      return;
    }

    setState(() {
      _endTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedClockTime.hour,
        selectedClockTime.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startTime != null &&
        _endTime != null &&
        !_endTime!.isAfter(_startTime!)) {
      showError(
        context,
        'The expected end time must be after the job start time.',
      );
      return;
    }

    if (widget.session.workshop.requireVehiclePhoto &&
        _photo == null &&
        !_skipPhoto) {
      showError(
        context,
        'A vehicle photo is required by workshop settings.',
      );
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final parts = _parts
          .map(
            (row) => {
              'name': row.name.text.trim(),
              'amount': double.tryParse(row.amount.text) ?? 0,
            },
          )
          .where(
            (row) =>
                row['name'].toString().isNotEmpty ||
                (row['amount'] as double) > 0,
          )
          .toList();

      final response = await widget.session.api.multipart(
        'jobs/',
        method: 'POST',
        fields: {
          'plate_number': _plate.text.trim().toUpperCase(),
          'work_description': _work.text.trim(),
          'labour_charges':
              (double.tryParse(_labour.text) ?? 0).toStringAsFixed(2),
          'priority': _priority,
          'internal_notes': _notes.text.trim(),
          if (_dueDate != null) 'due_date': _dueDate!.toIso8601String(),
          if (_startTime != null)
            'start_time': _startTime!.toUtc().toIso8601String(),
          if (_endTime != null) 'end_time': _endTime!.toUtc().toIso8601String(),
          'parts_json': jsonEncode(parts),
        },
        fileBytes: _skipPhoto ? null : _photo,
        filename: _photoName,
      ) as Map<String, dynamic>;

      final job = JobModel.fromJson(response);

      if (_assignedUsers.isNotEmpty && widget.session.can('jobs.assign')) {
        await widget.session.api.post(
          'jobs/${job.id}/assign/',
          body: {
            'assignments': _assignedUsers
                .map(
                  (userId) => {
                    'user': userId,
                    'can_view': true,
                    'can_view_photo': true,
                    'can_view_amounts': true,
                    'can_print_invoice': true,
                    'can_edit': true,
                    'can_add_parts': true,
                    'can_change_status': true,
                    'can_complete': true,
                    'can_delete': false,
                  },
                )
                .toList(),
          },
        );
      }

      if (!mounted) {
        return;
      }

      showSuccess(
        context,
        'Job saved as ${job.invoiceNumber}.',
      );

      _clear();
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _clear() {
    _plate.clear();
    _work.clear();
    _labour.text = '0';
    _notes.clear();

    for (final row in _parts) {
      row.dispose();
    }

    _parts
      ..clear()
      ..add(_PartControllers());

    setState(() {
      _photo = null;
      _photoName = null;
      _skipPhoto = false;
      _photoBusy = false;
      _priority = 'normal';
      _dueDate = null;
      _startTime = null;
      _endTime = null;
      _assignedUsers.clear();
    });
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      color: const Color(0xFFF0F2F3),
      alignment: Alignment.center,
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_car_outlined,
              color: PccColors.hazard,
              size: 52,
            ),
            SizedBox(height: 12),
            Text(
              'No vehicle photo selected',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PccColors.charcoal,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Use the camera or gallery to add a photo.',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: PccColors.inkSoft,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 600;

        return AspectRatio(
          aspectRatio: mobile ? 4 / 3 : 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_photo == null)
                  _buildPhotoPlaceholder()
                else
                  Image.memory(
                    _photo!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                if (_photoBusy)
                  Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.white,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Preparing photo...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_photo != null && !_photoBusy)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xDD2F9E44),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 15,
                            color: Colors.white,
                          ),
                          SizedBox(height: 0, width: 5),
                          Text(
                            'PHOTO READY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoButtons() {
    final galleryAllowed = widget.session.workshop.allowGalleryUpload;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 560;

        final cameraButton = FilledButton.icon(
          onPressed:
              _busy || _photoBusy ? null : () => _pick(ImageSource.camera),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: PccColors.hazard,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(
            Icons.camera_alt_outlined,
          ),
          label: Text(
            _photo == null ? 'CAPTURE PHOTO' : 'RETAKE WITH CAMERA',
          ),
        );

        final galleryButton = OutlinedButton.icon(
          onPressed:
              _busy || _photoBusy ? null : () => _pick(ImageSource.gallery),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(
            Icons.photo_library_outlined,
          ),
          label: const Text(
            'GALLERY',
          ),
        );

        final removeButton = OutlinedButton.icon(
          onPressed: _busy || _photoBusy ? null : _removePhoto,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: PccColors.danger,
          ),
          icon: const Icon(
            Icons.delete_outline,
          ),
          label: const Text(
            'REMOVE',
          ),
        );

        if (mobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cameraButton,
              if (galleryAllowed || _photo != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (galleryAllowed)
                      Expanded(
                        child: galleryButton,
                      ),
                    if (galleryAllowed && _photo != null)
                      const SizedBox(width: 10),
                    if (_photo != null)
                      Expanded(
                        child: removeButton,
                      ),
                  ],
                ),
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              flex: 2,
              child: cameraButton,
            ),
            if (galleryAllowed) ...[
              const SizedBox(width: 10),
              Expanded(
                child: galleryButton,
              ),
            ],
            if (_photo != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: removeButton,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPhotoPanel() {
    return PccPanel(
      title: 'Vehicle Check-in Photo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: PccColors.line,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildPhotoPreview(),
          ),
          const SizedBox(height: 14),
          _buildPhotoButtons(),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: PccColors.line,
              ),
            ),
            child: CheckboxListTile(
              value: _skipPhoto,
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                widget.session.workshop.requireVehiclePhoto
                    ? 'Vehicle photo is required by workshop settings'
                    : 'No camera available — skip photo for this entry',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
              onChanged: widget.session.workshop.requireVehiclePhoto
                  ? null
                  : (value) {
                      setState(() {
                        _skipPhoto = value ?? false;

                        if (_skipPhoto) {
                          _photo = null;
                          _photoName = null;
                        }
                      });
                    },
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The system automatically adds the workshop date and time to the selected photo.',
            style: TextStyle(
              color: PccColors.inkSoft,
              fontSize: 10.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartRow(int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 520;

        final nameField = TextFormField(
          controller: _parts[index].name,
          decoration: const InputDecoration(
            hintText: 'Part / material name',
          ),
          onChanged: (_) {
            setState(() {});
          },
        );

        final amountField = TextFormField(
          controller: _parts[index].amount,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: const InputDecoration(
            hintText: 'Cost',
          ),
          onChanged: (_) {
            setState(() {});
          },
          validator: (value) {
            final number = double.tryParse(value ?? '');

            if (number != null && number < 0) {
              return 'Invalid';
            }

            return null;
          },
        );

        final deleteButton = IconButton(
          tooltip: 'Remove part',
          onPressed: () => _removePart(index),
          color: PccColors.danger,
          icon: const Icon(
            Icons.close,
          ),
        );

        if (mobile) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: PccColors.line,
              ),
            ),
            child: Column(
              children: [
                nameField,
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: amountField,
                    ),
                    const SizedBox(width: 5),
                    deleteButton,
                  ],
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: nameField,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: amountField,
              ),
              deleteButton,
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriorityAndDueDate() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 520;

        final priorityField = DropdownButtonFormField<String>(
          key: ValueKey(_priority),
          initialValue: _priority,
          decoration: const InputDecoration(
            labelText: 'Priority',
          ),
          items: const [
            DropdownMenuItem(
              value: 'low',
              child: Text('Low'),
            ),
            DropdownMenuItem(
              value: 'normal',
              child: Text('Normal'),
            ),
            DropdownMenuItem(
              value: 'high',
              child: Text('High'),
            ),
            DropdownMenuItem(
              value: 'urgent',
              child: Text('Urgent'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _priority = value ?? 'normal';
            });
          },
        );

        final dueDateButton = OutlinedButton.icon(
          onPressed: _selectDueDate,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
          icon: const Icon(
            Icons.event_outlined,
          ),
          label: Text(
            _dueDate == null
                ? 'DUE DATE'
                : DateFormat('dd MMM yyyy').format(_dueDate!),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );

        if (mobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              priorityField,
              const SizedBox(height: 10),
              dueDateButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: priorityField,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: dueDateButton,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStartAndEndTime() {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _selectEndTime,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
      ),
      icon: const Icon(
        Icons.stop_circle_outlined,
      ),
      label: Text(
        _endTime == null
            ? 'EXPECTED END TIME (OPTIONAL)'
            : DateFormat('dd MMM yyyy, hh:mm a').format(_endTime!),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSaveButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 480;

        final saveButton = FilledButton.icon(
          onPressed: _busy ? null : _save,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: PccColors.hazard,
            foregroundColor: Colors.white,
          ),
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.save_outlined,
                ),
          label: Text(
            _busy ? 'SAVING...' : 'SAVE ENTRY',
          ),
        );

        final clearButton = OutlinedButton.icon(
          onPressed: _busy ? null : _clear,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
          icon: const Icon(
            Icons.clear,
          ),
          label: const Text(
            'CLEAR',
          ),
        );

        if (mobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              saveButton,
              const SizedBox(height: 10),
              clearButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              flex: 2,
              child: saveButton,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: clearButton,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailsPanel() {
    return PccPanel(
      title: 'Job Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _plate,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Plate Number',
              hintText: 'e.g. DXB A 12345',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Plate number is required.';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _work,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Work Description',
              hintText: 'Describe the workshop job',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Work description is required.';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'PARTS & MATERIALS USED',
            style: TextStyle(
              fontSize: 12,
              color: PccColors.inkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F6),
              border: Border.all(
                color: PccColors.line,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                for (var index = 0; index < _parts.length; index++)
                  _buildPartRow(index),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _addPart,
                    icon: const Icon(
                      Icons.add,
                    ),
                    label: const Text(
                      'ADD PART / MATERIAL',
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Materials Subtotal',
                    ),
                    Flexible(
                      child: Text(
                        money(
                          materialsTotal,
                          widget.session.workshop.currency,
                        ),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _labour,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: 'Labour Charges (${widget.session.workshop.currency})',
            ),
            onChanged: (_) {
              setState(() {});
            },
            validator: (value) {
              final number = double.tryParse(value ?? '');

              if (number == null || number < 0) {
                return 'Enter a valid amount.';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildPriorityAndDueDate(),
          const SizedBox(height: 14),
          _buildStartAndEndTime(),
          const SizedBox(height: 14),
          TextFormField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Internal Instructions (optional)',
            ),
          ),
          if (widget.session.can('jobs.assign') && _users.isNotEmpty) ...[
            const SizedBox(height: 15),
            const Text(
              'ASSIGN USERS',
              style: TextStyle(
                fontSize: 12,
                color: PccColors.inkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _users.map((user) {
                return FilterChip(
                  label: Text(
                    user.fullName,
                  ),
                  selected: _assignedUsers.contains(user.id),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _assignedUsers.add(user.id);
                      } else {
                        _assignedUsers.remove(user.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 14,
            ),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: PccColors.line,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
                      fontSize: 21,
                      color: PccColors.hazardDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSaveButtons(),
        ],
      ),
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

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        pagePadding,
        16,
        pagePadding,
        30,
      ),
      child: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildPhotoPanel(),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildDetailsPanel(),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _buildPhotoPanel(),
                const SizedBox(height: 14),
                _buildDetailsPanel(),
              ],
            );
          },
        ),
      ),
    );
  }
}
