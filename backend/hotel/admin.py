from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import AuditLog, Invoice, InvoiceLine, Payment, RoomMove, User


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


class InvoiceLineInline(admin.TabularInline):
    model = InvoiceLine
    extra = 0
    readonly_fields = [field.name for field in InvoiceLine._meta.fields]
    can_delete = False

    def has_add_permission(self, request, obj=None):
        return False

    def has_change_permission(self, request, obj=None):
        return False


@admin.register(Invoice)
class InvoiceAdmin(AuditLogAdmin):
    list_display = ["code", "guest_name", "room_number", "total", "issued_at", "issued_by"]
    search_fields = ["code", "booking_code", "guest_name", "room_number"]
    readonly_fields = [field.name for field in Invoice._meta.fields]
    inlines = [InvoiceLineInline]


@admin.register(Payment)
class PaymentAdmin(AuditLogAdmin):
    list_display = ["code", "invoice", "amount", "method", "received_at", "received_by"]
    readonly_fields = [field.name for field in Payment._meta.fields]


@admin.register(RoomMove)
class RoomMoveAdmin(AuditLogAdmin):
    list_display = ["booking", "from_number", "to_number", "effective_date", "price_mode", "created_by"]
    readonly_fields = [field.name for field in RoomMove._meta.fields]
