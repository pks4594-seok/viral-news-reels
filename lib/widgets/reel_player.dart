import 'package:flutter/material.dart';

import '../models/reel_project.dart';
import '../services/reel_player_controller.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'reel_stage.dart';

/// 인라인 릴스 플레이어
///
/// 9:16 무대 + 탭 재생/일시정지 + 진행 바 탐색 + 컨트롤 버튼.
/// 상세 화면에 삽입해 바로 재생을 확인할 수 있습니다.
class ReelPlayer extends StatefulWidget {
  final ReelProject reel;

  /// 자동 재생 여부
  final bool autoPlay;

  /// 컨트롤 바 표시
  final bool showControls;

  /// 최대 폭 제한
  final double maxWidth;

  /// 전장 버튼 탭 콜백
  final VoidCallback? onFullscreen;

  const ReelPlayer({
    super.key,
    required this.reel,
    this.autoPlay = false,
    this.showControls = true,
    this.maxWidth = 268,
    this.onFullscreen,
  });

  @override
  State<ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer>
    with SingleTickerProviderStateMixin {
  late final ReelPlayerController _ctrl;

  /// 탭 시 잠깐 나타나는 재생/일시정지 아이콘
  bool _flashIcon = false;

  @override
  void initState() {
    super.initState();
    _ctrl = ReelPlayerController(reel: widget.reel, vsync: this);
    if (widget.autoPlay && widget.reel.isReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.play());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapStage() {
    _ctrl.toggle();
    setState(() => _flashIcon = true);
    Future.delayed(const Duration(milliseconds: 520), () {
      if (mounted) setState(() => _flashIcon = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.reel.isReady;

    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.borderStrong),
                  boxShadow: AppShadows.glow(AppColors.neonMagenta,
                      blur: 34, opacity: 0.22),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: GestureDetector(
                    onTap: ready ? _onTapStage : null,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ReelStage(
                          reel: widget.reel,
                          controller: _ctrl,
                          scale: 1.0,
                        ),

                        // 재생/일시정지 플래시 아이콘
                        if (ready)
                          AnimatedBuilder(
                            animation: _ctrl,
                            builder: (ctx, _) {
                              final show = _flashIcon || !_ctrl.isPlaying;
                              return IgnorePointer(
                                child: AnimatedOpacity(
                                  opacity: show ? 1 : 0,
                                  duration:
                                      const Duration(milliseconds: 220),
                                  child: Center(
                                    child: Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.brandGradient,
                                        shape: BoxShape.circle,
                                        boxShadow: AppShadows.glow(
                                            AppColors.neonMagenta,
                                            blur: 22,
                                            opacity: 0.55),
                                      ),
                                      child: Icon(
                                        _ctrl.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                        // 렌더링 중 오버레이
                        if (!ready)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.62),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: CircularProgressIndicator(
                                      value: widget.reel.overallProgress,
                                      strokeWidth: 3.5,
                                      color: AppColors.neonMagenta,
                                      backgroundColor: AppColors.surfaceHigh,
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),
                                  const SizedBox(height: 13),
                                  Text(
                                    '${widget.reel.stage.label} 처리 중',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${(widget.reel.overallProgress * 100).round()}%',
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
          ),
        ),

        if (widget.showControls && ready) ...[
          const SizedBox(height: 12),
          ReelControls(
            controller: _ctrl,
            onFullscreen: widget.onFullscreen,
          ),
        ],
      ],
    );
  }
}

/// 외부 컨트롤러 수용형 플레이어
///
/// 부모 State가 컨트롤러를 소유할 때 사용합니다. 자막 타임라인처럼
/// 같은 화면의 다른 위젯과 재생 상태를 공유해야 하는 경우에 적합합니다.
/// 컨트롤러가 null이면 렌더링 진행 상태만 표시합니다.
class ReelPlayerView extends StatefulWidget {
  final ReelProject reel;
  final ReelPlayerController? controller;
  final VoidCallback? onFullscreen;
  final double maxWidth;

  const ReelPlayerView({
    super.key,
    required this.reel,
    this.controller,
    this.onFullscreen,
    this.maxWidth = 268,
  });

  @override
  State<ReelPlayerView> createState() => _ReelPlayerViewState();
}

class _ReelPlayerViewState extends State<ReelPlayerView> {
  bool _flashIcon = false;

  void _onTapStage() {
    final c = widget.controller;
    if (c == null) return;
    c.toggle();
    setState(() => _flashIcon = true);
    Future.delayed(const Duration(milliseconds: 520), () {
      if (mounted) setState(() => _flashIcon = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final ready = widget.reel.isReady && ctrl != null;

    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.borderStrong),
                  boxShadow: AppShadows.glow(AppColors.neonMagenta,
                      blur: 34, opacity: 0.22),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: GestureDetector(
                    onTap: ready ? _onTapStage : null,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (ready)
                          ReelStage(reel: widget.reel, controller: ctrl)
                        else
                          _RenderingPlaceholder(reel: widget.reel),

                        if (ready)
                          AnimatedBuilder(
                            animation: ctrl,
                            builder: (c2, _) {
                              final show = _flashIcon || !ctrl.isPlaying;
                              return IgnorePointer(
                                child: AnimatedOpacity(
                                  opacity: show ? 1 : 0,
                                  duration:
                                      const Duration(milliseconds: 220),
                                  child: Center(
                                    child: Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.brandGradient,
                                        shape: BoxShape.circle,
                                        boxShadow: AppShadows.glow(
                                            AppColors.neonMagenta,
                                            blur: 22,
                                            opacity: 0.55),
                                      ),
                                      child: Icon(
                                        ctrl.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (ready) ...[
          const SizedBox(height: 12),
          ReelControls(
            controller: ctrl,
            onFullscreen: widget.onFullscreen,
          ),
        ],
      ],
    );
  }
}

/// 렌더링 진행 표시 — 아직 재생할 수 없는 상태
class _RenderingPlaceholder extends StatelessWidget {
  final ReelProject reel;
  const _RenderingPlaceholder({required this.reel});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        NetImage(url: reel.article.imageUrl),
        Container(
          color: Colors.black.withValues(alpha: 0.66),
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
      ],
    );
  }
}

/// 플레이어 컨트롤 바 — 진행 바 + 버튼 행
class ReelControls extends StatelessWidget {
  final ReelPlayerController controller;
  final VoidCallback? onFullscreen;
  final bool compact;

  const ReelControls({
    super.key,
    required this.controller,
    this.onFullscreen,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          children: [
            // ── 진행 바 (드래그 탐색) ────────────────
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: AppColors.neonMagenta,
                inactiveTrackColor: AppColors.surfaceHigh,
                thumbColor: Colors.white,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16),
                overlayColor:
                    AppColors.neonMagenta.withValues(alpha: 0.18),
              ),
              child: Slider(
                value: controller.progress,
                onChanged: controller.seekRatio,
              ),
            ),

            // ── 시간 표시 ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  Text(
                    controller.timeLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMid,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.neonCyan.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '씬 ${controller.sceneIndex + 1}/'
                      '${controller.reel.scenes.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.neonCyan,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── 버튼 행 ─────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _iconBtn(
                  Icons.replay_rounded,
                  '처음부터',
                  controller.stop,
                ),
                const SizedBox(width: 6),
                _iconBtn(
                  Icons.skip_previous_rounded,
                  '이전 씬',
                  controller.prevSceneJump,
                ),
                const SizedBox(width: 10),

                // 메인 재생 버튼
                GestureDetector(
                  onTap: controller.toggle,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.glow(AppColors.neonMagenta,
                          blur: 20, opacity: 0.45),
                    ),
                    child: Icon(
                      controller.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                _iconBtn(
                  Icons.skip_next_rounded,
                  '다음 씬',
                  controller.nextSceneJump,
                ),
                const SizedBox(width: 6),
                _iconBtn(
                  controller.isLooping
                      ? Icons.repeat_on_rounded
                      : Icons.repeat_rounded,
                  controller.isLooping ? '반복 끄기' : '반복 켜기',
                  () => controller.setLoop(!controller.isLooping),
                  active: controller.isLooping,
                ),
                if (onFullscreen != null) ...[
                  const SizedBox(width: 6),
                  _iconBtn(
                    Icons.fullscreen_rounded,
                    '전체 화면',
                    onFullscreen!,
                    color: AppColors.neonCyan,
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _iconBtn(
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool active = false,
    Color color = AppColors.textMid,
  }) {
    final c = active ? AppColors.neonLime : color;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? AppColors.neonLime.withValues(alpha: 0.13)
                  : AppColors.surface,
              border: Border.all(
                color: active
                    ? AppColors.neonLime.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Icon(icon, size: 17, color: c),
          ),
        ),
      ),
    );
  }
}
