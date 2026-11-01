# Dịch vụ qua bốn thời điểm

## Cách dùng

1. **Đặt phòng → chọn phòng:** ngay dưới phòng được chọn có **Dịch vụ đặt kèm (tùy chọn)**. Thêm dịch vụ, nhập số lượng, bỏ mục không cần. Bước **Chốt** hiển thị từng dịch vụ, tiền phòng và tổng dự kiến. Quay lại sửa phòng/lịch vẫn giữ giỏ.
2. **Booking Đã đặt → Nhận phòng:** mở bảng **Nhận phòng & dịch vụ** để kiểm tra các khoản đặt kèm. Có thể thêm hoặc hủy có lý do. Bấm **Nhận phòng** dưới cùng để xác nhận; dịch vụ được chuyển vào lưu trú một lần, giữ tên/đơn vị/giá đã đặt.
3. **Trong lúc đang ở:** giữ các lối ghi phát sinh từ chi tiết booking hoặc **Thêm → Dịch vụ → Áp dụng**. Khoản mới cộng vào cùng bảng kê; có thể hủy có lý do trước chốt.
4. **Trả phòng → Quyết toán:** bấm **Bổ sung / hủy dịch vụ**, sửa các khoản còn thiếu/nhầm, quay lại bảng kê mới. Xác nhận nhận tiền cũ được bỏ, cần kiểm tra và xác nhận lại. Sau chốt hóa đơn không ghi/hủy thêm.

Trong chi tiết booking Đã đặt cũng có **Dịch vụ đặt kèm** để cập nhật trước ngày đến. Admin/lễ tân được thao tác; quản lý xem. Dịch vụ thiếu đơn vị/ngừng bán không được chọn mới. Dịch vụ đã cam kết vẫn giữ giá đã chốt khi danh mục đổi giá hoặc ngừng bán.

## Dữ liệu và bảo toàn tiền

- Migration SQL Server `hotel.0009_bookingserviceplan`: `BookingServicePlan` liên kết booking, snapshot tên/đơn vị/giá/số lượng, trạng thái `reserved/posted/cancelled`, người/thời điểm/lý do hủy, mã chống gửi lặp và liên kết duy nhất tới khoản lưu trú.
- Tạo booking và giỏ dịch vụ trong cùng transaction. Bất kỳ dòng sai giá, đơn vị, số lượng, mục ngừng bán hoặc phòng không còn phù hợp đều rollback cả booking và giỏ. Tối đa 50 dòng khác dịch vụ, số lượng mỗi dòng 1–999.
- `Idempotency-Key` của booking bao gồm nội dung giỏ (sắp theo ID dịch vụ). Gửi lại cùng nội dung không tạo thêm; giỏ khác với cùng mã bị từ chối. Request không có dịch vụ giữ cách tính mã cũ để tương thích.
- Check-in giữ khóa booking/phòng, tạo Stay và chuyển các khoản reserved trong cùng transaction. Mỗi plan chỉ nối một ServiceUsage; nhận phòng lại/hai máy đồng thời không nhân đôi. Check-in không định giá lại khoản cam kết.
- Hủy booking hủy các plan còn reserved. Đổi phòng/gia hạn không nhân đôi, không tự nhân số lượng theo số đêm. Muốn đổi số lượng của khoản đã lưu: hủy có lý do rồi ghi khoản mới.
- API hủy plan tách với hủy usage để tránh dùng nhầm ID nếu có máy khác check-in trong lúc nhân viên đang thao tác. Plan đã chuyển phải tải lại bảng kê để hủy khoản usage tương ứng.
- Danh mục có tham chiếu kế hoạch hoặc lịch sử không xóa được; có thể ngừng bán. Các ảnh/tên/giá lịch sử không bị thay đổi theo danh mục mới.
- Báo cáo thêm `planned_service_total` cho khoản reserved của booking confirmed, xếp vào ngày nhận dự kiến. `estimated_total = room_total + service_total + planned_service_total`; sau nhận phòng plan không còn reserved, khoản usage được tính thay thế. `collected_total` vẫn chỉ từ phiếu thu thật.
- Số lượng là tổng cho lượt đặt. Chưa có lịch giao dịch vụ từng ngày, lịch tự phát sinh, gói miễn phí/đã gồm giá phòng, cọc/hoàn tiền hoặc phụ thu/giảm giá.

## API

- `POST /api/v1/bookings/` nhận thêm trường tùy chọn `services: [{service_id, quantity, expected_unit_price}]`. Chưa chọn dịch vụ thì bỏ trường hoặc gửi `[]`.
- `GET /api/v1/bookings/{id}/services/` trả khoản plan khi booking chưa có Stay, khoản usage khi đã vào lưu trú; thêm `booking_status` và `planned` trên từng dòng. Tổng và `can_edit` theo trạng thái máy chủ.
- `POST /api/v1/bookings/{id}/planned-services/`: thêm khoản trước khi nhận, body giống ghi phát sinh, cần UUID `Idempotency-Key`.
- `POST /api/v1/bookings/{id}/planned-services/{plan_id}/cancel/`: `reason`, chỉ hủy plan reserved, giữ lịch sử.
- `POST /api/v1/bookings/{id}/check-in/`: tự chuyển plan hợp lệ trong transaction hiện có; không cần gửi lại giỏ.
- API usage/check-out giữ nguyên đường dẫn. Hóa đơn lấy khoản usage còn hiệu lực; không cộng plan thêm lần nữa.
- Booking trả thêm `planned_service_total`, `service_total`, `estimated_total`. `room_total` vẫn chỉ tiền phòng.

## Kiểm tra

- `backend/tests/test_service_lifecycle.py`: bốn giai đoạn, giá lịch sử/ngừng bán sau cam kết, retry, giỏ sai rollback, hủy plan/booking, phân quyền, khóa sau chốt, token quyết toán cũ, chuyển đổi lỗi rollback, hai kết nối check-in và doanh thu dự kiến/thực thu.
- `mobile/test/service_lifecycle_test.dart`: giỏ ngay lúc chọn phòng và giữ khi Back, payload/tổng, bổ sung/hủy trước nhận, nhận phòng một lần, sửa khoản trực tiếp từ quyết toán và bỏ xác nhận thanh toán cũ, màn hẹp/ngang/chữ lớn.
- `node scripts/check-service-lifecycle-preview.cjs`: kiểm tra bốn thời điểm trên Edge bằng fixture API riêng, đối chiếu tổng hóa đơn; không tạo booking hoặc phiếu thu giả trong database khách sạn. Ảnh tại `.artifacts/service-lifecycle-*.png`.
