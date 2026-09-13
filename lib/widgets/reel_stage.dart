import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/reel_project.dart';
import '../services/reel_player_controller.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// 릴스 무대 — 9:16 화면에 씬 모션과 자막을 합성해 재생합니다.
///
/// 구성 레이어 (아래에서 위로):
///   1. 현재 씬 이미지 + 켄번스 모션
///   2. 다음 씬 크로스페이드
///   3. 시네마틱 그라디언트 마스크
///   4. 씬 진행 바 (상단)
///   5. 자막 (중앙 강조형 / 하단 자막형)
///   6. 하단 BGM 라벨 + 오디오 파형
class ReelStage extends StatelessWidget {
  final ReelProject reel;
  final ReelPlayerController controller;

  /// 자막 크기 배율 — 전장 재생 시 1.0, 카드 프리뷰 시 축소
  final double scale;

  /// 상단 씬 진행 바 표시
  final bool showProgressBars;

  /// 하단 BGM · 파형 표시
  final bool showAudioBar;

  const ReelStage({
    super.key,
    required this.reel,
    required this.controller,
    this.scale = 1.0,
    this.showProgressBars = true,
    this.showAudioBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final scene = controller.currentScene;
        final next = controller.nextScene;
        final fade = controller.crossfade;
        final caption = controller.currentCaption;

        return RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. 현재 씬 + 켄번스 모션 ──────────────
              if (scene != null)
                _KenBurns(
                  imageUrl: scene.imageUrl,
                  motion: scene.motion,
                  progress: controller.sceneProgress,
                )
              else
                Container(
                  decoration:
                      const BoxDecoration(gradient: AppColors.purpleGradient),
                ),

              // ── 2. 다음 씬 크로스페이드 ────────────────
              if (next != null && fade > 0)
                Opacity(
                  opacity: fade,
                  child: _KenBurns(
                    imageUrl: next.imageUrl,
                    motion: next.motion,
                    progress: 0,
                  ),
                ),

              // ── 3. 시네마틱 마스크 ────────────────────
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.52),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.88),
                        ],
                        stops: const [0, 0.26, 0.5, 1],
                      ),
                    ),
                  ),
                ),
              ),

              // ── 4. 씬 진행 바 ────────────────────────
              if (showProgressBars)
                Positioned(
                  left: 10 * scale,
                  right: 10 * scale,
                  top: 10 * scale,
                  child: _SceneBars(
                    count: reel.scenes.length,
                    index: controller.sceneIndex,
                    sceneProgress: controller.sceneProgress,
                  ),
                ),

              // ── 5. 자막 ──────────────────────────────
              if (caption != null)
                _CaptionLayer(
                  caption: caption,
                  entry: controller.captionEntry,
                  style: reel.formulaName,
                  scale: scale,
                ),

              // ── 6. 오디오 바 ─────────────────────────
              if (showAudioBar)
                Positioned(
                  left: 12 * scale,
                  right: 12 * scale,
                  bottom: 11 * scale,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.music_note_rounded,
                              size: 11 * scale, color: AppColors.neonCyan),
                          SizedBox(width: 4 * scale),
                          Expanded(
                            child: Text(
                              reel.bgm,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5 * scale,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 5 * scale),
                      WaveformBar(
                        color: AppColors.neonCyan,
                        height: 17 * scale,
                        bars: 32,
                        animate: controller.isPlaying,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 켄번스 모션 — 정지 이미지에 카메라 움직임을 부여합니다.
///
/// [motion] 값에 따라 스케일·평행이동을 보간합니다.
/// 릴스 생성 시 씬마다 배정된 모션 이름을 그대로 해석합니다.
class _KenBurns extends StatelessWidget {
  final String imageUrl;
  final String motion;
  final double progress;

  const _KenBurns({
    required this.imageUrl,
    required this.motion,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    // 부드러운 가감속 (ease-in-out)
    final t = Curves.easeInOutSine.transform(progress.clamp(0.0, 1.0));

    double sx = 1.0, sy = 1.0, dx = 0, dy = 0;

    switch (motion) {
      case '줌 인':
        final s = 1.0 + 0.18 * t;
        sx = sy = s;
        break;
      case '줌 아웃':
        final s = 1.18 - 0.18 * t;
        sx = sy = s;
        break;
      case '좌→우 팬':
        sx = sy = 1.16;
        dx = -0.07 + 0.14 * t;
        break;
      case '상→하 슬라이드':
        sx = sy = 1.16;
        dy = -0.06 + 0.12 * t;
        break;
      case '켄번스':
        // 줌과 대각 이동을 동시에
        sx = sy = 1.0 + 0.22 * t;
        dx = -0.04 + 0.08 * t;
        dy = 0.03 - 0.06 * t;
        break;
      case '고정 + 자막':
      default:
        // 미세한 호흡감만 부여 (완전 정지는 숏폼에서 지루함)
        sx = sy = 1.04 + 0.03 * math.sin(t * math.pi);
        break;
    }

    return ClipRect(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translateByDouble(dx * 100, dy * 100, 0, 1)
          ..scaleByDouble(sx, sy, 1, 1),
        child: NetImage(url: imageUrl, fit: BoxFit.cover),
      ),
    );
  }
}

/// 씬 진행 바 — 인스타 스토리 방식
class _SceneBars extends StatelessWidget {
  final int count;
  final int index;
  final double sceneProgress;

  const _SceneBars({
    required this.count,
    required this.index,
    required this.sceneProgress,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Row(
      children: List.generate(count, (i) {
        final fill = i < index
            ? 1.0
            : i == index
                ? sceneProgress
                : 0.0;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            height: 2.5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fill,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 자막 레이어
///
/// 공식별로 자막 스타일이 다릅니다:
///   · 감탄 리액션형 → 중앙 대형, 네온 글로우 강조
///   · 속보 임팩트형 → 하단 박스 + 키워드 하이라이트
///   · 숫자 충격형   → 중앙 초대형 볼드
///   · 결론 선행형   → 상단 요약 배치
///   · 의문 유발형   → 하단 타임라인 자막
class _CaptionLayer extends StatelessWidget {
  final CaptionLine caption;
  final double entry;
  final String style;
  final double scale;

  const _CaptionLayer({
    required this.caption,
    required this.entry,
    required this.style,
    required this.scale,
  });

  bool get _isTopStyle => style == '결론 선행형';

  @override
  Widget build(BuildContext context) {
    // 등장 애니메이션 — 페이드 + 아래에서 위로 슬라이드
    final e = Curves.easeOutCubic.transform(entry.clamp(0.0, 1.0));
    final offsetY = (1 - e) * 16 * scale;

    if (caption.emphasis) {
      // 강조 자막 — 화면 중앙
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
          child: Opacity(
            opacity: e,
            child: Transform.translate(
              offset: Offset(0, offsetY),
              child: Transform.scale(
                scale: 0.94 + 0.06 * e,
                child: Text(
                  caption.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: (style == '숫자 충격형' ? 23 : 20) * scale,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.26,
                    letterSpacing: -0.6 * scale,
                    shadows: [
                      Shadow(
                          color: Colors.black.withValues(alpha: 0.9),
                          blurRadius: 12 * scale),
                      Shadow(
                          color: AppColors.neonMagenta
                              .withValues(alpha: 0.85 * e),
                          blurRadius: 24 * scale),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 일반 자막 — 상단 또는 하단 박스
    final child = Opacity(
      opacity: e,
      child: Transform.translate(
        offset: Offset(0, _isTopStyle ? -offsetY : offsetY),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: 10 * scale, vertical: 7 * scale),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.64),
            borderRadius: BorderRadius.circular(9 * scale),
            border: Border.all(
              color: AppColors.neonCyan.withValues(alpha: 0.28 * e),
            ),
          ),
          child: Text(
            caption.text,
            style: TextStyle(
              fontSize: 12.5 * scale,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.36,
              shadows: [
                Shadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 6 * scale),
              ],
            ),
          ),
        ),
      ),
    );

    if (_isTopStyle) {
      return Positioned(
        left: 14 * scale,
        right: 14 * scale,
        top: 46 * scale,
        child: child,
      );
    }
    return Positioned(
      left: 14 * scale,
      right: 14 * scale,
      bottom: 58 * scale,
      child: child,
    );
  }
}
