from django.urls import include, path
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView, TokenBlacklistView
from .views import (
    RegisterView, LoginView, MeView, UserViewSet, RoleViewSet, PermissionViewSet,
    JobViewSet, ExpenseViewSet, WorkshopSettingsView, FinancialSummaryView,
    FinancialSummaryPdfView, DashboardView, AuditLogViewSet,
)

router = DefaultRouter()
router.register('users', UserViewSet, basename='users')
router.register('roles', RoleViewSet, basename='roles')
router.register('permissions', PermissionViewSet, basename='permissions')
router.register('jobs', JobViewSet, basename='jobs')
router.register('expenses', ExpenseViewSet, basename='expenses')
router.register('audit-logs', AuditLogViewSet, basename='audit-logs')

urlpatterns = [
    path('auth/register/', RegisterView.as_view()),
    path('auth/login/', LoginView.as_view()),
    path('auth/refresh/', TokenRefreshView.as_view()),
    path('auth/logout/', TokenBlacklistView.as_view()),
    path('auth/me/', MeView.as_view()),
    path('dashboard/', DashboardView.as_view()),
    path('workshop-settings/', WorkshopSettingsView.as_view()),
    path('financial-summary/', FinancialSummaryView.as_view()),
    path('financial-summary/pdf/', FinancialSummaryPdfView.as_view()),
    path('', include(router.urls)),
]
