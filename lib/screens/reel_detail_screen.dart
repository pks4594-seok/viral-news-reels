import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/reel_project.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/platform_picker.dart';

/// 릴스 상세 — 세로 프리뷰 + 자막 타임라인 + 메타데이터 편집
class ReelDetailScreen extends StatefulWidget {
  final String reelId;
  const ReelDetailScreen({super.key, required this.reelId});

  @override
  State<ReelDetailScreen> createState() => _ReelDetailScreenState();
}

class _ReelDetailScreenState extends State<ReelDetailScreen> {
  int _sceneIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reel = state.reelById(widget.reelId);

    if (reel == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('릴스')),
        body: const EmptyState(
          icon: Icons.error_outline_rounded,
          title: '릴스를 찾을 수 없습니다',
          message: '삭제되었거나 아직 생성되지 않았습니다.',
        ),
      );
    }

    final safeIndex =
        reel.scenes.isEmpty ? 0 : _sceneIndex.clamp(0, reel.scenes.length - 1);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(reel.formulaName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () => _confirmDelete(context, state, reel),
            icon: const Icon(Icons.delete_outline_rounded, size: 21),
            color: AppColors.neonRed,
            tooltip: '삭제',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          _Preview(reel: reel, sceneIndex: safeIndex),
          const SizedBox(height: 14),
          _ScoreRow(reel: reel),
          const SizedBox(height: 18),
          _MetaSection(reel: reel),
          const SizedBox(height: 18),
          _TimelineSection(
            reel: reel,
            selected: safeIndex,
            onSelect: (i) => setState(() => _sceneIndex = i),
          ),
          const SizedBox(height: 18),
          _SpecSection(reel: reel),
          const SizedBox(height: 22),
          NeonButton(
            label: '업로드 큐에 추가',
            icon: Icons.cloud_upload_rounded,
            expanded: true,
            gradient: AppColors.purpleGradient,
            onPressed: reel.isReady
                ? () => _queue(context, state, reel)
                : null,
          ),
          if (!reel.isReady)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Center(
                child: Text(
                  '렌더링이 완료되면 업로드할 수 있습니다',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _queue(BuildContext context, AppState state, ReelProject reel) {
    final messenger = ScaffoldMessenger.of(context);
    PlatformPickerSheet.show(
      context,
      title: '업로드 큐 추가',
      subtitle: reel.hookTitle,
      onConfirm: (platforms, scheduledAt) {
        state.enqueueUploads(reel, platforms, scheduledAt: scheduledAt);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('${platforms.length}개 플랫폼 큐에 추가했습니다'),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, AppState state, ReelProject reel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('릴스 삭제',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(
          '이 릴스와 연결된 업로드 작업이 모두 삭제됩니다.',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('취소', style: TextStyle(color: AppColors.textMid)),
          ),
          TextButton(
            onPressed: () {
              state.deleteReel(reel.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('삭제',
                style: TextStyle(
                    color: AppColors.neonRed, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

/// 9:16 세로 프리뷰 — 선택된 씬 + 자막 오버레이
class _Preview extends StatelessWidget {
  final ReelProject reel;
  final int sceneIndex;
  const _Preview({required this.reel, required this.sceneIndex});

  @override
  Widget build(BuildContext context) {
    final scene = reel.scenes.isNotEmpty ? reel.scenes[sceneIndex] : null;
    final caption =
        reel.captions.isNotEmpty && sceneIndex < reel.captions.length
            ? reel.captions[sceneIndex]
            : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 268),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.borderStrong),
              boxShadow: AppShadows.glow(AppColors.neonMagenta,
                  blur: 34, opacity: 0.24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (scene != null)
                    NetImage(url: scene.imageUrl)
                  else
                    Container(
                        decoration: const BoxDecoration(
                            gradient: AppColors.purpleGradient)),

                  // 시네마틱 마스크
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.9),
                          ],
                          stops: const [0, 0.28, 0.52, 1],
                        ),
                      ),
                    ),
                  ),

                  // 상단 진행 바 (씬 단위)
                  Positioned(
                    left: 10,
                    right: 10,
                    top: 10,
                    child: Row(
                      children: List.generate(reel.scenes.length, (i) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: i <= sceneIndex
                                  ? Colors.white
                                  : Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // 상단 정보
                  Positioned(
                    left: 11,
                    right: 11,
                    top: 22,
                    child: Row(
                      children: [
                        NeonBadge(
                          label: reel.article.category,
                          color: AppColors.categoryColor(
                              reel.article.category),
                          filled: true,
                        ),
                        const Spacer(),
                        if (scene != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '${scene.motion} · ${scene.durationSec}s',
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 중앙 자막 (강조형)
                  if (caption != null && caption.emphasis)
                    Center(
                      child: Padding
                        (padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Text(
                          caption.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.28,
                            letterSpacing: -0.6,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 12),
                              Shadow(
                                  color: AppColors.neonMagenta,
                                  blurRadius: 22),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // 하단 자막 + 파형
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (caption != null && !caption.emphasis)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.62),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              caption.text,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.35,
                              ),
                            ),
                          ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            const Icon(Icons.music_note_rounded,
                                size: 11, color: AppColors.neonCyan),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                reel.bgm,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        WaveformBar(
                          color: AppColors.neonCyan,
                          height: 17,
                          bars: 32,
                          animate: reel.isReady,
                        ),
                      ],
                    ),
                  ),

                  // 렌더링 중 오버레이
                  if (!reel.isReady)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 52,
                              height: 52,
                              child: CircularProgressIndicator(
                                value: reel.overallProgress,
                                strokeWidth: 3.5,
                                color: AppColors.neonMagenta,
                                backgroundColor: AppColors.surfaceHigh,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            const SizedBox(height: 13),
                            Text(
                              '${reel.stage.label} 처리 중',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${(reel.overallProgress * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.neonMagenta,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final ReelProject reel;
  const _ScoreRow({required this.reel});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: '바이럴 점수',
            value: '${reel.viralScore}',
            icon: Icons.whatshot_rounded,
            color: AppColors.heatColor(reel.viralScore),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: StatTile(
            label: '예측 조회수',
            value: reel.viewsLabel,
            icon: Icons.visibility_rounded,
            color: AppColors.neonCyan,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: StatTile(
            label: '영상 길이',
            value: '${reel.durationSec}초',
            icon: Icons.timer_outlined,
            color: AppColors.neonLime,
          ),
        ),
      ],
    );
  }
}

/// 제목 / 설명 / 해시태그 — 편집 가능
class _MetaSection extends StatelessWidget {
  final ReelProject reel;
  const _MetaSection({required this.reel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '업로드 메타데이터',
          subtitle: 'AI가 학습 공식으로 생성 · 탭하여 편집',
          icon: Icons.edit_note_rounded,
          accent: AppColors.neonAmber,
          trailing: IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                  text: '${reel.hookTitle}\n\n${reel.description}\n\n'
                      '${reel.hashtagLine}'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('메타데이터를 복사했습니다')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            color: AppColors.neonAmber,
            tooltip: '전체 복사',
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(context, '후킹 제목', reel.hookTitle,
                  AppColors.neonMagenta, () => _edit(context, reel, true)),
              const Divider(height: 22),
              _field(context, '설명 / 블로그 본문',
                  reel.description.split('\n').take(4).join('\n'),
                  AppColors.neonCyan, () => _edit(context, reel, false)),
              const Divider(height: 22),
              Text('해시태그',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: reel.hashtags
                    .map((h) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.neonPurple
                                .withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.neonPurple
                                    .withValues(alpha: 0.3)),
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(BuildContext context, String label, String value, Color color,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const Spacer(),
              Icon(Icons.edit_rounded, size: 13, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _edit(BuildContext context, ReelProject reel, bool isTitle) {
    final state = context.read<AppState>();
    final ctrl = TextEditingController(
        text: isTitle ? reel.hookTitle : reel.description);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isTitle ? '후킹 제목 편집' : '설명 편집',
            style:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          maxLines: isTitle ? 2 : 10,
          autofocus: true,
          style: const TextStyle(color: AppColors.textHigh, fontSize: 13.5),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('취소', style: TextStyle(color: AppColors.textMid)),
          ),
          TextButton(
            onPressed: () {
              state.updateReel(isTitle
                  ? reel.copyWith(hookTitle: ctrl.text)
                  : reel.copyWith(description: ctrl.text));
              Navigator.pop(ctx);
            },
            child: const Text('저장',
                style: TextStyle(
                    color: AppColors.neonMagenta,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

/// 자막 타임라인 — 컷별 자막과 타임코드
class _TimelineSection extends StatelessWidget {
  final ReelProject reel;
  final int selected;
  final ValueChanged<int> onSelect;

  const _TimelineSection({
    required this.reel,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '자막 스크립트',
          subtitle: '${reel.captions.length}개 컷 · 탭하여 프리뷰 이동',
          icon: Icons.closed_caption_rounded,
          accent: AppColors.neonCyan,
        ),
        const SizedBox(height: 12),
        ...reel.captions.asMap().entries.map((e) {
          final i = e.key;
          final c = e.value;
          final active = i == selected;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 11),
              glowColor: active ? AppColors.neonCyan : null,
              onTap: () => onSelect(i),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: active ? AppColors.cyanGradient : null,
                      color: active ? null : AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: active
                              ? Colors.white
                              : AppColors.textLow,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.text,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                c.emphasis ? FontWeight.w900 : FontWeight.w600,
                            color: c.emphasis
                                ? AppColors.textHigh
                                : AppColors.textMid,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(c.timeLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall),
                            if (c.emphasis) ...[
                              const SizedBox(width: 6),
                              const NeonBadge(
                                label: '강조',
                                color: AppColors.neonMagenta,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (i < reel.scenes.length)
                    NetImage(
                      url: reel.scenes[i].imageUrl,
                      width: 34,
                      height: 34,
                      radius: 7,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// 제작 스펙
class _SpecSection extends StatelessWidget {
  final ReelProject reel;
  const _SpecSection({required this.reel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '제작 스펙',
          icon: Icons.tune_rounded,
          accent: AppColors.neonLime,
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            children: [
              _row(context, Icons.science_rounded, '적용 공식',
                  reel.formulaName, AppColors.neonPurple),
              _row(context, Icons.record_voice_over_rounded, '내레이션',
                  reel.voiceName, AppColors.neonAmber),
              _row(context, Icons.music_note_rounded, 'BGM', reel.bgm,
                  AppColors.neonCyan),
              _row(context, Icons.content_cut_rounded, '컷 구성',
                  '${reel.scenes.length}컷', AppColors.neonMagenta),
              _row(context, Icons.language_rounded, '원본 출처',
                  '${reel.article.source} · ${reel.article.relativeTime}',
                  AppColors.textMid,
                  last: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value,
      Color color,
      {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 13),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 9),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textLow)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textHigh,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
