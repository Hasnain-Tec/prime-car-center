import json
from django.contrib.auth import authenticate
from django.utils import timezone
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken
from .models import (
    User, Role, SystemPermission, WorkshopSettings, Job, JobPart,
    JobAssignment, Expense, AuditLog,
)


class PermissionSerializer(serializers.ModelSerializer):
    class Meta:
        model = SystemPermission
        fields = ('id', 'code', 'name', 'module', 'description')


class RoleSerializer(serializers.ModelSerializer):
    permission_ids = serializers.PrimaryKeyRelatedField(
        source='permissions', many=True, queryset=SystemPermission.objects.all(), required=False,
    )
    permissions = PermissionSerializer(many=True, read_only=True)

    class Meta:
        model = Role
        fields = ('id', 'name', 'description', 'is_system', 'permission_ids', 'permissions', 'created_at', 'updated_at')
        read_only_fields = ('is_system', 'created_at', 'updated_at')


class UserSerializer(serializers.ModelSerializer):
    role_name = serializers.CharField(source='role.name', read_only=True)
    effective_permissions = serializers.SerializerMethodField()
    allow_permission_ids = serializers.PrimaryKeyRelatedField(
        source='allow_permissions', many=True, queryset=SystemPermission.objects.all(), required=False,
    )
    deny_permission_ids = serializers.PrimaryKeyRelatedField(
        source='deny_permissions', many=True, queryset=SystemPermission.objects.all(), required=False,
    )

    class Meta:
        model = User
        fields = (
            'id', 'email', 'full_name', 'phone', 'status', 'role', 'role_name',
            'allow_permission_ids', 'deny_permission_ids', 'effective_permissions',
            'approved_at', 'last_login', 'last_activity_at', 'created_at',
        )
        read_only_fields = ('approved_at', 'last_login', 'last_activity_at', 'created_at')

    def get_effective_permissions(self, obj):
        return sorted(obj.effective_permission_codes)


class RegisterSerializer(serializers.Serializer):
    full_name = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    phone = serializers.CharField(max_length=40, required=False, allow_blank=True)
    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True)

    def validate_email(self, value):
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError('An account with this email already exists.')
        return value.lower()

    def validate(self, attrs):
        if attrs['password'] != attrs.pop('password_confirm'):
            raise serializers.ValidationError({'password_confirm': 'Passwords do not match.'})
        return attrs

    def create(self, validated_data):
        return User.objects.create_user(status=User.Status.PENDING, **validated_data)


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        email = attrs['email'].lower()
        try:
            account = User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            raise serializers.ValidationError('Invalid email or password.')

        if account.status != User.Status.ACTIVE:
            messages = {
                User.Status.PENDING: 'Your account is waiting for administrator approval.',
                User.Status.SUSPENDED: 'Your account has been suspended.',
                User.Status.REJECTED: 'Your registration request was rejected.',
                User.Status.DISABLED: 'Your account has been disabled.',
            }
            raise serializers.ValidationError({'status': account.status, 'message': messages.get(account.status, 'Account unavailable.')})

        user = authenticate(request=self.context.get('request'), email=email, password=attrs['password'])
        if not user:
            raise serializers.ValidationError('Invalid email or password.')
        refresh = RefreshToken.for_user(user)
        user.last_activity_at = timezone.now()
        user.save(update_fields=['last_activity_at', 'updated_at'])
        return {
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'user': UserSerializer(user, context=self.context).data,
        }


class WorkshopSettingsSerializer(serializers.ModelSerializer):
    logo_url = serializers.SerializerMethodField()

    class Meta:
        model = WorkshopSettings
        fields = (
            'id', 'name', 'address', 'phone', 'email', 'license_number', 'logo', 'logo_url',
            'currency', 'invoice_prefix', 'invoice_footer', 'accent_color',
            'require_vehicle_photo', 'allow_gallery_upload', 'updated_at',
        )
        read_only_fields = ('id', 'updated_at', 'logo_url')
        extra_kwargs = {'logo': {'write_only': True, 'required': False}}

    def get_logo_url(self, obj):
        if not obj.logo:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(obj.logo.url) if request else obj.logo.url


class JobPartSerializer(serializers.ModelSerializer):
    class Meta:
        model = JobPart
        fields = ('id', 'name', 'amount', 'sort_order')
        read_only_fields = ('id',)


class AssignmentSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.full_name', read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)

    class Meta:
        model = JobAssignment
        fields = (
            'id', 'user', 'user_name', 'user_email', 'can_view', 'can_view_photo',
            'can_view_amounts', 'can_print_invoice', 'can_edit', 'can_add_parts', 'can_change_status', 'can_complete', 'can_delete', 'assigned_at',
        )
        read_only_fields = ('id', 'assigned_at')


class JobSerializer(serializers.ModelSerializer):
    parts = JobPartSerializer(many=True, required=False)
    assignments = AssignmentSerializer(many=True, read_only=True)
    materials_total = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    total = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    photo_url = serializers.SerializerMethodField()
    created_by_name = serializers.CharField(source='created_by.full_name', read_only=True)
    modified_by_name = serializers.CharField(source='modified_by.full_name', read_only=True)

    class Meta:
        model = Job
        fields = (
            'id', 'invoice_number', 'plate_number', 'work_description', 'parts',
            'materials_total', 'labour_charges', 'total', 'photo', 'photo_url',
            'status', 'priority', 'due_date', 'start_time', 'end_time',
            'internal_notes', 'assignments',
            'created_by', 'created_by_name', 'modified_by_name', 'created_at', 'updated_at',
        )
        read_only_fields = (
            'id', 'invoice_number', 'materials_total', 'total', 'created_by',
            'created_by_name', 'modified_by_name', 'created_at', 'updated_at', 'photo_url',
        )
        extra_kwargs = {'photo': {'write_only': True, 'required': False, 'allow_null': True}}

    def get_photo_url(self, obj):
        if not obj.photo:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(obj.photo.url) if request else obj.photo.url

    def to_representation(self, instance):
        data = super().to_representation(instance)
        request = self.context.get('request')
        user = getattr(request, 'user', None)
        if not user or not user.is_authenticated:
            return data
        assignment = instance.assignments.filter(user=user).first()
        can_view_photo = user.is_superuser or user.can('jobs.view_photos') or bool(assignment and assignment.can_view_photo)
        can_view_amounts = user.is_superuser or user.can('jobs.view_amounts') or bool(assignment and assignment.can_view_amounts)
        if not can_view_photo:
            data['photo_url'] = None
        if not can_view_amounts:
            data['materials_total'] = None
            data['labour_charges'] = None
            data['total'] = None
            for part in data.get('parts', []):
                part['amount'] = None
        return data

    def _extract_parts(self, validated_data):
        parts = validated_data.pop('parts', None)
        request = self.context.get('request')
        if parts is None and request is not None:
            raw = request.data.get('parts_json')
            if raw:
                parsed = json.loads(raw) if isinstance(raw, str) else raw
                parts_serializer = JobPartSerializer(data=parsed, many=True)
                parts_serializer.is_valid(raise_exception=True)
                parts = parts_serializer.validated_data
        return parts

    def create(self, validated_data):
        parts = self._extract_parts(validated_data) or []
        job = Job.objects.create(created_by=self.context['request'].user, **validated_data)
        JobPart.objects.bulk_create([
            JobPart(job=job, name=item['name'], amount=item['amount'], sort_order=item.get('sort_order', index))
            for index, item in enumerate(parts)
        ])
        return job

    def update(self, instance, validated_data):
        parts = self._extract_parts(validated_data)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.modified_by = self.context['request'].user
        instance.save()
        if parts is not None:
            instance.parts.all().delete()
            JobPart.objects.bulk_create([
                JobPart(job=instance, name=item['name'], amount=item['amount'], sort_order=item.get('sort_order', index))
                for index, item in enumerate(parts)
            ])
        return instance


class ExpenseSerializer(serializers.ModelSerializer):
    submitted_by_name = serializers.CharField(source='submitted_by.full_name', read_only=True)
    reviewed_by_name = serializers.CharField(source='reviewed_by.full_name', read_only=True)
    receipt_url = serializers.SerializerMethodField()

    class Meta:
        model = Expense
        fields = (
            'id', 'amount', 'description', 'category', 'receipt', 'receipt_url', 'status',
            'submitted_by', 'submitted_by_name', 'reviewed_by_name', 'reviewed_at',
            'created_at', 'updated_at',
        )
        read_only_fields = (
            'id', 'status', 'submitted_by', 'submitted_by_name', 'reviewed_by_name',
            'reviewed_at', 'created_at', 'updated_at', 'receipt_url',
        )
        extra_kwargs = {'receipt': {'write_only': True, 'required': False}}

    def get_receipt_url(self, obj):
        if not obj.receipt:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(obj.receipt.url) if request else obj.receipt.url

    def create(self, validated_data):
        return Expense.objects.create(submitted_by=self.context['request'].user, **validated_data)


class AuditLogSerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(source='actor.full_name', read_only=True)

    class Meta:
        model = AuditLog
        fields = ('id', 'actor', 'actor_name', 'action', 'module', 'object_type', 'object_id', 'details', 'ip_address', 'created_at')