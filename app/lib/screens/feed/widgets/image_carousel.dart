import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../chat/full_screen_image_viewer.dart';

// ─── Image Carousel ───

class ImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final VoidCallback onDoubleTap;

  const ImageCarousel({
    super.key,
    required this.imageUrls,
    required this.onDoubleTap,
  });

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.length == 1) {
      return GestureDetector(
        onDoubleTap: widget.onDoubleTap,
        onTap: () => FullScreenImageViewer.open(
          context,
          imageUrl: widget.imageUrls.first,
        ),
        child: CachedNetworkImage(
          imageUrl: widget.imageUrls.first,
          width: double.infinity,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => Container(
            height: 300,
            color: Colors.grey.shade100,
            child: const Center(
              child: Icon(Icons.image_not_supported_outlined,
                  color: AppTheme.textHint, size: 48),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: PageView.builder(
              itemCount: widget.imageUrls.length,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => FullScreenImageViewer.openGallery(
                    context,
                    imageUrls: widget.imageUrls,
                    initialIndex: index,
                  ),
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrls[index],
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: AppTheme.textHint, size: 48),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Page indicator
          Positioned(
            bottom: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                widget.imageUrls.length,
                (index) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? AppTheme.primaryColor
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
          // Counter
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentPage + 1}/${widget.imageUrls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
