from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.conf import settings
from django.db import models, transaction
from django.utils import timezone


class UserManager(BaseUserManager):
    use_in_migrations = True

    def _create_user(self, email, password, **extra_fields):
        if not email:
            raise ValueError('Email is required.')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', False)
        extra_fields.setdefault('is_superuser', False)
        extra_fields.setdefault('status', User.Status.PENDING)
        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('status', User.Status.ACTIVE)
        if not extra_fields.get('is_staff') or not extra_fields.get('is_superuser'):
            raise ValueError('Superuser must have is_staff=True and is_superuser=True.')
        return self._create_user(email, password, **extra_fields)


class SystemPermission(models.Model):
    code = models.CharField(max_length=80, unique=True)
    name = models.CharField(max_length=140)
    module = models.CharField(max_length=50, db_index=True)
    description = models.TextField(blank=True)

    class Meta:
        ordering = ('module', 'name')

    def __str__(self):
        return self.name


class Role(models.Model):
    name = models.CharField(max_length=80, unique=True)
    description = models.TextField(blank=True)
    permissions = models.ManyToManyField(SystemPermission, blank=True, related_name='roles')
    is_system = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ('name',)

    def __str__(self):
        return self.name


class User(AbstractUser):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending approval'
        ACTIVE = 'active', 'Active'
        SUSPENDED = 'suspended', 'Suspended'
        REJECTED = 'rejected', 'Rejected'
        DISABLED = 'disabled', 'Disabled'

    username = models.CharField(max_length=150, unique=True, blank=True, null=True)
    email = models.EmailField(unique=True)
    full_name = models.CharField(max_length=150)
    phone = models.CharField(max_length=40, blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING, db_index=True)
    role = models.ForeignKey(Role, null=True, blank=True, on_delete=models.SET_NULL, related_name='users')
    allow_permissions = models.ManyToManyField(SystemPermission, blank=True, related_name='allowed_users')
    deny_permissions = models.ManyToManyField(SystemPermission, blank=True, related_name='denied_users')
    approved_by = models.ForeignKey('self', null=True, blank=True, on_delete=models.SET_NULL, related_name='approved_accounts')
    approved_at = models.DateTimeField(null=True, blank=True)
    last_activity_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['full_name']
    objects = UserManager()

    def save(self, *args, **kwargs):
        self.is_active = self.status == self.Status.ACTIVE
        super().save(*args, **kwargs)

    @property
    def effective_permission_codes(self):
        if self.is_superuser:
            return set(SystemPermission.objects.values_list('code', flat=True))
        role_codes = set()
        if self.role_id:
            role_codes = set(self.role.permissions.values_list('code', flat=True))
        allowed = set(self.allow_permissions.values_list('code', flat=True))
        denied = set(self.deny_permissions.values_list('code', flat=True))
        return (role_codes | allowed) - denied

    def can(self, code):
        return self.is_superuser or code in self.effective_permission_codes

    def __str__(self):
        return self.full_name or self.email


class WorkshopSettings(models.Model):
    name = models.CharField(max_length=150, default='Prime Car Center')
    address = models.TextField(blank=True)
    phone = models.CharField(max_length=50, blank=True)
    email = models.EmailField(blank=True)
    license_number = models.CharField(max_length=100, blank=True)
    logo = models.ImageField(upload_to='settings/', blank=True, null=True)
    currency = models.CharField(max_length=10, default='AED')
    invoice_prefix = models.CharField(max_length=30, default='PCC-INV-')
    next_invoice_number = models.PositiveBigIntegerField(default=1)
    invoice_footer = models.CharField(max_length=255, default='Thank you for choosing Prime Car Center')
    accent_color = models.CharField(max_length=10, default='#E8590C')
    require_vehicle_photo = models.BooleanField(default=False)
    allow_gallery_upload = models.BooleanField(default=True)
    updated_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL)
    updated_at = models.DateTimeField(auto_now=True)

    @classmethod
    def get_solo(cls):
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj

    def __str__(self):
        return self.name


class Job(models.Model):
    class Status(models.TextChoices):
        UNASSIGNED = 'unassigned', 'Unassigned'
        ASSIGNED = 'assigned', 'Assigned'
        IN_PROGRESS = 'in_progress', 'In progress'
        ON_HOLD = 'on_hold', 'On hold'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'

    class Priority(models.TextChoices):
        LOW = 'low', 'Low'
        NORMAL = 'normal', 'Normal'
        HIGH = 'high', 'High'
        URGENT = 'urgent', 'Urgent'

    invoice_number = models.CharField(max_length=50, unique=True, editable=False, db_index=True)
    plate_number = models.CharField(max_length=50, db_index=True)
    work_description = models.TextField()
    labour_charges = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    photo = models.ImageField(upload_to='vehicles/%Y/%m/', blank=True, null=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.UNASSIGNED, db_index=True)
    priority = models.CharField(max_length=20, choices=Priority.choices, default=Priority.NORMAL)
    due_date = models.DateTimeField(null=True, blank=True)
    start_time = models.DateTimeField(null=True, blank=True)
    end_time = models.DateTimeField(null=True, blank=True)
    internal_notes = models.TextField(blank=True)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='created_jobs')
    modified_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name='modified_jobs')
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ('-created_at',)
        indexes = [models.Index(fields=('plate_number', 'created_at'))]

    def save(self, *args, **kwargs):
        if not self.invoice_number:
            with transaction.atomic():
                settings_obj = WorkshopSettings.objects.select_for_update().get_or_create(pk=1)[0]
                self.invoice_number = f'{settings_obj.invoice_prefix}{settings_obj.next_invoice_number:06d}'
                settings_obj.next_invoice_number += 1
                settings_obj.save(update_fields=['next_invoice_number', 'updated_at'])
        super().save(*args, **kwargs)

    @property
    def materials_total(self):
        return sum((part.amount for part in self.parts.all()), start=0)

    @property
    def total(self):
        return self.materials_total + self.labour_charges

    def __str__(self):
        return f'{self.invoice_number} - {self.plate_number}'


class JobPart(models.Model):
    job = models.ForeignKey(Job, on_delete=models.CASCADE, related_name='parts')
    name = models.CharField(max_length=180)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    sort_order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ('sort_order', 'id')

    def __str__(self):
        return self.name


class JobAssignment(models.Model):
    job = models.ForeignKey(Job, on_delete=models.CASCADE, related_name='assignments')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='job_assignments')
    assigned_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name='assignments_made')
    can_view = models.BooleanField(default=True)
    can_view_photo = models.BooleanField(default=True)
    can_view_amounts = models.BooleanField(default=True)
    can_print_invoice = models.BooleanField(default=False)
    can_edit = models.BooleanField(default=False)
    can_add_parts = models.BooleanField(default=False)
    can_change_status = models.BooleanField(default=False)
    can_complete = models.BooleanField(default=False)
    can_delete = models.BooleanField(default=False)
    assigned_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=('job', 'user'), name='unique_job_assignment')]

    def __str__(self):
        return f'{self.job.invoice_number} → {self.user}'


class Expense(models.Model):
    class Status(models.TextChoices):
        SUBMITTED = 'submitted', 'Submitted'
        APPROVED = 'approved', 'Approved'
        REJECTED = 'rejected', 'Rejected'

    amount = models.DecimalField(max_digits=12, decimal_places=2)
    description = models.TextField()
    category = models.CharField(max_length=100, blank=True)
    receipt = models.ImageField(upload_to='expenses/%Y/%m/', blank=True, null=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.SUBMITTED, db_index=True)
    submitted_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='submitted_expenses')
    reviewed_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name='reviewed_expenses')
    reviewed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ('-created_at',)

    def __str__(self):
        return f'{self.description[:40]} ({self.amount})'


class AuditLog(models.Model):
    actor = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL)
    action = models.CharField(max_length=100, db_index=True)
    module = models.CharField(max_length=50, db_index=True)
    object_type = models.CharField(max_length=80, blank=True)
    object_id = models.CharField(max_length=80, blank=True)
    details = models.JSONField(default=dict, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ('-created_at',)

    def __str__(self):
        return f'{self.action} by {self.actor or "system"}'