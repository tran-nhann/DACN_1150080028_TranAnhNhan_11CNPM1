from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView
from rest_framework.routers import DefaultRouter

from hotel.billing_views import BookingBillingViewSet, InvoiceViewSet
from hotel.booking_views import BookingViewSet
from hotel.revenue_views import RevenueEstimateView
from hotel.service_views import BookingServiceViewSet, ServiceItemViewSet, ServiceUnitsView
from hotel.views import (
    CustomerViewSet,
    DashboardView,
    HealthView,
    LoginView,
    LogoutView,
    MeView,
    RefreshView,
    RoomTypeViewSet,
    RoomViewSet,
)

router = DefaultRouter()
router.register("room-types", RoomTypeViewSet)
router.register("rooms", RoomViewSet)
router.register("customers", CustomerViewSet)
router.register("bookings", BookingViewSet)
router.register("services", ServiceItemViewSet)
router.register("invoices", InvoiceViewSet)
booking_services = BookingServiceViewSet.as_view({"get": "services", "post": "add"})
cancel_service = BookingServiceViewSet.as_view({"post": "cancel"})
urlpatterns = [
    path("api/v1/bookings/<int:pk>/planned-services/", BookingServiceViewSet.as_view({"post": "plan"}), name="booking-plan-service"),
    path("api/v1/bookings/<int:pk>/planned-services/<int:plan_id>/cancel/", BookingServiceViewSet.as_view({"post": "cancel_plan"}), name="booking-cancel-plan-service"),
    path("api/v1/bookings/<int:pk>/folio/", BookingBillingViewSet.as_view({"get": "folio"}), name="booking-folio"),
    path("api/v1/bookings/<int:pk>/check-out/", BookingBillingViewSet.as_view({"post": "check_out"}), name="booking-check-out"),
    path("api/v1/reports/revenue-estimate/", RevenueEstimateView.as_view(), name="revenue-estimate"),
    path("api/v1/service-units/", ServiceUnitsView.as_view(), name="service-units"),
    path("api/v1/bookings/<int:pk>/services/", booking_services, name="booking-services"),
    path("api/v1/bookings/<int:pk>/services/<int:usage_id>/cancel/", cancel_service, name="booking-service-cancel"),
    path("admin/", admin.site.urls),
    path("api/v1/health/", HealthView.as_view(), name="health"),
    path("api/v1/auth/login/", LoginView.as_view(), name="login"),
    path("api/v1/auth/refresh/", RefreshView.as_view(), name="refresh"),
    path("api/v1/auth/logout/", LogoutView.as_view(), name="logout"),
    path("api/v1/me/", MeView.as_view(), name="me"),
    path("api/v1/dashboard/", DashboardView.as_view(), name="dashboard"),
    path("api/v1/schema/", SpectacularAPIView.as_view(), name="schema"),
    path("api/v1/docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="docs"),
    path("api/v1/", include(router.urls)),
]
urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
