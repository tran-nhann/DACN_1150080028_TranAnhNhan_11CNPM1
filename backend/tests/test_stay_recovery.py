from datetime import timedelta
from io import StringIO

import pytest
from django.core.management import call_command
from django.utils import timezone

from hotel.models import AuditLog, Booking, Customer, Invoice, Payment, Stay
from hotel.stay_recovery import recover_open_stay

pytestmark = pytest.mark.django_db


@pytest.fixture
def orphan(users, room):
    guest = Customer.objects.create(full_name="Khách dữ liệu cũ", phone="0901234567")
    today = timezone.localdate()
    return Booking.objects.create(room=room, customer=guest, start_date=today - timedelta(days=1), end_date=today + timedelta(days=1),
        guests=1, nightly_rate=650000, status="checked_in", created_by=users["admin"], request_fingerprint="legacy")


def test_missing_stay_is_explained_and_recovery_enables_services_and_folio(client, users, orphan):
    client.force_authenticate(users["admin"])
    endpoint = f"/api/v1/bookings/{orphan.pk}/"
    error = client.get(endpoint + "folio/")
    assert error.status_code == 409 and "thiếu hồ sơ" in error.data["error"]["message"]
    summary = client.get(endpoint + "services/").data
    assert not summary["can_edit"] and "thiếu hồ sơ" in summary["blocked_reason"]
    assert client.post(endpoint + "check-in/").status_code == 409
    out = StringIO()
    call_command("recover_open_stay", booking=orphan.pk, actor="admin", stdout=out)
    assert not Stay.objects.exists()
    before = timezone.now()
    call_command("recover_open_stay", booking=orphan.pk, actor="admin", apply=True, stdout=out)
    stay = Stay.objects.get(booking=orphan)
    assert stay.checked_in_at >= before
    assert client.get(endpoint).data["check_in_record_recovered"] is True
    assert client.get(endpoint + "folio/").status_code == 200
    assert client.get(endpoint + "services/").data["can_edit"] is True
    assert Invoice.objects.count() == Payment.objects.count() == 0
    again, created = recover_open_stay(users["admin"], orphan.pk)
    assert not created and again.pk == stay.pk
    assert AuditLog.objects.filter(action="stay_recovered_now").count() == 1


def test_recovery_uses_known_checkin_audit_instead_of_inventing_time(client, users, orphan):
    entry = AuditLog.objects.create(actor=users["receptionist"], action="booking_check_in", entity="booking", entity_id=str(orphan.pk))
    recorded = timezone.now() - timedelta(hours=3)
    AuditLog.objects.filter(pk=entry.pk).update(created_at=recorded)
    stay, created = recover_open_stay(users["admin"], orphan.pk)
    assert created and stay.checked_in_at == recorded and stay.checked_in_by_id == users["receptionist"].pk
    client.force_authenticate(users["admin"])
    assert not client.get(f"/api/v1/bookings/{orphan.pk}/").data["check_in_record_recovered"]


def test_closed_booking_cannot_be_reopened_by_recovery(users, orphan):
    from hotel.booking_services import BookingConflict
    Booking.objects.filter(pk=orphan.pk).update(status="checked_out")
    with pytest.raises(BookingConflict):
        recover_open_stay(users["admin"], orphan.pk)
    assert not Stay.objects.exists()
