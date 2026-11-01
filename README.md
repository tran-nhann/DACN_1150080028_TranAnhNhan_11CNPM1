# Aster Hotel

Ứng dụng quản lý khách sạn trên Android bằng Flutter/Dart, Django REST Framework và SQL Server. Đã có đăng nhập ba vai trò, phòng, khách hàng, đặt phòng và nhận phòng. Mobile gọi API thật; dữ liệu được lưu trong SQL Server Express trên máy này.

## Phần đã chạy được

- Đăng nhập, khôi phục phiên, tự refresh access token, rotation refresh token và đăng xuất.
- Ba vai trò: `admin`, `receptionist`, `manager`; kiểm tra quyền ở API và điều hướng UI.
- Dashboard phòng sẵn sàng/đang ở/đã đặt/cần dọn/bảo trì, khách đến/đi và số khách đang ở.
- Tìm kiếm phòng, lọc trạng thái/tầng, phân trang, xem chi tiết và cập nhật tình trạng vận hành.
- Admin thêm/sửa phòng, mô tả, diện tích, giường, hướng nhìn, tiện nghi và ghi chú nội bộ; tải nhiều ảnh và chọn ảnh bìa. Danh mục loại phòng có API tạo/sửa, hiện seed sẵn bốn loại.
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

Server preview dùng mã build trong địa chỉ JavaScript, font/icon và tài nguyên đóng gói, đồng thời tắt cache HTTP để trình duyệt không giữ giao diện hoặc bộ icon cũ sau khi build lại. `start-dev.ps1` tự chuyển server preview cũ sang cách phục vụ này.

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
.\.venv\Scripts\python.exe scripts/serve_preview.py
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

Trong app, đăng nhập **admin → Phòng → chọn phòng → biểu tượng Sửa phòng** để cập nhật thông tin và hình ảnh. Nút **+** mở form thêm phòng với cùng các mục. Chi tiết phòng hiển thị ảnh bìa, thư viện ảnh có thể phóng to, thông số, mô tả, tiện nghi, ghi chú và lịch đặt. Phòng cũ chưa nhập thông số/ảnh sẽ hiển thị trạng thái chưa cập nhật; không tự điền thông tin giả.

Thông số phòng hiển thị theo hàng `Nhãn: giá trị`, giá trị in đậm. Thanh nút chính của đặt phòng mới, đổi lịch/phòng, xác nhận gia hạn và thêm/sửa phòng nằm cố định bên dưới vùng nội dung cuộn; khi mở bàn phím, thanh này nằm phía trên bàn phím. Lịch đặt có mã riêng và màu theo ngày đến: hôm nay màu cam, ngày mai xanh dương, còn nhiều ngày tím, trễ ngày nhận đỏ; lịch đã hủy dùng thẻ hồng nhạt và nhãn Đã hủy. Các nhãn này tính theo ngày khách sạn, không suy diễn giờ nhận phòng khi dữ liệu chưa lưu giờ cụ thể.

Mỗi phòng tối đa 10 ảnh JPG/PNG/WebP, mỗi ảnh tối đa 5 MB và 25 triệu điểm ảnh. Chọn biểu tượng ngôi sao để đặt ảnh bìa; thao tác xóa/chọn ảnh chỉ được ghi nhận khi lưu phòng. Ảnh lưu tại `backend/media/` (không đưa vào Git); cần sao lưu thư mục này cùng database. Development phục vụ ảnh qua `/media/` khi `DEBUG=True`; production cần cấu hình web server/storage phục vụ `MEDIA_URL`.

Bộ ảnh mẫu có sẵn tại `backend/hotel/demo_assets/rooms/`: 4 loại phòng × 3 ảnh (phòng ngủ, góc nội thất, phòng tắm). Đây là ảnh nội thất hư cấu tạo bằng AI cho bản demo. Các phòng cùng loại dùng chung bộ ảnh mẫu; file phục vụ được sao chép riêng cho từng phòng nên sửa/xóa ảnh một phòng không ảnh hưởng phòng khác. Nạp ảnh cho phòng chưa có gallery bằng lệnh dưới; chạy lại không tạo trùng hoặc ghi đè gallery đã nhập:

```powershell
.\.venv\Scripts\python.exe backend/manage.py seed_room_images
```

API tạo/sửa phòng nhận JSON cho thông tin. Khi kèm ảnh, gửi multipart gồm `data` (chuỗi JSON) và các file lặp tên `upload_images`. `image_ids` là danh sách ID ảnh giữ lại theo thứ tự (bỏ trường này để giữ toàn bộ ảnh cũ, gửi `[]` để bỏ toàn bộ); `cover_upload_index` là chỉ số từ 0 của ảnh tải mới được chọn làm bìa. Lưu thông tin và thư viện ảnh trong cùng transaction; chỉ admin được ghi, các vai trò còn lại được xem.

- Health: `GET /api/v1/health/`
- Đăng nhập: `POST /api/v1/auth/login/`
- Refresh: `POST /api/v1/auth/refresh/`
- Đăng xuất: `POST /api/v1/auth/logout/`
- Hồ sơ hiện tại: `GET /api/v1/me/`
- Tổng quan: `GET /api/v1/dashboard/`
- Phòng: `GET/POST /api/v1/rooms/`, `GET/PUT/PATCH /api/v1/rooms/{id}/`
- Đổi tình trạng: `POST /api/v1/rooms/{id}/condition/`
- Loại phòng: `/api/v1/room-types/`
- Bộ lọc phòng kết hợp: `GET /api/v1/rooms/?room_type=1&floor=2&status=ready&search=201` (bỏ trường không chọn). Trên app mở **Phòng → Bộ lọc phòng** để chọn hạng, tầng và trạng thái; nút Xóa bộ lọc đặt lại ba lựa chọn.
- Danh mục dịch vụ: `GET/POST /api/v1/services/`, `GET/PUT/PATCH/DELETE /api/v1/services/{id}/`. Hồ sơ có nhóm, mô tả, ảnh, đơn vị, giá, ghi chú, trạng thái, ngày tạo/cập nhật và số khoản sử dụng. Admin mở chi tiết để sửa/xóa; DELETE trả 409 nếu đã có lịch sử sử dụng, kể cả khoản đã hủy. Có thể ngừng bán để giữ lịch sử.
- Ảnh dịch vụ: gửi multipart trường `image` cùng các trường thông tin, hoặc JSON `remove_image: true` để bỏ ảnh; JPG/PNG/WebP tối đa 5 MB và 25 triệu điểm ảnh. File cũ chỉ xóa sau khi transaction thành công.
- Doanh thu ước tính (admin/quản lý): `GET /api/v1/reports/revenue-estimate/?start_date=2026-10-01&end_date=2026-11-01`. Kỳ `[start_date, end_date)` tối đa 366 ngày, mặc định tháng hiện tại. App có thẻ trên Tổng quan và mục **Thêm → Doanh thu ước tính**, chọn ngày/kỳ, biểu đồ và tổng theo hạng phòng hiện tại.
- Khách hàng: `/api/v1/customers/`
- Phòng trống theo ngày: `GET /api/v1/rooms/availability/?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD&guests=1`
- Đặt phòng: `GET/POST /api/v1/bookings/`; POST cần UUID trong header `Idempotency-Key`.
- Đặt kèm dịch vụ ngay khi chọn phòng: POST booking nhận `services: [{service_id, quantity, expected_unit_price}]` tùy chọn; lưu cùng booking trong một transaction. Trước check-in có API `planned-services/` để bổ sung/hủy, check-in chuyển khoản vào lưu trú một lần. Xem [dịch vụ qua bốn thời điểm](docs/PHASE_05_SERVICE_LIFECYCLE.md).
- Hành động: `POST /api/v1/bookings/{id}/cancel/`, `check-in/`, `reschedule/`, `extend/`.
- Trả phòng: `GET /api/v1/bookings/{id}/folio/` → `POST /api/v1/bookings/{id}/check-out/`. Thu đủ bằng tiền mặt/chuyển khoản, giữ mã yêu cầu chống gửi lặp, chốt hóa đơn và chuyển Cần dọn trong cùng transaction. Chi tiết tại [Check-out và billing](docs/PHASE_04_CHECKOUT_BILLING.md).
- Hóa đơn/phiếu thu: `GET /api/v1/invoices/`, `GET /api/v1/invoices/{id}/`; trên app **Thêm → Hóa đơn & phiếu thu** hoặc mở booking Đã trả. Hồ sơ giữ nguyên giá và thông tin lúc chốt, không sửa/xóa trực tiếp.
- Xác nhận dọn phòng: `POST /api/v1/rooms/{id}/confirm-cleaned/` với `expected_updated_at`. Có nút trên hồ sơ phòng và truy cập từ ô Cần dọn trong sơ đồ lịch.
- Django Admin: `http://127.0.0.1:8000/admin/`; dùng tài khoản `admin` development.

Các endpoint nghiệp vụ yêu cầu `Authorization: Bearer <access>`. Danh sách có phân trang 30 bản ghi; hỗ trợ search và bộ lọc có kiểm tra dữ liệu. Mã lỗi được chuẩn hóa trong object `error`, kèm request ID. Không có endpoint xóa trực tiếp phòng/khách hàng trong bản đầu.

Schema tại `docs/openapi.yaml`. Swagger `/api/v1/docs/` và schema online được giới hạn cho admin đã xác thực; server chưa cấp session API tự động từ giao diện mobile. Dùng schema đã xuất để xem hợp đồng API hoặc đăng nhập Django Admin trước. JWT access hết hạn sau 15 phút; logout thu hồi refresh token, access đã cấp còn hiệu lực tới khi hết hạn. Tài khoản bị khóa bị chặn cả access và refresh.

## Backend và SQL Server

`hotel/models.py` chứa entity; serializer kiểm tra input, permission giới hạn vai trò và service quản lý transaction. Đặt phòng khóa UUID yêu cầu, khóa Shared danh mục rồi khóa Exclusive phòng bằng `sp_getapplock`, owner Transaction. Cập nhật danh mục lấy Exclusive cùng khóa để giá/sức chứa/tình trạng không đổi giữa lúc xác nhận. Đổi phòng khóa theo thứ tự ID. Lịch dùng khoảng `[ngày nhận, ngày trả)`, cho phép hai lượt giáp ngày. Các tranh chấp đặt phòng được kiểm tra bằng hai connection SQL Server độc lập.

Migrations blacklist của Simple JWT 5.5.1 được lưu tại `backend/jwt_migrations`, cùng license và mô tả thay đổi. Migration 0008 được chỉnh riêng cho SQL Server: bỏ tạm unique constraint phụ thuộc vào `token_id`, đổi kiểu khóa rồi khôi phục unique. Không fake migration hoặc bỏ blacklist. Bộ kiểm thử dựng schema từ database test mới để kiểm tra thay đổi này.

Cấu hình development tin chứng thư local tự ký và dùng tài khoản Windows hiện tại. Khi triển khai cần DEBUG=False, secret riêng, database user có quyền tối thiểu, HTTPS, chứng thư database hợp lệ, allowed hosts/CORS cụ thể và cơ chế hạn chế đăng nhập dùng cache chia sẻ. Bản hiện tại dùng throttling cache local của DRF cho development.

## Kiểm tra

Kiểm tra form phòng và thư viện ảnh trên preview (fixture riêng, không ghi database khách sạn):

```powershell
node scripts/check-rooms-preview.cjs
```

Kiểm tra trình duyệt có service worker cũ vẫn tải bản hiện tại và admin thật mở được form phòng (chỉ đăng nhập/đọc dữ liệu):

```powershell
node scripts/check-preview-cache.cjs
```

Kiểm tra thông số ngang, icon mô tả, lịch có màu/nhãn ngày đến và các nút cố định với danh sách 30 phòng (fixture riêng):

```powershell
node scripts/check-room-layout-preview.cjs
```

Sau khi nạp ảnh mẫu, kiểm tra toàn bộ ảnh bằng API thật, thử tải ảnh/đổi bìa/xóa ảnh thử rồi khôi phục gallery, và mở thư viện 4 loại phòng trên giao diện admin:

```powershell
node scripts/check-room-images-live.cjs
```

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

Đợt 31/10/2026 đã đối chiếu file đề cương Word; xem [bảng đối chiếu yêu cầu và phần còn thiếu](docs/DE_CUONG_GAP_REVIEW.md). Phần ước tính phân bổ giá phòng lúc đặt theo đêm trong kỳ, cộng dịch vụ theo ngày ghi và giá chốt; loại lịch/khoản đã hủy. Báo cáo có thêm **Đã thu trong kỳ** từ phiếu thu thật (`collected_total`, `cash_total`, `bank_total`, `payment_count`), tính theo ngày nhận tiền tại múi giờ khách sạn. Không lấy giá danh mục hiện tại để tính lại lịch sử.

Kiểm tra riêng bộ lọc, hồ sơ dịch vụ và báo cáo bằng `flutter test test/catalog_reports_test.dart`, API bằng `pytest -q tests/test_catalog_reports.py` từ thư mục tương ứng. Kiểm tra Edge trên preview: `node scripts/check-catalog-revenue-preview.cjs` (đăng nhập thật; tạo/sửa/xóa một dịch vụ thử riêng, không thay đổi phòng hoặc booking).

Luồng thu đủ tiền/chốt hóa đơn/trả phòng/dọn phòng đã có. Chưa có phụ thu/giảm giá/cọc/hoàn tiền/công nợ, quản lý tài khoản/loại phòng trên app và lịch sử công suất. **SQL Server đã được duyệt**, là công nghệ chính thức; các đoạn PostgreSQL trong đề cương gốc cần đổi trong thuyết minh. Theo dõi kế hoạch đầy đủ tại `PLAN_DU_AN.md`.
