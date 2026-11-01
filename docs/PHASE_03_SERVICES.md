# Đợt 1 — Dịch vụ trong lưu trú

Ngày triển khai: 24/10/2026.

## Sửa điều hướng và đơn vị sau kiểm tra sử dụng

- Khách hàng và Dịch vụ là trang con của Thêm (`/profile/customers`, `/profile/services`); hai URL cũ tiếp tục chuyển hướng được. Mũi tên bên trái và Back hệ thống trở về trang Thêm. Bấm lại tab Thêm khi đang ở trang con trở về Thêm; đổi sang tab khác rồi quay lại vẫn giữ tìm kiếm và vị trí đang xem.
- Đơn vị được chọn từ API `GET /api/v1/service-units/`: chai, lon, ly, bình, suất, kg, cái, bộ, lượt, giờ, ngày, đêm, gói. Mỗi lựa chọn có ví dụ; form mới bắt buộc chọn, không tự gán đơn vị mặc định.
- API tạo/sửa từ chối đơn vị ngoài danh sách. Danh mục cũ có đơn vị sai được trả `unit_valid=false`, hiển thị “Cần chọn đơn vị” và bị chặn ghi thêm vào lưu trú tới khi admin sửa. Form sửa giữ tên/giá và yêu cầu chọn lại đơn vị; không tự suy đoán từ tên.
- Migration `0005_service_unit_choices` đã áp dụng, giữ nguyên dữ liệu cũ và đơn vị trong lịch sử sử dụng. 55 kiểm thử Flutter và 23 kiểm thử dịch vụ SQL Server đã đạt; browser kiểm tra mũi tên, Back trình duyệt, bấm lại Thêm và danh sách đơn vị từ API thật.

## Các luồng đã hoàn thành

1. **Thêm → Dịch vụ:** tìm kiếm, phân trang, lọc Đang bán/Ngừng bán/Tất cả. Admin tạo/sửa tên, đơn vị, giá và trạng thái bán; lưu xong danh sách tìm tới đúng dịch vụ vừa thay đổi. Có nút quay lại Thêm.
2. **Đặt phòng → Đang ở → Dịch vụ → Ghi dịch vụ:** chọn dịch vụ đang bán, nhập số lượng 1–999, xem thành tiền, ghi nhận và trở lại danh sách trong cùng sheet.
3. **Hủy khoản ghi nhầm:** xác nhận tên/số lượng/tiền, bắt buộc lý do, ghi người hủy/thời điểm. Khoản vẫn ở lịch sử với trạng thái Đã hủy và số tiền gạch ngang; không cộng vào tổng dịch vụ.
4. **Xem tạm tính:** tiền phòng đã chốt + dịch vụ còn hiệu lực. Đây chưa phải hóa đơn, tiền đã thu hay số dư sau cọc.

## Phân quyền và trạng thái

| Thao tác | Admin | Lễ tân | Quản lý |
| --- | --- | --- | --- |
| Xem danh mục và lịch sử dịch vụ | Có | Có | Có |
| Tạo/sửa/ngừng bán dịch vụ | Có | Không | Không |
| Ghi/hủy khoản khi khách đang ở | Có | Có | Không |
| Đặt/hủy dịch vụ kèm booking trước nhận phòng | Có | Có | Không |

API yêu cầu phiên đăng nhập. Ghi/hủy khoản phát sinh chỉ được phép khi booking là Đang ở, đã có Stay và Stay chưa có thời điểm trả. Booking chưa nhận phòng dùng khoản đặt kèm `BookingServicePlan`; khoản này được chuyển một lần khi check-in. Booking đã hủy/đã trả chỉ xem, không ghi thêm. Không mở thêm quyền liên hệ khách cho quản lý. Xem [luồng đủ bốn thời điểm](PHASE_05_SERVICE_LIFECYCLE.md).

## Bảo toàn dữ liệu

- `ServiceItem` giữ danh mục hiện tại; `ServiceUsage` giữ tên, đơn vị và đơn giá tại lúc ghi. Thay tên/giá hoặc ngừng bán không đổi khoản cũ.
- Client gửi giá đã thấy; API kiểm tra lại giá và tình trạng bán dưới khóa danh mục trước khi ghi. Giá thay đổi thì yêu cầu chọn lại, giữ số lượng đang nhập.
- Mỗi lần ghi có UUID `Idempotency-Key`, duy nhất theo người thực hiện. Cùng mã/cùng nội dung trả lại khoản cũ; cùng mã/nội dung khác trả 409. Kiểm tra bằng hai kết nối SQL Server độc lập.
- Khóa theo booking đồng bộ ghi/hủy dịch vụ với trạng thái lưu trú. Tổng và trang danh sách được đọc dưới khóa chia sẻ theo booking để không lệch nhau giữa các truy vấn trong cùng phản hồi.
- Hai admin cập nhật riêng giá/đơn vị không ghi đè các trường của nhau từ bản dữ liệu cũ. Tạo đồng thời cùng tên được xử lý thành lỗi ngay tại trường tên, không để lỗi database thoát ra màn hình.
- Lỗi mạng sau khi server đã ghi: form giữ dữ liệu và mã yêu cầu để thử lại, không tạo khoản thứ hai. Khi đang gửi, khóa nút gửi, nhập liệu, đóng, Back và chạm nền/vuốt đóng.
- Hủy lặp cùng lý do trả kết quả cũ, không nhân bản nhật ký; lý do khác sau khi đã hủy bị từ chối. Không có xóa cứng khoản dịch vụ.
- Lưu người ghi/hủy, thời gian, lý do và AuditLog. Ràng buộc database kiểm tra số lượng, giá, tính nhất quán của thông tin hủy và mã yêu cầu.

## API và dữ liệu

- `GET/POST /api/v1/services/`: danh mục; tìm theo `search`, lọc `active=true|false`, phân trang.
- `GET/PUT/PATCH /api/v1/services/{id}/`: xem/sửa theo quyền. Cập nhật 31/10/2026: admin dùng `DELETE` để xóa mục chưa có lịch sử sử dụng; trả 409 nếu đã từng dùng, khi đó chọn ngừng bán. Khoản sử dụng vẫn chỉ hủy có lý do, không xóa cứng.
- `GET /api/v1/bookings/{id}/services/`: lịch sử có phân trang, `room_total`, `service_total`, `estimated_total`, `can_edit`.
- `POST /api/v1/bookings/{id}/services/`: `service_id`, `quantity`, `expected_unit_price` và header `Idempotency-Key`; 201 khi tạo, 200 khi gửi lại.
- `POST /api/v1/bookings/{id}/services/{usage_id}/cancel/`: `reason`; kiểm tra khoản thuộc đúng booking.

Migration `hotel.0004_stay_services` tạo hai bảng và ràng buộc mới, đã áp dụng ở database development. `seed_demo` thêm bốn dịch vụ mẫu nếu chưa tồn tại; không ghi đè mục đã chỉnh sửa. Không tạo hoặc nhận phòng thêm một booking development chỉ để kiểm tra giao diện.

Cập nhật 31/10/2026: migration `hotel.0007` bổ sung nhóm, mô tả, ảnh và ghi chú nội bộ. Mở mục trong danh sách để xem hồ sơ, sau đó dùng nút **Sửa dịch vụ** hoặc **Xóa** cố định dưới màn hình. Ảnh nhận qua multipart, JPG/PNG/WebP tối đa 5 MB. Chi tiết báo cáo ước tính và đối chiếu đề cương tại [bảng rà soát](DE_CUONG_GAP_REVIEW.md).

## Cách thử

Mở `http://127.0.0.1:4173`, Ctrl + F5. Đăng nhập admin để xem/sửa danh mục tại Thêm → Dịch vụ. Ghi khoản sử dụng từ một đặt phòng đã nhận, tại Đặt phòng → Đang ở → chi tiết → Dịch vụ. Lễ tân ghi được khoản, quản lý chỉ xem.

Từ **Thêm → Dịch vụ**, admin/lễ tân có thể bấm **Áp dụng** ngay trên từng mục, hoặc mở chi tiết rồi chọn **Áp dụng cho phòng**. Chọn khách/phòng đang ở (có tìm kiếm và phân trang), nhập số lượng và bấm **Ghi nhận** cố định dưới màn hình. Dịch vụ được chọn sẵn; sau khi ghi sẽ mở bảng dịch vụ của đúng lưu trú để đối chiếu tổng tiền. Không cần quay qua tab Đặt phòng để bắt đầu.

Mục thiếu đơn vị hoặc đã ngừng bán khóa nút Áp dụng và hiển thị lý do. Admin mở mục → Sửa dịch vụ → chọn đơn vị → Lưu; không tự gán đơn vị cho dữ liệu nhập thiếu. Nếu không có phòng đang ở thì hướng dẫn nhận phòng trước. Server vẫn kiểm tra khách còn ở, giá còn đúng và quyền ghi tại thời điểm nhận yêu cầu; khách đã trả phòng trong lúc đang chọn sẽ không bị ghi thêm chi phí.

Nếu chưa có khách đang ở, nhận phòng một bản đặt phù hợp theo luồng hiện có trước khi ghi dịch vụ. Nút ghi dịch vụ không xuất hiện ở bản đặt chưa nhận.

## Xác minh

- 51 kiểm thử Flutter: gồm luồng cũ, ghi/hủy dịch vụ, retry giữ UUID, giá gửi đúng, lý do hủy, tổng tiền, quyền quản lý, Back, màn 320px/480px, chữ gấp đôi và bàn phím.
- 18 kiểm thử dịch vụ trên SQL Server: giá lịch sử, giá cũ/ngừng bán, input sai, mã yêu cầu, tranh chấp hai kết nối, hủy có lý do, phạm vi booking, phân trang/tổng, ràng buộc database và hai admin cập nhật đồng thời. Bộ backend 68 kiểm thử đã đạt trước khi bổ sung hai ca tranh chấp danh mục; hai ca mới đã đạt trong bộ dịch vụ 18 ca.
- Flutter analyze, Ruff, Django check, migration check, OpenAPI validation và bản web release.
- `node scripts/check-services-preview.cjs`: chạy thao tác ghi sau khi mất phản hồi, retry, hủy, tạo/sửa/ngừng bán và quản lý chỉ đọc bằng API fixture cô lập; không ghi nghiệp vụ vào database development. Ảnh ở `docs/screenshots/services-*.png` đã kiểm tra trực quan.
- `node scripts/check-apply-service-preview.cjs`: từ danh sách Dịch vụ → Áp dụng → tìm phòng đang ở → chọn phòng → nhập số lượng → Ghi nhận; kiểm tra nút cố định và tổng cập nhật của đúng lưu trú, không ghi database khách sạn. Các kiểm tra Flutter mới nằm trong `mobile/test/apply_service_test.dart`.
- `node scripts/check-detail-preview.cjs`: đọc API local thật, đối chiếu danh mục/giá trên form, tạm tính và các luồng chi tiết cũ; chặn yêu cầu ghi nghiệp vụ.
- APK và thiết bị Android chưa được dựng/kiểm tra lại ở đợt này.

## Đợt tiếp theo

Luồng hóa đơn/ghi nhận thu đủ tiền, trả phòng và dọn phòng đã triển khai tại [phase 04](PHASE_04_CHECKOUT_BILLING.md). Chốt dùng cùng khóa booking với dịch vụ; sau chốt không ghi/hủy dịch vụ hoặc gia hạn. Chính sách cọc, giảm giá, hoàn tiền, điều chỉnh/hủy hóa đơn và cho nợ chưa triển khai, không tự áp vào số tạm tính.
