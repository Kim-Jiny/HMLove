import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'constants.dart';

/// 내장 알림 소리 정의
class NotificationSound {
  final String id;
  final String label;
  final String emoji;

  const NotificationSound({
    required this.id,
    required this.label,
    required this.emoji,
  });

  /// 사용자 녹음인지 여부
  bool get isCustom => id.startsWith('custom_');
}

class NotificationSoundService {
  NotificationSoundService._();

  static final AudioPlayer _player = AudioPlayer();
  static String? _soundDir;

  /// 내장 사운드 목록
  static const builtInSounds = <NotificationSound>[
    NotificationSound(id: 'none', label: '없음', emoji: '🔇'),
    NotificationSound(id: 'default', label: '기본', emoji: '🔔'),
    NotificationSound(id: 'bell', label: '벨', emoji: '🛎️'),
    NotificationSound(id: 'heart', label: '하트', emoji: '💕'),
    NotificationSound(id: 'star', label: '별', emoji: '⭐'),
    NotificationSound(id: 'droplet', label: '물방울', emoji: '💧'),
    NotificationSound(id: 'chime', label: '차임', emoji: '🎵'),
    NotificationSound(id: 'pop', label: '팝', emoji: '🫧'),
    NotificationSound(id: 'ding', label: '딩동', emoji: '🔊'),
  ];

  /// 초기화: 내장 사운드 WAV 파일 생성
  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    _soundDir = '${dir.path}/notification_sounds';
    final soundDir = Directory(_soundDir!);
    if (!soundDir.existsSync()) {
      soundDir.createSync(recursive: true);
    }

    // 내장 사운드 생성 (없으면)
    for (final sound in builtInSounds) {
      if (sound.id == 'none') continue;
      final file = File('${_soundDir!}/${sound.id}.wav');
      if (!file.existsSync()) {
        final bytes = _generateTone(sound.id);
        await file.writeAsBytes(bytes);
      }
    }
  }

  /// 사운드 디렉토리 경로
  static String get soundDir => _soundDir ?? '';

  /// 사용자 녹음 목록 조회
  static List<NotificationSound> getCustomSounds() {
    final box = Hive.box(AppConstants.settingsBox);
    final list = box.get('custom_sounds', defaultValue: <dynamic>[]) as List;
    return list.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return NotificationSound(
        id: map['id'] as String,
        label: map['label'] as String,
        emoji: '🎙️',
      );
    }).toList();
  }

  /// 전체 사운드 목록 (내장 + 사용자)
  static List<NotificationSound> getAllSounds() {
    return [...builtInSounds, ...getCustomSounds()];
  }

  /// 특정 카테고리에 설정된 사운드 ID
  static String getSoundId(String categoryKey) {
    final box = Hive.box(AppConstants.settingsBox);
    return box.get('${categoryKey}_sound_id', defaultValue: 'default') as String;
  }

  /// 카테고리에 사운드 설정
  static void setSoundId(String categoryKey, String soundId) {
    final box = Hive.box(AppConstants.settingsBox);
    box.put('${categoryKey}_sound_id', soundId);
  }

  /// 사운드 미리 듣기
  static Future<void> preview(String soundId) async {
    await _player.stop();
    if (soundId == 'none') return;

    final path = _getPath(soundId);
    if (path == null || !File(path).existsSync()) return;

    await _player.play(DeviceFileSource(path));
  }

  /// 알림 사운드 재생 (카테고리 키 기반)
  static Future<void> playForCategory(String categoryKey) async {
    final soundId = getSoundId(categoryKey);
    if (soundId == 'none') return;

    final box = Hive.box(AppConstants.settingsBox);
    final catSound = box.get('${categoryKey}_sound', defaultValue: true) as bool;
    if (!catSound) return;

    final path = _getPath(soundId);
    if (path == null || !File(path).existsSync()) return;

    await _player.play(DeviceFileSource(path));
  }

  /// 녹음 시작
  static Future<bool> startRecording(String recordId) async {
    final recorder = AudioRecorder();
    if (!await recorder.hasPermission()) return false;

    final path = '${_soundDir!}/$recordId.m4a';
    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
    _activeRecorder = recorder;
    return true;
  }

  static AudioRecorder? _activeRecorder;

  /// 녹음 중지 → 저장
  static Future<String?> stopRecording(String recordId, String label) async {
    if (_activeRecorder == null) return null;
    final path = await _activeRecorder!.stop();
    await _activeRecorder!.dispose();
    _activeRecorder = null;
    if (path == null) return null;

    // Hive에 사용자 녹음 목록 저장
    final box = Hive.box(AppConstants.settingsBox);
    final list = (box.get('custom_sounds', defaultValue: <dynamic>[]) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    list.add({'id': recordId, 'label': label});
    await box.put('custom_sounds', list);

    return path;
  }

  /// 녹음 취소
  static Future<void> cancelRecording() async {
    if (_activeRecorder == null) return;
    await _activeRecorder!.stop();
    await _activeRecorder!.dispose();
    _activeRecorder = null;
  }

  /// 사용자 녹음 삭제
  static Future<void> deleteCustomSound(String soundId) async {
    final box = Hive.box(AppConstants.settingsBox);
    final list = (box.get('custom_sounds', defaultValue: <dynamic>[]) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    list.removeWhere((e) => e['id'] == soundId);
    await box.put('custom_sounds', list);

    // 파일 삭제
    final file = File('${_soundDir!}/$soundId.m4a');
    if (file.existsSync()) await file.delete();
  }

  /// 사운드 파일 경로
  static String? _getPath(String soundId) {
    if (_soundDir == null) return null;
    // 사용자 녹음은 m4a
    final m4a = File('${_soundDir!}/$soundId.m4a');
    if (m4a.existsSync()) return m4a.path;
    // 내장 사운드는 wav
    final wav = File('${_soundDir!}/$soundId.wav');
    if (wav.existsSync()) return wav.path;
    return null;
  }

  // ── WAV 톤 생성 ──

  static Uint8List _generateTone(String id) {
    switch (id) {
      case 'default':
        return _makeTone(freq: 880, durationMs: 200, fadeMs: 50);
      case 'bell':
        return _makeTone(freq: 1200, durationMs: 300, fadeMs: 80);
      case 'heart':
        return _makeMultiTone([
          (freq: 660, durationMs: 120, fadeMs: 30),
          (freq: 880, durationMs: 200, fadeMs: 60),
        ]);
      case 'star':
        return _makeMultiTone([
          (freq: 1046, durationMs: 100, fadeMs: 20),
          (freq: 880, durationMs: 150, fadeMs: 40),
        ]);
      case 'droplet':
        return _makeTone(freq: 1400, durationMs: 80, fadeMs: 20);
      case 'chime':
        return _makeMultiTone([
          (freq: 523, durationMs: 150, fadeMs: 40),
          (freq: 659, durationMs: 150, fadeMs: 40),
          (freq: 784, durationMs: 250, fadeMs: 80),
        ]);
      case 'pop':
        return _makeTone(freq: 600, durationMs: 60, fadeMs: 15);
      case 'ding':
        return _makeMultiTone([
          (freq: 784, durationMs: 200, fadeMs: 50),
          (freq: 1046, durationMs: 300, fadeMs: 100),
        ]);
      default:
        return _makeTone(freq: 880, durationMs: 200, fadeMs: 50);
    }
  }

  static Uint8List _makeTone({
    required double freq,
    required int durationMs,
    required int fadeMs,
  }) {
    const sampleRate = 44100;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final fadeSamples = (sampleRate * fadeMs / 1000).round();
    final samples = Int16List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      double amplitude = 0.5;
      // Fade in
      if (i < fadeSamples) {
        amplitude *= i / fadeSamples;
      }
      // Fade out
      if (i > numSamples - fadeSamples) {
        amplitude *= (numSamples - i) / fadeSamples;
      }
      samples[i] = (amplitude * 32767 * sin(2 * pi * freq * i / sampleRate)).round().clamp(-32767, 32767);
    }

    return _encodeWav(samples, sampleRate);
  }

  static Uint8List _makeMultiTone(List<({double freq, int durationMs, int fadeMs})> tones) {
    const sampleRate = 44100;
    const gapMs = 60;
    final gapSamples = (sampleRate * gapMs / 1000).round();

    final allSamples = <int>[];
    for (int t = 0; t < tones.length; t++) {
      final tone = tones[t];
      final numSamples = (sampleRate * tone.durationMs / 1000).round();
      final fadeSamples = (sampleRate * tone.fadeMs / 1000).round();

      for (int i = 0; i < numSamples; i++) {
        double amplitude = 0.5;
        if (i < fadeSamples) amplitude *= i / fadeSamples;
        if (i > numSamples - fadeSamples) amplitude *= (numSamples - i) / fadeSamples;
        allSamples.add(
          (amplitude * 32767 * sin(2 * pi * tone.freq * i / sampleRate)).round().clamp(-32767, 32767),
        );
      }
      // 톤 사이 간격
      if (t < tones.length - 1) {
        allSamples.addAll(List.filled(gapSamples, 0));
      }
    }

    return _encodeWav(Int16List.fromList(allSamples), sampleRate);
  }

  static Uint8List _encodeWav(Int16List samples, int sampleRate) {
    final dataSize = samples.length * 2;
    final fileSize = 36 + dataSize;
    final buffer = ByteData(44 + dataSize);

    // RIFF header
    buffer.setUint8(0, 0x52); // R
    buffer.setUint8(1, 0x49); // I
    buffer.setUint8(2, 0x46); // F
    buffer.setUint8(3, 0x46); // F
    buffer.setUint32(4, fileSize, Endian.little);
    buffer.setUint8(8, 0x57);  // W
    buffer.setUint8(9, 0x41);  // A
    buffer.setUint8(10, 0x56); // V
    buffer.setUint8(11, 0x45); // E

    // fmt chunk
    buffer.setUint8(12, 0x66); // f
    buffer.setUint8(13, 0x6D); // m
    buffer.setUint8(14, 0x74); // t
    buffer.setUint8(15, 0x20); // (space)
    buffer.setUint32(16, 16, Endian.little); // chunk size
    buffer.setUint16(20, 1, Endian.little);  // PCM
    buffer.setUint16(22, 1, Endian.little);  // mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    buffer.setUint16(32, 2, Endian.little);  // block align
    buffer.setUint16(34, 16, Endian.little); // bits per sample

    // data chunk
    buffer.setUint8(36, 0x64); // d
    buffer.setUint8(37, 0x61); // a
    buffer.setUint8(38, 0x74); // t
    buffer.setUint8(39, 0x61); // a
    buffer.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      buffer.setInt16(44 + i * 2, samples[i], Endian.little);
    }

    return buffer.buffer.asUint8List();
  }
}
