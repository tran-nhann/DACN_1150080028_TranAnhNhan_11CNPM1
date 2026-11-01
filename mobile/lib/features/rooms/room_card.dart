import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'room_images.dart';

class RoomCard extends StatelessWidget {
  const RoomCard({super.key, required this.room, required this.onTap});
  final HotelRoom room;
  final VoidCallback onTap;

  Widget _spec(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AsterColors.muted),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(fontSize: 11, color: AsterColors.muted),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${room.number} ${room.type.name}, Tầng ${room.floor}, ${room.type.capacity} khách, ${ConditionBadge.details(room.displayStatus).$1}, ${money(room.type.rate)} mỗi đêm',
    button: true,
    onTap: onTap,
    excludeSemantics: true,
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AsterColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.45,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  room.images.isEmpty
                      ? const PhotoPlaceholder()
                      : RoomPhotoView(photo: room.images.first),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x990B2A56)],
                        stops: [.35, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .96),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ConditionBadge(room.displayStatus),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 10,
                    child: Text(
                      room.number,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 27,
                        height: 1,
                      ),
                    ),
                  ),
                  if (room.images.length > 1)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .4),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_library_outlined,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${room.images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    room.type.name,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AsterColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _spec(Icons.layers_outlined, 'Tầng ${room.floor}'),
                      _spec(
                        Icons.person_outline,
                        '${room.type.capacity} khách',
                      ),
                      if (room.area != null)
                        _spec(
                          Icons.square_foot_rounded,
                          '${room.area!.toStringAsFixed(room.area! % 1 == 0 ? 0 : 1)} m²',
                        ),
                    ],
                  ),
                  if (room.view.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      room.view,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AsterColors.muted,
                      ),
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      money(room.type.rate),
                      style: const TextStyle(
                        fontSize: 18,
                        color: AsterColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'mỗi đêm',
                    style: TextStyle(fontSize: 10, color: AsterColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
