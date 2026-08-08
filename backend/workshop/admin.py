from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import (
    User, Role, SystemPermission, WorkshopSettings, Job, JobPart,
    JobAssignment, Expense, AuditLog,
)

@admin.register(User)
class CustomUserAdmin(UserAdmin):
    ordering = ('email',)
    list_display = ('email', 'full_name', 'status', 'role', 'is_superuser', 'created_at')
    list_filter = ('status', 'role', 'is_superuser')
    search_fields = ('email', 'full_name', 'phone')
    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Profile', {'fields': ('full_name', 'phone', 'status', 'role')}),
        ('Direct permissions', {'fields': ('allow_permissions', 'deny_permissions')}),
        ('Django access', {'fields': ('is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Dates', {'fields': ('last_login', 'date_joined', 'approved_at')}),
    )
    add_fieldsets = ((None, {'classes': ('wide',), 'fields': ('email', 'full_name', 'password1', 'password2', 'status')}),)

admin.site.register(Role)
admin.site.register(SystemPermission)
admin.site.register(WorkshopSettings)
admin.site.register(Job)
admin.site.register(JobPart)
admin.site.register(JobAssignment)
admin.site.register(Expense)
admin.site.register(AuditLog)
