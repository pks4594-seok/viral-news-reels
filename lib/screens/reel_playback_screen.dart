import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/reel_project.dart';
import '../services/reel_player_controller.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/platform_picker.dart';
import '../widgets/reel_stage.dart';

/// 전장 몰입 재생 화면
///
/// 틱톡·쇼츠처럼 화면 전체에 릴스를 띄우고, 세로 스와이프로
/// 다음/이전 릴스로 이동합니다. 탭하면 재생/일시정지,
/// 좌우 절반 탭으로 씬 이동, 상하 드래그로 릴스 전환.
class ReelPlaybackScreen extends StatefulWidget {
  final List<ReelProject> reels;
  final int initialIndex;

  const ReelPlaybackScreen({
    super.key,
    required this.reels,
    this.initialIndex = 0,
  });

  @override
  State<ReelPlaybackScreen> createState() => _ReelPlaybackScreenState();
}

class _ReelPlaybackScreenState extends State<ReelPlaybackScreen> {
  late final PageController _pages;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.reels.length - 1);
    _pages = PageController(initialPage: _index);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pages.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: EmptyState(
          icon: Icons.movie_creation_outlined,
          title: '재생할 릴스가 없습니다',
          message: '뉴스 탭에서 릴스를 먼저 만들어 주세요.',
          action: GhostButton(
            label: '닫기',
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            scrollDirection: Axis.vertical,
            itemCount: widget.reels.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (ctx, i) => _FullReelPage(
              reel: widget.reels[i],
              active: i == _index,
            ),
          ),

          // 상단 닫기 + 순서 표시
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    _circleBtn(
                      Icons.close_rounded,
                      () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_index + 1} / ${widget.reels.length}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 스와이프 안내 (첫 화면에만)
          if (widget.reels.length > 1 && _index == 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 96,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swipe_vertical_rounded,
                            size: 13, color: Colors.white70),
                        SizedBox(width: 5),
                        Text(
                          '위로 넘겨 다음 릴스',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.45),
          ),
          child: Icon(icon, size: 19, color: Colors.white),
        ),
      ),
    );
  }
}

/// 전장 한 페이지 — 릴스 1개
class _FullReelPage extends StatefulWidget {
  final ReelProject reel;
  final bool active;

  const _FullReelPage({required this.reel, required this.active});

  @override
  State<_FullReelPage> createState() => _FullReelPageState();
}

class _FullReelPageState extends State<_FullReelPage>
    with SingleTickerProviderStateMixin {
  late final ReelPlayerController _ctrl;
  bool _showUi = true;

  @override
  void initState() {
    super.initState();
    _ctrl = ReelPlayerController(reel: widget.reel, vsync: this);
    if (widget.active && widget.reel.isReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.play());
    }
  }

  @override
  void didUpdateWidget(_FullReelPage old) {
    super.didUpdateWidget(old);
    // 페이지에서 벗어나면 정지, 들어오면 처음부터 재생
    if (widget.active && !old.active) {
      _ctrl.stop();
      if (widget.reel.isReady) _ctrl.play();
    } else if (!widget.active && old.active) {
      _ctrl.pause();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails d, BoxConstraints box) {
    final x = d.localPosition.dx;
    final w = box.maxWidth;

    // 좌 25% → 이전 씬, 우 25% → 다음 씬, 중앙 → 재생 토글
    if (x < w * 0.25) {
      _ctrl.prevSceneJump();
    } else if (x > w * 0.75) {
      _ctrl.nextSceneJump();
    } else {
      _ctrl.toggle();
      setState(() => _showUi = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reel = widget.reel;

    return LayoutBuilder(
      builder: (context, box) {
        return GestureDetector(
          onTapDown: reel.isReady ? (d) => _onTapDown(d, box) : null,
          onLongPress: () => setState(() => _showUi = !_showUi),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 무대
              ReelStage(
                reel: reel,
                controller: _ctrl,
                scale: 1.35,
                showAudioBar: false,
              ),

              // 일시정지 아이콘
              AnimatedBuilder(
                animation: _ctrl,
                builder: (ctx, _) => IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _ctrl.isPlaying ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Center(
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.42),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white24, width: 1.5),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 38),
                      ),
                    ),
                  ),
                ),
              ),

              // 하단 정보 + 액션
              if (_showUi)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _BottomPanel(reel: reel, controller: _ctrl),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 하단 정보 패널 — 제목·출처·해시태그 + 우측 액션 열
class _BottomPanel extends StatelessWidget {
  final ReelProject reel;
  final ReelPlayerController controller;

  const _BottomPanel({required this.reel, required this.controller});

  @override
  Widget build(BuildContext context) {
    final heat = AppColors.heatColor(reel.viralScore);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 40, 12, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 좌측 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      NeonBadge(
                        label: reel.article.category,
                        color:
                            AppColors.categoryColor(reel.article.category),
                        filled: true,
                      ),
                      const SizedBox(width: 5),
                      NeonBadge(
                        label: reel.formulaName,
                        color: AppColors.neonPurple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    reel.hookTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.3,
                      letterSpacing: -0.4,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.language_rounded,
                          size: 11, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(
                        '${reel.article.source} · ${reel.article.relativeTime}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.white54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    reel.hashtags.take(5).map((h) => '#$h').join(' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neonCyan,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 진행 바
                  AnimatedBuilder(
                    animation: controller,
                    builder: (ctx, _) => Row(
                      children: [
                        Text(
                          controller.timeLabel,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white60,
                            fontFeatures: [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: controller.progress,
                              minHeight: 3,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation(
                                  AppColors.neonMagenta),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // 우측 액션 열
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 26),
              child: Column(
                children: [
                  _action(
                    Icons.whatshot_rounded,
                    '${reel.viralScore}',
                    heat,
                  ),
                  const SizedBox(height: 15),
                  _action(
                    Icons.visibility_rounded,
                    reel.viewsLabel,
                    AppColors.neonCyan,
                  ),
                  const SizedBox(height: 15),
                  _action(
                    Icons.timer_outlined,
                    '${reel.durationSec}s',
                    Colors.white70,
                  ),
                  const SizedBox(height: 15),
                  AnimatedBuilder(
                    animation: controller,
                    builder: (ctx, _) => GestureDetector(
                      onTap: () =>
                          controller.setLoop(!controller.isLooping),
                      child: _action(
                        controller.isLooping
                            ? Icons.repeat_on_rounded
                            : Icons.repeat_rounded,
                        '반복',
                        controller.isLooping
                            ? AppColors.neonLime
                            : Colors.white38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap: () => _queueFromPlayer(context, reel),
                    child: _action(
                      Icons.cloud_upload_rounded,
                      '업로드',
                      AppColors.neonPurple,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 플레이어에서 바로 업로드 큐에 추가 — 플랫폼/시각 선택 시트를 띄웁니다.
  void _queueFromPlayer(BuildContext context, ReelProject reel) {
    final state = context.read<AppState>();
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
}
