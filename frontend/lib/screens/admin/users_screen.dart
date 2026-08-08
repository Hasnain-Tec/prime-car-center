import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class UsersScreen extends StatefulWidget {
  final SessionController session;

  const UsersScreen({
    super.key,
    required this.session,
  });

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<AppUser> users = [];
  List<RoleModel> roles = [];
  List<PermissionModel> permissions = [];

  bool loading = true;
  String filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------------------------------------------------------------------
  // EXISTING LOGIC — UNCHANGED
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    setState(() => loading = true);

    try {
      final results = await Future.wait([
        widget.session.api.get(
          'users/',
          query: {
            'status': filter == 'all' ? null : filter,
          },
        ),
        widget.session.api.get('roles/'),
        widget.session.api.get('permissions/'),
      ]);

      users = widget.session.api
          .unwrapList(results[0])
          .map(
            (e) => AppUser.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList();

      roles = widget.session.api
          .unwrapList(results[1])
          .map(
            (e) => RoleModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList();

      permissions = widget.session.api
          .unwrapList(results[2])
          .map(
            (e) => PermissionModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _approve(AppUser user) async {
    int? roleId = user.roleId ?? (roles.isEmpty ? null : roles.first.id);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    color: PccColors.success,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Approve ${user.fullName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 430,
                child: DropdownButtonFormField<int>(
                  initialValue: roleId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Assign role',
                    prefixIcon: Icon(
                      Icons.admin_panel_settings_outlined,
                    ),
                  ),
                  items: roles
                      .map(
                        (role) => DropdownMenuItem(
                          value: role.id,
                          child: Text(role.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      roleId = value;
                    });
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: roleId == null
                      ? null
                      : () {
                          Navigator.pop(dialogContext, true);
                        },
                  icon: const Icon(
                    Icons.check_circle_outline,
                  ),
                  label: const Text('Approve'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.session.api.post(
        'users/${user.id}/approve/',
        body: {
          'role': roleId,
        },
      );

      if (mounted) {
        showSuccess(
          context,
          'Registration approved.',
        );
      }

      _load();
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _reject(AppUser user) async {
    if (!await confirmAction(
      context,
      'Reject ${user.fullName}\'s registration request?',
    )) {
      return;
    }

    try {
      await widget.session.api.post(
        'users/${user.id}/reject/',
      );

      if (mounted) {
        showSuccess(
          context,
          'Registration rejected.',
        );
      }

      _load();
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _status(
    AppUser user,
    String value,
  ) async {
    try {
      await widget.session.api.post(
        'users/${user.id}/set_status/',
        body: {
          'status': value,
        },
      );

      if (mounted) {
        showSuccess(
          context,
          'User status changed.',
        );
      }

      _load();
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _edit(AppUser user) async {
    final name = TextEditingController(
      text: user.fullName,
    );

    final phone = TextEditingController(
      text: user.phone,
    );

    int? roleId = user.roleId;

    final allowIds = <int>{
      ...user.allowPermissionIds,
    };

    final denyIds = <int>{
      ...user.denyPermissionIds,
    };

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final screenSize = MediaQuery.sizeOf(context);
            final dialogWidth =
                screenSize.width < 820 ? screenSize.width - 32 : 760.0;
            final dialogHeight =
                screenSize.height < 760 ? screenSize.height - 80 : 610.0;

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              titlePadding: const EdgeInsets.fromLTRB(
                22,
                20,
                22,
                10,
              ),
              contentPadding: const EdgeInsets.fromLTRB(
                22,
                8,
                22,
                8,
              ),
              actionsPadding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                14,
              ),
              title: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: PccColors.hazard.withOpacity(.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.manage_accounts_outlined,
                      color: PccColors.hazardDark,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'User Access',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PccColors.inkSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: dialogWidth,
                height: dialogHeight,
                child: ListView(
                  children: [
                    _dialogSectionLabel(
                      icon: Icons.person_outline,
                      title: 'PROFILE & ROLE',
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 560;

                        final nameField = TextField(
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(
                              Icons.badge_outlined,
                            ),
                          ),
                        );

                        final phoneField = TextField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            prefixIcon: Icon(
                              Icons.phone_outlined,
                            ),
                          ),
                        );

                        if (!wide) {
                          return Column(
                            children: [
                              nameField,
                              const SizedBox(height: 10),
                              phoneField,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: nameField,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: phoneField,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: roleId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        prefixIcon: Icon(
                          Icons.admin_panel_settings_outlined,
                        ),
                      ),
                      items: roles
                          .map(
                            (role) => DropdownMenuItem(
                              value: role.id,
                              child: Text(role.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          roleId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 22),
                    _dialogSectionLabel(
                      icon: Icons.security_outlined,
                      title: 'INDIVIDUAL PERMISSION OVERRIDES',
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Allow grants access beyond the role. Deny removes access even when the role grants it.',
                      style: TextStyle(
                        color: PccColors.inkSoft,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final module
                        in permissions.map((e) => e.module).toSet())
                      Container(
                        margin: const EdgeInsets.only(
                          bottom: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF9F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: PccColors.line,
                          ),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            14,
                            0,
                            14,
                            12,
                          ),
                          title: Text(
                            module.toUpperCase(),
                            style: const TextStyle(
                              color: PccColors.charcoal,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .5,
                            ),
                          ),
                          children: permissions
                              .where(
                                (p) => p.module == module,
                              )
                              .map(
                                (p) => Container(
                                  margin: const EdgeInsets.only(
                                    top: 7,
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: PccColors.line,
                                    ),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (
                                      context,
                                      constraints,
                                    ) {
                                      final compact =
                                          constraints.maxWidth < 470;

                                      final permissionName = Text(
                                        p.name,
                                        style: const TextStyle(
                                          color: PccColors.charcoal,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      );

                                      final chips = Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          FilterChip(
                                            label: const Text(
                                              'ALLOW',
                                            ),
                                            selected: allowIds.contains(
                                              p.id,
                                            ),
                                            selectedColor: PccColors.success
                                                .withOpacity(.14),
                                            onSelected: (value) {
                                              setDialogState(() {
                                                if (value) {
                                                  allowIds.add(p.id);
                                                  denyIds.remove(p.id);
                                                } else {
                                                  allowIds.remove(p.id);
                                                }
                                              });
                                            },
                                          ),
                                          FilterChip(
                                            label: const Text(
                                              'DENY',
                                            ),
                                            selected: denyIds.contains(
                                              p.id,
                                            ),
                                            selectedColor: PccColors.danger
                                                .withOpacity(.15),
                                            onSelected: (value) {
                                              setDialogState(() {
                                                if (value) {
                                                  denyIds.add(p.id);
                                                  allowIds.remove(p.id);
                                                } else {
                                                  denyIds.remove(p.id);
                                                }
                                              });
                                            },
                                          ),
                                        ],
                                      );

                                      if (compact) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            permissionName,
                                            const SizedBox(height: 8),
                                            chips,
                                          ],
                                        );
                                      }

                                      return Row(
                                        children: [
                                          Expanded(
                                            child: permissionName,
                                          ),
                                          const SizedBox(width: 12),
                                          chips,
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      false,
                    );
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      true,
                    );
                  },
                  icon: const Icon(
                    Icons.save_outlined,
                  ),
                  label: const Text('Save Access'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      return;
    }

    try {
      await widget.session.api.patch(
        'users/${user.id}/',
        body: {
          'full_name': name.text.trim(),
          'phone': phone.text.trim(),
          'role': roleId,
          'allow_permission_ids': allowIds.toList(),
          'deny_permission_ids': denyIds.toList(),
        },
      );

      if (mounted) {
        showSuccess(
          context,
          'User access updated.',
        );
      }

      _load();
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _addUser() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final password = TextEditingController();

    int? roleId = roles.isEmpty ? null : roles.first.id;
    String statusValue = 'active';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.person_add_alt_1_outlined,
                    color: PccColors.hazard,
                  ),
                  SizedBox(width: 10),
                  Text('Add User'),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(
                            Icons.badge_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: Icon(
                            Icons.phone_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Temporary password',
                          prefixIcon: Icon(
                            Icons.password_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        initialValue: roleId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          prefixIcon: Icon(
                            Icons.admin_panel_settings_outlined,
                          ),
                        ),
                        items: roles
                            .map(
                              (role) => DropdownMenuItem(
                                value: role.id,
                                child: Text(role.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            roleId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: statusValue,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Account status',
                          prefixIcon: Icon(
                            Icons.manage_accounts_outlined,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pending approval'),
                          ),
                          DropdownMenuItem(
                            value: 'disabled',
                            child: Text('Disabled'),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            statusValue = value ?? 'active';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      false,
                    );
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      true,
                    );
                  },
                  icon: const Icon(
                    Icons.person_add_alt_1,
                  ),
                  label: const Text('Create User'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      return;
    }

    if (name.text.trim().isEmpty ||
        !email.text.contains('@') ||
        password.text.length < 8) {
      if (mounted) {
        showError(
          context,
          'Enter a valid name, email, and password of at least 8 characters.',
        );
      }
      return;
    }

    try {
      await widget.session.api.post(
        'users/',
        body: {
          'full_name': name.text.trim(),
          'email': email.text.trim(),
          'phone': phone.text.trim(),
          'password': password.text,
          'role': roleId,
          'status': statusValue,
        },
      );

      if (mounted) {
        showSuccess(
          context,
          'User created.',
        );
      }

      _load();
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _resetPassword(AppUser user) async {
    final password = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Row(
            children: [
              const Icon(
                Icons.password_outlined,
                color: PccColors.hazard,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Reset Password — ${user.fullName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 430,
            child: TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New temporary password',
                prefixIcon: Icon(
                  Icons.lock_reset_outlined,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(
                Icons.lock_reset,
              ),
              label: const Text('Reset Password'),
            ),
          ],
        );
      },
    );

    if (saved != true) {
      return;
    }

    if (password.text.length < 8) {
      if (mounted) {
        showError(
          context,
          'Password must contain at least 8 characters.',
        );
      }
      return;
    }

    try {
      await widget.session.api.post(
        'users/${user.id}/reset_password/',
        body: {
          'password': password.text,
        },
      );

      if (mounted) {
        showSuccess(
          context,
          'Password reset successfully.',
        );
      }
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    if (user.id == widget.session.user!.id) {
      if (mounted) {
        showError(
          context,
          'You cannot delete your own account.',
        );
      }
      return;
    }

    if (!await confirmAction(
      context,
      'Remove ${user.fullName} from the system? Existing workshop records will remain.',
    )) {
      return;
    }

    try {
      await widget.session.api.delete(
        'users/${user.id}/',
      );

      if (mounted) {
        showSuccess(
          context,
          'User removed.',
        );
      }

      _load();
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // DESIGN HELPERS
  // ---------------------------------------------------------------------------

  Widget _dialogSectionLabel({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: PccColors.hazardDark,
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: PccColors.charcoal,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      ],
    );
  }

  Widget _pageHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PccColors.charcoal,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(
            color: PccColors.hazard,
            width: 5,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;

          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'USER MANAGEMENT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Manage registrations, roles, permissions, account status and access from one place.',
                style: TextStyle(
                  color: Colors.white.withOpacity(.72),
                  fontSize: 11.5,
                  height: 1.45,
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
              color: PccColors.hazard.withOpacity(.12),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: PccColors.hazard.withOpacity(.45),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.group_outlined,
                  color: PccColors.hazard,
                  size: 17,
                ),
                SizedBox(width: 6),
                Text(
                  'ACCESS CONTROL',
                  style: TextStyle(
                    color: PccColors.hazard,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 14),
                badge,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 18),
              badge,
            ],
          );
        },
      ),
    );
  }

  Widget _filterPanel() {
    const filterItems = [
      ('all', 'All Users'),
      ('pending', 'Pending'),
      ('active', 'Active'),
      ('suspended', 'Suspended'),
      ('rejected', 'Rejected'),
      ('disabled', 'Disabled'),
    ];

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: PccColors.line,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;

          final filters = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in filterItems)
                ChoiceChip(
                  label: Text(item.$2),
                  selected: filter == item.$1,
                  onSelected: (_) {
                    setState(() {
                      filter = item.$1;
                    });
                    _load();
                  },
                ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: loading ? null : _load,
                icon: const Icon(
                  Icons.refresh,
                ),
                label: const Text(
                  'REFRESH',
                ),
              ),
              if (widget.session.can('users.manage'))
                FilledButton.icon(
                  onPressed: _addUser,
                  icon: const Icon(
                    Icons.person_add_alt_1,
                  ),
                  label: const Text(
                    'ADD USER',
                  ),
                ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'FILTER USERS',
                  style: TextStyle(
                    color: PccColors.inkSoft,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 10),
                filters,
                const SizedBox(height: 14),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: filters,
              ),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _statusBadge(
    String status, {
    bool compact = false,
  }) {
    final color = _statusColor(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: color.withOpacity(.45),
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w900,
          letterSpacing: .45,
        ),
      ),
    );
  }

  Widget _avatar(
    AppUser user, {
    double radius = 22,
  }) {
    final color = _statusColor(user.status);

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withOpacity(.13),
      child: Text(
        user.fullName.isEmpty ? '?' : user.fullName[0].toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: radius * .72,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  PopupMenuButton<String> _actionsMenu(
    AppUser user, {
    bool compact = false,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'User actions',
      icon: Icon(
        Icons.more_vert,
        size: compact ? 21 : 23,
      ),
      onSelected: (value) {
        if (value == 'edit') {
          _edit(user);
        } else if (value == 'reset') {
          _resetPassword(user);
        } else if (value == 'delete') {
          _deleteUser(user);
        } else {
          _status(
            user,
            value,
          );
        }
      },
      itemBuilder: (_) {
        return [
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(
                  Icons.manage_accounts_outlined,
                  size: 19,
                ),
                SizedBox(width: 9),
                Text(
                  'Edit role & permissions',
                ),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'reset',
            child: Row(
              children: [
                Icon(
                  Icons.lock_reset_outlined,
                  size: 19,
                ),
                SizedBox(width: 9),
                Text(
                  'Reset password',
                ),
              ],
            ),
          ),
          if (user.status != 'active')
            const PopupMenuItem(
              value: 'active',
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: PccColors.success,
                    size: 19,
                  ),
                  SizedBox(width: 9),
                  Text('Activate'),
                ],
              ),
            ),
          if (user.status != 'suspended')
            const PopupMenuItem(
              value: 'suspended',
              child: Row(
                children: [
                  Icon(
                    Icons.pause_circle_outline,
                    color: PccColors.steel,
                    size: 19,
                  ),
                  SizedBox(width: 9),
                  Text('Suspend'),
                ],
              ),
            ),
          if (user.status != 'disabled')
            const PopupMenuItem(
              value: 'disabled',
              child: Row(
                children: [
                  Icon(
                    Icons.block_outlined,
                    color: PccColors.danger,
                    size: 19,
                  ),
                  SizedBox(width: 9),
                  Text('Disable'),
                ],
              ),
            ),
          if (user.id != widget.session.user!.id)
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.person_remove_alt_1_outlined,
                    color: PccColors.danger,
                    size: 19,
                  ),
                  SizedBox(width: 9),
                  Text('Remove user'),
                ],
              ),
            ),
        ];
      },
    );
  }

  Widget _desktopUsersTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        horizontalMargin: 16,
        columnSpacing: 28,
        headingRowHeight: 48,
        dataRowMinHeight: 66,
        dataRowMaxHeight: 76,
        headingRowColor: WidgetStateProperty.all(
          const Color(0xFFF5F3EE),
        ),
        columns: const [
          DataColumn(
            label: Text('USER'),
          ),
          DataColumn(
            label: Text('CONTACT'),
          ),
          DataColumn(
            label: Text('ROLE'),
          ),
          DataColumn(
            label: Text('REGISTERED'),
          ),
          DataColumn(
            label: Text('STATUS'),
          ),
          DataColumn(
            label: Text('ACTIONS'),
          ),
        ],
        rows: users.map(
          (user) {
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      _avatar(
                        user,
                        radius: 19,
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 165,
                        child: Text(
                          user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PccColors.charcoal,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 195,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PccColors.charcoal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (user.phone.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            user.phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PccColors.inkSoft,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 130,
                    child: Text(
                      user.roleName ?? 'No role',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _date(user.createdAt),
                  ),
                ),
                DataCell(
                  _statusBadge(
                    user.status,
                    compact: true,
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (user.status == 'pending' &&
                          widget.session.can('users.approve'))
                        IconButton(
                          tooltip: 'Approve',
                          onPressed: () {
                            _approve(user);
                          },
                          icon: const Icon(
                            Icons.check_circle_outline,
                            color: PccColors.success,
                          ),
                        ),
                      if (user.status == 'pending' &&
                          widget.session.can('users.approve'))
                        IconButton(
                          tooltip: 'Reject',
                          onPressed: () {
                            _reject(user);
                          },
                          icon: const Icon(
                            Icons.cancel_outlined,
                            color: PccColors.danger,
                          ),
                        ),
                      if (widget.session.can('users.manage'))
                        _actionsMenu(
                          user,
                          compact: true,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ).toList(),
      ),
    );
  }

  Widget _mobileUserCard(AppUser user) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: PccColors.line,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: _statusColor(
                user.status,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _avatar(
                      user,
                      radius: 24,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PccColors.charcoal,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PccColors.inkSoft,
                              fontSize: 11,
                            ),
                          ),
                          if (user.phone.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              user.phone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: PccColors.inkSoft,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.session.can('users.manage'))
                      _actionsMenu(
                        user,
                        compact: true,
                      ),
                  ],
                ),
                const SizedBox(height: 13),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF9F6),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: PccColors.line,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _miniInfo(
                          label: 'ROLE',
                          value: user.roleName ?? 'No role',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: PccColors.line,
                      ),
                      Expanded(
                        child: _miniInfo(
                          label: 'REGISTERED',
                          value: _date(
                            user.createdAt,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    _statusBadge(
                      user.status,
                      compact: true,
                    ),
                    const Spacer(),
                    if (user.status == 'pending' &&
                        widget.session.can('users.approve')) ...[
                      IconButton(
                        tooltip: 'Approve',
                        onPressed: () {
                          _approve(user);
                        },
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: PccColors.success,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Reject',
                        onPressed: () {
                          _reject(user);
                        },
                        icon: const Icon(
                          Icons.cancel_outlined,
                          color: PccColors.danger,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniInfo({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: PccColors.inkSoft,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .55,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PccColors.charcoal,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _usersPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: PccColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              15,
              16,
              13,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: PccColors.hazard.withOpacity(.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.people_alt_outlined,
                    color: PccColors.hazardDark,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registered Users',
                        style: TextStyle(
                          color: PccColors.charcoal,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Review user accounts and manage access.',
                        style: TextStyle(
                          color: PccColors.inkSoft,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!loading)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F3EF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${users.length} USER${users.length == 1 ? '' : 'S'}',
                      style: const TextStyle(
                        color: PccColors.charcoal,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            color: PccColors.line,
          ),
          if (loading)
            const SizedBox(
              height: 300,
              child: LoadingView(),
            )
          else if (users.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 48,
                horizontal: 24,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.person_search_outlined,
                    color: PccColors.inkSoft,
                    size: 44,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No users in this category.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: PccColors.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 930) {
                  return _desktopUsersTable();
                }

                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: users
                        .map(
                          _mobileUserCard,
                        )
                        .toList(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final pagePadding = screenWidth < 600
        ? 12.0
        : screenWidth < 1000
            ? 18.0
            : 24.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        pagePadding,
        16,
        pagePadding,
        32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1260,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _pageHeader(),
                const SizedBox(height: 14),
                _filterPanel(),
                const SizedBox(height: 14),
                _usersPanel(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _date(String? value) {
    final d = DateTime.tryParse(
      value ?? '',
    );

    return d == null
        ? '—'
        : DateFormat(
            'dd MMM yyyy',
          ).format(
            d.toLocal(),
          );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'active' => PccColors.success,
      'pending' => PccColors.hazard,
      'suspended' => PccColors.steel,
      _ => PccColors.danger,
    };
  }
}

extension _RoleFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
