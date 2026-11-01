# Đối chiếu ứng dụng với đề cương đồ án quản lý khách sạn

Ngày đối chiếu: 31/10/2026. Nguồn: `11ĐHCNPM1_TranAnhNhan_DECUONGDOANCN (1).docx` do người dùng cung cấp trong Downloads. Các nội dung trong tài liệu được dùng làm yêu cầu tham chiếu, không phải lệnh thao tác hệ thống.

SQL Server đã được duyệt theo xác nhận của người dùng; đây là lựa chọn chính thức của dự án. Đề cương gốc ghi PostgreSQL là thông tin cũ, cần cập nhật tên công nghệ trong bản thuyết minh.

Đã bổ sung chu trình: đặt phòng → nhận phòng → dịch vụ → bảng quyết toán → ghi nhận thu đủ tiền và chốt hóa đơn → trả phòng → Cần dọn → xác nhận đã dọn. Báo cáo tách giá trị lưu trú ước tính và tiền đã thu theo phiếu thu thật.

| Yêu cầu trong đề cương | Hiện trạng sau cập nhật | Phần cần hoàn thiện |
| --- | --- | --- |
| Đăng nhập và ba vai trò — mục 1.2, 2.2 | Đã có xác thực và phân quyền API/app | Màn quản lý tài khoản, khóa/mở và phân quyền trên mobile; hiện quản trị tài khoản qua Django Admin |
| Quản lý phòng và loại phòng — mục 1.4, 2.3 | CRUD phòng, ảnh/thông số, lọc kết hợp hạng/tầng/trạng thái, thẻ và sơ đồ lịch | Giao diện quản lý danh mục loại phòng trên app |
| Khách hàng và lịch sử — mục 1.2, 2.4 | Có tra cứu/thêm/sửa khách, lịch đặt theo phòng/khách và tra cứu hóa đơn/phiếu thu | Mở rộng liên kết báo cáo nhiều kỳ nếu cần |
| Đặt phòng, đổi lịch, gia hạn và chống trùng — mục 1.4 | Có dịch vụ đặt kèm ngay dưới phòng được chọn, lưu cùng booking và tổng ở bước Chốt; chống trùng/gửi lặp | Mở rộng gói dịch vụ theo ngày nếu cần; hiện nhập tổng số lượng cho lượt đặt |
| Check-in — mục 1.5 | Có màn đối chiếu/bổ sung/hủy dịch vụ trước nhận phòng; chuyển khoản đặt kèm sang lưu trú một lần và giữ giá | Đã đáp ứng luồng hiện tại |
| Check-out và chuyển Cần dọn — mục 1.5, 3.2 | Đã có bảng quyết toán, thu tiền/chốt/trả trong cùng transaction, thời gian trả, Cần dọn và xác nhận đã dọn; khóa sửa dịch vụ sau chốt | Chính sách trả sớm/phụ thu theo giờ nếu mở rộng; hiện tính đủ số đêm đã đặt/gia hạn |
| Danh mục và sử dụng dịch vụ — mục 1.5 | Đã có hồ sơ, ảnh, sửa/xóa mục chưa dùng, ngừng bán, giá lịch sử và khóa sau checkout | Thống kê dịch vụ theo kỳ nếu mở rộng |
| Hóa đơn — mục 1.5, công thức Tổng = phòng + dịch vụ + phụ thu − giảm giá | Có hóa đơn và dòng chi tiết giữ nguyên thông tin lúc chốt, mã hóa đơn, người lập/ngày lập, tra cứu và sao chép; không sửa/xóa trực tiếp | Phụ thu/giảm giá, điều chỉnh/hủy có lý do và quyền riêng |
| Thanh toán và lịch sử giao dịch — mục 1.5, 2.3 | Có phiếu thu toàn bộ bằng tiền mặt/chuyển khoản, tham chiếu, người thu/thời điểm; xem lại hóa đơn, tìm kiếm/lọc hình thức | Cọc, trả nhiều lần, công nợ, hoàn tiền chưa triển khai |
| Thống kê phòng, booking, khách — mục 2.5–2.6, 3.3 | Dashboard hiện trạng và danh sách đến/đi | Thống kê theo khoảng thời gian, công suất và so sánh theo hạng phòng |
| Doanh thu theo kỳ, bảng và biểu đồ — mục 2.5–2.6, 3.3 | Có ước tính theo kỳ/biểu đồ/hạng phòng; đã thu theo ngày nhận tiền, tách tiền mặt/chuyển khoản và số phiếu thu | Xuất báo cáo, so sánh nhiều kỳ nếu mở rộng |
| Bộ dữ liệu thực nghiệm — mục 2.4, 3.4 | Có phòng/khách/booking/dịch vụ/ảnh mẫu; kiểm thử SQL Server và fixture trình duyệt cho luồng đến trả phòng | Chưa tạo phiếu thu giả trong database khách sạn chỉ để trình diễn |
| Kiểm thử — mục 2.7, 3.6 | Đã có kiểm thử API/Flutter/tranh chấp và preview | Bổ sung kiểm thử cho các phần mới, đặc biệt tiền và kết thúc lưu trú |

## Phạm vi thực hiện trong đợt này

- Bộ lọc phòng kết hợp hạng phòng, tầng, trạng thái và tìm kiếm; thiết kế lại thẻ phòng.
- Hồ sơ dịch vụ gồm nhóm, mô tả, ảnh, đơn vị, giá, ghi chú, trạng thái, ngày tạo/cập nhật và số khoản sử dụng. Admin sửa được và xóa được dịch vụ chưa có lịch sử; dịch vụ đã được sử dụng phải giữ liên kết lịch sử và có thể ngừng bán.
- Báo cáo doanh thu ước tính theo khoảng ngày: tiền phòng phân bổ theo số đêm giao với kỳ, sử dụng giá tại lúc đặt; dịch vụ tính theo ngày ghi và giá/số lượng đã chốt. Bỏ booking và khoản dịch vụ đã hủy. Có tách lịch xác nhận và lưu trú, bảng theo hạng phòng và biểu đồ.
- Báo cáo ước tính chưa tính phụ thu, giảm giá, cọc/hoàn tiền hoặc công nợ vì chưa có các mô hình đó. Không hiển thị số tiền thực thu giả.
- Đã bổ sung check-out, hóa đơn/dòng chi tiết, phiếu thu đủ tiền mặt hoặc chuyển khoản, tra cứu/sao chép hóa đơn, tự chuyển Cần dọn và xác nhận đã dọn. Đã thu trong kỳ lấy từ phiếu thu thật và trình bày tách với ước tính.

## Thứ tự nghiệp vụ còn thiếu

1. Phụ thu/giảm giá, chính sách điều chỉnh/hủy hóa đơn và hoàn tiền nếu cần; luồng dịch vụ đủ bốn thời điểm, chốt thu đủ tiền và trả phòng đã có.
2. Màn quản lý tài khoản/phân quyền và danh mục loại phòng trên mobile.
3. Thống kê lịch sử công suất, khách lưu trú, dịch vụ và so sánh kỳ; gói dịch vụ theo lịch/ngày và xuất báo cáo mở rộng.

Chi tiết nghiệp vụ đã triển khai: [Check-out và billing](PHASE_04_CHECKOUT_BILLING.md).

## Bổ sung nghiệp vụ: chuyển phòng khi đang ở

Đã triển khai **Đang ở → Chuyển phòng → Xem chênh lệch → Xác nhận**. Có giá phòng mới/giữ giá hiện tại, lý do, phòng cũ Cần dọn/Bảo trì, lịch sử từng chặng, bảng kê/hóa đơn và báo cáo theo giá từng phòng. Giữ nguyên cùng lượt lưu trú và dịch vụ. Chi tiết chính sách, API và kiểm tra tại [Chuyển phòng](PHASE_06_ROOM_MOVE.md).

## Rà soát góp ý: chọn dịch vụ từ lúc đang đặt phòng

Góp ý của người dùng đã được triển khai trong luồng app và API. Chi tiết hợp đồng và kiểm tra tại [Dịch vụ qua bốn thời điểm](PHASE_05_SERVICE_LIFECYCLE.md).

| Thời điểm | Hiện trạng đã triển khai | Quy tắc |
| --- | --- | --- |
| Đang đặt/chọn phòng | Chọn dịch vụ và số lượng ngay dưới phòng đã chọn; bước Chốt có từng dòng và tổng dự kiến | Giữ giỏ khi quay lại sửa phòng/lịch; số lượng là tổng lượt đặt, không tự nhân số đêm |
| Nhận phòng | Nút Nhận phòng mở bảng đối chiếu dịch vụ; thêm/hủy trước khi xác nhận | Chuyển khoản reserved sang ServiceUsage một lần, giữ giá gốc, không nhập lại |
| Trong lúc đang ở | Đã ghi/hủy có lý do từ chi tiết lưu trú hoặc nút Áp dụng trong danh mục | Giữ luồng này cho phát sinh; cộng vào đúng bảng kê của booking |
| Chuẩn bị trả phòng | Nút Bổ sung / hủy dịch vụ ngay trong quyết toán; thêm/hủy trong cùng sheet rồi quay về tổng mới | Bỏ xác nhận nhận tiền cũ và tải lại token; sau chốt khóa sửa |

`BookingServicePlan` lưu khoản đặt kèm trước khi có Stay. Nhận phòng chuyển từng khoản còn hiệu lực sang `ServiceUsage` bằng liên kết duy nhất, trong cùng transaction với check-in. Khoản đã hủy không chuyển. Hủy booking hủy toàn bộ khoản reserved. Luồng ghi phát sinh cũ vẫn chỉ nhận khách đang ở.

Các quy tắc đã triển khai và được kiểm tra:

- Lưu booking và dịch vụ đặt kèm trong cùng transaction; kiểm tra giá/đơn vị/trạng thái bán tại thời điểm xác nhận. Mã chống gửi lặp phải bao gồm nội dung dịch vụ.
- Giữ giá và số lượng đã chốt của khoản đặt kèm; không tự đổi giá khi danh mục thay đổi.
- Phân biệt khoản đặt trước và khoản chuyển vào bảng kê lưu trú; không coi lựa chọn trong bản nháp hoặc đặt kèm là tiền đã thu. Nếu khách không dùng, nhân viên hủy khoản có lý do trước chốt.
- Nhận phòng/đổi phòng/gia hạn không tự nhân đôi dịch vụ; hủy booking phải xử lý dịch vụ đặt kèm, không để khoản được tính tiếp.
- Dịch vụ theo ngày/suất cần ghi rõ ngày hoặc số lượng; không tự nhân mọi dịch vụ với số đêm. Khoản đã bao gồm trong giá phòng không cộng tiền lần nữa.
- Tổng tại bước Chốt, chi tiết booking, bảng kê và hóa đơn phải đối chiếu được. Nếu thêm/hủy khoản khi chuẩn bị trả phòng thì vô hiệu xác nhận thanh toán cũ và kiểm tra lại tổng.

## Những điểm cần thống nhất trong tài liệu

- Công nghệ đã được duyệt: SQL Server Express, `mssql-django` và `sp_getapplock`. Cập nhật các đoạn PostgreSQL/pgAdmin trong đề cương gốc thành SQL Server/SSMS; không còn là quyết định công nghệ còn chờ duyệt.
- Phần thời gian ghi 12 tuần, 24/08–15/11/2026; bảng kế hoạch lại có tuần 13–15 đến 06/12/2026. Cần chốt một lịch thống nhất.
- Tiêu đề mục 2.6 ghi dự báo nhu cầu nhưng nội dung là tổng hợp thống kê. Tài liệu chưa đặc tả mô hình dự báo hay chỉ tiêu đánh giá dự báo; không nên tự đưa thêm yêu cầu AI/ML vào phạm vi.
