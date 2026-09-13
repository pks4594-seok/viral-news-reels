import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reel_project.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/platform_picker.dart';
import 'reel_detail_screen.dart';
import 'reel_playback_screen.dart';

/// 스튜디오 — 생성된 릴스를 세로형 카드로 관리
class StudioScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const StudioScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reels = state.reels;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _Header(state: state)),
        if (reels.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.movie_creation_outlined,
              title: '아직 만든 릴스가 없습니다',
              message: '뉴스 탭에서 헤드라인을 골라\n"AI 릴스 만들기"를 눌러 보세요.',
              action: NeonButton(
                label: '뉴스 보러 가기',
                icon: Icons.newspaper_rounded,
                onPressed: () => onNavigate(0),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 11,
                mainAxisSpacing: 11,
                childAspectRatio: 0.545,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ReelCard(reel: reels[i]),
                childCount: reels.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final AppState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    final ready = state.readyReels.length;
    final totalPredicted =
        state.reels.fold<int>(0, (s, r) => s + r.predictedViews);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.neonMagenta.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.movie_creation_rounded,
                    color: AppColors.neonMagenta, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: GradientText(
                  '릴스 스튜디오',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
              ),
              if (state.readyReels.isNotEmpty) ...[
                NeonButton(
                  label: '연속 재생',
                  icon: Icons.play_arrow_rounded,
                  compact: true,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ReelPlaybackScreen(reels: state.readyReels),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                GhostButton(
                  label: '큐 추가',
                  icon: Icons.playlist_add_rounded,
                  color: AppColors.neonPurple,
                  onPressed: () => _queueAll(context, state),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '전체 릴스',
                  value: '${state.reels.length}',
                  icon: Icons.video_collection_rounded,
                  color: AppColors.neonMagenta,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: StatTile(
                  label: '발행 대기',
                  value: '$ready',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.neonLime,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: StatTile(
                  label: '예측 합계',
                  value: _fmt(totalPredicted),
                  icon: Icons.trending_up_rounded,
                  color: AppColors.neonCyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}만';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}천';
    return '$n';
  }

  void _queueAll(BuildContext context, AppState state) {
    final messenger = ScaffoldMessenger.of(context);
    PlatformPickerSheet.show(
      context,
      title: '발행 대기 릴스 전체 큐 추가',
      subtitle: '${state.readyReels.length}개 릴스를 선택한 플랫폼에 큐잉합니다',
      onConfirm: (platforms, scheduledAt) {
        final count = state.readyReels.length * platforms.length;
        for (final r in state.readyReels) {
          state.enqueueUploads(r, platforms, scheduledAt: scheduledAt);
        }
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(content: Text('$count건을 업로드 큐에 추가했습니다')),
        );
      },
    );
  }
}

/// 세로형 릴스 카드 (9:16 프리뷰)
class _ReelCard extends StatelessWidget {
  final ReelProject reel;
  const _ReelCard({required this.reel});

  /// 전체 화면 재생 — 준비된 릴스 목록에서 이 릴스부터 시작
  void _playFullscreen(BuildContext context, ReelProject r) {
    final list = context.read<AppState>().readyReels;
    var idx = list.indexWhere((x) => x.id == r.id);
    if (idx < 0) idx = 0;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReelPlaybackScreen(
          reels: list.isNotEmpty ? list : [r],
          initialIndex: idx,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.heatColor(reel.viralScore);

    return GlassCard(
      padding: EdgeInsets.zero,
      glowColor: reel.viralScore >= 85 ? color : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReelDetailScreen(reelId: reel.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 9:16 프리뷰 ────────────────────────────
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: NetImage(url: reel.article.imageUrl),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.42),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.88),
                        ],
                        stops: const [0, 0.38, 1],
                      ),
                    ),
                  ),
                ),

                // 상단: 상태 + 길이
                Positioned(
                  left: 8,
                  right: 8,
                  top: 8,
                  child: Row(
                    children: [
                      if (reel.isReady)
                        const NeonBadge(
                          label: '완료',
                          color: AppColors.neonLime,
                          icon: Icons.check_rounded,
                          filled: true,
                        )
                      else
                        NeonBadge(
                          label: reel.stage.label,
                          color: AppColors.neonAmber,
                          filled: true,
                        ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5.5, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${reel.durationSec}s',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 중앙 재생 버튼 — 전장 재생으로 직행
                if (reel.isReady)
                  Center(
                    child: GestureDetector(
                      onTap: () => _playFullscreen(context, reel),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.glow(AppColors.neonMagenta,
                              blur: 18, opacity: 0.55),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 26),
                      ),
                    ),
                  ),

                // 하단: 후킹 자막 + 파형
                Positioned(
                  left: 9,
                  right: 9,
                  bottom: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reel.hookTitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.32,
                          letterSpacing: -0.25,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      WaveformBar(
                        color: AppColors.neonCyan,
                        height: 15,
                        bars: 26,
                        animate: reel.isReady,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 하단 메타 ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!reel.isReady) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: reel.overallProgress,
                      minHeight: 4,
                      backgroundColor: AppColors.surfaceHigh,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.neonAmber),
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
                Row(
                  children: [
                    Icon(Icons.whatshot_rounded, size: 12, color: color),
                    const SizedBox(width: 3),
                    Text(
                      '${reel.viralScore}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.visibility_rounded,
                        size: 11, color: AppColors.textLow),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        reel.viewsLabel,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMid,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.neonPurple.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    reel.formulaName,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.neonPurple,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
