import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';

class LocationData {
  final double lat;
  final double lng;
  final String label;
  const LocationData(this.lat, this.lng, this.label);
}

class LocationBubble extends StatelessWidget {
  final LocationData data;
  final bool isMe;
  final bool interactive;

  const LocationBubble({super.key, required this.data, required this.isMe, this.interactive = true});

  @override
  Widget build(BuildContext context) {
    // 서버 프록시를 통한 Naver Static Map (깔끔한 네이버 지도 이미지)
    final staticMapUrl =
        '${AppConstants.apiBaseUrl}/map/static'
        '?lat=${data.lat}&lng=${data.lng}&w=600&h=300&zoom=15';

    return GestureDetector(
      onTap: interactive ? () => _openInMaps(data.lat, data.lng, data.label) : null,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 네이버 Static Map 미리보기
            SizedBox(
              height: 130,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    staticMapUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFFF0F4F8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on, color: Colors.red, size: 36),
                          const SizedBox(height: 4),
                          Text(
                            '${data.lat.toStringAsFixed(4)}, ${data.lng.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textHint),
                          ),
                        ],
                      ),
                    ),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: const Color(0xFFF0F4F8),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                  ),
                  // 네이버 지도로 보기 뱃지
                  Positioned(
                    top: 6,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1EC800),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'N',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 3),
                          Text(
                            '지도 보기',
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 18, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      data.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: AppTheme.textHint),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInMaps(double lat, double lng, String label) async {
    final encodedLabel = Uri.encodeComponent(label);
    // 네이버 지도: 마커 표시 + 장소명
    final naverUrl = Uri.parse(
      'nmap://place?lat=$lat&lng=$lng&name=$encodedLabel&appname=com.jiny.hmlove',
    );

    if (await canLaunchUrl(naverUrl)) {
      await launchUrl(naverUrl);
    } else if (Platform.isIOS) {
      // iOS: 애플 지도 fallback
      final appleUrl = Uri.parse(
        'https://maps.apple.com/?ll=$lat,$lng&q=$encodedLabel',
      );
      await launchUrl(appleUrl, mode: LaunchMode.externalApplication);
    } else {
      // Android: 구글 지도 fallback
      final googleUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    }
  }
}
