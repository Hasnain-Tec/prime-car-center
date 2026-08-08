from django.db.models import Q
from rest_framework.exceptions import PermissionDenied
from .models import AuditLog, JobAssignment


def has_permission(user, code):
    return user.is_authenticated and user.status == user.Status.ACTIVE and user.can(code)


def require_permission(user, code):
    if not has_permission(user, code):
        raise PermissionDenied(f'Missing permission: {code}')


def visible_jobs(user, queryset):
    if user.is_superuser or user.can('jobs.view_all'):
        return queryset
    query = Q(pk__in=[])
    if user.can('jobs.view_created'):
        query |= Q(created_by=user)
    query |= Q(assignments__user=user, assignments__can_view=True)
    return queryset.filter(query).distinct()


def can_edit_job(user, job):
    if user.is_superuser or user.can('jobs.edit_all'):
        return True
    return JobAssignment.objects.filter(job=job, user=user, can_edit=True).exists()


def can_delete_job(user, job):
    if user.is_superuser or user.can('jobs.delete_all'):
        return True
    return JobAssignment.objects.filter(job=job, user=user, can_delete=True).exists()


def client_ip(request):
    forwarded = request.META.get('HTTP_X_FORWARDED_FOR')
    return forwarded.split(',')[0].strip() if forwarded else request.META.get('REMOTE_ADDR')


def log_action(request, action, module, obj=None, details=None):
    AuditLog.objects.create(
        actor=request.user if getattr(request, 'user', None) and request.user.is_authenticated else None,
        action=action,
        module=module,
        object_type=obj.__class__.__name__ if obj else '',
        object_id=str(getattr(obj, 'pk', '')) if obj else '',
        details=details or {},
        ip_address=client_ip(request),
    )
