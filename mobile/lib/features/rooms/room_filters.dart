import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/theme.dart';

class RoomFilters extends StatelessWidget {
  const RoomFilters({
    super.key,
    required this.types,
    required this.floors,
    required this.status,
    required this.floor,
    required this.typeId,
    required this.onStatus,
    required this.onFloor,
    required this.onType,
    required this.onClear,
    this.typesLoading = false,
  });
  final List<RoomType> types;
  final List<int> floors;
  final String status;
  final int? floor, typeId;
  final ValueChanged<String> onStatus;
  final ValueChanged<int?> onFloor, onType;
  final VoidCallback onClear;
  final bool typesLoading;

  @override
  Widget build(BuildContext context) {
    final selected = [
      status.isNotEmpty,
      floor != null,
      typeId != null,
    ].where((value) => value).length;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AsterColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const PageStorageKey('room_filters'),
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.tune_rounded, color: AsterColors.navy),
        title: Text(
          selected == 0 ? 'Bộ lọc phòng' : 'Bộ lọc phòng · $selected',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final typeField = DropdownButtonFormField<int>(
                key: ValueKey('filter_type_$typeId'),
                initialValue: typeId ?? 0,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Hạng phòng',
                  prefixIcon: Icon(Icons.hotel_outlined, size: 19),
                ),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('Tất cả hạng')),
                  ...types.map(
                    (type) => DropdownMenuItem(
                      value: type.id,
                      child: Text(type.name),
                    ),
                  ),
                ],
                onChanged: typesLoading
                    ? null
                    : (value) => onType(value == 0 ? null : value),
              );
              final floorField = Tooltip(
                message: 'Lọc theo tầng',
                child: DropdownButtonFormField<int>(
                  key: ValueKey('filter_floor_$floor'),
                  initialValue: floor ?? 0,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tầng',
                    prefixIcon: Icon(Icons.layers_outlined, size: 19),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('Tất cả tầng'),
                    ),
                    ...floors.map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('Tầng $value'),
                      ),
                    ),
                  ],
                  onChanged: (value) => onFloor(value == 0 ? null : value),
                ),
              );
              return box.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3
                  ? Column(
                      children: [
                        typeField,
                        const SizedBox(height: 14),
                        floorField,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: typeField),
                        const SizedBox(width: 12),
                        Expanded(child: floorField),
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Trạng thái',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...[
                  ('', 'Tất cả'),
                  ('ready', 'Sẵn sàng'),
                  ('occupied', 'Đang ở'),
                  ('reserved', 'Đã đặt'),
                  ('cleaning', 'Cần dọn'),
                  ('maintenance', 'Bảo trì'),
                ].map(
                  (item) => ChoiceChip(
                    label: Text(item.$2, style: const TextStyle(fontSize: 11)),
                    selected: status == item.$1,
                    showCheckmark: false,
                    onSelected: (_) => onStatus(item.$1),
                  ),
                ),
              ],
            ),
          ),
          if (selected > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
                label: const Text('Xóa bộ lọc'),
              ),
            ),
        ],
      ),
    );
  }
}
