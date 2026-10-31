from contextlib import contextmanager

from django.db import connection, transaction
from rest_framework.exceptions import APIException, NotFound

from .models import AuditLog


class RoomBusy(APIException):
    status_code = 409
    default_detail = "Phòng đang được cập nhật. Vui lòng thử lại."
    default_code = "room_busy"


@contextmanager
def application_transaction(resource, mode="Exclusive"):
    """Lock ownership is tied to this transaction, including nested savepoints."""
    with transaction.atomic():
        with connection.cursor() as cursor:
            cursor.execute(
                "DECLARE @result int; EXEC @result = sys.sp_getapplock "
                "@Resource=%s, @LockMode=%s, @LockOwner='Transaction', "
                "@LockTimeout=5000; SELECT @result;",
                [resource, mode],
            )
            result = cursor.fetchone()[0]
            if result < 0:
                raise RoomBusy()
        yield


def normalize_id(value):
    try:
        value = int(value)
        if value < 1 or value > 9223372036854775807:
            raise ValueError
    except (ValueError, TypeError) as exc:
        raise NotFound("Không tìm thấy dữ liệu.") from exc
    return value


@contextmanager
def room_transaction(room_id):
    with application_transaction(f"hotel:room:{normalize_id(room_id)}"):
        yield


def record_audit(user, action, instance):
    AuditLog.objects.create(
        actor=user, action=action, entity=instance._meta.model_name, entity_id=str(instance.pk)
    )
