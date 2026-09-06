import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/news_article.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'reel_detail_screen.dart';

/// 뉴스 수집실 — 포털/신문사에서 모은 최신 뉴스를 트렌드 점수 순으로 배치
class NewsScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const NewsScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final articles = state.filteredArticles;

    return RefreshIndicator(
      onRefresh: state.refreshNews,
      color: AppColors.neonMagenta,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Header(state: state)),
          SliverToBoxAdapter(child: _CategoryChips(state: state)),
          SliverToBoxAdapter(child: _SourceStatusBanner(state: state)),
          if (state.newsError != null)
            SliverToBoxAdapter(child: _ErrorBanner(state: state)),
          if (state.loadingNews && articles.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _LoadingBlock(),
            )
          else if (articles.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: '수집된 뉴스가 없습니다',
                message: '카테고리를 바꾸거나 아래로 당겨 새로 수집해 보세요.',
                action: NeonButton(
                  label: '뉴스 수집',
                  icon: Icons.refresh_rounded,
                  onPressed: state.refreshNews,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              sliver: SliverList.separated(
                itemCount: articles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 13),
                itemBuilder: (ctx, i) => _NewsCard(
                  article: articles[i],
                  rank: i + 1,
                  onNavigate: onNavigate,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    final fetched = state.lastFetched;
    final timeLabel = fetched == null
        ? '수집 대기'
        : '${fetched.hour.toString().padLeft(2, '0')}:'
            '${fetched.minute.toString().padLeft(2, '0')} 수집 완료';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: AppShadows.glow(AppColors.neonMagenta,
                      blur: 16, opacity: 0.45),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GradientText(
                      '오늘의 바이럴 뉴스',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: state.loadingNews
                                ? AppColors.neonAmber
                                : AppColors.neonLime,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          state.loadingNews ? '수집 중…' : timeLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: state.loadingNews ? null : state.refreshNews,
                icon: state.loadingNews
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.neonCyan),
                      )
                    : const Icon(Icons.refresh_rounded, size: 21),
                color: AppColors.neonCyan,
                tooltip: '뉴스 재수집',
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '수집 기사',
                  value: '${state.articles.length}',
                  icon: Icons.article_rounded,
                  color: AppColors.neonCyan,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: StatTile(
                  label: '오늘 제작',
                  value: '${state.todayReelCount}',
                  icon: Icons.movie_filter_rounded,
                  color: AppColors.neonMagenta,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: StatTile(
                  label: '예측 조회수',
                  value: NewsArticle.formatCount(
                    state.articles.fold<int>(
                        0, (s, a) => s + a.predictedViews),
                  ),
                  icon: Icons.visibility_rounded,
                  color: AppColors.neonLime,
                  delta: '+18%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final AppState state;
  const _CategoryChips({required this.state});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: NewsCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (ctx, i) {
          final c = NewsCategory.values[i];
          final active = state.category == c;
          final color = c == NewsCategory.all
              ? AppColors.neonMagenta
              : AppColors.categoryColor(c);
          return Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => state.setCategory(c),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: active
                        ? LinearGradient(colors: [
                            color,
                            color.withValues(alpha: 0.62),
                          ])
                        : null,
                    color: active ? null : AppColors.surface,
                    border: Border.all(
                      color: active
                          ? Colors.transparent
                          : AppColors.border,
                    ),
                    boxShadow: active
                        ? AppShadows.glow(color, blur: 14, opacity: 0.35)
                        : null,
                  ),
                  child: Text(
                    c,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? Colors.white : AppColors.textMid,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 수집 소스 상태 배너
///
/// 어느 언론사에서 실제로 몇 건을 수집했는지, 실패한 소스는 무엇인지
/// 투명하게 보여줍니다. 웹에서 프록시를 경유했다면 그것도 밝힙니다.
class _SourceStatusBanner extends StatelessWidget {
  final AppState state;
  const _SourceStatusBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    if (!state.hasLiveData && !state.loadingNews) {
      return const SizedBox.shrink();
    }

    final ok = state.succeededSources.length;
    final fail = state.failedSources.length;
    final realImages =
        state.articles.where((a) => a.hasRealImage).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        glowColor: AppColors.neonLime,
        onTap: fail > 0 ? () => _showDetail(context) : null,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.neonLime.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.rss_feed_rounded,
                  size: 13, color: AppColors.neonLime),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '실시간 RSS 수집',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.neonLime,
                        ),
                      ),
                      const SizedBox(width: 5),
                      if (state.usedProxy)
                        const NeonBadge(
                          label: '프록시 경유',
                          color: AppColors.neonAmber,
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$ok개 언론사 · 기사 ${state.articles.length}건 · '
                    '실사진 $realImages장'
                    '${fail > 0 ? ' · 실패 $fail개' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (fail > 0)
              const Icon(Icons.chevron_right_rounded,
                  size: 17, color: AppColors.textLow),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
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
                Text('수집 결과 상세',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 14),
                if (state.succeededSources.isNotEmpty) ...[
                  Text('성공 (${state.succeededSources.length})',
                      style: Theme.of(ctx).textTheme.labelSmall),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: state.succeededSources
                        .map((s) => NeonBadge(
                            label: s, color: AppColors.neonLime))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (state.failedSources.isNotEmpty) ...[
                  Text('실패 (${state.failedSources.length})',
                      style: Theme.of(ctx).textTheme.labelSmall),
                  const SizedBox(height: 7),
                  ...state.failedSources.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 13, color: AppColors.neonRed),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                '${f.name} — ${f.reason}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMid,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 13),
                  Text(
                    '웹 브라우저는 CORS 정책으로 외부 피드 직접 호출이 '
                    '차단됩니다. 안드로이드 앱에서는 모든 소스가 직접 '
                    '수집됩니다.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final AppState state;
  const _ErrorBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        glowColor: AppColors.neonRed,
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.neonRed, size: 20),
            const SizedBox(width: 11),
            Expanded(
              child: Text(state.newsError!,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            GhostButton(
              label: '재시도',
              color: AppColors.neonRed,
              onPressed: state.refreshNews,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 130,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.neonCyan),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    height: 14,
                    width: 180,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(4),
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

/// 뉴스 카드 — 썸네일 + 헤드라인 + 트렌드 점수 + 릴스 생성 액션
class _NewsCard extends StatelessWidget {
  final NewsArticle article;
  final int rank;
  final ValueChanged<int> onNavigate;

  const _NewsCard({
    required this.article,
    required this.rank,
    required this.onNavigate,
  });

  Future<void> _create(BuildContext context) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: Text('"${article.keywords.isNotEmpty ? article.keywords.first : article.category}" 릴스 생성을 시작합니다'),
        duration: const Duration(seconds: 2),
      ),
    );

    final reel = await state.createReel(article);
    if (reel == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text('릴스 완성 · 바이럴 점수 ${reel.viralScore}점'),
        action: SnackBarAction(
          label: '보기',
          textColor: AppColors.neonCyan,
          onPressed: () => navigator.push(
            MaterialPageRoute(
              builder: (_) => ReelDetailScreen(reelId: reel.id),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final generating = state.isGenerating(article.id);
    final progress = state.generating[article.id] ?? 0;
    final catColor = AppColors.categoryColor(article.category);
    final heat = AppColors.heatColor(article.trendScore);

    return GlassCard(
      padding: EdgeInsets.zero,
      glowColor: article.trendScore >= 85 ? heat : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 썸네일 ────────────────────────────────
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
                child: SizedBox(
                  height: 152,
                  width: double.infinity,
                  child: NetImage(url: article.imageUrl),
                ),
              ),
              // 상단 그라디언트 마스크
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.72),
                      ],
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                ),
              ),
              // 랭크 + 카테고리
              Positioned(
                left: 12,
                top: 11,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$rank',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    NeonBadge(label: article.category, color: catColor),
                    if (article.reelCreated) ...[
                      const SizedBox(width: 6),
                      const NeonBadge(
                        label: '제작완료',
                        color: AppColors.neonLime,
                        icon: Icons.check_rounded,
                      ),
                    ],
                  ],
                ),
              ),
              // 트렌드 점수 링
              Positioned(
                right: 11,
                top: 9,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: ScoreRing(
                    score: article.trendScore,
                    size: 46,
                    label: '트렌드',
                  ),
                ),
              ),
              // 하단 예측 조회수 + 스파크라인
              Positioned(
                left: 12,
                right: 12,
                bottom: 9,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(Icons.trending_up_rounded, size: 14, color: heat),
                    const SizedBox(width: 4),
                    Text(
                      '예측 ${article.viewsLabel}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: heat,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Sparkline(
                        data: article.interestCurve,
                        color: heat,
                        height: 22,
                        strokeWidth: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── 본문 ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.32,
                    letterSpacing: -0.35,
                    color: AppColors.textHigh,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  article.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(Icons.language_rounded,
                        size: 12, color: AppColors.textLow),
                    const SizedBox(width: 4),
                    Text(
                      '${article.source} · ${article.relativeTime}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 키워드
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: article.keywords
                      .take(4)
                      .map((k) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              '#$k',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMid,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 13),

                // ── 액션 ─────────────────────────────
                if (generating)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.neonMagenta),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'AI 릴스 생성 중 ${(progress * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neonMagenta,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: AppColors.surfaceHigh,
                          valueColor: const AlwaysStoppedAnimation(
                              AppColors.neonMagenta),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: NeonButton(
                          label: article.reelCreated ? '다시 만들기' : 'AI 릴스 만들기',
                          icon: Icons.auto_awesome_rounded,
                          expanded: true,
                          compact: true,
                          onPressed: () => _create(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GhostButton(
                        label: '상세',
                        icon: Icons.article_outlined,
                        onPressed: () => _showSource(context),
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

  void _showSource(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        maxChildSize: 0.94,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 11, bottom: 5),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                  children: [
                    Row(
                      children: [
                        NeonBadge(
                          label: article.category,
                          color: AppColors.categoryColor(article.category),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '${article.source} · ${article.relativeTime}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                        letterSpacing: -0.5,
                        color: AppColors.textHigh,
                      ),
                    ),
                    const SizedBox(height: 15),
                    NetImage(url: article.imageUrl, radius: 15, height: 190),
                    const SizedBox(height: 16),
                    Text(
                      article.body,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.75,
                        color: AppColors.textMid,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassCard(
                      glowColor: AppColors.neonCyan,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.analytics_rounded,
                                  size: 15, color: AppColors.neonCyan),
                              SizedBox(width: 6),
                              Text(
                                '트렌드 분석',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.neonCyan,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _metric('트렌드 점수', '${article.trendScore} / 100'),
                          _metric('예측 조회수', article.viewsLabel),
                          _metric('숏폼 적합도',
                              article.trendScore >= 80 ? '매우 높음' : '보통'),
                          const SizedBox(height: 10),
                          Sparkline(
                            data: article.interestCurve,
                            color: AppColors.heatColor(article.trendScore),
                            height: 44,
                          ),
                          const SizedBox(height: 4),
                          Text('최근 24시간 관심도 추이',
                              style: Theme.of(ctx).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    if (article.hasSourceLink) ...[
                      const SizedBox(height: 16),
                      NeonButton(
                        label: '${article.source} 원문 열기',
                        icon: Icons.open_in_new_rounded,
                        expanded: true,
                        gradient: AppColors.cyanGradient,
                        onPressed: () => _openSource(ctx),
                      ),
                      const SizedBox(height: 7),
                      Center(
                        child: Text(
                          article.sourceUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 원문 기사 열기 — 시스템 브라우저 (안드로이드: Intent.ACTION_VIEW)
  Future<void> _openSource(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(article.sourceUrl);
    if (uri == null) return;

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('브라우저를 열 수 없습니다')),
      );
    }
  }

  Widget _metric(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textLow)),
            Text(v,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHigh)),
          ],
        ),
      );
}
