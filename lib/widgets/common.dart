import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 글래스모피즘 카드 — 반투명 표면 + 미세 경계
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? glowColor;
  final bool blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.onTap,
    this.glowColor,
    this.blur = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppColors.glassGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: glowColor?.withValues(alpha: 0.35) ?? AppColors.border,
        ),
        boxShadow: glowColor != null
            ? AppShadows.glow(glowColor!, blur: 20, opacity: 0.18)
            : null,
      ),
      child: child,
    );

    if (blur) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: content,
        ),
      );
    }

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: (glowColor ?? AppColors.neonMagenta).withValues(alpha: 0.1),
        highlightColor:
            (glowColor ?? AppColors.neonMagenta).withValues(alpha: 0.05),
        child: content,
      ),
    );
  }
}

/// 네온 그라디언트 버튼
class NeonButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final bool expanded;
  final bool compact;
  final bool loading;

  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.gradient = AppColors.brandGradient,
    this.expanded = false,
    this.compact = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final h = compact ? 38.0 : 50.0;

    final btn = Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: Container(
        height: h,
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 22),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(h / 2),
          boxShadow: disabled
              ? null
              : AppShadows.glow(AppColors.neonMagenta,
                  blur: 22, opacity: 0.38),
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else if (icon != null)
              Icon(icon, size: compact ? 16 : 19, color: Colors.white),
            if (loading || icon != null) SizedBox(width: compact ? 7 : 9),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 12.5 : 14.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(h / 2),
        child: btn,
      ),
    );
  }
}

/// 아웃라인 버튼 (보조 액션)
class GhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final bool expanded;

  const GhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = AppColors.neonCyan,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: color.withValues(alpha: 0.5)),
            color: color.withValues(alpha: 0.07),
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 네온 배지 (카테고리, 상태 표시)
class NeonBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  const NeonBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: filled ? 1 : 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: filled ? Colors.white : color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: filled ? Colors.white : color,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 그라디언트 텍스트
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;
  final TextAlign? align;

  const GradientText(
    this.text, {
    super.key,
    required this.style,
    this.gradient = AppColors.brandGradient,
    this.align,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (b) => gradient.createShader(Offset.zero & b.size),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style, textAlign: align),
    );
  }
}

/// 스파크라인 차트 — 관심도 추이 미니 그래프
class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;
  final bool fill;
  final double strokeWidth;

  const Sparkline({
    super.key,
    required this.data,
    required this.color,
    this.height = 28,
    this.fill = true,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(
          data: data,
          color: color,
          fill: fill,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool fill;
  final double strokeWidth;

  _SparkPainter({
    required this.data,
    required this.color,
    required this.fill,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final maxV = data.reduce(math.max);
    final minV = data.reduce(math.min);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : (maxV - minV);

    final pts = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = size.width * (i / (data.length - 1));
      final y = size.height * (1 - (data[i] - minV) / range);
      pts.add(Offset(x, y.clamp(strokeWidth, size.height - strokeWidth)));
    }

    // 부드러운 곡선
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);

    if (fill) {
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.32),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // 마지막 점 강조
    canvas.drawCircle(
      pts.last,
      strokeWidth + 1.2,
      Paint()..color = color,
    );
    canvas.drawCircle(
      pts.last,
      strokeWidth + 3.5,
      Paint()..color = color.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.data != data || old.color != color;
}

/// 원형 진행 링 (트렌드 점수 / 유지율 표시)
class ScoreRing extends StatelessWidget {
  final int score;
  final double size;
  final String? label;
  final Color? color;

  const ScoreRing({
    super.key,
    required this.score,
    this.size = 54,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.heatColor(score);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: size * 0.085,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(c),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.w900,
                  color: c,
                  height: 1,
                ),
              ),
              if (label != null)
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: size * 0.15,
                    color: AppColors.textLow,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 네트워크 이미지 (로딩/에러 처리 포함)
class NetImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  const NetImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 0,
  });

  @override
  Widget build(BuildContext context) {
    final img = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (ctx, child, prog) {
        if (prog == null) return child;
        return Container(
          width: width,
          height: height,
          color: AppColors.surfaceHigh,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.neonCyan,
              ),
            ),
          ),
        );
      },
      errorBuilder: (ctx, err, st) => Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(gradient: AppColors.purpleGradient),
        child: const Center(
          child: Icon(Icons.newspaper_rounded,
              color: Colors.white38, size: 28),
        ),
      ),
    );

    if (radius <= 0) return img;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);
  }
}

/// 섹션 헤더
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;
  final Color accent;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
    this.accent = AppColors.neonMagenta,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 22,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
            boxShadow: AppShadows.glow(accent, blur: 10, opacity: 0.7),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: accent),
                    const SizedBox(width: 6),
                  ],
                  Text(title,
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// 통계 타일
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? delta;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(13),
      glowColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const Spacer(),
              if (delta != null)
                Text(
                  delta!,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: delta!.startsWith('-')
                        ? AppColors.neonRed
                        : AppColors.neonLime,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textHigh,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// 빈 상태 표시
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, size: 32, color: AppColors.textLow),
            ),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 오디오 파형 (릴스 프리뷰 하단 장식)
class WaveformBar extends StatefulWidget {
  final Color color;
  final double height;
  final int bars;
  final bool animate;

  const WaveformBar({
    super.key,
    this.color = AppColors.neonCyan,
    this.height = 26,
    this.bars = 34,
    this.animate = true,
  });

  @override
  State<WaveformBar> createState() => _WaveformBarState();
}

class _WaveformBarState extends State<WaveformBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<double> _seeds;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(11);
    _seeds = List.generate(widget.bars, (_) => rng.nextDouble());
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.animate) _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, _) {
          return SizedBox(
            height: widget.height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(widget.bars, (i) {
                final phase = (_ctrl.value * 2 * math.pi) + i * 0.42;
                final amp = widget.animate
                    ? (0.35 + 0.65 * ((math.sin(phase) + 1) / 2)) * _seeds[i]
                    : _seeds[i];
                final h = (widget.height * (0.18 + amp * 0.82))
                    .clamp(3.0, widget.height);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.8),
                    child: Container(
                      height: h,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.55 + amp * 0.45),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
