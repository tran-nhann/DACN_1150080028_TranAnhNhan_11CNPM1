# Aster Hotel

Ứng dụng quản lý khách sạn trên Android bằng Flutter/Dart, Django REST Framework và SQL Server. Đã có đăng nhập ba vai trò, phòng, khách hàng, đặt phòng và nhận phòng. Mobile gọi API thật; dữ liệu được lưu trong SQL Server Express trên máy này.

## Phần đã chạy được

- Đăng nhập, khôi phục phiên, tự refresh access token, rotation refresh token và đăng xuất.
- Ba vai trò: `admin`, `receptionist`, `manager`; kiểm tra quyền ở API và điều hướng UI.
- Dashboard phòng sẵn sàng/đang ở/đã đặt/cần dọn/bảo trì, khách đến/đi và số khách đang ở.
- Tìm kiếm phòng, lọc trạng thái/tầng, phân trang, xem chi tiết và cập nhật tình trạng vận hành.
- Admin thêm phòng; danh mục loại phòng có API tạo/sửa, hiện seed sẵn bốn loại.
- Admin/lễ tân tìm kiếm, thêm và cập nhật khách hàng. Người quản lý không được truy cập thông tin khách hàng trong bản này.
- Nhật ký thay đổi, kiểm tra dữ liệu đầu vào và ràng buộc toàn vẹn ở SQL Server.
- UI dành cho điện thoại, điều hướng dưới, ít chữ; font Manrope được đóng gói trong app.
- Đặt phòng theo ngày, chọn khách và phòng trống; giá được chốt tại thời điểm đặt.
- Hủy, đổi lịch/phòng, gia hạn và nhận phòng; người quản lý chỉ đọc đặt phòng.
- Hồ sơ khách, lịch đặt theo khách/phòng; mở các chi tiết liên quan trong cùng sheet.
- Dịch vụ lưu trú: chọn số lượng, giữ giá tại lúc ghi, xem tạm tính, hủy khoản có lý do; chống gửi trùng và phân quyền ở API.
- Danh mục dịch vụ trên app: admin tạo/sửa giá, đơn vị và ngừng bán; đã có bốn dịch vụ mẫu.
- Đơn vị dịch vụ chọn từ danh sách có ví dụ, được kiểm tra ở API; mục cũ nhập sai được đánh dấu để admin sửa. Khách hàng/Dịch vụ có nút về Thêm và hỗ trợ Back hệ thống.
- Dashboard mở danh sách đến/đi đúng ngày, lọc theo tầng và mở phòng cần xử lý.
- Khóa SQL Server chống đặt trùng, khóa mã yêu cầu chống gửi lặp; duplicate check-in không tạo lưu trú thứ hai.

Hóa đơn/thanh toán, check-out và báo cáo doanh thu là giai đoạn tiếp theo. Dịch vụ hiện tính vào số tạm tính, chưa phải tiền đã thu. Phòng trống trong form được kiểm tra theo khoảng ngày; trạng thái trong danh mục/dashboard phản ánh hôm nay. Dashboard không hiển thị doanh thu giả.

## Môi trường trên máy hiện tại

| Thành phần | Phiên bản hoặc cấu hình |
| --- | --- |
| Python | 3.12.10; venv tại `.venv` |
| Django | 5.2.18 |
| DRF | 3.18.3 |
| mssql-django | 2.0.0; driver pyodbc và ODBC Driver 18 |
| SQL Server | SQL Server 2022 Express, instance `SQLEXPRESS` |
| Database development | `HotelManagementDev` |
| Database kiểm thử | `HotelManagementTest`, tách dữ liệu demo |
| Flutter | 3.47.7 stable; SDK local tại `.tools/flutter` |
| Dart | 3.13.5 |

Các package Python đã khóa tại `backend/requirements.txt`; Flutter đã khóa tại `mobile/pubspec.lock`. `.env`, venv, SDK và output build được bỏ qua trong Git. JDK 21 và Android SDK được cài riêng tại `.tools`; không thay Java/PATH toàn máy. Giả lập `Aster_API34` dùng Android 14 x86_64, WHPX, 2 CPU và 1536 MB RAM. Trên máy này dùng GPU host, tắt Vulkan của giả lập; chế độ SwiftShader khiến máy ảo không phản hồi.

## Mở app

Chạy trên giả lập Android:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-android.ps1
```

Thêm `-Build` sau khi sửa Flutter, thêm `-RestartApi` sau khi sửa backend. APK debug x86_64 nằm tại `mobile/build/app/outputs/flutter-apk/app-debug.apk`; dành cho giả lập này. Android Emulator cần ít nhất 5 GB trống lúc khởi động; nên chừa thêm dung lượng cho Gradle/SDK.

Bản xem nhanh **http://127.0.0.1:4173** là cùng app Flutter, được giới hạn khung điện thoại, không phải website riêng. Dùng `start-dev.ps1 -Rebuild` để cập nhật bản xem này.

Các tài khoản development:

| Tên đăng nhập | Vai trò |
| --- | --- |
| `admin` | Quản trị viên |
| `letan` | Lễ tân |
| `quanly` | Người quản lý |

Mật khẩu được sinh ngẫu nhiên trên máy, nằm ở dòng `DEMO_PASSWORD` trong `backend/.env`. Ba tài khoản seed ban đầu dùng cùng mật khẩu development này. Seed chạy lại không reset mật khẩu hoặc ghi đè dữ liệu đã sửa. Không dùng các tài khoản seed cho triển khai thực tế.

Trong PowerShell tại thư mục dự án, xem mật khẩu local bằng:

```powershell
Get-Content .\backend\.env | Select-String '^DEMO_PASSWORD='
```

## Chạy lại sau khi tắt máy

Mở một terminal ở thư mục gốc:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-dev.ps1
```

Script `start-dev.ps1` khởi động backend và bản xem Flutter trên trình duyệt. Để dùng mobile, ưu tiên `start-android.ps1`. Chạy riêng API bằng `scripts/start-api.ps1`; thêm `-Restart` để nạp source backend mới. Log nằm trong `.artifacts`.

Hoặc chạy riêng hai terminal:

```powershell
# Terminal 1: API
.\.venv\Scripts\python.exe backend/manage.py runserver 127.0.0.1:8000

# Terminal 2: bản Flutter đã build
.\.venv\Scripts\python.exe -m http.server 4173 --bind 127.0.0.1 --directory mobile/build/web
```

## Dựng lại môi trường

Máy Windows cần Python 3.12, SQL Server instance tương ứng và Microsoft ODBC Driver 18. Cấu hình mẫu dùng Windows Authentication, kết nối shared memory tới `lpc:.\SQLEXPRESS`; backend không cần SQL Browser hoặc cổng TCP public để chạy trên máy này.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-backend.ps1
```

Script tạo venv nếu thiếu, cài dependencies đã khóa, sinh `.env` nếu thiếu, tạo riêng `HotelManagementDev` nếu chưa có, chạy migrations và seed. Script không sửa database khác. Nếu dùng SQL Server khác, chỉnh `backend/.env` và tự chuẩn bị database; script tạo database local chỉ chấp nhận tên `HotelManagementDev`.

Để dựng Flutter SDK local trên máy mới:

```powershell
git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git .tools/flutter
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 pub get
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 build web --no-wasm-dry-run
```

`scripts/flutter.ps1` tạo junction trong `%LOCALAPPDATA%\AsterHotel\workspace` trỏ về source hiện tại để tránh lỗi LSP của Flutter với tên workspace có ký tự `Đ` trên máy này. Source vẫn nằm trong thư mục gốc, không bị di chuyển hoặc sao chép. Script từ chối ghi đè nếu junction đã trỏ sang dự án khác.

Cache Gradle riêng đặt tại `%LOCALAPPDATA%\AsterHotel\gradle`, là đường dẫn ASCII vật lý. Gradle có thể resolve junction trở lại tên Unicode; cache trong thư mục source gây lỗi biên dịch Kotlin DSL trên môi trường này.

Để phát triển bằng hot reload trên trình duyệt, dừng server xem thử ở cổng 4173 trước rồi chạy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 run -d chrome --web-port=4173
```

Để build hoặc hot reload Android bằng toolchain đã chuẩn bị:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 doctor
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-android.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 run -d emulator-5554 --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1/
```

Source mặc định dùng `http://10.0.2.2:8000/api/v1/` cho Android. APK debug từ `build-android.ps1` dùng `http://127.0.0.1:8000/api/v1/` và `start-android.ps1` thiết lập `adb reverse tcp:8000 tcp:8000`; cách này đã kết nối được API trên giả lập của máy này khi mạng guest không truy cập được `10.0.2.2`. API vẫn chỉ bind loopback, không cần mở cổng ra mạng. Bản debug cho phép HTTP local. Bản release cần API HTTPS qua `--dart-define=API_BASE_URL=https://your-api.example/api/v1/` và cấu hình máy chủ tương ứng.

## API và quản trị

- Health: `GET /api/v1/health/`
- Đăng nhập: `POST /api/v1/auth/login/`
- Refresh: `POST /api/v1/auth/refresh/`
- Đăng xuất: `POST /api/v1/auth/logout/`
- Hồ sơ hiện tại: `GET /api/v1/me/`
- Tổng quan: `GET /api/v1/dashboard/`
- Phòng: `GET/POST /api/v1/rooms/`, `GET/PUT/PATCH /api/v1/rooms/{id}/`
- Đổi tình trạng: `POST /api/v1/rooms/{id}/condition/`
- Loại phòng: `/api/v1/room-types/`
- Khách hàng: `/api/v1/customers/`
- Phòng trống theo ngày: `GET /api/v1/rooms/availability/?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD&guests=1`
- Đặt phòng: `GET/POST /api/v1/bookings/`; POST cần UUID trong header `Idempotency-Key`.
- Hành động: `POST /api/v1/bookings/{id}/cancel/`, `check-in/`, `reschedule/`, `extend/`.
- Django Admin: `http://127.0.0.1:8000/admin/`; dùng tài khoản `admin` development.

Các endpoint nghiệp vụ yêu cầu `Authorization: Bearer <access>`. Danh sách có phân trang 30 bản ghi; hỗ trợ search và bộ lọc có kiểm tra dữ liệu. Mã lỗi được chuẩn hóa trong object `error`, kèm request ID. Không có endpoint xóa trực tiếp phòng/khách hàng trong bản đầu.

Schema tại `docs/openapi.yaml`. Swagger `/api/v1/docs/` và schema online được giới hạn cho admin đã xác thực; server chưa cấp session API tự động từ giao diện mobile. Dùng schema đã xuất để xem hợp đồng API hoặc đăng nhập Django Admin trước. JWT access hết hạn sau 15 phút; logout thu hồi refresh token, access đã cấp còn hiệu lực tới khi hết hạn. Tài khoản bị khóa bị chặn cả access và refresh.

## Backend và SQL Server

`hotel/models.py` chứa entity; serializer kiểm tra input, permission giới hạn vai trò và service quản lý transaction. Đặt phòng khóa UUID yêu cầu, khóa Shared danh mục rồi khóa Exclusive phòng bằng `sp_getapplock`, owner Transaction. Cập nhật danh mục lấy Exclusive cùng khóa để giá/sức chứa/tình trạng không đổi giữa lúc xác nhận. Đổi phòng khóa theo thứ tự ID. Lịch dùng khoảng `[ngày nhận, ngày trả)`, cho phép hai lượt giáp ngày. Các tranh chấp đặt phòng được kiểm tra bằng hai connection SQL Server độc lập.

Migrations blacklist của Simple JWT 5.5.1 được lưu tại `backend/jwt_migrations`, cùng license và mô tả thay đổi. Migration 0008 được chỉnh riêng cho SQL Server: bỏ tạm unique constraint phụ thuộc vào `token_id`, đổi kiểu khóa rồi khôi phục unique. Không fake migration hoặc bỏ blacklist. Bộ kiểm thử dựng schema từ database test mới để kiểm tra thay đổi này.

Cấu hình development tin chứng thư local tự ký và dùng tài khoản Windows hiện tại. Khi triển khai cần DEBUG=False, secret riêng, database user có quyền tối thiểu, HTTPS, chứng thư database hợp lệ, allowed hosts/CORS cụ thể và cơ chế hạn chế đăng nhập dùng cache chia sẻ. Bản hiện tại dùng throttling cache local của DRF cho development.

## Kiểm tra

Đợt dịch vụ ngày 24/10/2026 đã triển khai API, migration và UI. Xem [phạm vi và cách thử](docs/PHASE_03_SERVICES.md). Kiểm tra toàn luồng dịch vụ bằng fixture cô lập trên preview:

```powershell
node scripts/check-services-preview.cjs
```

UI mới giữ trạng thái bốn tab, dùng sheet có các trang nội bộ, chuyển động nhẹ và nhãn ngắn. Kiểm thử Flutter bao gồm Back, sửa đặt phòng ở bước Chốt, lỗi tại trường nhập, khóa đóng/gửi lặp khi lưu, cỡ chữ gấp đôi và bàn phím ở màn hình ngang.

Đợt rà soát thông tin/luồng ngày 15/10/2026: 41 tests Flutter và 52 tests backend đã đạt. Xem [chi tiết rà soát UI](docs/UI_REVIEW.md). Đối chiếu hồ sơ, lịch sử và bộ lọc bằng API local thật, không ghi dữ liệu nghiệp vụ:

```powershell
node scripts/check-detail-preview.cjs
```

Kiểm tra workflow trên bản web đã build, với API mô phỏng trong Playwright:

```powershell
node scripts/check-workflow-preview.cjs
```

Script chỉ cần preview ở cổng 4173 và Playwright tại `.tools/ui-check`. Nó chụp các màn vào `docs/screenshots/ui-*.png`; các thao tác thêm khách, đặt phòng, đổi lịch và hủy trong script không ghi vào SQL Server.

Kết quả phase 02: 43 tests backend trên SQL Server, 11 tests Flutter đã đạt. Ruff, Django check, migration check, OpenAPI validation và Flutter analyze đều đạt. Tests bao gồm gửi lặp, tranh chấp phòng, giáp ngày, giá lịch sử, bảo trì, đổi lịch/gia hạn, nhận phòng, phân quyền và CORS cho header idempotency; Flutter kiểm tra màn nhỏ/cỡ chữ lớn, giữ dữ liệu và mã yêu cầu khi submit lỗi, xác nhận check-in và quyền người quản lý. APK debug x86_64 đã build và cài thành công; đăng nhập lễ tân và đặt phòng trên Android đã gọi API thật.

```powershell
# Backend: SQL Server thật; tạo/xóa database test riêng
Set-Location backend
..\.venv\Scripts\python.exe -m pytest -q
Set-Location ..
.\.venv\Scripts\python.exe -m ruff check backend scripts/setup_local.py
.\.venv\Scripts\python.exe backend/manage.py check
.\.venv\Scripts\python.exe backend/manage.py makemigrations --check --dry-run

# Flutter
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 analyze --no-pub
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 test
```

Để chạy kiểm tra UI trên Edge với hai server đã bật:

```powershell
npm install --prefix .tools/ui-check playwright
node scripts/check-preview.cjs
```

Script dùng mật khẩu local từ `.env`, không in token/mật khẩu. Nó kiểm tra đăng nhập, dashboard thật, cập nhật phòng, lưu khách hàng và khôi phục phiên; dữ liệu phòng/ghi chú được khôi phục sau khi kiểm tra. Ảnh giao diện nằm trong `docs/screenshots`. Các bài kiểm thử Flutter sử dụng fake API để kiểm tra hành vi UI, còn kiểm tra trên Edge kết nối backend thật.

Kiểm tra trực tiếp Android sau khi mở app và đăng nhập `letan` hoặc `admin`:

```powershell
.\.venv\Scripts\python.exe -X utf8 scripts/check-android.py
```

Script kiểm tra đặt/hủy phòng và khôi phục phiên qua Android Keystore. Các bài smoke dùng khách giả đã seed, để lại lịch sử đặt phòng đã hủy; không xóa lịch sử hoặc để phòng bị chiếm. APK hiện dành cho giả lập x86_64, chưa kiểm tra điện thoại vật lý.

## Tiếp theo

Triển khai dịch vụ sử dụng, hóa đơn/thanh toán, check-out/dọn phòng và báo cáo doanh thu. Theo dõi kế hoạch đầy đủ tại `PLAN_DU_AN.md`.
