from django.test import TestCase
from .models import User, Role, SystemPermission, Job, JobAssignment
from .access import visible_jobs, can_edit_job, can_delete_job

class PermissionFlowTests(TestCase):
    def setUp(self):
        self.admin = User.objects.create_superuser(email='admin@example.com', full_name='Admin', password='StrongPass123!')
        self.user = User.objects.create_user(email='staff@example.com', full_name='Staff', password='StrongPass123!', status=User.Status.ACTIVE)
        self.job = Job.objects.create(plate_number='DXB 123', work_description='Test job', created_by=self.admin)

    def test_assignment_controls_visibility_and_actions(self):
        assignment = JobAssignment.objects.create(job=self.job, user=self.user, assigned_by=self.admin, can_view=True, can_edit=True, can_delete=False)
        self.assertEqual(visible_jobs(self.user, Job.objects.all()).count(), 1)
        self.assertTrue(can_edit_job(self.user, self.job))
        self.assertFalse(can_delete_job(self.user, self.job))
        assignment.can_delete = True
        assignment.save()
        self.assertTrue(can_delete_job(self.user, self.job))
