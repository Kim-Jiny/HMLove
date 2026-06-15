import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/wish_item.dart';

class WishlistState {
  static const _sentinel = Object();

  final List<WishItem> items;
  final bool isLoading;
  final String? error;
  final WishCategory? filterCategory;

  const WishlistState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.filterCategory,
  });

  WishlistState copyWith({
    List<WishItem>? items,
    bool? isLoading,
    Object? error = _sentinel,
    WishCategory? filterCategory,
    bool clearFilter = false,
  }) {
    return WishlistState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      filterCategory: clearFilter
          ? null
          : (filterCategory ?? this.filterCategory),
    );
  }

  List<WishItem> get filteredItems {
    if (filterCategory == null) return items;
    return items.where((i) => i.category == filterCategory).toList();
  }
}

class WishlistNotifier extends Notifier<WishlistState> {
  late final Dio _dio;

  List<WishItem> _sortItems(List<WishItem> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  @override
  WishlistState build() {
    _dio = ref.read(dioProvider);
    return const WishlistState();
  }

  void setFilter(WishCategory? category) {
    if (category == null) {
      state = state.copyWith(clearFilter: true);
    } else if (category == state.filterCategory) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filterCategory: category);
    }
  }

  void applyItems(List<dynamic>? rawItems) {
    if (rawItems == null) return;
    final items = rawItems
        .map((e) => WishItem.fromJson(e as Map<String, dynamic>))
        .toList();
    state = state.copyWith(
      items: _sortItems(items),
      isLoading: false,
      error: null,
    );
  }

  Future<void> fetchItems() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/wishlist');
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List)
          .map((e) => WishItem.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        items: _sortItems(items),
        isLoading: false,
        error: null,
      );
    } on DioException catch (e) {
      final message =
          ((e.response?.data is Map)
                  ? (e.response?.data['error'] ?? e.response?.data['message'])
                  : null)
              as String? ??
          '위시리스트를 불러오는데 실패했습니다.';
      state = state.copyWith(error: message, isLoading: false);
    } catch (e) {
      debugPrint('[Wishlist] fetchItems error: $e');
      state = state.copyWith(error: '알 수 없는 오류가 발생했습니다.', isLoading: false);
    }
  }

  Future<bool> addItem({
    required String title,
    String? memo,
    WishCategory category = WishCategory.OTHER,
  }) async {
    try {
      final response = await _dio.post(
        '/wishlist',
        data: {'title': title, 'memo': memo, 'category': category.name},
      );
      final data = response.data as Map<String, dynamic>;
      final item = WishItem.fromJson(data['item'] as Map<String, dynamic>);
      // 소켓 이벤트로 이미 추가되었을 수 있으므로 중복 체크
      if (!state.items.any((i) => i.id == item.id)) {
        state = state.copyWith(items: _sortItems([item, ...state.items]));
      }
      return true;
    } on DioException catch (e) {
      final message =
          ((e.response?.data is Map)
                  ? (e.response?.data['error'] ?? e.response?.data['message'])
                  : null)
              as String? ??
          '위시리스트 추가에 실패했습니다.';
      state = state.copyWith(error: message);
      return false;
    } catch (e) {
      debugPrint('[Wishlist] addItem error: $e');
      state = state.copyWith(error: '알 수 없는 오류가 발생했습니다.');
      return false;
    }
  }

  Future<bool> updateItem(
    String id, {
    String? title,
    String? memo,
    WishCategory? category,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (memo != null) data['memo'] = memo;
      if (category != null) data['category'] = category.name;
      final response = await _dio.patch('/wishlist/$id', data: data);
      final updated = WishItem.fromJson(
        (response.data as Map<String, dynamic>)['item'] as Map<String, dynamic>,
      );
      state = state.copyWith(
        items: _sortItems(
          state.items.map((i) => i.id == id ? updated : i).toList(),
        ),
      );
      return true;
    } on DioException catch (e) {
      final message =
          ((e.response?.data is Map)
                  ? (e.response?.data['error'] ?? e.response?.data['message'])
                  : null)
              as String? ??
          '위시리스트 수정에 실패했습니다.';
      state = state.copyWith(error: message);
      return false;
    } catch (e) {
      debugPrint('[Wishlist] updateItem error: $e');
      state = state.copyWith(error: '알 수 없는 오류가 발생했습니다.');
      return false;
    }
  }

  Future<bool> toggleFavorite(String id) async {
    try {
      final response = await _dio.patch('/wishlist/$id/favorite');
      final updated = WishItem.fromJson(
        (response.data as Map<String, dynamic>)['item'] as Map<String, dynamic>,
      );
      state = state.copyWith(
        items: _sortItems(
          state.items.map((i) => i.id == id ? updated : i).toList(),
        ),
      );
      return true;
    } on DioException catch (e) {
      final message =
          ((e.response?.data is Map)
                  ? (e.response?.data['error'] ?? e.response?.data['message'])
                  : null)
              as String? ??
          '즐겨찾기 변경에 실패했습니다.';
      state = state.copyWith(error: message);
      return false;
    } catch (e) {
      debugPrint('[Wishlist] toggleFavorite error: $e');
      state = state.copyWith(error: '알 수 없는 오류가 발생했습니다.');
      return false;
    }
  }

  Future<bool> toggleItem(String id) async {
    try {
      final response = await _dio.patch('/wishlist/$id/toggle');
      final updated = WishItem.fromJson(
        (response.data as Map<String, dynamic>)['item'] as Map<String, dynamic>,
      );
      state = state.copyWith(
        items: _sortItems(
          state.items.map((i) => i.id == id ? updated : i).toList(),
        ),
      );
      return true;
    } on DioException catch (e) {
      final message =
          ((e.response?.data is Map)
                  ? (e.response?.data['error'] ?? e.response?.data['message'])
                  : null)
              as String? ??
          '완료 상태 변경에 실패했습니다.';
      state = state.copyWith(error: message);
      return false;
    } catch (e) {
      debugPrint('[Wishlist] toggleItem error: $e');
      state = state.copyWith(error: '알 수 없는 오류가 발생했습니다.');
      return false;
    }
  }

  Future<bool> deleteItem(String id) async {
    try {
      await _dio.delete('/wishlist/$id');
      state = state.copyWith(
        items: state.items.where((i) => i.id != id).toList(),
      );
      return true;
    } on DioException catch (e) {
      final message =
          ((e.response?.data is Map)
                  ? (e.response?.data['error'] ?? e.response?.data['message'])
                  : null)
              as String? ??
          '위시리스트 삭제에 실패했습니다.';
      state = state.copyWith(error: message);
      return false;
    } catch (e) {
      debugPrint('[Wishlist] deleteItem error: $e');
      state = state.copyWith(error: '알 수 없는 오류가 발생했습니다.');
      return false;
    }
  }

  /// 소켓 이벤트로 아이템 업데이트
  void onSocketNew(WishItem item) {
    if (!state.items.any((i) => i.id == item.id)) {
      state = state.copyWith(items: _sortItems([item, ...state.items]));
    }
  }

  void onSocketUpdated(WishItem item) {
    final exists = state.items.any((i) => i.id == item.id);
    if (exists) {
      state = state.copyWith(
        items: _sortItems(
          state.items.map((i) => i.id == item.id ? item : i).toList(),
        ),
      );
    }
  }

  void onSocketToggled(WishItem item) {
    final exists = state.items.any((i) => i.id == item.id);
    if (!exists) return;
    state = state.copyWith(
      items: _sortItems(
        state.items.map((i) => i.id == item.id ? item : i).toList(),
      ),
    );
  }

  void onSocketDeleted(String id) {
    state = state.copyWith(
      items: state.items.where((i) => i.id != id).toList(),
    );
  }
}

final wishlistProvider = NotifierProvider<WishlistNotifier, WishlistState>(
  WishlistNotifier.new,
);
