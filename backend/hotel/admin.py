from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import AuditLog, User


@admin.register(User)
class HotelUserAdmin(UserAdmin):
    fieldsets = UserAdmin.fieldsets + (("Khách sạn", {"fields": ("display_name", "role")}),)
    add_fieldsets = UserAdmin.add_fieldsets + (("Khách sạn", {"fields": ("display_name", "role")}),)
    list_display = ["username", "display_name", "role", "is_active"]


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ["created_at", "actor", "action", "entity", "entity_id"]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
