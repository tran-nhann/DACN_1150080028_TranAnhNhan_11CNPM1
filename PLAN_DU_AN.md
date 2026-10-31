# Kế hoạch xây dựng ứng dụng di động quản lý khách sạn

Ngày lập: 14/10/2026. Mốc hoàn thành kỹ thuật dự kiến: 15/11/2026.

Nền tảng đã chốt theo cập nhật của người dùng: Flutter và Dart cho ứng dụng, Python và Django REST Framework cho Web API, Microsoft SQL Server cho dữ liệu. Chất lượng được đánh giá bằng giao diện sử dụng thuận tiện, luồng nghiệp vụ chạy hoàn chỉnh và kiểm thử các tình huống sai dữ liệu, tranh chấp đặt phòng và tính tiền.

## 1. Căn cứ và hiện trạng

- Đã đọc nội dung đề cương tại `C:\Users\Thang\Downloads\11ĐHCNPM1_TranAnhNhan_DECUONGDOANCN.docx`.
- Người dùng đã đổi database sang SQL Server. File đề cương gốc vẫn ghi PostgreSQL; cần đồng bộ phần công nghệ, công cụ và mô tả cài đặt khi cập nhật báo cáo. Kế hoạch này sử dụng lựa chọn mới của người dùng.
- Tên đề tài: Xây dựng ứng dụng di động quản lý khách sạn.
- Phạm vi: một khách sạn; ba vai trò quản trị viên, lễ tân, người quản lý; quản lý tài khoản, phòng, loại phòng, khách hàng, đặt phòng, lưu trú, dịch vụ, hóa đơn, thanh toán và thống kê.
- Đã triển khai nền tảng phase 01 tại `backend`, `mobile`, `scripts` và `docs`: đăng nhập/phân quyền, dashboard vận hành, danh mục phòng và khách hàng. Chi tiết cách chạy ở `README.md`.
- SQL Server 2022 Express instance `SQLEXPRESS` đang chạy; ODBC Driver 18 đã có. Django kết nối Windows Authentication tới database riêng `HotelManagementDev`. Đã cài Flutter 3.47.7/Dart 3.13.5 riêng trong `.tools/flutter`; Android SDK chưa có nên bản xem thử hiện dùng Flutter Web. Docker Engine chưa chạy trong lần kiểm tra.
- Đề cương ghi thời gian 24/08–15/11/2026 và 12 tuần, nhưng bảng kế hoạch có 15 tuần tới 06/12/2026. Kế hoạch kỹ thuật này dùng mốc sớm 15/11; cần thống nhất mốc nộp chính thức với giảng viên.
- Mục 2.6 mang tên dự báo nhu cầu nhưng nội dung mô tả thống kê. Phạm vi hiện tại là tổng hợp và biểu đồ; việc bổ sung mô hình dự báo cần yêu cầu riêng, dữ liệu phù hợp và cách đánh giá riêng.
- Lịch bên dưới giả định một người làm đều khoảng 4–6 giờ/ngày và đã biết lập trình cơ bản. Đây là ước lượng để tổ chức công việc, chưa phải cam kết tiến độ đã kiểm chứng.

## 2. Công nghệ

**Các công nghệ đã chốt cho bản triển khai**

| Thành phần | Công nghệ | Vai trò |
| --- | --- | --- |
| Ứng dụng di động | Flutter và Dart | Giao diện và tương tác trên thiết bị di động |
| Máy chủ | Python, Django, Django REST Framework | API, phân quyền và nghiệp vụ |
| Cơ sở dữ liệu | Microsoft SQL Server | Dữ liệu tập trung, giao dịch, ràng buộc toàn vẹn |
| Giao diện | Material Design, thư viện biểu đồ Flutter | Thành phần giao diện và thống kê |
| Công cụ | VS Code, Android Studio, SQL Server Management Studio (SSMS), Git | Phát triển, giả lập, quản lý dữ liệu và mã nguồn |
| Kiểm tra API | Postman | Thử luồng API và lưu bộ request phục vụ demo |

**Các bổ sung đề xuất**

| Thành phần | Lựa chọn | Mục đích |
| --- | --- | --- |
| Trạng thái Flutter | flutter_riverpod | Quản lý dữ liệu bất đồng bộ và tách logic khỏi widget |
| Điều hướng | go_router | Các tuyến màn hình và điều hướng theo phiên đăng nhập |
| Gọi API | Dio | Timeout, interceptor, chuyển lỗi API thành thông báo dễ hiểu |
| Lưu phiên | flutter_secure_storage | Lưu refresh token trong vùng lưu trữ bảo mật của nền tảng |
| Model JSON | json_serializable; Freezed khi cần | Chuyển đổi dữ liệu nhất quán, giảm lỗi model |
| Biểu đồ | fl_chart | Biểu đồ doanh thu, đặt phòng, tỷ lệ sử dụng phòng |
| Xác thực | Simple JWT | Access token, refresh token và thu hồi refresh token |
| Tài liệu API | drf-spectacular | OpenAPI, Swagger UI và hợp đồng dữ liệu |
| Kết nối database | mssql-django, pyodbc, Microsoft ODBC Driver 18 for SQL Server | Backend Django kết nối SQL Server với `ENGINE = 'mssql'` |
| Kiểm thử BE | pytest, pytest-django | Nghiệp vụ, quyền truy cập, API và tranh chấp dữ liệu |
| Kiểm tra mã | Ruff; dart format và flutter analyze | Kiểm tra định dạng và lỗi tĩnh |
| Môi trường | Docker Compose | SQL Server và API có cấu hình tái lập; có thể kết nối SQL Server cài sẵn trên Windows |
| Triển khai API | Gunicorn và reverse proxy HTTPS | Chạy bản demo trên máy chủ |

Phase 01 dùng Python 3.12.10, Django 5.2.18, DRF 3.18.3, mssql-django 2.0.0, Simple JWT 5.5.1, Flutter 3.47.7 và SQL Server 2022 Express hiện có trên máy. Phiên bản Python dependencies được khóa trong `backend/requirements.txt`, Flutter dependencies trong `mobile/pubspec.lock`. Đã kiểm tra kết nối, migrations từ database mới và xác thực trên SQL Server thật. Migrations blacklist JWT có bản điều chỉnh tương thích SQL Server trong `backend/jwt_migrations`, kèm license và giải thích; không fake migration hay vô hiệu hóa blacklist.

Cấu hình kết nối lấy server, port, database, user và password từ biến môi trường; khai báo `ENGINE = 'mssql'` và ODBC Driver 18 cho nhánh pyodbc. Tài khoản API có quyền tối thiểu, tách tài khoản chạy migrations; không dùng `sa` cho ứng dụng. Kết nối triển khai dùng mã hóa và xác minh chứng thư. Nếu chạy Docker, API container cần cài ODBC Driver tương ứng và database có volume bền vững. Kiểm thử migrations, Unicode tiếng Việt, Decimal, unique/check constraints, báo cáo ngày và datetime ngay khi dựng môi trường vì backend SQL Server có các giới hạn cần đối chiếu theo phiên bản.

Android là nền tảng nghiệm thu đầu tiên trên môi trường Windows hiện tại. Giữ mã Flutter có khả năng mở rộng sang iOS, nhưng build và kiểm tra iOS là phần việc riêng cần môi trường macOS.

## 3. Kiến trúc và tổ chức mã nguồn

Luồng xử lý: Flutter → HTTPS REST API `/api/v1/` → Django xử lý nghiệp vụ → SQL Server → API trả dữ liệu → Flutter cập nhật giao diện.

Ứng dụng tổ chức theo tính năng, với giao diện, controller/provider và repository/API service tách riêng. Django tổ chức thành các module nghiệp vụ trong một ứng dụng máy chủ; các thao tác đặt phòng, nhận phòng, trả phòng và thanh toán nằm trong service có giao dịch rõ ràng.

```text
project/
  mobile/
    lib/
      core/              # API client, theme, session, router, UI dùng chung
      features/
        auth/
        dashboard/
        rooms/
        customers/
        bookings/
        stays/
        services/
        billing/
        accounts/
    test/
    integration_test/
  backend/
    config/
    apps/
      accounts/
      rooms/
      customers/
      bookings/
      stays/
      services/
      billing/
      reports/
      audit/
    tests/
  docs/                  # Yêu cầu, ERD, UML, API, kiểm thử và tài liệu demo
  compose.yaml
  .env.example
  README.md
  PLAN_DU_AN.md
```

Các quy tắc giá, quyền và trạng thái được quyết định ở API. Mobile có thể hiển thị tiền ước tính và kiểm tra form, nhưng phải dùng kết quả xác nhận từ máy chủ. Tách cấu hình development/demo; không đưa mật khẩu và khóa bí mật vào Git.

## 4. Phạm vi và quyền truy cập

| Nhóm | Quyền dự kiến |
| --- | --- |
| Quản trị viên | Quản lý tài khoản, vai trò, loại phòng, phòng, dịch vụ, cấu hình và tra cứu nhật ký |
| Lễ tân | Quản lý khách hàng, đặt/hủy/đổi lịch/gia hạn, check-in, dịch vụ, check-out, hóa đơn và thu tiền |
| Người quản lý | Xem tình trạng phòng, doanh thu, đặt phòng, khách lưu trú; duyệt điều chỉnh hóa đơn nếu có |

Chốt ma trận quyền tới từng hành động và trường dữ liệu. Phân quyền phải áp dụng ở API, queryset và serializer; giao diện cũng cần ẩn hành động không được phép. Những quyền sửa giá, giảm giá, hủy hóa đơn và xem giấy tờ khách hàng cần được ghi riêng.

Các luồng bắt buộc:

1. Đăng nhập, duy trì phiên, đăng xuất, khóa tài khoản và quản lý vai trò.
2. Quản lý loại phòng, phòng, tầng, sức chứa, giá và trạng thái vệ sinh/bảo trì.
3. Quản lý khách hàng, tìm kiếm và lịch sử lưu trú.
4. Chọn khoảng ngày → tìm phòng phù hợp → tạo booking → xác nhận; hỗ trợ hủy, đổi lịch, gia hạn có kiểm tra lại.
5. Check-in từ booking; khách vãng lai được tạo booking và check-in theo cùng quy tắc.
6. Ghi nhận các dịch vụ đã dùng, số lượng, đơn giá và thời điểm sử dụng.
7. Xem chi phí → lập hóa đơn → ghi nhận thanh toán → check-out → chuyển phòng sang cần dọn.
8. Xác nhận dọn xong, ghi nhận/kết thúc bảo trì.
9. Dashboard tình trạng phòng, lượt đặt, khách lưu trú và doanh thu theo ngày/khoảng thời gian.

Thanh toán ban đầu là ghi nhận tiền mặt hoặc chuyển khoản đã được lễ tân xác nhận. Có thể ghi nhận tiền cọc trong cùng sổ thanh toán và đối trừ khi quyết toán; không tích hợp cổng thanh toán ở phạm vi đầu tiên. Hóa đơn phục vụ quản lý nội bộ của đồ án.

Xuất PDF, ảnh phòng và dark mode xếp sau các luồng bắt buộc. Đa chi nhánh, đồng bộ nền tảng đặt phòng bên ngoài, kho, nhân sự và mô hình AI để giai đoạn mở rộng.

## 5. Thiết kế giao diện

Hướng đề xuất: giao diện quản lý khách sạn hiện đại, nền sáng, chữ rõ, xanh đậm làm màu chính và xanh ngọc làm màu hành động. Màu trạng thái phòng chỉ dùng ở badge, icon và các vùng nhỏ để màn hình dễ đọc.

**Bộ quy tắc giao diện**

- Material Design phù hợp phiên bản Flutter được chọn, với theme và component chung; ưu tiên Material 3 nếu SDK cung cấp ổn định.
- Bảng màu ban đầu: nền `#F6F8FC`, chữ `#172B4D`, màu chính `#173B66`, nhấn `#0F766E`; kiểm tra độ tương phản trước khi chốt.
- Font hỗ trợ đầy đủ tiếng Việt, tiêu đề rõ cấp độ; nội dung chính khoảng 14–16 logical px, khoảng cách theo nhịp 8.
- Card bo góc 12–16, bóng nhẹ, khoảng trắng đủ; icon cùng một bộ.
- Badge trạng thái luôn có chữ và icon, không chỉ khác nhau bằng màu.
- Vùng chạm chính ít nhất 48 logical px; kiểm tra màn hình nhỏ, bàn phím, phóng to chữ và xoay màn hình khi phù hợp.
- Danh sách có loading/skeleton, rỗng, lỗi và thử lại; form giữ dữ liệu khi lỗi kết nối.
- Sau thao tác có phản hồi rõ, nút đang gửi bị khóa; màn hình đọc có kéo để làm mới và cập nhật lại sau nghiệp vụ.

**Các màn hình ưu tiên**

| Màn hình | Thiết kế và mục tiêu |
| --- | --- |
| Đăng nhập | Form gọn, thông báo lỗi rõ, tên ứng dụng và vai trò sau đăng nhập |
| Tổng quan | Phòng sẵn sàng, đang ở, cần dọn; khách đến/đi hôm nay; chỉ hiện doanh thu với vai trò được phép |
| Phòng | Grid/card theo tầng, bộ lọc trạng thái/loại; chọn khoảng ngày để xem khả dụng |
| Chi tiết phòng | Thông tin, tình trạng hiện tại, lịch đặt, thao tác phù hợp quyền |
| Đặt phòng | Các bước khách hàng → ngày/phòng → xem lại giá → xác nhận |
| Lịch đặt | Danh sách theo ngày, tìm kiếm, filter trạng thái, chi tiết và thao tác |
| Lưu trú | Khách đang ở, thời gian thực tế, dịch vụ và thao tác trả phòng |
| Hóa đơn | Các dòng tiền rõ ràng, tiền đã nhận, còn phải thu và lịch sử thanh toán |
| Báo cáo | Bộ lọc thời gian, KPI, biểu đồ doanh thu và bảng đối chiếu |
| Quản trị | Tài khoản, loại phòng, dịch vụ; danh sách có tìm kiếm và form nhất quán |

Bottom navigation dự kiến: Tổng quan, Phòng, Đặt phòng, Thêm. Hóa đơn, khách hàng và quản trị nằm trong mục Thêm hoặc được mở trực tiếp từ luồng lưu trú. Tablet dùng bố cục rộng hơn. Duyệt thiết kế ba màn hình Tổng quan, Phòng và Đặt phòng trước khi nhân rộng, vì chúng xác định phần lớn phong cách và tương tác.

## 6. Dữ liệu và nghiệp vụ backend

**Các thực thể chính**

`User/Role`, `Customer`, `RoomType`, `Room`, `Booking`, `RoomAllocation`, `Stay`, `Service`, `ServiceUsage`, `Invoice`, `InvoiceLine`, `Payment`, `AuditLog`.

MVP: một booking gắn một phòng; danh sách khách lưu trú liên kết với Stay để thống kê số khách thực tế. `RoomAllocation` lưu `start_date`, `end_date`, `is_active`, liên kết booking hoặc lịch bảo trì; database có CHECK `start_date < end_date` và index phục vụ tra cứu theo phòng/ngày. Lịch bảo trì chưa có ngày kết thúc phải được mô hình hóa riêng và chặn khả dụng rõ ràng. Một Stay gắn một booking; một hóa đơn quyết toán gắn một Stay; nhiều Payment gắn hóa đơn hoặc booking có cọc với liên kết đối trừ rõ ràng.

**A. Chống đặt phòng trùng**

- MVP tính theo đêm, dùng khoảng ngày nửa mở `[ngày nhận, ngày trả)`. Khách trả ngày 20 và khách khác nhận ngày 20 không tự động bị xem là trùng; nhận phòng vẫn cần trạng thái đã dọn.
- Kiểm tra allocation đang hiệu lực theo điều kiện `existing.start_date < requested.end_date AND existing.end_date > requested.start_date`, cùng phòng. CHECK thời gian và unique key thông thường không đủ để ngăn các khoảng ngày chồng lấn.
- Booking xác nhận, đang lưu trú và khoảng bảo trì đều chặn lịch; hủy booking giải phóng allocation trong cùng transaction. Booking kết thúc giữ lịch sử khoảng lưu trú đã kết thúc.
- Khi tạo, hủy, đổi lịch, gia hạn, chuyển phòng hoặc tạo/kết thúc bảo trì: dùng `transaction.atomic()` trên kết nối SQL Server với isolation READ COMMITTED. Trước khi đọc và ghi lịch, gọi `sp_getapplock` với resource thống nhất `hotel:room:{id}`, LockMode Exclusive, LockOwner Transaction và timeout hữu hạn. Khóa được giữ tới commit/rollback; phải kiểm tra mã trả về trước khi tiếp tục. Không chỉ kiểm tra phòng trống rồi INSERT ngoài transaction.
- Sau khi lấy khóa, kiểm tra lại lịch và trạng thái, loại bản ghi đang được sửa khỏi phép kiểm tra xung đột, rồi cập nhật trong cùng transaction. Mọi nghiệp vụ ảnh hưởng phòng dùng cùng resource khóa; nếu tác động nhiều phòng, lấy khóa theo thứ tự ID tăng dần để giảm deadlock. Check-in/check-out cũng dùng cùng cơ chế khóa phòng và bảo vệ bản ghi booking/Stay liên quan.
- Xung đột lịch trả HTTP 409 và thông báo tiếng Việt. Timeout khóa hoặc deadlock phải rollback, có thông báo thử lại phù hợp và chỉ retry có giới hạn khi toàn thao tác được bảo vệ khỏi gửi lặp. Không đưa lỗi SQL ra ứng dụng hoặc tiếp tục transaction đã lỗi.
- Mọi đường ghi dữ liệu, gồm Django Admin và script nhập dữ liệu, phải gọi cùng service có khóa và kiểm tra nghiệp vụ. Application lock chỉ bảo vệ các writer cùng tuân thủ cơ chế này; để bảo vệ thêm trước đường ghi SQL trực tiếp, có thể đóng gói allocation write trong stored procedure và giới hạn quyền DML trực tiếp của tài khoản runtime. Không bật sửa allocation bằng CRUD/Admin mặc định.
- Kiểm thử bằng hai connection SQL Server độc lập: hai yêu cầu cùng phòng và lịch chỉ có một thành công; lặp lại với database đang dùng READ_COMMITTED_SNAPSHOT nếu cấu hình triển khai bật tùy chọn này. Không dùng isolation SNAPSHOT cho luồng kiểm tra rồi ghi lịch nếu chưa chứng minh việc đọc không dùng dữ liệu cũ.

**B. Trạng thái và khả dụng**

- Trạng thái vận hành/vệ sinh của phòng tách khỏi lịch đặt. Phòng có booking tháng sau vẫn có thể trống hôm nay.
- Khả dụng theo khoảng ngày được tính từ allocation và lịch bảo trì. Trạng thái hiển thị như Trống, Đã đặt, Đang ở, Cần dọn, Bảo trì được suy ra theo ngữ cảnh ngày xem.
- Booking dự kiến: confirmed → checked_in → checked_out; confirmed → cancelled/no_show. Chặn chuyển trạng thái trái quy tắc.
- Check-in yêu cầu booking hợp lệ, chưa nhận phòng, phòng đã sẵn sàng và không bảo trì. Lấy application lock theo phòng và bảo vệ booking trong cùng transaction trước khi chuyển trạng thái.
- Check-out yêu cầu đang lưu trú, hóa đơn hợp lệ và điều kiện thanh toán đã chốt; chuyển phòng sang cần dọn. Dọn xong mới được nhận khách tiếp.
- Ghi thời điểm thực tế bằng datetime có timezone ở Python; quy ước lưu UTC trong SQL Server và hiển thị Asia/Ho_Chi_Minh. Kiểm thử round-trip timezone với mssql-django và kiểu cột được migration tạo. Ngày tính đêm theo múi giờ khách sạn; ưu tiên chuyển ranh giới khoảng lọc về UTC ở service trước khi truy vấn để tránh phụ thuộc vào các phép chuyển timezone chưa được backend hỗ trợ đầy đủ.

**C. Giá, hóa đơn và thanh toán**

- Chốt chính sách tính đêm, trả sớm/trễ, phụ thu, giảm giá và cọc trước khi code. MVP đề xuất giá cố định theo đêm; thay đổi số đêm phải được xác nhận trước khi quyết toán.
- Tiền dùng Decimal ở API/database; truyền dưới dạng decimal string hoặc integer VND theo hợp đồng API, không dùng float để tính tiền.
- Lưu giá phòng tại thời điểm xác nhận booking và giá dịch vụ tại thời điểm sử dụng. Giá danh mục thay đổi không làm biến đổi hóa đơn cũ.
- Tổng hóa đơn = tiền phòng + tiền dịch vụ + phụ thu − giảm giá. Số còn phải thu = tổng hóa đơn − tổng thanh toán hợp lệ đã phân bổ; tiền cọc chỉ được phân bổ một lần.
- API tính lại tổng từ dữ liệu đã lưu, không tin tổng tiền mobile gửi. Ràng buộc giá không âm, số lượng dương và giảm giá trong giới hạn được phép.
- Giới hạn một hóa đơn quyết toán trên một Stay và dùng idempotency key cho thao tác tạo booking, quyết toán và ghi thanh toán. Khóa unique gắn người dùng/hành động/key; cùng key khác nội dung phải bị từ chối.
- Lần gửi lại do timeout trả kết quả đã tạo, không sinh booking/hóa đơn/thanh toán thứ hai. Việc khóa nút ở mobile chỉ là hỗ trợ trải nghiệm.
- Hóa đơn đã chốt không được sửa/xóa trực tiếp; điều chỉnh hoặc hủy theo quyền, có lý do và nhật ký. Khóa ngoại bảo vệ lịch sử; phòng/dịch vụ/tài khoản đã phát sinh giao dịch dùng vô hiệu hóa khi cần.

**D. API, an toàn và vận hành**

- API có phân trang, tìm kiếm, bộ lọc được giới hạn và cấu trúc lỗi chung gồm code, message, field_errors, request_id.
- Quyền tối thiểu mặc định, kiểm tra từng hành động, chống ghi đè trường role/price/status bằng request không hợp lệ.
- Refresh token lưu bảo mật ở mobile; access token ngắn hạn, rotation/blacklist refresh và kiểm tra tài khoản active. Không ghi token, mật khẩu hoặc giấy tờ khách hàng đầy đủ vào log.
- Giới hạn yêu cầu đăng nhập và cơ chế chống thử mật khẩu phù hợp khi công khai máy chủ; DRF throttling chỉ là một phần kiểm soát lưu lượng.
- Khi mất mạng, hiển thị trạng thái và cho làm mới dữ liệu; các nghiệp vụ thay đổi đặt phòng/thanh toán cần xác nhận trực tuyến. Không tự retry POST nếu chưa có idempotency key.
- Query có index cho phòng/khoảng ngày, trạng thái booking, ngày thanh toán; dùng select_related/prefetch_related khi cần. Báo cáo tổng hợp ở DB, không tải toàn bộ dữ liệu xuống mobile.
- Máy chủ demo dùng HTTPS, DEBUG=False, biến môi trường, health check, log có request_id; SQL Server dùng mạng nội bộ, không public cổng database. Có backup SQL Server và thực hành khôi phục trước buổi bảo vệ.

## 7. API dự kiến

| Nhóm | Các đường dẫn chính |
| --- | --- |
| Tài khoản | `/auth/login/`, `/auth/refresh/`, `/auth/logout/`, `/me/`, `/users/` |
| Phòng | `/room-types/`, `/rooms/`, `/rooms/availability/`, `/rooms/{id}/mark-clean/`, `/room-blocks/` |
| Khách hàng | `/customers/`, `/customers/{id}/stays/` |
| Đặt phòng | `/bookings/`, `/bookings/{id}/cancel/`, `/bookings/{id}/reschedule/`, `/bookings/{id}/extend/` |
| Lưu trú | `/bookings/{id}/check-in/`, `/stays/`, `/stays/{id}/charges/`, `/stays/{id}/checkout-preview/`, `/stays/{id}/check-out/` |
| Thanh toán | `/invoices/`, `/invoices/{id}/payments/` và endpoint tiền cọc nếu bật nghiệp vụ cọc |
| Thống kê | `/reports/overview/`, `/reports/revenue/`, `/reports/occupancy/` |

Mọi đường dẫn có prefix `/api/v1/`. Chốt request/response, quyền, mã lỗi và hành vi gửi lại trước khi nối mobile. POST dùng cho các chuyển trạng thái; không cho PATCH tự do trạng thái nghiệp vụ.

## 8. Tiến độ từ 14/10 đến 15/11/2026

| Thời gian | Công việc | Điều kiện hoàn thành |
| --- | --- | --- |
| 14–16/10 | Chốt nghiệp vụ, quyền, tính đêm/tiền, ERD/UML, phác thảo 3 màn hình; kiểm tra SDK, SQL Server, ODBC và dựng môi trường | Có phạm vi, schema, API mẫu và thiết kế; Django kết nối SQL Server, migrations và kiểm tra driver/Unicode/Decimal/ngày đạt; API health check, Flutter chạy trên Android |
| 17–21/10 | Custom User từ đầu, đăng nhập/phân quyền; phòng/loại phòng/khách hàng; dựng theme và UI nối API | Đăng nhập được, danh sách thật, tạo/sửa dữ liệu theo quyền; kiểm thử API cốt lõi chạy được |
| 22–27/10 | Allocation, kiểm tra phòng trống, đặt/hủy/đổi lịch/gia hạn, check-in và trạng thái | Demo từ chọn ngày đến nhận phòng; test tranh chấp, giáp ngày và bảo trì đạt |
| 28/10–02/11 | Dịch vụ sử dụng, snapshot giá, hóa đơn, thanh toán, check-out và dọn phòng | Demo trọn vòng lưu trú; kiểm thử tính tiền, gửi lặp và quyền chỉnh hóa đơn đạt |
| 03–08/11 | Thống kê, bộ dữ liệu mẫu, hoàn thiện màn hình còn thiếu, bản demo trên thiết bị thật | Dashboard đối chiếu đúng DB; API demo truy cập được từ điện thoại; UI đủ trạng thái |
| 09–12/11 | Kiểm thử toàn luồng, bảo mật/phân quyền, đo hiệu năng, sửa lỗi, hoàn thiện README/UML/báo cáo | Không còn lỗi chặn nghiệp vụ; tài liệu và số liệu kiểm thử thống nhất với mã nguồn |
| 13–15/11 | Đóng phạm vi, build APK, backup/restore, quay demo, diễn tập bảo vệ | Cài lại được trên máy sạch theo hướng dẫn; APK, dữ liệu, tài liệu và kịch bản demo sẵn sàng |

Viết báo cáo và lưu minh chứng từ mỗi giai đoạn. Sau 08/11 ưu tiên sửa lỗi và tài liệu. Nếu chậm, bỏ dark mode/PDF/ảnh và thu gọn trang trí trước; vẫn giữ chống trùng lịch, phân quyền, tính hóa đơn và các luồng trong đề cương. Nếu khối lượng bắt buộc vượt thời gian thực tế, cần điều chỉnh mốc với giảng viên thay vì đánh dấu hoàn thành khi chưa đạt.

## 9. Kiểm thử và tiêu chí nghiệm thu

**Backend**

1. Hai lễ tân đặt cùng phòng với lịch chồng lấn: một thành công, một nhận 409; không có dữ liệu dở dang.
2. Hai booking giáp ngày hợp lệ; đổi lịch/gia hạn chồng lịch bị từ chối; hủy giải phóng lịch; bảo trì chặn đúng khoảng.
3. Phòng chưa dọn hoặc đang bảo trì không được check-in; gọi check-in/check-out lặp không tạo lưu trú hoặc hóa đơn thứ hai.
4. Đổi giá phòng/dịch vụ không sửa dữ liệu lịch sử; đối chiếu hóa đơn có phụ thu, giảm giá, cọc và thanh toán nhiều lần nếu đã bật.
5. Mất phản hồi sau khi server đã ghi và client gửi lại: trả đúng kết quả cũ, không thu tiền hai lần.
6. Gọi API trực tiếp bằng role không đủ quyền phải bị từ chối; tài khoản khóa và refresh bị thu hồi không sử dụng được như phiên hợp lệ.
7. Doanh thu xác định theo tổng thanh toán hợp lệ và ngày thu tiền của khách sạn; hóa đơn chưa thu không tính là tiền đã thu. Báo cáo công nợ/tổng hóa đơn, nếu có, hiển thị riêng.
8. Công suất theo số phòng-đêm được dùng và số phòng-đêm có thể bán, đã trừ bảo trì; ghi rõ cách tính để đối chiếu.
9. Backup khôi phục được và migrations tạo được schema từ database mới.

Kiểm thử transaction/tranh chấp chạy trên SQL Server thật, với transactional pytest hoặc TransactionTestCase và connection độc lập; SQLite hoặc TestCase bọc transaction mặc định không đủ chứng minh cơ chế khóa này. Kiểm tra thêm rollback, lock timeout, mã trả về của sp_getapplock, migrations tạo database mới, unique key chống gửi lặp và tổng hợp ngày theo timezone. Tài khoản test database có quyền tạo/xóa database test riêng; tránh dùng database demo hoặc dữ liệu thật.

**Mobile và UI**

- Chạy hoàn chỉnh luồng lễ tân và luồng người quản lý trên Android emulator và ít nhất một điện thoại thật.
- Kiểm tra màn hình rộng khoảng 360, 390 và 430 logical px; không tràn khi mở bàn phím hoặc tăng cỡ chữ.
- Kiểm tra phiên hết hạn, mất mạng, lỗi server, danh sách rỗng, gửi form lặp và quay lại màn hình sau thao tác.
- Widget test tập trung form đặt phòng, lỗi quyền, trạng thái tải và điều hướng phiên; integration test tập trung một luồng lưu trú hoàn chỉnh.
- Text, ngày và VND đúng định dạng tiếng Việt; hành động chính rõ và trạng thái phòng đọc được bằng chữ.

**Dữ liệu và hiệu năng**

- Seed đề xuất: 30 phòng, 4 loại phòng, 100 khách, khoảng 300 booking trong 3 tháng, 10 dịch vụ; có trạng thái hủy, đang ở, đã trả, cần dọn và bảo trì. Dùng dữ liệu khách hàng giả.
- Có bộ dữ liệu nhỏ với tổng tiền biết trước để kiểm tra báo cáo; seed lớn hơn chỉ phục vụ đo hiệu năng.
- Mục tiêu ban đầu: API danh sách và dashboard p95 dưới 1 giây trong môi trường demo đã ghi cấu hình và điều kiện mạng; đo rồi mới kết luận đạt.
- Khi kết thúc: flutter analyze, tests BE, tests mobile quan trọng, schema check và migrations đều đạt. Bản APK và API kết nối thành công; không còn lỗi nghiêm trọng về booking, tiền hoặc quyền truy cập.

## 10. Sản phẩm bàn giao

Mã nguồn có lịch sử Git; README dựng môi trường; cấu hình mẫu không chứa secret; migrations và seed; APK Android; API và OpenAPI; ERD; Use Case, Activity, Sequence, Class Diagram; ma trận quyền; test cases và kết quả; ảnh giao diện; video/kịch bản demo; báo cáo và slide bảo vệ. Các sơ đồ phải phản ánh hệ thống cuối cùng.

Kịch bản demo chính: lễ tân đăng nhập → chọn khách và phòng → đặt phòng → check-in → thêm dịch vụ → xem hóa đơn → ghi nhận thanh toán → check-out → dọn phòng → người quản lý xem báo cáo. Kịch bản bổ sung: hai phiên đặt cùng phòng, đổi lịch xung đột, gửi lại thanh toán và gọi API không đủ quyền.

## 11. Tài liệu kỹ thuật đã đối chiếu

SQL Server là cập nhật đã được người dùng yêu cầu. Các thư viện bổ sung và kiến trúc bên trên là đề xuất, không phải toàn bộ đều được ghi trong đề cương.

- Flutter khuyến nghị tách UI/data và repository, hỗ trợ cách tổ chức mobile trong kế hoạch: [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations).
- Lựa chọn quản lý trạng thái: [Riverpod getting started](https://riverpod.dev/docs/introduction/getting_started).
- Các package mobile: [Dio](https://pub.dev/packages/dio), [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage), [fl_chart](https://pub.dev/packages/fl_chart).
- Dòng Django hỗ trợ dài hạn đề xuất: [Django supported versions](https://www.djangoproject.com/download/).
- Backend Django, driver và các giới hạn theo phiên bản SQL Server: [Microsoft mssql-django](https://github.com/microsoft/mssql-django).
- Khóa độc quyền theo phòng trong transaction: [SQL Server sp_getapplock](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-getapplock-transact-sql?view=sql-server-ver17).
- Môi trường SQL Server container: [Microsoft SQL Server Docker quickstart](https://learn.microsoft.com/en-us/sql/linux/install-upgrade/quickstart-install-docker?tabs=cli&view=sql-server-ver17).
- Giao dịch khi chuyển trạng thái và ghi hóa đơn: [Django database transactions](https://docs.djangoproject.com/en/5.2/topics/db/transactions/).
- Quyền tại API: [DRF permissions](https://www.django-rest-framework.org/api-guide/permissions/).
- Tài liệu API và lựa chọn drf-spectacular: [DRF schemas](https://www.django-rest-framework.org/api-guide/schemas/).
- Xác thực và yêu cầu phiên bản cần kiểm tra: [Simple JWT getting started](https://django-rest-framework-simplejwt.readthedocs.io/en/stable/getting_started.html).

## 12. Tiến độ thực tế

- Đã làm: đăng nhập ba vai trò, refresh/rotation/logout, dashboard phòng, tìm kiếm/lọc/phân trang phòng, cập nhật tình trạng, admin thêm phòng, thêm/sửa/tìm khách hàng, nhật ký và schema API.
- Đã chạy: 19 bài kiểm thử backend trên SQL Server thật; 8 bài kiểm thử Flutter về phiên, form, điều hướng quyền và màn hình nhỏ; Ruff, Django check, migration check, OpenAPI validation và Flutter analyze đều đạt.
- Đã kiểm tra UI trên Edge với API thật: đăng nhập, dashboard, cập nhật phòng, lưu khách hàng, khôi phục phiên sau reload. Có ảnh UI trong `docs/screenshots`.
- Phase 02 đã làm: phòng trống theo ngày, đặt/hủy/đổi lịch/phòng/gia hạn, snapshot giá, idempotency, check-in và trạng thái phòng/dashboard theo dữ liệu lưu trú. UI chuyển về bố cục điện thoại và giảm chữ.
- Phase 02 đã kiểm tra: 43 tests backend trên SQL Server, gồm 3 bài tranh chấp với hai connection độc lập; 11 tests Flutter; Flutter analyze, Ruff, Django check, migration check và OpenAPI validation đạt.
- Đã chuẩn bị JDK 21, Android SDK và giả lập Android 14 x86_64 riêng trong dự án, WHPX có thể sử dụng. Chưa kiểm tra điện thoại vật lý.
- APK debug x86_64 đã build, cài và đăng nhập trên giả lập với dữ liệu SQL Server thật. Có ảnh Android trong `docs/screenshots` và script chạy lại `scripts/start-android.ps1`.
- Chưa làm: check-out, dịch vụ lưu trú, hóa đơn/thanh toán và doanh thu. Còn cần thử toàn vòng lưu trú và đối chiếu số tiền sau khi triển khai các phần này.

### Cập nhật 24/10/2026

- Đã bổ sung dịch vụ lưu trú: danh mục trên app, ghi số lượng với giá tại lúc ghi, tạm tính, hủy có lý do, lịch sử người/thời gian và chống gửi trùng.
- Admin quản lý danh mục; admin/lễ tân ghi/hủy khi khách đang ở; quản lý chỉ đọc. Migration `hotel.0004_stay_services` đã áp dụng ở development; có bốn dịch vụ mẫu.
- Đã đạt 51 tests Flutter và 18 tests dịch vụ SQL Server; bộ backend 68 tests cũng đã đạt trước khi bổ sung hai ca tranh chấp danh mục. Kiểm tra UI trên web bằng fixture và đối chiếu danh mục với API local thật. Xem [đợt dịch vụ](docs/PHASE_03_SERVICES.md).
- Phần nối tiếp còn lại: hóa đơn/thu tiền, check-out/dọn phòng và báo cáo doanh thu. Chưa dựng lại APK trong đợt này.
