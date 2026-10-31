from rest_framework.permissions import SAFE_METHODS, BasePermission

from .models import User


class AdminRolePermission(BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == User.Role.ADMIN


class CatalogPermission(BasePermission):
    """All staff can read; only administrators can change the room catalog."""

    def has_permission(self, request, view):
        return request.user.is_authenticated and (
            request.method in SAFE_METHODS or request.user.role == User.Role.ADMIN
        )


class CustomerPermission(BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role in {
            User.Role.ADMIN,
            User.Role.RECEPTIONIST,
        }


class BookingPermission(BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and (
            request.method in SAFE_METHODS or request.user.role in {"admin", "receptionist"}
        )


class RoomConditionPermission(BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role in {
            User.Role.ADMIN,
            User.Role.RECEPTIONIST,
        }
