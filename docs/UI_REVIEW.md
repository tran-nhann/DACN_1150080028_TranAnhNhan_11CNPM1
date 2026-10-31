# Rà soát thông tin và luồng Aster — 15/10/2026

## Các thiếu sót đã sửa

| Khu vực | Trước | Hiện tại |
| --- | --- | --- |
| Khách hàng | Bấm khách mở thẳng form sửa | Mở hồ sơ: liên hệ có sao chép, ghi chú, ngày tạo và lịch đặt; sửa rồi trở về hồ sơ |
| Lịch sử khách/phòng | Chưa có đường xem riêng | Danh sách có trạng thái, ngày, giá, phân trang và mở đúng đặt phòng trong cùng sheet |
| Đặt phòng | Giấu mã, thiếu cách tính tiền và mốc thời gian | Mã có sao chép, đơn giá đã chốt × số đêm, tổng tiền, ngày nhận/trả, ngày tạo/nhận thực tế |
| Tác vụ đặt phòng | Nút hành động cuộn cùng nội dung | Nút chính ghim dưới sheet; lịch nhận chưa đến/quá hạn có lý do ngắn; đổi lịch/gia hạn/hủy theo quyền |
| Dữ liệu liên quan | Sửa tên khách có thể để lại tên cũ trong chi tiết đang mở | Cập nhật tên ngay khi quay lại; làm mới danh sách, lịch sử và dashboard |
| Dashboard | Chưa dùng dữ liệu tầng/phòng cần xử lý; nhiều số không mở được chi tiết | Mở danh sách đến/đi đúng ngày, khách đang ở, lọc phòng theo tầng/trạng thái và mở phòng cần xử lý |
| Khách đến trên dashboard | Mở danh sách đặt phòng chung | Mở đúng đặt phòng được bấm; nút xem tất cả mở danh sách đến của ngày |
| Phòng | Thiếu lịch sử/cập nhật; nút lưu luôn hiện | Có trạng thái sử dụng, tình trạng vận hành, giá, sức chứa, ngày cập nhật và lịch đặt; nút lưu hiện khi thay đổi |

Danh sách giữ nhãn ngắn. Thông tin dài nằm ở hồ sơ hoặc vùng mở rộng; thông tin chưa có dữ liệu không được tự điền giả.

## Điều hướng và phân quyền

- Chi tiết → hồ sơ khách → sửa → hồ sơ → chi tiết sử dụng các trang trong cùng sheet.
- Hồ sơ khách/phòng → đặt phòng → quay lại giữ vị trí danh sách và phạm vi lịch sử.
- Khi đang gửi, khóa gửi lặp, nút đóng, Back, chạm nền và vuốt đóng; lỗi giữ dữ liệu để thử lại.
- Quản lý xem đặt phòng/lịch sử phòng, không có nút nghiệp vụ hoặc đường mở liên hệ khách. API khách hàng vẫn từ chối vai trò này.
- Giá trong chi tiết lấy từ bản đặt đã chốt; đổi lịch cùng phòng giữ giá lịch sử. Kiểm tra phòng trống và khóa idempotency hiện có được giữ nguyên.

API đặt phòng bổ sung bộ lọc đọc `room`, `customer`, `arrival_on`, `departure_on`. Các endpoint và payload nghiệp vụ cũ được giữ nguyên; không có migration mới.

## Xác minh

- 41 kiểm thử Flutter: gồm các luồng mới, kiểm thử cũ, màn 320–480px, màn ngang, chữ gấp đôi, bàn phím, giảm chuyển động, lỗi/gửi lặp và quyền quản lý.
- 52 kiểm thử backend trên database test SQL Server riêng; có lọc lịch sử kết hợp, ngày đến/đi chính xác, đầu vào sai và giới hạn thông tin khách.
- Flutter analyze, Ruff, Django check, migration check, OpenAPI validation và web release build.
- `scripts/check-workflow-preview.cjs`: thao tác thêm khách, đặt/đổi/hủy với API mô phỏng, không ghi dữ liệu kinh doanh vào SQL Server; ảnh `docs/screenshots/ui-*.png`.
- `scripts/check-detail-preview.cjs`: đối chiếu UI với API local thật, kiểm tra hồ sơ, lịch sử và bộ lọc; chặn mọi yêu cầu ghi nghiệp vụ. Ảnh kiểm tra local ở `.artifacts/review-*.png`.

## Phạm vi còn thiếu của sản phẩm

Check-out, hóa đơn/thanh toán, dịch vụ và báo cáo doanh thu chưa có nghiệp vụ backend. Đây là phần phát triển tiếp theo, không thể hoàn thiện chỉ bằng thay đổi giao diện. Đợt rà soát này xác minh bản web; chưa dựng lại APK hoặc kiểm tra trên thiết bị Android.
