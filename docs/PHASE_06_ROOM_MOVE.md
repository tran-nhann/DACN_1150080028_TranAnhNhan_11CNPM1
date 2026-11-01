# Chuyển phòng khi khách đang ở

SQL Server: migration `hotel.0010_room_move`. Giữ một Booking, một Stay và cùng các khoản dịch vụ; `RoomMove` lưu từng lần chuyển, đơn giá và thông tin phòng/hạng tại thời điểm chuyển.

## Thao tác

1. **Đặt phòng → Đang ở → mở khách → Chuyển phòng**. Nút nằm cố định cùng vùng Thêm dịch vụ, Trả phòng và Gia hạn. Cũng dùng được khi mở lưu trú từ thẻ phòng/sơ đồ lịch.
2. Chọn phòng mới đã dọn, đang hoạt động, đủ sức chứa, không có khách và không vướng đặt phòng từ hôm nay đến ngày trả. Danh sách kiểm tra cả khách quá hạn chưa trả.
3. Chọn **Giá phòng mới** hoặc **Giữ giá hiện tại**; chọn phòng cũ thành **Cần dọn** hoặc **Bảo trì** và nhập lý do bắt buộc.
4. **Xem chênh lệch**: đối chiếu số đêm còn lại, giá trước/sau, tăng/giảm tiền phòng, dịch vụ và tổng dự kiến. Sau đó **Xác nhận chuyển phòng**. Chuyển phòng không tạo khoản thu; tiền vẫn chốt tại trả phòng.
5. Chi tiết khách hiện phòng mới, các chặng tiền phòng và lịch sử chuyển. Phòng cũ có thể dọn/xử lý bảo trì theo luồng phòng hiện có. Bảng kê và hóa đơn tách từng phòng đã ở, dịch vụ cộng đúng một lần.

## Chính sách giá và trạng thái

- Thời điểm thực hiện do server ghi; giá mới áp dụng từ **đêm của ngày chuyển theo giờ khách sạn**. Chưa hỗ trợ hẹn chuyển, chuyển lùi ngày hay tính theo giờ. Ngày trả hoặc đã quá hạn cần gia hạn trước khi chuyển.
- Các đêm trước chuyển giữ nguyên giá. Ví dụ 3 đêm × 650.000đ, sau đêm đầu chuyển sang 950.000đ: `1 × 650.000 + 2 × 950.000 = 2.550.000đ`. Đổi xuống hạng giảm tiền các đêm còn lại. Giữ giá dùng đơn giá hiện tại của lượt ở, có lý do/người thao tác trong lịch sử.
- Chuyển nhiều lần trong ngày chỉ tính đêm đó ở phòng cuối cùng; các lần chuyển vẫn được lưu đầy đủ. Chặng có 0 đêm không tạo dòng tiền 0 đêm. Gia hạn sau chuyển tính thêm ở phòng và đơn giá hiện tại.
- Giữ nguyên Stay, các khoản đặt kèm đã chuyển, các dịch vụ đã dùng/đã hủy, giá và người ghi. Không tạo hoặc chuyển bản sao dịch vụ.
- Phòng cũ về Cần dọn/Bảo trì; phòng mới Đang ở trên cả thẻ và lịch. Lịch quá khứ lấy đúng phòng của từng chặng. Lịch sử của phòng cũ vẫn tra cứu được lượt khách sau chuyển.
- Nếu phòng cũ còn booking đã đặt chưa hủy, chặn đưa vào Bảo trì để tránh làm mất khả năng nhận khách đã hẹn. Có thể chọn Cần dọn hoặc xử lý lịch đặt trước.
- Admin/lễ tân thực hiện; quản lý xem lịch sử và bảng kê. Không chuyển booking chưa nhận/đã hủy/đã trả, hồ sơ thiếu nhận phòng, đã chốt hóa đơn hoặc dữ liệu đang ở không nhất quán.

## API và tính nhất quán

| Endpoint | Hợp đồng |
| --- | --- |
| `GET /api/v1/bookings/{id}/transfer-options/` | Ngày hiệu lực theo server, chính sách, các phòng phù hợp |
| `POST /api/v1/bookings/{id}/transfer-quote/` | `room_id`, `price_mode: target|keep`, `old_room_condition: cleaning|maintenance`, `reason`; trả tiền trước/sau, chênh lệch, dịch vụ, tổng, `quote_token` |
| `POST /api/v1/bookings/{id}/transfer/` | Nội dung như xem trước + `quote_token`, header UUID `Idempotency-Key`; trả `{move_id, booking}` với 201 lần đầu/200 gọi lặp |
| Booking đọc thông thường | Bổ sung `room_segments` và `room_moves`; `room_total` là tổng các chặng, `nightly_rate` là giá hiện tại |

Khóa yêu cầu, booking, danh mục và hai phòng theo thứ tự cố định bằng `sp_getapplock`. Kiểm tra lại phòng, sức chứa, giá, phiên booking và chênh lệch khi xác nhận. Phòng vừa bị đặt, thay đổi giá/gia hạn/dịch vụ hoặc đổi lựa chọn thì cần xem lại. Ghi lịch sử + đổi phòng/giá booking + trạng thái phòng cũ + audit trong một transaction; lỗi rollback toàn bộ.

Gửi lặp cùng khóa/nội dung trả lần chuyển cũ, không chuyển tiếp hoặc làm phòng đã dọn bị bẩn lại. Giao diện khóa sửa/Back/gửi lặp khi đang gửi và giữ nguyên khóa sau lỗi mạng. Bảng quyết toán cũ mất hiệu lực sau chuyển; cần mở lại tổng trước thu tiền. Lịch sử chuyển chỉ đọc qua API và Django Admin.

Báo cáo tiền phòng theo ngày/hạng lấy từng chặng; dịch vụ thuộc hạng tại thời điểm ghi khoản, giữ nguyên phân bổ lịch sử sau chuyển. Tiền đã thu vẫn chỉ lấy phiếu thu thật.

## Kiểm tra

- `backend/tests/test_room_moves.py`: chuyển/nâng/hạ hạng/giữ giá, dịch vụ và Stay giữ nguyên, nhiều lần cùng ngày và khác ngày, gia hạn, bảng kê/hóa đơn, lịch/thẻ/phòng cũ, báo cáo ngày/hạng, quyền, giá cũ, phòng không hợp lệ, dữ liệu thiếu/không nhất quán, gửi lặp, rollback và hai kết nối cùng chọn một phòng.
- `mobile/test/room_move_test.dart`: nút cố định từ chi tiết, lựa chọn giá/trạng thái/lý do, xem trước và xác nhận, lỗi/thử lại giữ khóa, khóa thao tác khi gửi, hết phòng, màn nhỏ/ngang với chữ gấp đôi.
- `node scripts/check-room-move-preview.cjs`: Edge với API fixture, không chuyển khách hoặc ghi hóa đơn trong dữ liệu khách sạn thật.
- Kiểm tra xuyên suốt Edge → API DRF thật → **HotelManagementTest**: từ thư mục `backend`, đặt `$env:RUN_BROWSER_E2E='1'` rồi chạy `..\.venv\Scripts\python.exe -m pytest tests/test_room_moves.py -k edge --reuse-db -q`. Pytest khởi động HTTP server riêng, trình duyệt dùng web build tại 4173 và chuyển API sang server kiểm thử. Thực hiện nâng hạng, giữ đúng một Stay/dịch vụ, trả phòng và thu một hóa đơn 2.580.000đ; dữ liệu kiểm thử được dọn theo fixture. Script con từ chối cổng API khách sạn 8000. Bỏ biến môi trường sau khi chạy. Mặc định test Edge được bỏ qua nếu chưa bật biến này.
