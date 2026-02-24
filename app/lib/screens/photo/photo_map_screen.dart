import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme.dart';
import '../../providers/photo_provider.dart';

class PhotoMapScreen extends ConsumerStatefulWidget {
  const PhotoMapScreen({super.key});

  @override
  ConsumerState<PhotoMapScreen> createState() => _PhotoMapScreenState();
}

class _PhotoMapScreenState extends ConsumerState<PhotoMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  bool _isMapView = true;
  Set<Marker> _markers = {};

  static const LatLng _defaultCenter = LatLng(37.5665, 126.9780); // Seoul

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(photoProvider.notifier).fetchMapPhotos();
    });
  }

  void _buildMarkers(List<dynamic> photos) {
    final markers = <Marker>{};
    for (final photo in photos) {
      if (photo.latitude != null && photo.longitude != null) {
        markers.add(
          Marker(
            markerId: MarkerId(photo.id),
            position: LatLng(photo.latitude!, photo.longitude!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRose,
            ),
            onTap: () => _showPhotoBottomSheet(photo),
          ),
        );
      }
    }
    setState(() {
      _markers = markers;
    });
  }

  void _showPhotoBottomSheet(dynamic photo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Photo preview
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: photo.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: photo.imageUrl!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: double.infinity,
                        height: 200,
                        color: AppTheme.primaryLight.withValues(alpha: 0.1),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: double.infinity,
                        height: 200,
                        color: AppTheme.primaryLight.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: AppTheme.textHint,
                        ),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      height: 200,
                      color: AppTheme.primaryLight.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.photo,
                        size: 48,
                        color: AppTheme.textHint,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            // Caption
            if (photo.caption != null && photo.caption!.isNotEmpty)
              Text(
                photo.caption!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 4),
            // Date
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  photo.createdAt != null
                      ? DateFormat('yyyy년 M월 d일').format(photo.createdAt!)
                      : '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Address
            if (photo.address != null && photo.address!.isNotEmpty)
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      photo.address!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image == null) return;

    if (!mounted) return;

    // Show caption dialog
    final captionController = TextEditingController();
    final caption = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사진 설명'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: TextField(
          controller: captionController,
          decoration: const InputDecoration(
            hintText: '이 순간을 설명해주세요...',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, captionController.text),
            child: const Text(
              '업로드',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (caption == null) return;

    await ref.read(photoProvider.notifier).uploadPhoto(
          imageFile: File(image.path),
          caption: caption,
        );
  }

  @override
  Widget build(BuildContext context) {
    final photoState = ref.watch(photoProvider);
    final photos = photoState.mapPhotos ?? [];

    // Build markers when photos change
    if (photos.isNotEmpty && _markers.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _buildMarkers(photos);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('우리의 발자취'),
            if (photos.isNotEmpty)
              Text(
                '${photos.length}개의 추억',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: AppTheme.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isMapView ? Icons.grid_view_rounded : Icons.map_outlined,
            ),
            onPressed: () {
              setState(() {
                _isMapView = !_isMapView;
              });
            },
            tooltip: _isMapView ? '갤러리 보기' : '지도 보기',
          ),
        ],
      ),
      body: photoState.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : _isMapView
              ? _buildMapView(photos)
              : _buildGridView(photos),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadPhoto,
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  Widget _buildMapView(List<dynamic> photos) {
    if (photos.isEmpty) {
      return _buildEmptyState();
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: photos.isNotEmpty &&
                photos.first.latitude != null &&
                photos.first.longitude != null
            ? LatLng(photos.first.latitude!, photos.first.longitude!)
            : _defaultCenter,
        zoom: 12,
      ),
      markers: _markers,
      onMapCreated: (controller) {
        if (!_mapController.isCompleted) {
          _mapController.complete(controller);
        }
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  Widget _buildGridView(List<dynamic> photos) {
    if (photos.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return GestureDetector(
          onTap: () => _showFullScreenPhoto(photo),
          child: photo.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: photo.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppTheme.primaryLight.withValues(alpha: 0.1),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppTheme.primaryLight.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: AppTheme.textHint,
                    ),
                  ),
                )
              : Container(
                  color: AppTheme.primaryLight.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.photo,
                    color: AppTheme.textHint,
                  ),
                ),
        );
      },
    );
  }

  void _showFullScreenPhoto(dynamic photo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              photo.caption ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: photo.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: photo.imageUrl!,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.photo,
                      size: 64,
                      color: Colors.white54,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.photo_camera_outlined,
              size: 40,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '아직 추억이 없어요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '사진을 올려 우리만의 지도를 채워보세요',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
