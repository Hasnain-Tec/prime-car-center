import 'package:flutter/material.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class RolesScreen extends StatefulWidget {
  final SessionController session;
  const RolesScreen({super.key, required this.session});
  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  List<RoleModel> roles = [];
  List<PermissionModel> permissions = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final results = await Future.wait([
        widget.session.api.get('roles/'),
        widget.session.api.get('permissions/')
      ]);
      roles = widget.session.api
          .unwrapList(results[0])
          .map((e) => RoleModel.fromJson(e as Map<String, dynamic>))
          .toList();
      permissions = widget.session.api
          .unwrapList(results[1])
          .map((e) => PermissionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _edit([RoleModel? role]) async {
    if (!widget.session.can('roles.manage')) return;
    final name = TextEditingController(text: role?.name ?? '');
    final description = TextEditingController(text: role?.description ?? '');
    final selected = <int>{...?role?.permissionIds};
    final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title:
                      Text(role == null ? 'Create Role' : 'Edit ${role.name}'),
                  content: SizedBox(
                      width: 730,
                      height: 610,
                      child: ListView(children: [
                        TextField(
                            controller: name,
                            decoration:
                                const InputDecoration(labelText: 'Role name')),
                        const SizedBox(height: 10),
                        TextField(
                            controller: description,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                                labelText: 'Description')),
                        const SizedBox(height: 15),
                        for (final module
                            in permissions.map((p) => p.module).toSet())
                          ExpansionTile(
                            initiallyExpanded: true,
                            title: Text(module.toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            children: permissions
                                .where((p) => p.module == module)
                                .map((p) => CheckboxListTile(
                                    value: selected.contains(p.id),
                                    title: Text(p.name),
                                    subtitle: Text(p.code,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: PccColors.inkSoft)),
                                    onChanged: (value) => setDialogState(() {
                                          if (value == true) {
                                            selected.add(p.id);
                                          } else {
                                            selected.remove(p.id);
                                          }
                                        })))
                                .toList(),
                          ),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Save Role'))
                  ],
                )));
    if (save != true || name.text.trim().isEmpty) return;
    try {
      final body = {
        'name': name.text.trim(),
        'description': description.text.trim(),
        'permission_ids': selected.toList()
      };
      if (role == null) {
        await widget.session.api.post('roles/', body: body);
      } else {
        await widget.session.api.patch('roles/${role.id}/', body: body);
      }
      showSuccess(context, 'Role saved.');
      _load();
    } catch (error) {
      showError(context, error);
    }
  }

  Future<void> _delete(RoleModel role) async {
    if (role.isSystem ||
        !await confirmAction(context, 'Delete the ${role.name} role?')) return;
    try {
      await widget.session.api.delete('roles/${role.id}/');
      showSuccess(context, 'Role deleted.');
      _load();
    } catch (error) {
      showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        PccPanel(
            title: 'Roles & Permissions',
            child: Row(children: [
              const Expanded(
                  child: Text(
                      'Create roles and choose every function that the role can access.',
                      style: TextStyle(color: PccColors.inkSoft))),
              if (widget.session.can('roles.manage'))
                FilledButton.icon(
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('NEW ROLE')),
            ])),
        const SizedBox(height: 16),
        if (loading)
          const SizedBox(height: 300, child: LoadingView())
        else
          LayoutBuilder(builder: (context, constraints) {
            final count = constraints.maxWidth >= 1000
                ? 3
                : constraints.maxWidth >= 650
                    ? 2
                    : 1;
            return GridView.count(
                crossAxisCount: count,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: roles
                    .map((role) => Card(
                        child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(role.name,
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900))),
                                    if (role.isSystem)
                                      const Chip(
                                          label: Text('SYSTEM',
                                              style: TextStyle(fontSize: 9)))
                                  ]),
                                  const SizedBox(height: 5),
                                  Text(
                                      role.description.isEmpty
                                          ? 'No description.'
                                          : role.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: PccColors.inkSoft)),
                                  const SizedBox(height: 12),
                                  Text(
                                      '${role.permissionIds.length} permissions',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const Spacer(),
                                  Wrap(spacing: 8, children: [
                                    if (widget.session.can('roles.manage'))
                                      OutlinedButton.icon(
                                          onPressed: () => _edit(role),
                                          icon: const Icon(Icons.edit_outlined),
                                          label: const Text('EDIT')),
                                    if (widget.session.can('roles.manage') &&
                                        !role.isSystem)
                                      IconButton(
                                          onPressed: () => _delete(role),
                                          icon: const Icon(Icons.delete_outline,
                                              color: PccColors.danger))
                                  ]),
                                ]))))
                    .toList());
          }),
      ]);
}
