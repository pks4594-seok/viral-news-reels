import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/news_article.dart';
import '../models/viral_pattern.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 트렌드 & 학습실
///
/// 실시간 급상승 키워드 + 벤치마크 크리에이터 학습 현황 + 도출된 바이럴 공식
class TrendScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  const TrendScreen({super.key, required this.onNavigate});

  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Header(),
        _TabBar(controller: _tabs),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _KeywordsTab(),
              _LearningTab(),
              _FormulasTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final stats = context.select<AppState, Map<String, dynamic>>(
        (s) => s.learningStats);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.neonAmber.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: AppColors.neonAmber, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: GradientText(
                  '트렌드 & 학습',
                  gradient: LinearGradient(
                      colors: [AppColors.neonAmber, AppColors.neonMagenta]),
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '학습 클립',
                  value: '${stats['totalClips']}',
                  icon: Icons.video_library_rounded,
                  color: AppColors.neonMagenta,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: StatTile(
                  label: '평균 유지율',
                  value:
                      '${((stats['avgRetention'] as double) * 100).round()}%',
                  icon: Icons.timelapse_rounded,
                  color: AppColors.neonCyan,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: StatTile(
                  label: '도출 공식',
                  value: '${stats['formulas']}',
                  icon: Icons.science_rounded,
                  color: AppColors.neonLime,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow:
              AppShadows.glow(AppColors.neonMagenta, blur: 14, opacity: 0.3),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textMid,
        labelStyle:
            const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
        unselectedLabelStyle:
            const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(height: 34, text: '급상승'),
          Tab(height: 34, text: '벤치마크'),
          Tab(height: 34, text: '공식'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 급상승 키워드
// ══════════════════════════════════════════════════════════

class _KeywordsTab extends StatelessWidget {
  const _KeywordsTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final keywords = List.of(state.trendKeywords)
      ..sort((a, b) => b.changeRate.compareTo(a.changeRate));
    final hot = state.hotArticles;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        const SectionHeader(
          title: '실시간 급상승 키워드',
          subtitle: '포털 검색량 · SNS 언급량 통합 지표',
          icon: Icons.bolt_rounded,
          accent: AppColors.neonAmber,
        ),
        const SizedBox(height: 12),
        ...keywords.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _KeywordRow(rank: e.key + 1, keyword: e.value),
            )),
        const SizedBox(height: 22),
        const SectionHeader(
          title: '릴스 제작 추천 뉴스',
          subtitle: '트렌드 점수 상위 · 지금 만들면 효과 최대',
          icon: Icons.recommend_rounded,
          accent: AppColors.neonMagenta,
        ),
        const SizedBox(height: 12),
        if (hot.isEmpty)
          GlassCard(
            child: Text('뉴스를 먼저 수집해 주세요.',
                style: Theme.of(context).textTheme.bodyMedium),
          )
        else
          ...hot.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _HotArticleRow(article: a),
              )),
      ],
    );
  }
}

class _KeywordRow extends StatelessWidget {
  final int rank;
  final TrendKeyword keyword;
  const _KeywordRow({required this.rank, required this.keyword});

  @override
  Widget build(BuildContext context) {
    final color = keyword.isRising ? AppColors.neonMagenta : AppColors.textLow;
    final catColor = AppColors.categoryColor(keyword.category);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      glowColor: rank <= 3 ? color : null,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: rank <= 3 ? color : AppColors.textLow,
                height: 1,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        keyword.keyword,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textHigh,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    NeonBadge(label: keyword.category, color: catColor),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '언급 ${NewsArticle.formatCount(keyword.volume)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 62,
            child: Sparkline(
              data: keyword.curve,
              color: keyword.isRising
                  ? AppColors.neonLime
                  : AppColors.neonRed,
              height: 26,
              strokeWidth: 1.6,
            ),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                keyword.isRising
                    ? Icons.arrow_drop_up_rounded
                    : Icons.arrow_drop_down_rounded,
                size: 19,
                color:
                    keyword.isRising ? AppColors.neonLime : AppColors.neonRed,
              ),
              Text(
                keyword.changeLabel,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: keyword.isRising
                      ? AppColors.neonLime
                      : AppColors.neonRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HotArticleRow extends StatelessWidget {
  final NewsArticle article;
  const _HotArticleRow({required this.article});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final generating = state.isGenerating(article.id);

    return GlassCard(
      padding: const EdgeInsets.all(11),
      child: Row(
        children: [
          NetImage(
              url: article.imageUrl, width: 62, height: 62, radius: 11),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: AppColors.textHigh,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    NeonBadge(
                      label: '${article.trendScore}점',
                      color: AppColors.heatColor(article.trendScore),
                      icon: Icons.whatshot_rounded,
                    ),
                    const SizedBox(width: 5),
                    Text(article.viewsLabel,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (generating)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.neonMagenta),
            )
          else
            IconButton(
              onPressed: () => state.createReel(article),
              icon: const Icon(Icons.auto_awesome_rounded, size: 19),
              color: AppColors.neonMagenta,
              tooltip: '릴스 생성',
              style: IconButton.styleFrom(
                backgroundColor:
                    AppColors.neonMagenta.withValues(alpha: 0.12),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 벤치마크 학습
// ══════════════════════════════════════════════════════════

class _LearningTab extends StatelessWidget {
  const _LearningTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        // 학습 실행 카드
        GlassCard(
          glowColor: AppColors.neonPurple,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.purpleGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.psychology_rounded,
                        color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '바이럴 패턴 학습 엔진',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textHigh,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '조회수 상위 크리에이터 영상에서 후킹·템포·자막 문법을 추출',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (state.learningInProgress) ...[
                Row(
                  children: [
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.neonPurple),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '클립 분석 중 ${(state.learningProgress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neonPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: state.learningProgress,
                    minHeight: 5,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.neonPurple),
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: NeonButton(
                        label: '학습 재실행',
                        icon: Icons.model_training_rounded,
                        gradient: AppColors.purpleGradient,
                        expanded: true,
                        compact: true,
                        onPressed: state.retrainModel,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GhostButton(
                      label: '계정 추가',
                      icon: Icons.add_rounded,
                      color: AppColors.neonCyan,
                      onPressed: () => _addCreatorDialog(context, state),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 후킹 유형별 성과
        const SectionHeader(
          title: '후킹 유형별 성과',
          subtitle: '학습 결과 — 유형별 평균 시청 유지율',
          icon: Icons.insights_rounded,
          accent: AppColors.neonCyan,
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            children: state.hookInsights.map((h) {
              final ret = h['retention'] as double;
              final share = h['share'] as double;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            h['type'] as String,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHigh,
                            ),
                          ),
                        ),
                        Text(
                          '유지 ${(ret * 100).round()}%',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.heatColor((ret * 100).round()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '점유 ${(share * 100).round()}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ret,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceHigh,
                        valueColor: AlwaysStoppedAnimation(
                            AppColors.heatColor((ret * 100).round())),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // 벤치마크 크리에이터
        SectionHeader(
          title: '벤치마크 크리에이터',
          subtitle:
              '${state.creators.where((c) => c.learning).length}개 계정 학습 중',
          icon: Icons.groups_rounded,
          accent: AppColors.neonMagenta,
        ),
        const SizedBox(height: 12),
        ...state.creators.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _CreatorRow(creator: c),
            )),
        const SizedBox(height: 20),

        // 분석된 클립
        const SectionHeader(
          title: '분석된 바이럴 클립',
          subtitle: '학습 근거가 된 상위 조회수 영상',
          icon: Icons.movie_filter_rounded,
          accent: AppColors.neonLime,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 232,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.viralClips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 11),
            itemBuilder: (ctx, i) => _ClipCard(clip: state.viralClips[i]),
          ),
        ),
      ],
    );
  }

  void _addCreatorDialog(BuildContext context, AppState state) {
    final ctrl = TextEditingController();
    var platform = 'youtube';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('벤치마크 계정 추가',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '학습시킬 인기 크리에이터의 계정을 입력하세요.\n해당 계정의 상위 조회수 영상이 분석 대상이 됩니다.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(color: AppColors.textHigh),
                decoration: InputDecoration(
                  hintText: '@계정명',
                  hintStyle: const TextStyle(color: AppColors.textLow),
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
                    borderSide:
                        const BorderSide(color: AppColors.neonMagenta),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _platformChip(
                    'YouTube',
                    platform == 'youtube',
                    AppColors.neonRed,
                    () => setLocal(() => platform = 'youtube'),
                  ),
                  const SizedBox(width: 8),
                  _platformChip(
                    'TikTok',
                    platform == 'tiktok',
                    AppColors.neonCyan,
                    () => setLocal(() => platform = 'tiktok'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소',
                  style: TextStyle(color: AppColors.textMid)),
            ),
            TextButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  state.addCreator(ctrl.text.trim(), platform);
                }
                Navigator.pop(ctx);
              },
              child: const Text('추가',
                  style: TextStyle(
                      color: AppColors.neonMagenta,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _platformChip(
      String label, bool active, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? color : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? color : AppColors.textMid,
          ),
        ),
      ),
    );
  }
}

class _CreatorRow extends StatelessWidget {
  final BenchmarkCreator creator;
  const _CreatorRow({required this.creator});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final pColor = creator.platform == 'youtube'
        ? AppColors.neonRed
        : AppColors.neonCyan;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      glowColor: creator.learning ? pColor : null,
      child: Row(
        children: [
          Stack(
            children: [
              NetImage(
                  url: creator.avatarUrl, width: 42, height: 42, radius: 21),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: pColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 1.5),
                  ),
                  child: Icon(
                    creator.platform == 'youtube'
                        ? Icons.play_arrow_rounded
                        : Icons.music_note_rounded,
                    size: 8,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creator.handle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHigh,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  creator.followers > 0
                      ? '팔로워 ${NewsArticle.formatCount(creator.followers)} · '
                          '클립 ${creator.analyzedClips}개 분석'
                      : '분석 대기 중',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (creator.avgViewRate > 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: NeonBadge(
                label: '도달 ${(creator.avgViewRate * 100).round()}%',
                color: AppColors.neonLime,
              ),
            ),
          Switch(
            value: creator.learning,
            onChanged: (_) => state.toggleCreatorLearning(creator.id),
          ),
        ],
      ),
    );
  }
}

class _ClipCard extends StatelessWidget {
  final ViralClip clip;
  const _ClipCard({required this.clip});

  @override
  Widget build(BuildContext context) {
    final pColor =
        clip.platform == 'youtube' ? AppColors.neonRed : AppColors.neonCyan;

    return SizedBox(
      width: 152,
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: 118,
                    width: double.infinity,
                    child: NetImage(url: clip.thumbnailUrl),
                  ),
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
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.78),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: NeonBadge(
                    label: clip.platform == 'youtube' ? 'YT' : 'TT',
                    color: pColor,
                    filled: true,
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${clip.durationSec}s',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 7,
                  child: Text(
                    '"${clip.hookText}"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.visibility_rounded,
                          size: 11, color: AppColors.neonMagenta),
                      const SizedBox(width: 3),
                      Text(
                        NewsArticle.formatCount(clip.views),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.neonMagenta,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '유지 ${(clip.retentionRate * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neonLime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '컷 ${clip.cutCount}회 · ${clip.pacing}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: clip.tags
                        .take(2)
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t,
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMid,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 바이럴 공식
// ══════════════════════════════════════════════════════════

class _FormulasTab extends StatelessWidget {
  const _FormulasTab();

  @override
  Widget build(BuildContext context) {
    final formulas = context.select<AppState, List<ViralFormula>>(
        (s) => s.formulas);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        const SectionHeader(
          title: '학습으로 도출된 바이럴 공식',
          subtitle: '릴스 생성 시 뉴스 성격에 맞춰 자동 적용됩니다',
          icon: Icons.science_rounded,
          accent: AppColors.neonLime,
        ),
        const SizedBox(height: 12),
        ...formulas.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: _FormulaCard(formula: f),
            )),
      ],
    );
  }
}

class _FormulaCard extends StatelessWidget {
  final ViralFormula formula;
  const _FormulaCard({required this.formula});

  @override
  Widget build(BuildContext context) {
    final conf = (formula.confidence * 100).round();
    final color = AppColors.heatColor(conf);

    return GlassCard(
      glowColor: conf >= 88 ? color : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formula.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textHigh,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              ScoreRing(score: conf, size: 42, label: '신뢰'),
            ],
          ),
          const SizedBox(height: 9),
          Text(formula.description,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 13),

          // 후킹 템플릿
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.bg.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.format_quote_rounded,
                        size: 13, color: AppColors.neonAmber),
                    const SizedBox(width: 4),
                    Text('후킹 템플릿',
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  formula.hookTemplate,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neonAmber,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _spec(Icons.timer_outlined, '${formula.recommendedDuration}초',
                  AppColors.neonCyan),
              _spec(Icons.content_cut_rounded,
                  '${formula.recommendedCuts}컷', AppColors.neonPurple),
              _spec(Icons.closed_caption_rounded, formula.captionStyle,
                  AppColors.neonMagenta),
              _spec(
                  Icons.timelapse_rounded,
                  '유지 ${(formula.avgRetention * 100).round()}%',
                  AppColors.neonLime),
              _spec(Icons.dataset_rounded, '샘플 ${formula.sampleSize}',
                  AppColors.textMid),
            ],
          ),
        ],
      ),
    );
  }

  Widget _spec(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
