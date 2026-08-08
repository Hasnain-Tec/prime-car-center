from django.db.models.signals import post_migrate
from django.dispatch import receiver
from .models import Role, SystemPermission
from .permission_codes import PERMISSIONS

@receiver(post_migrate)
def seed_permissions(sender, **kwargs):
    if sender.name != 'workshop':
        return
    permission_objects = {}
    for code, name, module in PERMISSIONS:
        obj, _ = SystemPermission.objects.update_or_create(
            code=code,
            defaults={'name': name, 'module': module},
        )
        permission_objects[code] = obj

    admin_role, _ = Role.objects.get_or_create(name='Administrator', defaults={'is_system': True})
    admin_role.permissions.set(permission_objects.values())

    staff_role, _ = Role.objects.get_or_create(name='Workshop Staff', defaults={'is_system': True})
    staff_codes = [
        'jobs.create', 'jobs.view_assigned', 'jobs.view_created',
        'jobs.edit_assigned', 'jobs.change_status', 'jobs.print_invoice',
        'jobs.view_photos', 'jobs.view_amounts', 'jobs.add_parts', 'jobs.complete',
        'expenses.create', 'expenses.view_own',
    ]
    staff_role.permissions.set([permission_objects[c] for c in staff_codes])
