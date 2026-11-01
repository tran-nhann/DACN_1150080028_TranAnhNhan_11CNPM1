import os

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from hotel.models import Customer, Room, RoomType, ServiceItem, User


class Command(BaseCommand):
    help = "Tạo dữ liệu mẫu development; chạy lại không ghi đè dữ liệu đã chỉnh sửa."

    @transaction.atomic
    def handle(self, *args, **options):
        if not settings.DEBUG:
            raise CommandError("Chỉ được seed tài khoản demo khi DJANGO_DEBUG=True.")
        password = os.getenv("DEMO_PASSWORD", "")
        if len(password) < 12:
            raise CommandError("Thiếu DEMO_PASSWORD tối thiểu 12 ký tự trong backend/.env.")
        accounts = [
            ("admin", "Anh Nhân", User.Role.ADMIN),
            ("letan", "Minh Anh", User.Role.RECEPTIONIST),
            ("quanly", "Thanh Trí", User.Role.MANAGER),
        ]
        for username, name, role in accounts:
            if not User.objects.filter(username=username).exists():
                User.objects.create_user(
                    username=username,
                    password=password,
                    display_name=name,
                    role=role,
                    is_staff=role == "admin",
                    is_superuser=role == "admin",
                )
        room_types = []
        for name, capacity, rate, description in [
            ("Superior", 2, 650000, "Không gian ấm cúng · giường queen"),
            ("Deluxe", 2, 950000, "Thoáng sáng · hướng thành phố"),
            ("Premier", 3, 1250000, "Rộng rãi · phù hợp gia đình"),
            ("Suite", 4, 1850000, "Phòng khách riêng · trải nghiệm cao cấp"),
        ]:
            instance, _ = RoomType.objects.get_or_create(
                name=name,
                defaults={"capacity": capacity, "base_rate": rate, "description": description},
            )
            room_types.append(instance)
        for floor in range(1, 4):
            for index in range(1, 11):
                condition = (
                    "maintenance" if index == 10 else "cleaning" if index in {4, 8} else "ready"
                )
                Room.objects.get_or_create(
                    number=f"{floor}{index:02}",
                    defaults={
                        "floor": floor,
                        "room_type": room_types[(index - 1) % 4],
                        "condition": condition,
                    },
                )
        for index, name in enumerate(
            [
                "Nguyễn Minh An",
                "Trần Ngọc Hà",
                "Lê Hoàng Nam",
                "Phạm Thu Linh",
                "Đỗ Gia Bảo",
                "Vũ Thanh Mai",
            ],
            start=1,
        ):
            Customer.objects.get_or_create(
                phone=f"09000000{index:02}",
                defaults={
                    "full_name": name,
                    "email": f"guest{index}@example.com",
                    "notes": "Dữ liệu giả phục vụ demo",
                },
            )
        for name, unit, price, category, description in [
            ("Nước suối", "chai", 15000, "minibar", "Nước uống đóng chai, tính theo số chai sử dụng."),
            ("Giặt ủi", "kg", 30000, "laundry", "Giặt ủi quần áo, tính theo khối lượng đồ nhận giặt."),
            ("Ăn sáng", "suất", 60000, "food", "Phục vụ bữa sáng, tính theo số suất khách sử dụng."),
            ("Đưa đón", "lượt", 200000, "transport", "Dịch vụ xe đưa đón khách, tính theo số lượt."),
        ]:
            ServiceItem.objects.get_or_create(name=name, defaults={
                "unit": unit, "unit_price": price, "category": category, "description": description,
            })
        self.stdout.write(
            self.style.SUCCESS(
                "Đã seed tài khoản, phòng, khách và 4 dịch vụ mẫu. Mật khẩu nằm trong backend/.env."
            )
        )
