# Đề xuất bổ sung luồng Aster

Ngày rà soát: 24/10/2026. Đây là đặc tả đề xuất dựa trên mã nguồn hiện tại, chưa phải tính năng đã triển khai.

## 1. Điểm thiếu hiện tại

- Có đặt/hủy/đổi lịch/gia hạn/nhận phòng. `Booking.Status` có `checked_out` và `Stay` có `checked_out_at`, nhưng chưa có nghiệp vụ/API trả phòng.
- Chưa có dữ liệu dịch vụ sử dụng, hóa đơn, cọc hoặc thanh toán. Tổng tiền hiện tại chỉ là tiền phòng của bản đặt, không phải số tiền đã thu.
- Đã có hồ sơ và lịch sử theo khách/phòng. Form đặt phòng vẫn khởi tạo trống; chưa nhận sẵn khách/phòng từ màn chi tiết.
- Backend chỉ cho đổi lịch/phòng với đặt phòng chưa nhận. Chuyển phòng trong lúc ở cần thiết kế riêng để giữ lịch sử phòng và giá.
- Có danh mục và bộ lọc phòng, chưa có lịch phòng theo khoảng ngày hoặc danh sách công việc quá hạn chuyên biệt.
- Có AuditLog, nhưng hiện chỉ lưu người thao tác, hành động, đối tượng và thời gian; chưa đủ dữ liệu để dựng lịch sử trước/sau cho mọi thay đổi.
- Có tài khoản ba vai trò và Django admin; chưa có màn quản lý nhân viên/quyền trên app Flutter.

## 2. Vòng lưu trú cần hoàn thiện trước

Đặt phòng → Nhận phòng → Ghi dịch vụ → Xem quyết toán → Ghi nhận thanh toán → Trả phòng → Cần dọn → Sẵn sàng.

### A. Chi tiết lưu trú và dịch vụ

**Điểm vào:** bấm một phòng đang có khách hoặc một đặt phòng có trạng thái Đang ở.

**Thông tin chính:** phòng, khách đại diện, ngày nhận thực tế, ngày trả dự kiến, số khách, tiền phòng, tiền dịch vụ và số còn phải thu. Số chưa phát sinh không được trình bày như tiền đã thu.

**Thao tác:** “Dịch vụ” mở trang chọn trong cùng sheet; tìm dịch vụ → chọn số lượng → thấy đơn giá và thành tiền → thêm → trở lại lưu trú. Danh sách đã thêm có số lượng, thời gian và người ghi nhận.

**Quy tắc cần có:**

- Giá được chụp tại lúc ghi dịch vụ; sửa giá danh mục không đổi khoản đã ghi.
- Gửi lại cùng một yêu cầu không thêm dịch vụ hai lần. Hai lần khách gọi cùng một dịch vụ là hai yêu cầu khác nhau.
- Trước khi chốt hóa đơn, sửa/hủy khoản ghi nhầm theo quyền và có dấu vết. Sau khi chốt phải dùng điều chỉnh có lý do; không âm thầm sửa lịch sử.
- Khi máy khác đã kết thúc lưu trú, máy đang mở không được ghi thêm dịch vụ vào phiên cũ; hiện lý do và làm mới dữ liệu.

**Nghiệm thu:** đổi giá danh mục không đổi dịch vụ cũ; mất phản hồi rồi gửi lại không nhân đôi; ghi sai có thể xử lý theo đúng trạng thái hóa đơn.

### B. Hóa đơn, cọc và thanh toán

**Điểm vào:** “Thanh toán” từ chi tiết lưu trú. Giai đoạn đầu ghi nhận tiền mặt/chuyển khoản thủ công; tích hợp cổng thanh toán là phạm vi riêng.

**Trình tự:** xem tiền phòng + dịch vụ + điều chỉnh được phép → đối trừ khoản đã thu/cọc → thấy số còn lại → nhập số tiền và phương thức → kiểm tra → xác nhận → cập nhật hóa đơn và danh sách lần thu.

**Thông tin từng lần thu:** mã giao dịch nội bộ, số tiền, phương thức, người nhận, thời điểm, trạng thái. Khoản chuyển khoản ghi tay cần phân biệt với giao dịch đã được ngân hàng xác nhận tự động.

**Quy tắc cần có:**

- Backend tính tổng; client không gửi tổng tiền tùy ý để quyết định số phải thu.
- Cọc là khoản đã nhận và cần đối trừ, không phải doanh thu được cộng thêm lần nữa lúc quyết toán.
- Chống ghi nhận hai lần khi bấm lặp/mất mạng; ràng buộc cũng nằm ở backend.
- Hai nhân viên cùng thu tiền: kiểm tra lại số dư khi ghi, không dựa vào số đang hiển thị cũ.
- Thu từng phần có trạng thái Chưa thu/Thu một phần/Đã đủ. Thu thừa phải được xử lý rõ, không mặc nhiên xóa chênh lệch.
- Khoản thu đã xác nhận không xóa cứng; điều chỉnh/hoàn tiền có quyền, lý do và bản ghi riêng.

**Cần chốt chính sách trước triển khai:** có nhận cọc không; có cho nợ khi trả phòng không; ai được giảm giá/hoàn tiền; các khoản phí/thuế nào thực sự áp dụng. Không tự đặt chính sách tiền trong UI.

**Nghiệm thu:** đối chiếu được tổng hóa đơn, từng lần thu và số dư; retry không thu hai lần; sửa giá hiện tại không đổi hóa đơn cũ; vai trò thiếu quyền bị chặn khi gọi API trực tiếp.

### C. Trả phòng và bàn giao dọn phòng

**Điểm vào:** nút chính “Trả phòng” của lưu trú đang ở. Gia hạn và chuyển phòng nằm ở menu phụ.

**Trình tự:** mở quyết toán → kiểm tra khoản phát sinh và số dư → thanh toán nếu cần → xác nhận phòng/khách/số tiền → kết thúc lưu trú → phòng thành Cần dọn → mở từ danh sách Cần dọn → xác nhận Đã dọn → Sẵn sàng, hoặc Đã đặt nếu có lịch tiếp theo đang hiệu lực.

**Quy tắc cần có:**

- Cập nhật thời điểm trả, trạng thái đặt phòng và tình trạng phòng trong cùng giao dịch; lỗi thì không để ba phần lệch nhau.
- Trả phòng không tự đánh dấu Sẵn sàng khi chưa dọn.
- Gửi lại trả phòng trả về kết quả cũ, không tạo hóa đơn hoặc kết thúc lưu trú lần thứ hai.
- Số dư còn nợ chỉ được bỏ qua nếu có chính sách và quyền cụ thể; ghi rõ ai cho phép.
- Trả sớm/trễ cần thấy lại cách tính trước khi xác nhận; phí phụ thu hoặc hoàn tiền phụ thuộc chính sách đã chốt.
- Lịch của khách kế tiếp được giữ; khách tiếp theo không được nhận phòng khi phòng chưa dọn.

**Nghiệm thu xuyên suốt:** hai lượt giáp ngày; trả khách A → phòng cần dọn → nhận khách B bị chặn → dọn xong → nhận B thành công. Thử thêm mất mạng sau khi server đã trả phòng.

## 3. Rút ngắn thao tác đặt phòng

### A. Đặt lại từ hồ sơ khách

Hồ sơ khách → “Đặt phòng” → bước Lịch đã chọn khách → chọn ngày/số khách → chọn phòng trống → Chốt. Vẫn cho đổi khách; không tự sao chép ngày/giá cũ.

### B. Đặt từ phòng hoặc ô lịch

Chi tiết phòng/ô lịch → “Đặt phòng” → giữ phòng đang quan tâm và ngày được chọn → nhập khách/số người → kiểm tra khả dụng → Chốt.

Phòng được gợi ý không đồng nghĩa đã giữ chỗ. Nếu đổi ngày/số khách làm phòng không còn phù hợp, hiển thị lý do và các lựa chọn khác, giữ thông tin khách đã nhập. Backend kiểm tra lại trước khi tạo.

### C. Bỏ dở và xung đột

- Rời form đã thay đổi: hỏi “Bỏ thay đổi?”; không hỏi khi chưa nhập gì.
- Quay về từ thêm khách giữ lịch, số người, tìm kiếm và lựa chọn hiện tại.
- Giá thay đổi: hiện giá cũ/mới và cho chọn lại, không đổi giá âm thầm.
- Phòng vừa bị đặt: trở lại bước Phòng, giữ khách/lịch, làm mới danh sách phù hợp; không bắt nhập từ đầu.

**Nghiệm thu:** khách/phòng được điền sẵn đúng điểm vào; thao tác sửa giữ dữ liệu; không xác nhận phòng đã hết chỗ hoặc vượt sức chứa.

## 4. Lịch phòng và việc cần xử lý

**Lịch phòng:** hàng theo phòng, cột theo ngày; chọn ngày đầu/kết thúc để tra cứu. Mobile xem ít ngày với cuộn ngang; có cách xem dạng danh sách khi chữ lớn. Ô đặt mở đúng bản đặt; ô trống đi tới đặt phòng đã điền sẵn phòng/ngày.

Phân biệt đặt phòng, đang ở, cần dọn và bảo trì bằng nhãn/icon/màu. Nếu chưa triển khai bảo trì theo khoảng ngày, không vẽ trạng thái bảo trì tương lai như đã có dữ liệu.

**Công việc:** danh sách Khách đến, Khách đi, Quá giờ trả, Chưa nhận và Cần dọn. Phân biệt khách chưa đến trong lịch vẫn còn hiệu lực với bản đặt đã hết hạn. Bấm mục việc mở đúng đối tượng và hành động tiếp theo.

Không tự hủy bản đặt chưa nhận hoặc tự giải phóng phòng có khách quá hạn chỉ vì đã sang ngày. Xử lý no-show cần trạng thái/lý do và chính sách cọc riêng.

**Nghiệm thu:** ngày giáp nhau không hiển thị sai trùng lịch; lịch mở đúng ID; khách quá hạn vẫn giữ trạng thái có người ở; dữ liệu làm mới sau thao tác từ màn khác.

## 5. Chuyển phòng khi đang ở

Đang ở → menu “Chuyển phòng” → chọn thời điểm và phòng trống → xem chênh lệch giá → lý do → xác nhận → phòng mới có khách, phòng cũ cần dọn.

Đây là luồng khác đổi phòng trước check-in. Không sửa trực tiếp phòng của toàn bộ bản đặt vì sẽ mất lịch sử khách đã ở phòng nào và tiền từng chặng. Cần lưu phân bổ phòng theo từng khoảng lưu trú; giữ lịch sử dịch vụ, thanh toán và giá từng chặng.

Hai phòng và lịch liên quan phải được khóa/cập nhật cùng giao dịch. Phòng đích không đủ sức chứa, chưa dọn hoặc vừa có khách phải bị từ chối mà vẫn giữ nguyên phòng cũ.

**Ưu tiên:** sau khi vòng lưu trú, quyết toán và trả phòng cơ bản đã ổn định.

## 6. Lịch sử thao tác và quản trị

**Lịch sử nghiệp vụ:** trong chi tiết đặt/lưu trú, mở “Lịch sử” để xem ai tạo, đổi lịch, chuyển phòng, ghi dịch vụ, thu tiền và trả phòng; có ngày/giờ, lý do và giá trị trước/sau phù hợp. Cần bổ sung dữ liệu AuditLog trước khi hiển thị chi tiết này; log hiện tại chưa chứa tất cả nội dung.

**Loại phòng/dịch vụ:** admin tạo/sửa tên, sức chứa, giá và trạng thái bán. Thay đổi chỉ áp dụng cho yêu cầu mới; hồ sơ cũ giữ giá đã chốt. Ngừng bán thay vì xóa dữ liệu đang được tham chiếu.

**Tài khoản nhân viên:** admin tạo → phân vai trò → kích hoạt/khóa; nhân viên đổi mật khẩu. Khóa tài khoản phải có hiệu lực ở API/phiên đang dùng, không chỉ ẩn trong danh sách. Lưu lịch sử thay đổi quyền; ngăn tự khóa tài khoản quản trị cuối cùng.

Giữ ma trận quyền hiện tại cho đến khi có yêu cầu đổi; không tự cho manager quyền thu tiền, hoàn tiền hoặc xem liên hệ khách.

## 7. Báo cáo có thể đối chiếu

Thêm sau khi có thanh toán thật: lọc ngày/khoảng ngày → xem tiền đã thu, khoản hoàn, số dư phải thu và công suất → bấm số liệu để xem bản ghi cấu thành → mở hóa đơn/lưu trú.

Không dùng tổng tiền của mọi booking làm số đã thu. Phân biệt tiền thu, giá trị hóa đơn và công nợ; thống nhất khoảng ngày theo múi giờ khách sạn. Công suất cần mẫu số phòng-đêm có thể bán và dữ liệu bảo trì nếu áp dụng.

**Nghiệm thu:** có bộ dữ liệu nhỏ biết trước tổng; số trên báo cáo bằng danh sách bên dưới; khoản hủy/hoàn/thu từng phần được xử lý đúng định nghĩa.

## 8. Cách đưa vào UI

- Giữ bốn tab. Lịch phòng nằm trong tab Phòng; lưu trú đi từ Đặt phòng hoặc dashboard. Danh mục, nhân viên và báo cáo nằm trong Thêm theo quyền.
- Chọn/thêm/sửa ngắn dùng các trang của cùng sheet. Lịch nhiều ngày, hóa đơn dài và báo cáo dùng màn riêng để có đủ diện tích và Back rõ ràng.
- Theo trạng thái chỉ có một hành động chính: Đã đặt → Nhận phòng; Đang ở → Trả phòng; Cần dọn → Đã dọn. Các thao tác phụ đi vào menu hoặc vùng tác vụ liên quan.
- Dùng nhãn ngắn: “Dịch vụ”, “Còn thu”, “Thu tiền”, “Trả phòng”, “Đã dọn”, “Lịch sử”. Giữ số tiền/ngày/trạng thái/nhãn trường; mở rộng các khoản chi tiết khi cần.
- Hiển thị lỗi ngay ở bước phát sinh, giữ dữ liệu, khóa gửi lặp và có đường thử lại. Không chỉ thêm nút hoặc sheet rỗng khi backend chưa hỗ trợ.

## 9. Thứ tự triển khai đề xuất

1. Một phần hoàn chỉnh từ Đang ở → dịch vụ cơ bản → quyết toán/thu tiền → trả phòng → dọn phòng. Thiết kế mô hình tiền/trạng thái trước, sau đó triển khai và kiểm thử trọn vòng.
2. Đặt phòng có dữ liệu điền sẵn từ khách/phòng; xử lý bản nháp và phục hồi sau xung đột.
3. Lịch phòng, quá hạn/no-show và công việc theo ngày.
4. Chuyển phòng đang ở, lịch sử trước/sau và các thao tác quản trị còn thiếu.
5. Báo cáo đối chiếu theo hóa đơn/thanh toán đã xác nhận.

Mỗi phần cần cả API, phân quyền, UI đầy đủ trạng thái, kiểm thử lỗi/gửi lặp và kịch bản demo từ đầu đến cuối. Không đánh dấu hoàn thành khi chỉ có màn hình.

## Tiến độ theo đợt

24/10/2026: đã triển khai đợt 1 — danh mục và dịch vụ trong lưu trú, gồm ghi/hủy, giá lịch sử, tạm tính, phân quyền và chống gửi lặp. Chi tiết tại [PHASE_03_SERVICES.md](PHASE_03_SERVICES.md). Hóa đơn/thu tiền và trả phòng/dọn phòng là phần nối tiếp, chưa được đánh dấu hoàn thành.
