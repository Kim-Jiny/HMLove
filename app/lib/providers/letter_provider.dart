import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

// Letter model
class Letter {
  final String id;
  final String title;
  final String? content;
  final DateTime deliveryDate;
  final bool isRead;
  final String status; // 'DRAFT', 'SCHEDULED', 'DELIVERED'
  final String writerId;
  final String? writerNickname;
  final String receiverId;
  final String? receiverNickname;
  final String coupleId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Letter({
    required this.id,
    required this.title,
    this.content,
    required this.deliveryDate,
    this.isRead = false,
    this.status = 'DRAFT',
    required this.writerId,
    this.writerNickname,
    required this.receiverId,
    this.receiverNickname,
    required this.coupleId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDelivered => status == 'DELIVERED';
  bool get isScheduled => status == 'SCHEDULED';

  factory Letter.fromJson(Map<String, dynamic> json) {
    final writer = json['writer'] as Map<String, dynamic>?;
    final receiver = json['receiver'] as Map<String, dynamic>?;
    return Letter(
      id: json['id'] as String,
      title: json['title'] as String? ?? '제목 없음',
      content: json['content'] as String?,
      deliveryDate: DateTime.parse(json['deliveryDate'] as String),
      isRead: json['isRead'] as bool? ?? false,
      status: json['status'] as String? ?? 'DRAFT',
      writerId: json['writerId'] as String,
      writerNickname:
          writer?['nickname'] as String? ?? json['writerNickname'] as String?,
      receiverId: json['receiverId'] as String,
      receiverNickname: receiver?['nickname'] as String? ??
          json['receiverNickname'] as String?,
      coupleId: json['coupleId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
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
      final data = response.data as Map<String, dynamic>;
      final lettersJson = data['letters'] as List<dynamic>;
      final letters = lettersJson
          .map((e) => Letter.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(letters: letters, isLoading: false);
    } on DioException catch (e) {
      final message =
          e.response?.data?['error'] as String? ?? '편지를 불러오지 못했습니다';
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
      final data = response.data as Map<String, dynamic>;
      final letter = Letter.fromJson(data['letter'] as Map<String, dynamic>);
      state = state.copyWith(selectedLetter: letter, isLoading: false);
    } on DioException catch (e) {
      final message =
          e.response?.data?['error'] as String? ?? '편지를 불러오지 못했습니다';
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
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post('/letter', data: {
        'title': title,
        'content': content,
        if (deliveryDate != null)
          'deliveryDate': deliveryDate.toIso8601String(),
      });

      final data = response.data as Map<String, dynamic>;
      final letter = Letter.fromJson(data['letter'] as Map<String, dynamic>);
      state = state.copyWith(
        letters: [letter, ...state.letters],
        isLoading: false,
      );
      return true;
    } on DioException catch (e) {
      final message =
          e.response?.data?['error'] as String? ?? '편지 작성에 실패했습니다';
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
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.put('/letter/$id', data: {
        if (title != null) 'title': title,
        if (content != null) 'content': content,
        if (deliveryDate != null)
          'deliveryDate': deliveryDate.toIso8601String(),
      });

      final data = response.data as Map<String, dynamic>;
      final updatedLetter =
          Letter.fromJson(data['letter'] as Map<String, dynamic>);
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
          e.response?.data?['error'] as String? ?? '편지 수정에 실패했습니다';
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
          e.response?.data?['error'] as String? ?? '편지 삭제에 실패했습니다';
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
      final data = response.data as Map<String, dynamic>;
      final updatedLetter =
          Letter.fromJson(data['letter'] as Map<String, dynamic>);
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
          e.response?.data?['error'] as String? ?? '읽음 처리에 실패했습니다';
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
  final state = ref.watch(letterProvider);
  final currentUserId = ApiClient.getUserId();
  return state.letters
      .where((l) => l.receiverId == currentUserId && l.isDelivered && !l.isRead)
      .length;
});
