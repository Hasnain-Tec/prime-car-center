from datetime import datetime
from decimal import Decimal
from django.db.models import Q, Sum
from django.db.models.functions import Coalesce
from django.http import FileResponse
from django.utils import timezone
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenRefreshView
from .access import (
    require_permission, visible_jobs, can_edit_job, can_delete_job, log_action,
)
from .models import (
    User, Role, SystemPermission, WorkshopSettings, Job, JobAssignment,
    Expense, AuditLog,
)
from .serializers import (
    RegisterSerializer, LoginSerializer, UserSerializer, RoleSerializer,
    PermissionSerializer, WorkshopSettingsSerializer, JobSerializer,
    AssignmentSerializer, ExpenseSerializer, AuditLogSerializer,
)
from .pdf_reports import build_invoice_pdf, build_summary_pdf


def parse_date_range(request):
    from_value = request.query_params.get('from')
    to_value = request.query_params.get('to')
    start = datetime.fromisoformat(from_value).date() if from_value else None
    end = datetime.fromisoformat(to_value).date() if to_value else None
    return start, end


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        log_action(request, 'registration_submitted', 'accounts', user, {'email': user.email})
        return Response({'message': 'Registration submitted. Wait for administrator approval.', 'status': user.status}, status=status.HTTP_201_CREATED)


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        return Response(data)


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user, context={'request': request}).data)


class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.select_related('role', 'approved_by').prefetch_related('allow_permissions', 'deny_permissions', 'role__permissions')
    serializer_class = UserSerializer

    def get_queryset(self):
        if not (self.request.user.is_superuser or self.request.user.can('users.view') or self.request.user.can('users.approve') or self.request.user.can('users.manage')):
            require_permission(self.request.user, 'users.view')
        qs = super().get_queryset().order_by('-created_at')
        status_value = self.request.query_params.get('status')
        search = self.request.query_params.get('search')
        if status_value:
            qs = qs.filter(status=status_value)
        if search:
            qs = qs.filter(Q(full_name__icontains=search) | Q(email__icontains=search) | Q(phone__icontains=search))
        return qs

    def create(self, request, *args, **kwargs):
        require_permission(request.user, 'users.manage')
        data = request.data.copy()
        password = data.pop('password', None)
        if isinstance(password, list):
            password = password[0]
        serializer = self.get_serializer(data=data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        if password:
            user.set_password(password)
            user.save()
        log_action(request, 'user_created', 'accounts', user)
        return Response(self.get_serializer(user).data, status=status.HTTP_201_CREATED)

    def update(self, request, *args, **kwargs):
        require_permission(request.user, 'users.manage')
        response = super().update(request, *args, **kwargs)
        log_action(request, 'user_updated', 'accounts', self.get_object())
        return response

    def destroy(self, request, *args, **kwargs):
        require_permission(request.user, 'users.manage')
        user = self.get_object()
        if user.is_superuser:
            return Response({'detail': 'Superuser accounts cannot be removed here.'}, status=400)
        user.status = User.Status.DISABLED
        user.save()
        log_action(request, 'user_removed', 'accounts', user, {'email': user.email})
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        require_permission(request.user, 'users.approve')
        user = self.get_object()
        role_id = request.data.get('role')
        if role_id:
            user.role_id = role_id
        user.status = User.Status.ACTIVE
        user.approved_by = request.user
        user.approved_at = timezone.now()
        user.save()
        log_action(request, 'registration_approved', 'accounts', user)
        return Response(self.get_serializer(user).data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        require_permission(request.user, 'users.approve')
        user = self.get_object()
        user.status = User.Status.REJECTED
        user.save()
        log_action(request, 'registration_rejected', 'accounts', user)
        return Response(self.get_serializer(user).data)

    @action(detail=True, methods=['post'])
    def set_status(self, request, pk=None):
        require_permission(request.user, 'users.manage')
        user = self.get_object()
        requested = request.data.get('status')
        if requested not in User.Status.values:
            return Response({'detail': 'Invalid status.'}, status=400)
        if user.is_superuser and requested != User.Status.ACTIVE:
            return Response({'detail': 'Superuser cannot be deactivated here.'}, status=400)
        user.status = requested
        user.save()
        log_action(request, 'user_status_changed', 'accounts', user, {'status': requested})
        return Response(self.get_serializer(user).data)


    @action(detail=True, methods=['post'])
    def reset_password(self, request, pk=None):
        require_permission(request.user, 'users.manage')
        user = self.get_object()
        password = request.data.get('password', '')
        if len(password) < 8:
            return Response({'detail': 'Password must contain at least 8 characters.'}, status=400)
        user.set_password(password)
        user.save()
        log_action(request, 'user_password_reset', 'accounts', user)
        return Response({'message': 'Password reset successfully.'})


class PermissionViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = SystemPermission.objects.all()
    serializer_class = PermissionSerializer
    pagination_class = None

    def list(self, request, *args, **kwargs):
        if not (request.user.is_superuser or request.user.can('users.view') or request.user.can('roles.manage')):
            require_permission(request.user, 'users.view')
        return super().list(request, *args, **kwargs)


class RoleViewSet(viewsets.ModelViewSet):
    queryset = Role.objects.prefetch_related('permissions').all()
    serializer_class = RoleSerializer
    pagination_class = None

    def list(self, request, *args, **kwargs):
        if not (request.user.is_superuser or request.user.can('users.view') or request.user.can('roles.manage')):
            require_permission(request.user, 'users.view')
        return super().list(request, *args, **kwargs)

    def create(self, request, *args, **kwargs):
        require_permission(request.user, 'roles.manage')
        response = super().create(request, *args, **kwargs)
        log_action(request, 'role_created', 'administration', details={'role': response.data.get('name')})
        return response

    def update(self, request, *args, **kwargs):
        require_permission(request.user, 'roles.manage')
        response = super().update(request, *args, **kwargs)
        log_action(request, 'role_updated', 'administration', self.get_object())
        return response

    def destroy(self, request, *args, **kwargs):
        require_permission(request.user, 'roles.manage')
        role = self.get_object()
        if role.is_system:
            return Response({'detail': 'System roles cannot be deleted.'}, status=400)
        return super().destroy(request, *args, **kwargs)


class JobViewSet(viewsets.ModelViewSet):
    serializer_class = JobSerializer

    def get_queryset(self):
        qs = Job.objects.select_related('created_by', 'modified_by').prefetch_related('parts', 'assignments__user')
        qs = visible_jobs(self.request.user, qs)
        plate = self.request.query_params.get('plate')
        invoice = self.request.query_params.get('invoice')
        status_value = self.request.query_params.get('status')
        assigned_to = self.request.query_params.get('assigned_to')
        start, end = parse_date_range(self.request)
        if plate:
            qs = qs.filter(plate_number__icontains=plate)
        if invoice:
            qs = qs.filter(invoice_number__icontains=invoice)
        if status_value:
            qs = qs.filter(status=status_value)
        if assigned_to:
            qs = qs.filter(assignments__user_id=assigned_to)
        if start:
            qs = qs.filter(created_at__date__gte=start)
        if end:
            qs = qs.filter(created_at__date__lte=end)
        return qs.distinct()

    def create(self, request, *args, **kwargs):
        require_permission(request.user, 'jobs.create')
        response = super().create(request, *args, **kwargs)
        job = Job.objects.get(pk=response.data['id'])
        log_action(request, 'job_created', 'jobs', job, {'invoice': job.invoice_number})
        return response

    def update(self, request, *args, **kwargs):
        job = self.get_object()
        assignment = JobAssignment.objects.filter(job=job, user=request.user).first()
        parts_requested = 'parts' in request.data or 'parts_json' in request.data
        if parts_requested and not (request.user.is_superuser or request.user.can('jobs.edit_all') or request.user.can('jobs.add_parts') or (assignment and assignment.can_add_parts)):
            return Response({'detail': 'You do not have permission to change job parts.'}, status=403)
        if not can_edit_job(request.user, job) and not (parts_requested and assignment and assignment.can_add_parts):
            return Response({'detail': 'You do not have permission to edit this job.'}, status=403)
        response = super().update(request, *args, **kwargs)
        log_action(request, 'job_updated', 'jobs', job)
        return response

    def partial_update(self, request, *args, **kwargs):
        return self.update(request, *args, partial=True, **kwargs)

    def destroy(self, request, *args, **kwargs):
        job = self.get_object()
        if not can_delete_job(request.user, job):
            return Response({'detail': 'You do not have permission to delete this job.'}, status=403)
        log_action(request, 'job_deleted', 'jobs', job, {'invoice': job.invoice_number})
        return super().destroy(request, *args, **kwargs)

    @action(detail=True, methods=['post'])
    def assign(self, request, pk=None):
        require_permission(request.user, 'jobs.assign')
        job = self.get_object()
        assignments = request.data.get('assignments', [])
        if not isinstance(assignments, list):
            return Response({'detail': 'assignments must be a list.'}, status=400)
        JobAssignment.objects.filter(job=job).delete()
        for item in assignments:
            serializer = AssignmentSerializer(data=item)
            serializer.is_valid(raise_exception=True)
            serializer.save(job=job, assigned_by=request.user)
        job.status = Job.Status.ASSIGNED if assignments else Job.Status.UNASSIGNED
        job.modified_by = request.user
        job.save(update_fields=['status', 'modified_by', 'updated_at'])
        log_action(request, 'job_assigned', 'jobs', job, {'users': [a.get('user') for a in assignments]})
        return Response(JobSerializer(job, context={'request': request}).data)

    @action(detail=True, methods=['post'])
    def change_status(self, request, pk=None):
        job = self.get_object()
        allowed = request.user.is_superuser or request.user.can('jobs.change_status') or JobAssignment.objects.filter(job=job, user=request.user, can_change_status=True).exists()
        if not allowed:
            return Response({'detail': 'You cannot change this job status.'}, status=403)
        status_value = request.data.get('status')
        if status_value not in Job.Status.values:
            return Response({'detail': 'Invalid job status.'}, status=400)
        if status_value == Job.Status.COMPLETED:
            complete_allowed = request.user.is_superuser or request.user.can('jobs.complete') or JobAssignment.objects.filter(job=job, user=request.user, can_complete=True).exists() or request.user.can('jobs.edit_all')
            if not complete_allowed:
                return Response({'detail': 'You cannot complete this job.'}, status=403)
        job.status = status_value
        job.modified_by = request.user
        job.save(update_fields=['status', 'modified_by', 'updated_at'])
        log_action(request, 'job_status_changed', 'jobs', job, {'status': status_value})
        return Response(JobSerializer(job, context={'request': request}).data)

    @action(detail=True, methods=['get'])
    def invoice_pdf(self, request, pk=None):
        job = self.get_object()
        assignment = JobAssignment.objects.filter(job=job, user=request.user).first()
        if not (request.user.is_superuser or request.user.can('jobs.print_invoice') or (assignment and assignment.can_print_invoice)):
            return Response({'detail': 'You do not have permission to print this invoice.'}, status=403)
        pdf = build_invoice_pdf(job)
        log_action(request, 'invoice_downloaded', 'jobs', job)
        return FileResponse(pdf, as_attachment=True, filename=f'{job.invoice_number}.pdf', content_type='application/pdf')


class ExpenseViewSet(viewsets.ModelViewSet):
    serializer_class = ExpenseSerializer

    def get_queryset(self):
        qs = Expense.objects.select_related('submitted_by', 'reviewed_by')
        user = self.request.user
        if not (user.is_superuser or user.can('expenses.view_all')):
            if user.can('expenses.view_own'):
                qs = qs.filter(submitted_by=user)
            else:
                qs = qs.none()
        status_value = self.request.query_params.get('status')
        start, end = parse_date_range(self.request)
        if status_value:
            qs = qs.filter(status=status_value)
        if start:
            qs = qs.filter(created_at__date__gte=start)
        if end:
            qs = qs.filter(created_at__date__lte=end)
        return qs

    def create(self, request, *args, **kwargs):
        require_permission(request.user, 'expenses.create')
        response = super().create(request, *args, **kwargs)
        expense = Expense.objects.get(pk=response.data['id'])
        expense.status = Expense.Status.APPROVED
        expense.save(update_fields=['status', 'updated_at'])
        response.data['status'] = Expense.Status.APPROVED
        log_action(request, 'expense_submitted', 'expenses', expense)
        return response

    def update(self, request, *args, **kwargs):
        require_permission(request.user, 'expenses.edit')
        response = super().update(request, *args, **kwargs)
        log_action(request, 'expense_updated', 'expenses', self.get_object())
        return response

    def destroy(self, request, *args, **kwargs):
        require_permission(request.user, 'expenses.delete')
        expense = self.get_object()
        log_action(request, 'expense_deleted', 'expenses', expense)
        return super().destroy(request, *args, **kwargs)

    @action(detail=True, methods=['post'])
    def review(self, request, pk=None):
        require_permission(request.user, 'expenses.approve')
        expense = self.get_object()
        new_status = request.data.get('status')
        if new_status not in (Expense.Status.APPROVED, Expense.Status.REJECTED):
            return Response({'detail': 'Status must be approved or rejected.'}, status=400)
        expense.status = new_status
        expense.reviewed_by = request.user
        expense.reviewed_at = timezone.now()
        expense.save()
        log_action(request, f'expense_{new_status}', 'expenses', expense)
        return Response(self.get_serializer(expense).data)


class WorkshopSettingsView(APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [AllowAny()]
        return [IsAuthenticated()]

    def get(self, request):
        obj = WorkshopSettings.get_solo()
        return Response(WorkshopSettingsSerializer(obj, context={'request': request}).data)

    def patch(self, request):
        require_permission(request.user, 'settings.manage')
        obj = WorkshopSettings.get_solo()
        serializer = WorkshopSettingsSerializer(obj, data=request.data, partial=True, context={'request': request})
        serializer.is_valid(raise_exception=True)
        serializer.save(updated_by=request.user)
        log_action(request, 'workshop_settings_updated', 'administration', obj)
        return Response(serializer.data)


class FinancialSummaryView(APIView):
    def get(self, request):
        require_permission(request.user, 'finance.view_profit_loss')
        start, end = parse_date_range(request)
        jobs = Job.objects.prefetch_related('parts').exclude(status=Job.Status.CANCELLED)
        expenses = Expense.objects.filter(status=Expense.Status.APPROVED)
        if start:
            jobs = jobs.filter(created_at__date__gte=start)
            expenses = expenses.filter(created_at__date__gte=start)
        if end:
            jobs = jobs.filter(created_at__date__lte=end)
            expenses = expenses.filter(created_at__date__lte=end)
        materials = sum((job.materials_total for job in jobs), Decimal('0'))
        labour = jobs.aggregate(v=Coalesce(Sum('labour_charges'), Decimal('0')))['v']
        revenue = materials + labour
        expense_total = expenses.aggregate(v=Coalesce(Sum('amount'), Decimal('0')))['v']
        payload = {
            'jobs': jobs.count(),
            'materials': materials,
            'labour': labour,
            'revenue': revenue,
            'expenses': expense_total,
            'net': revenue - expense_total,
        }
        return Response({key: str(value) if isinstance(value, Decimal) else value for key, value in payload.items()})


class FinancialSummaryPdfView(APIView):
    def get(self, request):
        require_permission(request.user, 'finance.export')
        start, end = parse_date_range(request)
        jobs = Job.objects.prefetch_related('parts').exclude(status=Job.Status.CANCELLED)
        expenses = Expense.objects.filter(status=Expense.Status.APPROVED)
        if start:
            jobs = jobs.filter(created_at__date__gte=start)
            expenses = expenses.filter(created_at__date__gte=start)
        if end:
            jobs = jobs.filter(created_at__date__lte=end)
            expenses = expenses.filter(created_at__date__lte=end)
        materials = sum((job.materials_total for job in jobs), Decimal('0'))
        labour = jobs.aggregate(v=Coalesce(Sum('labour_charges'), Decimal('0')))['v']
        expense_total = expenses.aggregate(v=Coalesce(Sum('amount'), Decimal('0')))['v']
        data = {'jobs': jobs.count(), 'materials': materials, 'labour': labour, 'revenue': materials + labour, 'expenses': expense_total, 'net': materials + labour - expense_total}
        label = f'{start or "Start"} to {end or "Today"}' if start or end else 'All Time'
        return FileResponse(build_summary_pdf(data, label), as_attachment=True, filename='financial-summary.pdf', content_type='application/pdf')


class DashboardView(APIView):
    def get(self, request):
        visible = visible_jobs(request.user, Job.objects.all())
        payload = {
            'jobs_total': visible.count(),
            'jobs_unassigned': visible.filter(status=Job.Status.UNASSIGNED).count(),
            'jobs_in_progress': visible.filter(status=Job.Status.IN_PROGRESS).count(),
            'jobs_completed': visible.filter(status=Job.Status.COMPLETED).count(),
        }
        if request.user.is_superuser or request.user.can('users.view'):
            payload['pending_users'] = User.objects.filter(status=User.Status.PENDING).count()
            payload['active_users'] = User.objects.filter(status=User.Status.ACTIVE).count()
        return Response(payload)


class AuditLogViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    queryset = AuditLog.objects.select_related('actor')
    serializer_class = AuditLogSerializer

    def get_queryset(self):
        require_permission(self.request.user, 'audit.view')
        qs = super().get_queryset()
        module = self.request.query_params.get('module')
        actor = self.request.query_params.get('actor')
        if module:
            qs = qs.filter(module=module)
        if actor:
            qs = qs.filter(actor_id=actor)
        return qs