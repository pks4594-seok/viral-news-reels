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
        SectionHeader(
          title: '플랫폼 계정 연동',
          subtitle: state.accounts.any((a) => a.canPublish)
              ? '인증된 계정으로 발행됩니다'
              : '아직 연동된 계정이 없습니다 — 직접 인증이 필요합니다',
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
          glowColor: AppColors.neonAmber,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 15, color: AppColors.neonAmber),
                  const SizedBox(width: 7),
                  Text(
                    '연동은 직접 하셔야 합니다',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.neonAmber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '이 앱은 기석님의 계정 정보를 알지 못하며, 임의로 연동하지 않습니다.\n'
                '발행하려면 ① 개발자 콘솔에서 API 키를 발급받아 등록하고, '
                '② 브라우저 로그인으로 직접 권한을 승인해야 합니다.\n'
                '아래 표시되는 모든 수치는 이 앱을 통해 실제 발행한 결과만 집계됩니다.',
                style: Theme.of(context).textTheme.bodySmall,
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
              _stat(context, '실제 발행', '${state.totalPublished}건',
                  AppColors.neonLime),
              _stat(
                  context,
                  '누적 조회수',
                  state.totalViews > 0
                      ? NewsArticle.formatCount(state.totalViews)
                      : '집계 없음',
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
    final connectedCount =
        state.accounts.where((a) => a.canPublish).length;

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
                    if (connectedCount > 0)
                      NeonBadge(
                        label: '$connectedCount개 계정 인증됨',
                        color: AppColors.neonLime,
                        icon: Icons.verified_rounded,
                      )
                    else
                      const NeonBadge(
                        label: '연동된 계정 없음',
                        color: AppColors.neonAmber,
                        icon: Icons.link_off_rounded,
                      ),
                    const SizedBox(width: 5),
                    NeonBadge(
                      label: '릴스 ${state.reels.length}개',
                      color: AppColors.neonMagenta,
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

/// 플랫폼 계정 카드
///
/// 3단 상태를 정직하게 구분해 표시합니다:
///   ① 자격증명 없음 → "API 키 등록" 필요
///   ② 자격증명 있음 / 미인증 → "인증하기" 필요
///   ③ 인증 완료 → 계정명 + 실제 발행 실적
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
    final state = context.watch<AppState>();
    final (icon, color) = _meta(account.platform);
    final authing = state.authenticating == account.platform;

    // 상태 판정
    final String statusLabel;
    final Color statusColor;
    final String detail;

    if (account.canPublish) {
      statusLabel = '인증 완료';
      statusColor = AppColors.neonLime;
      detail = account.publishedCount > 0
          ? '${account.displayName} · 이 앱에서 발행 ${account.publishedCount}건'
          : '${account.displayName} · 발행 이력 없음';
    } else if (account.hasCredentials) {
      statusLabel = '인증 필요';
      statusColor = AppColors.neonAmber;
      detail = 'API 키 등록됨 · 로그인 인증이 남았습니다';
    } else {
      statusLabel = '미연동';
      statusColor = AppColors.textLow;
      detail = 'API 자격증명이 등록되지 않았습니다';
    }

    return GlassCard(
      padding: const EdgeInsets.all(13),
      glowColor: account.canPublish ? color : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(
                      alpha: account.canPublish ? 0.16 : 0.07),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon,
                    size: 19,
                    color: account.canPublish
                        ? color
                        : color.withValues(alpha: 0.4)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          account.platform.label,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textHigh,
                          ),
                        ),
                        const SizedBox(width: 6),
                        NeonBadge(label: statusLabel, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(detail,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),

          // 필요 권한 범위 표시
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: account.requiredScopes
                .map((s) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLow,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 11),

          // 액션
          if (authing)
            Row(
              children: [
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.neonAmber),
                ),
                const SizedBox(width: 8),
                Text('브라우저에서 인증 진행 중…',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            )
          else if (account.canPublish)
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: '연동 해제',
                    icon: Icons.link_off_rounded,
                    color: AppColors.textMid,
                    expanded: true,
                    onPressed: () =>
                        state.disconnectAccount(account.platform),
                  ),
                ),
              ],
            )
          else if (account.hasCredentials)
            Row(
              children: [
                Expanded(
                  child: NeonButton(
                    label: '인증하기',
                    icon: Icons.login_rounded,
                    compact: true,
                    expanded: true,
                    gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.62)]),
                    onPressed: () => _auth(context, state),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'API 키 등록',
                    icon: Icons.key_rounded,
                    color: color,
                    expanded: true,
                    onPressed: () => _showCredentialSheet(context, state),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _auth(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await state.authenticate(account.platform);
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error),
          duration: const Duration(seconds: 5),
          backgroundColor: AppColors.surfaceHigh,
        ),
      );
    }
  }

  /// API 자격증명 등록 시트
  void _showCredentialSheet(BuildContext context, AppState state) {
    final idCtrl = TextEditingController();
    final secretCtrl = TextEditingController();
    final (icon, color) = _meta(account.platform);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                        Icon(icon, size: 20, color: color),
                        const SizedBox(width: 9),
                        Text('${account.platform.label} API 키',
                            style: Theme.of(ctx).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 발급 안내
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: color.withValues(alpha: 0.28)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 14, color: color),
                              const SizedBox(width: 6),
                              Text('발급 방법',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  )),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            account.credentialGuide,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.55,
                              color: AppColors.textMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text('Client ID',
                        style: Theme.of(ctx).textTheme.labelSmall),
                    const SizedBox(height: 7),
                    _input(idCtrl, false),
                    const SizedBox(height: 13),
                    Text('Client Secret',
                        style: Theme.of(ctx).textTheme.labelSmall),
                    const SizedBox(height: 7),
                    _input(secretCtrl, true),
                    const SizedBox(height: 13),

                    Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            size: 13, color: AppColors.textLow),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '입력한 키는 기기 내에만 보관되며 외부로 전송되지 않습니다.',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    NeonButton(
                      label: '등록',
                      icon: Icons.check_rounded,
                      expanded: true,
                      gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.62)]),
                      onPressed: () {
                        final messenger = ScaffoldMessenger.of(context);
                        if (idCtrl.text.trim().isEmpty ||
                            secretCtrl.text.trim().isEmpty) {
                          messenger.showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Client ID와 Secret을 모두 입력해 주세요')),
                          );
                          return;
                        }
                        state.registerCredentials(account.platform);
                        Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                                '${account.platform.label} API 키 등록됨 · '
                                '이제 "인증하기"를 눌러 주세요'),
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
    );
  }

  Widget _input(TextEditingController ctrl, bool obscure) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(
          color: AppColors.textHigh, fontSize: 13, fontFamily: 'monospace'),
      decoration: InputDecoration(
        hintText: obscure ? '••••••••••••••••' : '000000-xxxxx.apps...',
        hintStyle: const TextStyle(
            color: AppColors.textLow, fontSize: 12.5),
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
