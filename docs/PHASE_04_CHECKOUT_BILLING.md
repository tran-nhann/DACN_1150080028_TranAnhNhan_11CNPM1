# Check-out, hóa đơn, thanh toán và dọn phòng

Công nghệ: **SQL Server đã được duyệt**. Migration `hotel.0008` tạo `Invoice`, `InvoiceLine`, `Payment` và các ràng buộc tiền/ngày/phương thức/liên kết.

## Thao tác trên app

1. Đặt phòng → Đang ở → mở khách → **Trả phòng**. Có thể mở lưu trú từ lịch sử phòng hoặc sơ đồ lịch.
2. Bảng quyết toán hiển thị từng dòng: số đêm × giá lúc đặt, từng dịch vụ theo giá/số lượng lúc ghi; khoản đã hủy không tính tiền.
   Có nút **Bổ sung / hủy dịch vụ** ngay tại đây. Sau khi sửa khoản, bảng kê được tải lại và xác nhận nhận tiền cũ được bỏ; cần xác nhận lại trước chốt. Dịch vụ đặt kèm booking đã chuyển vào lưu trú lúc nhận phòng, không cộng thêm lần thứ hai.
3. Chọn **Tiền mặt** hoặc **Chuyển khoản**; nhập tham chiếu/ghi chú nếu có. Xác nhận đã nhận đủ tiền, bấm **Chốt hóa đơn & trả phòng**. Chuyển khoản là nhân viên xác nhận đã nhận tiền, không tự truy vấn ngân hàng.
4. App hiển thị hóa đơn đã thanh toán và phiếu thu. Hóa đơn lưu tên khách/số điện thoại, phòng/hạng, kỳ lưu trú, từng dòng và tổng tại thời điểm chốt. Có nút sao chép nội dung.
5. Booking chuyển Đã trả, lưu thời điểm trả và buồng chuyển **Cần dọn**. Dịch vụ và gia hạn bị khóa. Phòng vẫn chặn nhận khách mới cho đến khi đã dọn.
6. Trong **Phòng**, mở thẻ phòng hoặc chạm ô Cần dọn trên **Sơ đồ lịch** → **Xác nhận đã dọn** → xác nhận. Tình trạng buồng trở lại `ready`; cả hai màn và dashboard làm mới. Nếu đã có khách khác đặt đến hôm nay, nhãn tổng hợp có thể là Đã đặt; tình trạng vệ sinh vẫn là Sẵn sàng.
7. **Thêm → Hóa đơn & phiếu thu**: tìm mã hóa đơn/phiếu thu, tên khách, điện thoại, phòng hoặc tham chiếu; lọc hình thức; phân trang và xem lại chi tiết. Chi tiết booking Đã trả cũng có mục Xem hóa đơn / phiếu thu.
8. Báo cáo doanh thu có **Đã thu trong kỳ**, tiền mặt/chuyển khoản và số phiếu thu. Tiền thực thu tính theo ngày nhận tiền tại múi giờ khách sạn; phần giá trị lưu trú ước tính vẫn theo đêm/ngày dịch vụ và được trình bày riêng.

## Quy tắc và tính nhất quán

- Admin/lễ tân được chốt và xác nhận đã dọn; quản lý được xem bảng kê/hóa đơn và báo cáo. Giữ ba vai trò hiện có, chưa tạo tài khoản/vai trò buồng phòng riêng.
- Tiền phòng tính đủ số đêm đã đặt/gia hạn, kể cả trả sớm. Quá ngày trả phải cập nhật gia hạn trước khi chốt; không âm thầm bỏ đêm quá hạn. Chưa có phụ thu, giảm giá, cọc, trả góp, công nợ hoặc hoàn tiền.
- Mỗi lưu trú có tối đa một hóa đơn và mỗi hóa đơn một phiếu thu toàn bộ. Booking giá 0 vẫn chốt được, có phiếu ghi nhận 0 đồng.
- Hóa đơn/phiếu thu chỉ đọc qua API và Django Admin, không có sửa/xóa trực tiếp. Có mã riêng, người thực hiện, thời điểm và AuditLog. Không có chức năng điều chỉnh/hủy/hoàn tiền trong đợt này.
- `quote_token` đại diện toàn bộ bảng kê, không chỉ tổng. Thay đổi dịch vụ, số đêm hoặc thông tin chốt đều yêu cầu tải lại và xác nhận lại, kể cả thay đổi có tổng bằng nhau.
- Chốt giữ khóa yêu cầu, booking rồi phòng bằng `sp_getapplock`. Ghi hóa đơn + dòng + phiếu thu + giờ trả + booking Đã trả + phòng Cần dọn trong **một transaction**. Lỗi giữa chừng rollback tất cả.
- POST chốt cần UUID `Idempotency-Key`. Gửi lại cùng người/mã/nội dung trả hóa đơn cũ; nội dung khác trả 409. Hai thu ngân cùng chốt chỉ một người thành công. Gửi lại hóa đơn cũ không đổi một phòng đã dọn trở lại Cần dọn.
- Lỗi mạng giữ nguyên mã yêu cầu để thử lại; khi đang gửi khóa nút, hình thức, nhập liệu, đóng, Back và gửi lặp. Có thể tải lại bảng kê/hóa đơn để kiểm tra server đã chốt chưa.
- Xác nhận đã dọn yêu cầu `expected_updated_at` từ hồ sơ mới nhất. Phiên cũ không thể xác nhận nhầm lần dọn tiếp theo. Chặn phòng đang ở/bảo trì; xác nhận lại phòng đã sẵn sàng không tạo nhật ký trùng.

## API

| Endpoint | Nội dung |
| --- | --- |
| `GET /api/v1/bookings/{id}/folio/` | `state: open`, bảng kê + token; nếu đã chốt trả `state: closed`, hóa đơn cũ |
| `POST /api/v1/bookings/{id}/check-out/` | Header `Idempotency-Key`; body `quote_token`, `expected_total`, `method: cash|bank_transfer`, `payment_received: true`, `reference?`, `notes?`; trả `{invoice, booking}`, 201 lần đầu/200 gửi lại |
| `GET /api/v1/invoices/` | Tìm `search`, lọc `method`, ngày nhận tiền `[start_date,end_date)`, phân trang |
| `GET /api/v1/invoices/{id}/` | Hồ sơ hóa đơn, dòng chi tiết và phiếu thu |
| `POST /api/v1/rooms/{id}/confirm-cleaned/` | `expected_updated_at`; trả hồ sơ phòng mới |
| `GET /api/v1/reports/revenue-estimate/` | Bổ sung `collected_total`, `cash_total`, `bank_total`, `payment_count` cho kỳ báo cáo; số 0 khi không có phiếu thu |

## Kiểm tra

### Khắc phục màn hình quyết toán tải mãi

- Booking đang ở có nút **Thêm dịch vụ** trong vùng thao tác cố định, mở thẳng form ghi dịch vụ. Trong quyết toán, nút **Bổ sung / hủy dịch vụ** vẫn hiện khi bảng kê đang tải hoặc bị lỗi.
- Hai nguồn dữ liệu bảng kê/dịch vụ không tự thử lại lỗi nghiệp vụ. Lỗi hiện thông báo và nút **Thử lại**; yêu cầu quá 20 giây chuyển sang thông báo thay vì giữ skeleton mãi.
- Dữ liệu cũ có booking `checked_in` nhưng thiếu `Stay` trả 409 kèm lý do rõ ràng; gọi lại nhận phòng cũng không được báo thành công sai. Không tự tạo hồ sơ khi GET dữ liệu.
- Kiểm tra hồ sơ thiếu bằng `.venv\Scripts\python.exe backend/manage.py recover_open_stay --booking <id> --actor admin`; thêm `--apply` khi đã đối chiếu. Nếu có nhật ký nhận phòng, dùng mốc trong nhật ký; nếu không, dùng giờ khôi phục và giao diện ghi **Khôi phục hồ sơ lưu trú**. Thao tác có audit, chuyển dịch vụ đặt kèm một lần, không tạo hóa đơn/phiếu thu hay sửa ngày/giá đặt phòng.
- `backend/tests/test_stay_recovery.py` kiểm tra lỗi thiếu hồ sơ, khôi phục, nhật ký/thời điểm, gọi lặp và chặn mở lại booking đã trả. `mobile/test/stay_loading_test.dart` kiểm tra lỗi 409, hết thời gian chờ, thử lại thủ công, thêm dịch vụ trực tiếp và footer trên màn nhỏ/chữ lớn.
- `node scripts/check-live-stay-loading.cjs` kiểm tra API và Edge với dữ liệu thật: các booking đang ở có bảng kê mở được, nút cố định mở danh mục dịch vụ, quyết toán tải thành công không lặp. Script chặn thao tác ghi nghiệp vụ, chỉ đăng nhập và đọc; ảnh lưu ở `.artifacts/stay-live-*.png`.

`backend/tests/test_billing.py`: tiền phòng/dịch vụ lịch sử, khoản hủy, cả hai phương thức, chốt/phiếu thu/snapshot, phân quyền, token cũ, thu trùng, rollback, đóng dịch vụ/gia hạn, dọn phòng/phiên cũ, thẻ/sơ đồ, ranh giới ngày thu và hai kết nối SQL Server.

`mobile/test/billing_test.dart`: từ nút Trả phòng tới hóa đơn, lựa chọn/xác nhận nhận tiền, retry giữ mã, chặn Back/gửi lặp, quản lý chỉ xem, xác nhận đã dọn, tra cứu hóa đơn, màn 320px/ngang và chữ gấp đôi.

`node scripts/check-billing-preview.cjs`: kiểm tra Edge bằng API fixture riêng; không tạo hóa đơn, tiền thu hoặc thay đổi booking trong database khách sạn. Ảnh kiểm tra nằm trong `.artifacts/billing-*.png`.

Hướng giao diện được giữ đơn giản để agent thiết kế có thể thay giao diện mà dùng lại API, model/provider và các kiểm tra nghiệp vụ này.
