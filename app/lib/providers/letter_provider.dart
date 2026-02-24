import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

// Letter model
class Letter {
  final String id;
  final String title;
  final String content;
  final DateTime deliveryDate;
  final bool isRead;
  final bool isDelivered;
  final String senderId;
  final String? senderNickname;
  final String receiverId;
  final String? receiverNickname;
  final String coupleId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Letter({
    required this.id,
    required this.title,
    required this.content,
    required this.deliveryDate,
    this.isRead = false,
    this.isDelivered = false,
    required this.senderId,
    this.senderNickname,
    required this.receiverId,
    this.receiverNickname,
    required this.coupleId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Letter.fromJson(Map<String, dynamic> json) {
    return Letter(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      deliveryDate: DateTime.parse(json['deliveryDate'] as String),
      isRead: json['isRead'] as bool? ?? false,
      isDelivered: json['isDelivered'] as bool? ?? false,
      senderId: json['senderId'] as String,
      senderNickname: json['senderNickname'] as String?,
      receiverId: json['receiverId'] as String,
      receiverNickname: json['receiverNickname'] as String?,
      coupleId: json['coupleId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'deliveryDate': deliveryDate.toIso8601String(),
      'isRead': isRead,
      'isDelivered': isDelivered,
      'senderId': senderId,
      'senderNickname': senderNickname,
      'receiverId': receiverId,
      'receiverNickname': receiverNickname,
      'coupleId': coupleId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

// Letter state class
class LetterState {
  final List<Letter> letters;
  final Letter? selectedLetter;
  final bool isLoading;
  final String? error;

  const LetterState({
    this.letters = const [],
    this.selectedLetter,
    this.isLoading = false,
    this.error,
  });

  LetterState copyWith({
    List<Letter>? letters,
    Letter? selectedLetter,
    bool? isLoading,
    String? error,
  }) {
    return LetterState(
      letters: letters ?? this.letters,
      selectedLetter: selectedLetter ?? this.selectedLetter,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Letter Notifier
class LetterNotifier extends Notifier<LetterState> {
  late final Dio _dio;

  @override
  LetterState build() {
    _dio = ref.read(dioProvider);
    return const LetterState();
  }

  /// Fetch all letters (sent and received).
  Future<void> fetchLetters() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.get('/letter');
      final data = response.data as List<dynamic>;
      final letters =
          data.map((e) => Letter.fromJson(e as Map<String, dynamic>)).toList();
      state = state.copyWith(letters: letters, isLoading: false);
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '편지를 불러오지 못했습니다';
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
    }
  }

  /// Fetch a single letter by ID.
  Future<void> fetchLetter(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.get('/letter/$id');
      final letter = Letter.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(selectedLetter: letter, isLoading: false);
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '편지를 불러오지 못했습니다';
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
    }
  }

  /// Create a new letter.
  Future<bool> createLetter({
    required String title,
    required String content,
    DateTime? deliveryDate,
    String? status,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post('/letter', data: {
        'title': title,
        'content': content,
        if (deliveryDate != null) 'deliveryDate': deliveryDate.toIso8601String(),
        if (status != null) 'status': status,
      });

      final letter = Letter.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(
        letters: [letter, ...state.letters],
        isLoading: false,
      );
      return true;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '편지 작성에 실패했습니다';
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

  /// Update an existing letter.
  Future<bool> updateLetter({
    required String id,
    String? title,
    String? content,
    DateTime? deliveryDate,
    String? status,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.put('/letter/$id', data: {
        if (title != null) 'title': title,
        if (content != null) 'content': content,
        if (deliveryDate != null)
          'deliveryDate': deliveryDate.toIso8601String(),
        if (status != null) 'status': status,
      });

      final updatedLetter =
          Letter.fromJson(response.data as Map<String, dynamic>);
      final updatedLetters = state.letters.map((letter) {
        return letter.id == id ? updatedLetter : letter;
      }).toList();

      state = state.copyWith(
        letters: updatedLetters,
        selectedLetter:
            state.selectedLetter?.id == id ? updatedLetter : null,
        isLoading: false,
      );
      return true;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '편지 수정에 실패했습니다';
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

  /// Delete a letter.
  Future<bool> deleteLetter(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _dio.delete('/letter/$id');
      final updatedLetters =
          state.letters.where((letter) => letter.id != id).toList();
      state = state.copyWith(
        letters: updatedLetters,
        selectedLetter:
            state.selectedLetter?.id == id ? null : state.selectedLetter,
        isLoading: false,
      );
      return true;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '편지 삭제에 실패했습니다';
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

  /// Mark a letter as read.
  Future<bool> markAsRead(String id) async {
    try {
      final response = await _dio.patch('/letter/$id/read');
      final updatedLetter =
          Letter.fromJson(response.data as Map<String, dynamic>);
      final updatedLetters = state.letters.map((letter) {
        return letter.id == id ? updatedLetter : letter;
      }).toList();

      state = state.copyWith(
        letters: updatedLetters,
        selectedLetter:
            state.selectedLetter?.id == id ? updatedLetter : null,
      );
      return true;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '읽음 처리에 실패했습니다';
      state = state.copyWith(error: message);
      return false;
    } catch (e) {
      state = state.copyWith(error: '알 수 없는 오류가 발생했습니다');
      return false;
    }
  }
}

// Providers
final letterProvider =
    NotifierProvider<LetterNotifier, LetterState>(
  LetterNotifier.new,
);

final unreadLettersCountProvider = Provider<int>((ref) {
  final letters = ref.watch(letterProvider).letters;
  return letters.where((letter) => !letter.isRead && letter.isDelivered).length;
});
