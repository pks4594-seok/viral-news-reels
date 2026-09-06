import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/news_article.dart';
import '../models/upload_task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 내정보 — 계정 연동 · 자동화 설정 · 뉴스 소스 관리
class ProfileScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const ProfileScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        _ProfileCard(state: state),
        const SizedBox(height: 20),

        // ── 플랫폼 계정 ─────────────────────────────
        const SectionHeader(
          title: '플랫폼 계정 연동',
          subtitle: '연동된 계정으로 자동 발행됩니다',
          icon: Icons.link_rounded,
          accent: AppColors.neonPurple,
        ),
        const SizedBox(height: 12),
        ...state.accounts.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _AccountRow(account: a),
            )),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: AppColors.neonCyan),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '실제 발행에는 각 플랫폼의 OAuth 인증이 필요합니다. '
                  'API 키를 등록하면 이 화면에서 실계정 연동으로 전환됩니다.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // ── 자동화 ─────────────────────────────────
        const SectionHeader(
          title: '자동화 파이프라인',
          subtitle: '수집 → 생성 → 발행 자동 실행 설정',
          icon: Icons.auto_mode_rounded,
          accent: AppColors.neonMagenta,
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            children: [
              _AutoToggle(
                icon: Icons.download_rounded,
                title: '뉴스 자동 수집',
                subtitle: '30분마다 등록된 소스에서 최신 뉴스 수집',
                value: state.autoCollect,
                color: AppColors.neonCyan,
                onChanged: state.setAutoCollect,
              ),
              const Divider(height: 20),
              _AutoToggle(
                icon: Icons.auto_awesome_rounded,
                title: '릴스 자동 생성',
                subtitle:
                    '트렌드 점수 ${state.minTrendScore}점 이상 뉴스를 자동으로 릴스화',
                value: state.autoGenerate,
                color: AppColors.neonMagenta,
                onChanged: state.setAutoGenerate,
              ),
              if (state.autoGenerate) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('최소 트렌드 점수',
                        style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    Text(
                      '${state.minTrendScore}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.heatColor(state.minTrendScore),
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.neonMagenta,
                    inactiveTrackColor: AppColors.surfaceHigh,
                    thumbColor: AppColors.neonMagenta,
                    overlayColor:
                        AppColors.neonMagenta.withValues(alpha: 0.15),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: state.minTrendScore.toDouble(),
                    min: 50,
                    max: 95,
                    divisions: 9,
                    onChanged: (v) => state.setMinTrendScore(v.round()),
                  ),
                ),
              ],
              const Divider(height: 20),
              _AutoToggle(
                icon: Icons.rocket_launch_rounded,
                title: '자동 발행',
                subtitle: '생성 완료 즉시 연동된 플랫폼에 업로드',
                value: state.autoUpload,
                color: AppColors.neonPurple,
                onChanged: state.setAutoUpload,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // ── 뉴스 소스 ───────────────────────────────
        SectionHeader(
          title: '뉴스 소스',
          subtitle:
              '${state.sources.where((s) => s.enabled).length}개 활성화',
          icon: Icons.newspaper_rounded,
          accent: AppColors.neonLime,
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            children: state.sources.asMap().entries.map((e) {
              final s = e.value;
              final last = e.key == state.sources.length - 1;
              return Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: s.enabled
                              ? AppColors.neonLime.withValues(alpha: 0.14)
                              : AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(
                          child: Text(
                            s.name.substring(0, 1),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: s.enabled
                                  ? AppColors.neonLime
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
                              s.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: s.enabled
                                    ? AppColors.textHigh
                                    : AppColors.textLow,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'RSS 피드',
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: s.enabled,
                        onChanged: (_) => state.toggleSource(s.name),
                      ),
                    ],
                  ),
                  if (!last) const Divider(height: 16),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 22),

        // ── 성과 요약 ───────────────────────────────
        const SectionHeader(
          title: '성과 요약',
          icon: Icons.bar_chart_rounded,
          accent: AppColors.neonAmber,
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            children: [
              _stat(context, '누적 발행', '${state.totalPublished}건',
                  AppColors.neonLime),
              _stat(context, '누적 조회수',
                  NewsArticle.formatCount(state.totalViews),
                  AppColors.neonCyan),
              _stat(context, '제작한 릴스', '${state.reels.length}개',
                  AppColors.neonMagenta),
              _stat(
                  context,
                  '학습 클립',
                  '${state.learningStats['totalClips']}개',
                  AppColors.neonPurple),
              _stat(context, '오늘 제작', '${state.todayReelCount}개',
                  AppColors.neonAmber,
                  last: true),
            ],
          ),
        ),
        const SizedBox(height: 22),

        Center(
          child: Column(
            children: [
              Text('Trend Reel Studio',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 3),
              Text('v1.0.0 · 헤드라인이 릴스가 되는 곳',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color,
      {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 13),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 9),
          Text(label,
              style:
                  const TextStyle(fontSize: 12.5, color: AppColors.textMid)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AppState state;
  const _ProfileCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: AppColors.neonMagenta,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(17),
              boxShadow: AppShadows.glow(AppColors.neonMagenta,
                  blur: 20, opacity: 0.45),
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '기석님의 스튜디오',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textHigh,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    NeonBadge(
                      label:
                          '${state.accounts.where((a) => a.connected).length}개 계정 연동',
                      color: AppColors.neonLime,
                      icon: Icons.check_rounded,
                    ),
                    const SizedBox(width: 5),
                    NeonBadge(
                      label: state.autoCollect ? '자동 수집 ON' : '수동 모드',
                      color: state.autoCollect
                          ? AppColors.neonCyan
                          : AppColors.textLow,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final PlatformAccount account;
  const _AccountRow({required this.account});

  static (IconData, Color) _meta(UploadPlatform p) {
    switch (p) {
      case UploadPlatform.youtube:
        return (Icons.play_circle_fill_rounded, AppColors.neonRed);
      case UploadPlatform.tiktok:
        return (Icons.music_note_rounded, AppColors.neonCyan);
      case UploadPlatform.blog:
        return (Icons.article_rounded, AppColors.neonLime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final (icon, color) = _meta(account.platform);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      glowColor: account.connected ? color : null,
      child: Row(
        children: [
          Container
            (width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: account.connected ? 0.16 : 0.07),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon,
                size: 19,
                color: account.connected
                    ? color
                    : color.withValues(alpha: 0.4)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.platform.label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHigh,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  account.connected
                      ? '${account.displayName} · 발행 ${account.publishedCount}건 · '
                          '${NewsArticle.formatCount(account.totalViews)} 조회'
                      : '연동되지 않음',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          account.connected
              ? GhostButton(
                  label: '해제',
                  color: AppColors.textMid,
                  onPressed: () => state.toggleAccount(account.platform),
                )
              : NeonButton(
                  label: '연동',
                  icon: Icons.add_link_rounded,
                  compact: true,
                  gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.62)]),
                  onPressed: () {
                    state.toggleAccount(account.platform);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${account.platform.label} 계정이 연동되었습니다'),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

class _AutoToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _AutoToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: value ? 0.15 : 0.06),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon,
              size: 16,
              color: value ? color : color.withValues(alpha: 0.4)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: value ? AppColors.textHigh : AppColors.textMid,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
