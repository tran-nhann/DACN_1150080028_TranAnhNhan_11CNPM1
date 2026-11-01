import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

class RoomPhotoView extends ConsumerWidget {
  const RoomPhotoView({
    super.key,
    required this.photo,
    this.fit = BoxFit.cover,
  });
  final RoomPhoto photo;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Image.network(
    ref.watch(apiProvider).roomImageUrl(photo.url),
    fit: fit,
    semanticLabel: 'Ảnh phòng',
    loadingBuilder: (context, child, progress) => progress == null
        ? child
        : const ColoredBox(
            color: AsterColors.background,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
    errorBuilder: (_, error, stack) => const PhotoPlaceholder(error: true),
  );
}

class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({super.key, this.error = false});
  final bool error;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ColoredBox(
      color: AsterColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.image_outlined,
                color: AsterColors.muted,
                size: 28,
              ),
              if (constraints.maxHeight >= 120 &&
                  constraints.maxWidth >= 150) ...[
                const SizedBox(height: 6),
                Text(
                  error ? 'Không tải được ảnh' : 'Chưa có ảnh phòng',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AsterColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class RoomGallery extends StatefulWidget {
  const RoomGallery({super.key, required this.images});
  final List<RoomPhoto> images;
  @override
  State<RoomGallery> createState() => _RoomGalleryState();
}

class _RoomGalleryState extends State<RoomGallery> {
  int _index = 0;
  final _pages = PageController();
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const SizedBox(height: 130, child: PhotoPlaceholder());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.images.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog.fullscreen(
                    backgroundColor: Colors.black,
                    child: SafeArea(
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: 'Đóng ảnh',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Expanded(
                            child: InteractiveViewer(
                              minScale: 1,
                              maxScale: 4,
                              child: Center(
                                child: RoomPhotoView(
                                  photo: widget.images[index],
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                child: RoomPhotoView(photo: widget.images[index]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ảnh ${_index + 1}/${widget.images.length} · Chạm để phóng to',
          style: const TextStyle(fontSize: 11, color: AsterColors.muted),
        ),
        if (widget.images.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.images.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) => InkWell(
                onTap: () => _pages.jumpToPage(index),
                child: Container(
                  width: 74,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: index == _index
                          ? AsterColors.teal
                          : AsterColors.border,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: RoomPhotoView(photo: widget.images[index]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
