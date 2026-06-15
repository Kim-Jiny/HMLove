import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/api_error.dart';

// Photo model
class Photo {
  final String id;
  final String imageUrl;
  final String? thumbnailUrl;
  final String? caption;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String coupleId;
  final String authorId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Photo({
    required this.id,
    required this.imageUrl,
    this.thumbnailUrl,
    this.caption,
    this.latitude,
    this.longitude,
    this.address,
    required this.coupleId,
    required this.authorId,
    required this.createdAt,
    this.updatedAt,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    final imageUrl = (json['imageUrl'] ?? json['thumbnailUrl']) as String? ?? '';
    final createdAtRaw = json['createdAt'] ?? json['takenAt'];
    final updatedAtRaw = json['updatedAt'];

    return Photo(
      id: json['id'] as String,
      imageUrl: imageUrl,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      caption: json['caption'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: (json['address'] ?? json['location']) as String?,
      coupleId: json['coupleId'] as String? ?? '',
      authorId: (json['uploadedBy'] ?? json['authorId']) as String? ?? '',
      createdAt: createdAtRaw != null
          ? DateTime.parse(createdAtRaw as String)
          : DateTime.now(),
      updatedAt: updatedAtRaw != null
          ? DateTime.parse(updatedAtRaw as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'coupleId': coupleId,
      'authorId': authorId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

// Photo state class
class PhotoState {
  static const _sentinel = Object();

  final List<Photo> photos;
  final List<Photo> mapPhotos;
  final bool isLoading;
  final String? error;

  const PhotoState({
    this.photos = const [],
    this.mapPhotos = const [],
    this.isLoading = false,
    this.error,
  });

  PhotoState copyWith({
    List<Photo>? photos,
    List<Photo>? mapPhotos,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return PhotoState(
      photos: photos ?? this.photos,
      mapPhotos: mapPhotos ?? this.mapPhotos,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

// Photo Notifier
class PhotoNotifier extends Notifier<PhotoState> {
  late final Dio _dio;

  @override
  PhotoState build() {
    _dio = ref.read(dioProvider);
    return const PhotoState();
  }

  /// Fetch photos with optional date range filter.
  Future<void> fetchPhotos({DateTime? from, DateTime? to}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final queryParams = <String, dynamic>{
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      };

      final response =
          await _dio.get('/photo', queryParameters: queryParams);
      final data = response.data as Map<String, dynamic>;
      final photos = (data['photos'] as List<dynamic>)
          .map((e) => Photo.fromJson(e as Map<String, dynamic>)).toList();
      state = state.copyWith(photos: photos, isLoading: false);
    } on DioException catch (e) {
      final message =
          extractDioErrorMessage(e, fallback: '사진을 불러오지 못했습니다');
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
    }
  }

  /// Fetch photos with location data for map display.
  Future<void> fetchMapPhotos() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.get('/photo/map');
      final data = response.data as Map<String, dynamic>;
      final mapPhotos = (data['photos'] as List<dynamic>)
          .map((e) => Photo.fromJson(e as Map<String, dynamic>)).toList();
      state = state.copyWith(mapPhotos: mapPhotos, isLoading: false);
    } on DioException catch (e) {
      final message =
          extractDioErrorMessage(e, fallback: '지도 사진을 불러오지 못했습니다');
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
    }
  }

  /// Upload a photo with multipart form data.
  Future<bool> uploadPhoto({
    required File imageFile,
    String? caption,
    double? latitude,
    double? longitude,
    String? location,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final fileName = imageFile.path.split('/').last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
        'caption': ?caption,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'location': ?location,
      });

      final response = await _dio.post(
        '/photo',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final photoJson = data['photo'] as Map<String, dynamic>? ?? data;
      final photo = Photo.fromJson(photoJson);
      state = state.copyWith(
        photos: [photo, ...state.photos],
        mapPhotos: photo.latitude != null && photo.longitude != null
            ? [photo, ...state.mapPhotos.where((p) => p.id != photo.id)]
            : state.mapPhotos,
        isLoading: false,
      );
      return true;
    } on DioException catch (e) {
      final message =
          extractDioErrorMessage(e, fallback: '사진 업로드에 실패했습니다');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
      return false;
    }
  }

  /// Delete a photo.
  Future<bool> deletePhoto(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _dio.delete('/photo/$id');
      final updatedPhotos =
          state.photos.where((photo) => photo.id != id).toList();
      final updatedMapPhotos =
          state.mapPhotos.where((photo) => photo.id != id).toList();
      state = state.copyWith(
        photos: updatedPhotos,
        mapPhotos: updatedMapPhotos,
        isLoading: false,
      );
      return true;
    } on DioException catch (e) {
      final message =
          extractDioErrorMessage(e, fallback: '사진 삭제에 실패했습니다');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
      return false;
    }
  }
}

// Providers
final photoProvider = NotifierProvider<PhotoNotifier, PhotoState>(
  PhotoNotifier.new,
);

final mapPhotosProvider = Provider<List<Photo>>((ref) {
  return ref.watch(photoProvider).mapPhotos;
});
