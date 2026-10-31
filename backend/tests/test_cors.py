from rest_framework.test import APIClient


def test_booking_preflight_allows_idempotency_header():
    response = APIClient().options(
        "/api/v1/bookings/",
        HTTP_ORIGIN="http://127.0.0.1:4173",
        HTTP_ACCESS_CONTROL_REQUEST_METHOD="POST",
        HTTP_ACCESS_CONTROL_REQUEST_HEADERS="authorization,content-type,idempotency-key",
    )
    assert response.status_code == 200
    assert response["Access-Control-Allow-Origin"] == "http://127.0.0.1:4173"
    assert "idempotency-key" in response["Access-Control-Allow-Headers"].split(", ")


def test_preflight_rejects_unknown_origin():
    response = APIClient().options(
        "/api/v1/bookings/",
        HTTP_ORIGIN="https://untrusted.example",
        HTTP_ACCESS_CONTROL_REQUEST_METHOD="POST",
        HTTP_ACCESS_CONTROL_REQUEST_HEADERS="idempotency-key",
    )
    assert "Access-Control-Allow-Origin" not in response
