import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/device_calendar_service.dart';
import '../../../core/theme.dart';
import 'status_row.dart';

/// 공휴일 자동 감지가 비어있을 때 사용자가 직접 원인을 확인할 수 있는 시트.
/// - 권한 상태
/// - 기기에 등록된 캘린더 목록 (이름·계정·읽기전용·후보 매칭 여부)
/// - 후보가 0개면 한국 사용자 기준 가이드 표시
class HolidayDiagnosisSheet extends StatelessWidget {
  final bool hasPermission;
  final List<dc.Calendar> calendars;

  const HolidayDiagnosisSheet({
    super.key,
    required this.hasPermission,
    required this.calendars,
  });

  @override
  Widget build(BuildContext context) {
    final candidates = calendars
        .where(DeviceCalendarService.isHolidayCalendarCandidate)
        .toList();
    final hasCandidate = candidates.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
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
            const Text(
              '공휴일 진단',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // 1. 권한 상태
            StatusRow(
              ok: hasPermission,
              label: hasPermission ? '캘린더 권한 허용됨' : '캘린더 권한 거부됨',
            ),
            const SizedBox(height: 6),
            // 2. 후보 매칭 결과
            StatusRow(
              ok: hasCandidate,
              label: hasCandidate
                  ? '공휴일 캘린더 ${candidates.length}개 감지됨'
                  : '자동 감지된 공휴일 캘린더가 없음',
            ),
            const SizedBox(height: 16),
            if (calendars.isNotEmpty) ...[
              const Text(
                '기기 캘린더 목록',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              // 외부 SingleChildScrollView가 스크롤을 담당. 내부 ListView는 layout만.
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: calendars.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = calendars[i];
                  final isCandidate =
                      DeviceCalendarService.isHolidayCalendarCandidate(c);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: c.color != null ? Color(c.color!) : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      c.name?.isNotEmpty == true ? c.name! : '(이름 없음)',
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${c.accountName ?? "-"} · '
                      '${c.isReadOnly == true
                          ? "읽기전용"
                          : c.isReadOnly == false
                          ? "쓰기가능"
                          : "?"}',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isCandidate
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFD32F2F,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '공휴일',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFD32F2F),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : null,
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
            if (!hasPermission) ...[
              // 권한 거부 케이스: 캘린더 앱 가이드보다 권한 허용이 먼저.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '캘린더 권한이 거부돼 공휴일 캘린더를 읽을 수 없습니다.\n'
                  '시스템 설정에서 캘린더 권한을 허용해주세요.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Geolocator.openAppSettings();
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('설정으로 이동'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else if (!hasCandidate) ...[
              // 권한은 있는데 후보가 없음 → 캘린더 구독 가이드.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '공휴일을 표시하려면',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Google 캘린더 앱 설치 후 로그인\n'
                      '2. 앱 메뉴 → 설정 → 휴일 → 대한민국 추가\n'
                      '3. 동기화 후 이 화면을 다시 열기\n\n'
                      '삼성 캘린더 사용자: 캘린더 앱 → ☰ → 캘린더 관리에서\n'
                      '"대한민국 휴일"을 켜주세요.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('확인'),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('확인'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
