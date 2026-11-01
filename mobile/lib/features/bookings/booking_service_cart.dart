import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/detail_widgets.dart';
import '../../core/form_layout.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../services/services_screen.dart';

class BookingServiceChoice {
  const BookingServiceChoice(this.service, this.quantity);
  final HotelService service;
  final int quantity;
  int get total => service.price * quantity;
  Map<String, dynamic> toJson() => {
    'service_id': service.id,
    'quantity': quantity,
    'expected_unit_price': service.price,
  };
}

Future<HotelService?> pickBookingService(BuildContext context) =>
    showAsterSheet<HotelService>(
      context: context,
      form: true,
      builder: (context) => PinnedFormLayout(
        header: ScreenHeading(
          title: 'Dịch vụ đặt kèm',
          action: IconButton(
            tooltip: 'Đóng',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ),
        body: ServiceCatalog(
          activeOnly: true,
          onSelected: (service) => Navigator.pop(context, service),
        ),
        footer: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Quay lại'),
        ),
      ),
    );

class BookingServiceCart extends StatelessWidget {
  const BookingServiceCart({
    super.key,
    required this.items,
    required this.busy,
    required this.onAdd,
    required this.onQuantity,
    required this.onRemove,
  });
  final List<BookingServiceChoice> items;
  final bool busy;
  final VoidCallback onAdd;
  final void Function(int id, int quantity) onQuantity;
  final ValueChanged<int> onRemove;
  @override
  Widget build(BuildContext context) => DetailSection(
    title: 'Dịch vụ đặt kèm (tùy chọn)',
    icon: Icons.room_service_outlined,
    children: [
      const Text(
        'Số lượng là tổng cho lượt đặt. Không tự nhân với số đêm; chưa ghi nhận thanh toán.',
      ),
      const SizedBox(height: 12),
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.service.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    key: Key('remove_booking_service_${item.service.id}'),
                    tooltip: 'Bỏ ${item.service.name}',
                    onPressed: busy ? null : () => onRemove(item.service.id),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text('${money(item.service.price)} / ${item.service.unit}'),
              const SizedBox(height: 8),
              TextFormField(
                key: ValueKey('booking_service_quantity_${item.service.id}'),
                initialValue: '${item.quantity}',
                enabled: !busy,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                decoration: InputDecoration(
                  labelText: 'Số lượng ${item.service.name}',
                  suffixText: item.service.unit,
                  errorText: item.quantity < 1 || item.quantity > 999
                      ? 'Chọn 1–999.'
                      : null,
                ),
                onChanged: (value) =>
                    onQuantity(item.service.id, int.tryParse(value) ?? 0),
              ),
              const SizedBox(height: 8),
              Text('Thành tiền: ${money(item.total)}'),
            ],
          ),
        ),
      OutlinedButton.icon(
        key: const Key('booking_add_service'),
        onPressed: busy ? null : onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Thêm dịch vụ đặt kèm'),
      ),
    ],
  );
}
