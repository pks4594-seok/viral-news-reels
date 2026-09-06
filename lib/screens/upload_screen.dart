import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/news_article.dart';
import '../models/upload_task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 업로드 큐 — 플랫폼별 발행 관리 + 예약 발행
class UploadScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  const UploadScreen({super.key, required this.onNavigate});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  UploadStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tasks = state.uploadsByStatus(_filter);

    return Column(
      children: [
        _Header(state: state, onNavigate: widget.onNavigate),
        _FilterChips(
          state: state,
          current: _filter,
          onChange: (f) => setState(() => _filter = f),
        ),
        Expanded(
          child: tasks.isEmpty
              ? EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: _filter == null
                      ? '업로드 큐가 비어 있습니다'
                      : '${_filter!.label} 상태의 작업이 없습니다',
                  message: '스튜디오에서 완성된 릴스를\n업로드 큐에 추가해 보세요.',
                  action: NeonButton(
                    label: '스튜디오 열기',
                    icon: Icons.movie_creation_rounded,
                    onPressed: () => widget.onNavigate(2),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _TaskCard(task: tasks[i]),
                ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final AppState state;
  final ValueChanged<int> onNavigate;
  const _Header({required this.state, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final published = state.totalPublished;
    final pending = state.pendingUploadCount;
    final views = state.uploads
        .where((u) => u.status == UploadStatus.published)
        .fold<int>(0, (s, u) => s + u.actualViews);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.neonPurple.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_upload_rounded,
                    color: AppColors.neonPurple, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: GradientText(
                  '업로드 큐',
                  gradient: AppColors.purpleGradient,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
              ),
              if (pending > 0)
                NeonButton(
                  label: '전체 발행',
                  icon: Icons.rocket_launch_rounded,
                  compact: true,
                  gradient: AppColors.purpleGradient,
                  onPressed: () => _publishAll(context, state),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '발행 완료',
                  value: '$published',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.neonLime,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: StatTile(
                  label: '대기 중',
                  value: '$pending',
                  icon: Icons.pending_actions_rounded,
                  color: AppColors.neonAmber,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: StatTile(
                  label: '실제 조회',
                  value: views > 0
                      ? NewsArticle.formatCount(views)
                      : '집계 없음',
                  icon: Icons.visibility_rounded,
                  color: AppColors.neonCyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _publishAll(BuildContext context, AppState state) {
    final messenger = ScaffoldMessenger.of(context);
    final count = state.pendingUploadCount;
    messenger.showSnackBar(
      SnackBar(content: Text('$count건 발행을 시작합니다')),
    );
    state.runAllPending();
  }
}

class _FilterChips extends StatelessWidget {
  final AppState state;
  final UploadStatus? current;
  final ValueChanged<UploadStatus?> onChange;

  const _FilterChips({
    required this.state,
    required this.current,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final options = <(String, UploadStatus?, Color)>[
      ('전체', null, AppColors.neonPurple),
      ('초안', UploadStatus.draft, AppColors.textMid),
      ('예약됨', UploadStatus.scheduled, AppColors.neonAmber),
      ('발행 완료', UploadStatus.published, AppColors.neonLime),
      ('실패', UploadStatus.failed, AppColors.neonRed),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (ctx, i) {
          final (label, status, color) = options[i];
          final active = current == status;
          final count = state.uploadsByStatus(status).length;
          return Center(
            child: InkWell(
              onTap: () => onChange(status),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: active
                      ? color.withValues(alpha: 0.18)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: active ? color : AppColors.border),
                ),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            active ? FontWeight.w800 : FontWeight.w600,
                        color: active ? color : AppColors.textMid,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: active
                              ? color
                              : AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: active
                                ? Colors.white
                                : AppColors.textLow,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final UploadTask task;
  const _TaskCard({required this.task});

  static (IconData, Color) _platformMeta(UploadPlatform p) {
    switch (p) {
      case UploadPlatform.youtube:
        return (Icons.play_circle_fill_rounded, AppColors.neonRed);
      case UploadPlatform.tiktok:
        return (Icons.music_note_rounded, AppColors.neonCyan);
      case UploadPlatform.blog:
        return (Icons.article_rounded, AppColors.neonLime);
    }
  }

  static Color _statusColor(UploadStatus s) {
    switch (s) {
      case UploadStatus.draft:
        return AppColors.textMid;
      case UploadStatus.scheduled:
        return AppColors.neonAmber;
      case UploadStatus.uploading:
        return AppColors.neonCyan;
      case UploadStatus.published:
        return AppColors.neonLime;
      case UploadStatus.failed:
        return AppColors.neonRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final (pIcon, pColor) = _platformMeta(task.platform);
    final sColor = _statusColor(task.status);
    final uploading = task.status == UploadStatus.uploading;

    return GlassCard(
      padding: const EdgeInsets.all(12),
      glowColor: task.status == UploadStatus.failed
          ? AppColors.neonRed
          : (task.status == UploadStatus.published ? null : pColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 썸네일
              Stack(
                children: [
                  NetImage(
                      url: task.thumbnailUrl,
                      width: 54,
                      height: 68,
                      radius: 10),
                  Positioned(
                    left: 3,
                    top: 3,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(pIcon, size: 11, color: pColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        NeonBadge(
                          label: task.platform.short,
                          color: pColor,
                          filled: true,
                        ),
                        const SizedBox(width: 5),
                        NeonBadge(label: task.status.label, color: sColor),
                        const Spacer(),
                        if (task.status == UploadStatus.published)
                          Row(
                            children: [
                              const Icon(Icons.visibility_rounded,
                                  size: 11, color: AppColors.neonLime),
                              const SizedBox(width: 3),
                              Text(
                                NewsArticle.formatCount(task.actualViews),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.neonLime,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      task.platformTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textHigh,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          task.scheduledAt == null
                              ? Icons.bolt_rounded
                              : Icons.schedule_rounded,
                          size: 11,
                          color: AppColors.textLow,
                        ),
                        const SizedBox(width: 4),
                        Text(task.scheduleLabel,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 오류 메시지
          if (task.errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.neonRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                    color: AppColors.neonRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: AppColors.neonRed),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      task.errorMessage!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.neonRed,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 업로드 진행률
          if (uploading) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.neonCyan),
                ),
                const SizedBox(width: 7),
                Text(
                  '${task.platform.label} 전송 중 ${(task.progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neonCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: task.progress,
                minHeight: 5,
                backgroundColor: AppColors.surfaceHigh,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.neonCyan),
              ),
            ),
          ] else ...[
            const SizedBox(height: 11),
            Row(
              children: [
                if (task.status != UploadStatus.published)
                  Expanded(
                    child: NeonButton(
                      label: task.status == UploadStatus.failed
                          ? '재시도'
                          : '지금 발행',
                      icon: task.status == UploadStatus.failed
                          ? Icons.refresh_rounded
                          : Icons.rocket_launch_rounded,
                      expanded: true,
                      compact: true,
                      gradient: task.status == UploadStatus.failed
                          ? const LinearGradient(colors: [
                              AppColors.neonRed,
                              AppColors.neonAmber
                            ])
                          : AppColors.purpleGradient,
                      onPressed: () => state.runUpload(task.id),
                    ),
                  )
                else
                  Expanded(
                    child: GhostButton(
                      label: '발행 내용 복사',
                      icon: Icons.copy_rounded,
                      color: AppColors.neonLime,
                      expanded: true,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                            text: '${task.platformTitle}\n\n'
                                '${task.platformDescription}'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  '제목과 설명을 복사했습니다 — 플랫폼에 직접 붙여넣어 사용하실 수 있습니다')),
                        );
                      },
                    ),
                  ),
                const SizedBox(width: 7),
                GhostButton(
                  label: '메타',
                  icon: Icons.edit_note_rounded,
                  color: AppColors.neonAmber,
                  onPressed: () => _showMeta(context, state),
                ),
                const SizedBox(width: 7),
                IconButton(
                  onPressed: () => state.removeUpload(task.id),
                  icon: const Icon(Icons.close_rounded, size: 17),
                  color: AppColors.textLow,
                  visualDensity: VisualDensity.compact,
                  tooltip: '큐에서 제거',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showMeta(BuildContext context, AppState state) {
    final titleCtrl = TextEditingController(text: task.platformTitle);
    final descCtrl = TextEditingController(text: task.platformDescription);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
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
                    Row(
                      children: [
                        Text('${task.platform.label} 메타데이터',
                            style: Theme.of(ctx).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('플랫폼 특성에 맞춰 자동 최적화된 내용입니다',
                        style: Theme.of(ctx).textTheme.bodySmall),
                    const SizedBox(height: 18),
                    Text('제목',
                        style: Theme.of(ctx).textTheme.labelSmall),
                    const SizedBox(height: 7),
                    _input(titleCtrl, 2),
                    const SizedBox(height: 14),
                    Text('설명',
                        style: Theme.of(ctx).textTheme.labelSmall),
                    const SizedBox(height: 7),
                    _input(descCtrl, 8),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: task.hashtags
                          .map((h) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.neonPurple
                                      .withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#$h',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.neonPurple,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    NeonButton(
                      label: '저장',
                      icon: Icons.save_rounded,
                      expanded: true,
                      onPressed: () {
                        state.updateUploadMeta(
                          task.id,
                          title: titleCtrl.text,
                          description: descCtrl.text,
                        );
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, int maxLines) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(
          color: AppColors.textHigh, fontSize: 13, height: 1.5),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.neonMagenta),
        ),
      ),
    );
  }
}
