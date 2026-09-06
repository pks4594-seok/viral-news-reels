import 'package:flutter/material.dart';

import '../models/upload_task.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// 플랫폼 선택 + 예약 시각 지정 시트
///
/// 릴스를 어느 플랫폼에, 언제 발행할지 고릅니다.
class PlatformPickerSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final void Function(List<UploadPlatform> platforms, DateTime? scheduledAt)
      onConfirm;

  const PlatformPickerSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onConfirm,
  });

  /// 시트 표시 헬퍼
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required void Function(
            List<UploadPlatform> platforms, DateTime? scheduledAt)
        onConfirm,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => PlatformPickerSheet(
        title: title,
        subtitle: subtitle,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<PlatformPickerSheet> createState() => _PlatformPickerSheetState();
}

class _PlatformPickerSheetState extends State<PlatformPickerSheet> {
  final Set<UploadPlatform> _selected = {
    UploadPlatform.youtube,
    UploadPlatform.tiktok,
  };
  int _scheduleOption = 0;

  static const _meta = <UploadPlatform, (IconData, Color, String)>{
    UploadPlatform.youtube: (
      Icons.play_circle_fill_rounded,
      AppColors.neonRed,
      '세로 9:16 · 최대 60초 · 검색 키워드 최적화'
    ),
    UploadPlatform.tiktok: (
      Icons.music_note_rounded,
      AppColors.neonCyan,
      '세로 9:16 · 짧고 감각적인 제목 · 인라인 해시태그'
    ),
    UploadPlatform.blog: (
      Icons.article_rounded,
      AppColors.neonLime,
      '본문 + 스크립트 전문 · SEO 제목'
    ),
  };

  static const _scheduleLabels = ['즉시', '1시간 후', '오늘 저녁 7시', '내일 아침 8시'];

  DateTime? _resolveSchedule() {
    final now = DateTime.now();
    switch (_scheduleOption) {
      case 1:
        return now.add(const Duration(hours: 1));
      case 2:
        final t = DateTime(now.year, now.month, now.day, 19);
        return t.isBefore(now) ? t.add(const Duration(days: 1)) : t;
      case 3:
        return DateTime(now.year, now.month, now.day + 1, 8);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(widget.title,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(widget.subtitle,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 18),
                Text('발행 플랫폼',
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 9),
                ...UploadPlatform.values.map((p) {
                  final (icon, color, desc) = _meta[p]!;
                  final on = _selected.contains(p);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => setState(() {
                        if (on) {
                          _selected.remove(p);
                        } else {
                          _selected.add(p);
                        }
                      }),
                      borderRadius: BorderRadius.circular(13),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 11),
                        decoration: BoxDecoration(
                          color: on
                              ? color.withValues(alpha: 0.11)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: on
                                ? color.withValues(alpha: 0.55)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(icon, size: 20, color: color),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.label,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: on
                                          ? AppColors.textHigh
                                          : AppColors.textMid,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    desc,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              on
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              size: 19,
                              color: on ? color : AppColors.textLow,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Text('발행 시각',
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: List.generate(_scheduleLabels.length, (i) {
                    final on = _scheduleOption == i;
                    return InkWell(
                      onTap: () => setState(() => _scheduleOption = i),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: on
                              ? AppColors.neonPurple.withValues(alpha: 0.18)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color:
                                on ? AppColors.neonPurple : AppColors.border,
                          ),
                        ),
                        child: Text(
                          _scheduleLabels[i],
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: on
                                ? AppColors.neonPurple
                                : AppColors.textMid,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                NeonButton(
                  label: '${_selected.length}개 플랫폼에 큐 추가',
                  icon: Icons.playlist_add_check_rounded,
                  expanded: true,
                  gradient: AppColors.purpleGradient,
                  onPressed: _selected.isEmpty
                      ? null
                      : () => widget.onConfirm(
                            _selected.toList(),
                            _resolveSchedule(),
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
