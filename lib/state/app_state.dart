import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/news_article.dart';
import '../models/reel_project.dart';
import '../models/upload_task.dart';
import '../models/viral_pattern.dart';
import '../services/news_feed_service.dart';
import '../services/reel_generator_service.dart';
import '../services/viral_learning_service.dart';

/// 앱 전역 상태 — 뉴스 수집 → 릴스 생성 → 업로드 큐의 전 흐름을 관장
class AppState extends ChangeNotifier {
  final _news = NewsFeedService.instance;
  final _learning = ViralLearningService.instance;
  final _generator = ReelGeneratorService.instance;

  // ── 뉴스 ────────────────────────────────────────────
  List<NewsArticle> _articles = [];
  bool _loadingNews = false;
  String? _newsError;
  String _category = NewsCategory.all;
  DateTime? _lastFetched;

  List<NewsArticle> get articles => _articles;
  bool get loadingNews => _loadingNews;
  String? get newsError => _newsError;
  String get category => _category;
  DateTime? get lastFetched => _lastFetched;

  // ── 뉴스 소스 ────────────────────────────────────────
  List<NewsSource> _sources = List.of(NewsFeedService.defaultSources);
  List<NewsSource> get sources => _sources;

  // ── 릴스 ────────────────────────────────────────────
  final List<ReelProject> _reels = [];
  List<ReelProject> get reels => _reels;

  /// 생성 진행 중인 뉴스 ID → 진행률
  final Map<String, double> _generating = {};
  Map<String, double> get generating => _generating;

  // ── 업로드 큐 ────────────────────────────────────────
  final List<UploadTask> _uploads = [];
  List<UploadTask> get uploads => _uploads;

  // ── 벤치마크 / 학습 ──────────────────────────────────
  List<BenchmarkCreator> _creators = [];
  List<BenchmarkCreator> get creators => _creators;
  List<ViralClip> get viralClips => _learning.analyzedClips();
  List<ViralFormula> get formulas => _learning.formulas();
  List<TrendKeyword> get trendKeywords => _learning.trendingKeywords();
  Map<String, dynamic> get learningStats => _learning.learningStats();
  List<Map<String, dynamic>> get hookInsights => _learning.hookInsights();

  // ── 플랫폼 계정 ──────────────────────────────────────
  List<PlatformAccount> _accounts = const [
    PlatformAccount(
      platform: UploadPlatform.youtube,
      displayName: '@trendreel_kr',
      connected: true,
      publishedCount: 42,
      totalViews: 3840000,
    ),
    PlatformAccount(
      platform: UploadPlatform.tiktok,
      displayName: '@trendreel',
      connected: true,
      publishedCount: 58,
      totalViews: 6120000,
    ),
    PlatformAccount(
      platform: UploadPlatform.blog,
      displayName: 'trendreel.blog',
      connected: false,
    ),
  ];
  List<PlatformAccount> get accounts => _accounts;

  // ── 자동화 설정 ──────────────────────────────────────
  bool _autoCollect = true;
  bool _autoGenerate = false;
  bool _autoUpload = false;
  int _minTrendScore = 75;

  bool get autoCollect => _autoCollect;
  bool get autoGenerate => _autoGenerate;
  bool get autoUpload => _autoUpload;
  int get minTrendScore => _minTrendScore;

  AppState() {
    _creators = _learning.defaultCreators();
    refreshNews();
  }

  // ══════════════════════════════════════════════════════
  // 뉴스 수집
  // ══════════════════════════════════════════════════════

  Future<void> refreshNews() async {
    _loadingNews = true;
    _newsError = null;
    notifyListeners();

    try {
      final list = await _news.fetchLatest(sources: _sources);
      _articles = list;
      _lastFetched = DateTime.now();
      _loadingNews = false;
      notifyListeners();
    } catch (e) {
      _newsError = '뉴스 수집에 실패했습니다. 네트워크를 확인해 주세요.';
      _loadingNews = false;
      notifyListeners();
    }
  }

  void setCategory(String c) {
    _category = c;
    notifyListeners();
  }

  /// 현재 카테고리 필터가 적용된 뉴스 목록 (메모리 필터 — 인덱스 불필요)
  List<NewsArticle> get filteredArticles {
    if (_category == NewsCategory.all) return _articles;
    return _articles.where((a) => a.category == _category).toList();
  }

  /// 트렌드 스코어 기준 상위 뉴스
  List<NewsArticle> get hotArticles {
    final list = List.of(_articles)
      ..sort((a, b) => b.trendScore.compareTo(a.trendScore));
    return list.take(5).toList();
  }

  void toggleSource(String name) {
    _sources = _sources
        .map((s) => s.name == name ? s.copyWith(enabled: !s.enabled) : s)
        .toList();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════
  // 릴스 생성
  // ══════════════════════════════════════════════════════

  bool isGenerating(String articleId) => _generating.containsKey(articleId);

  /// 릴스 생성 실행 — 4단계 파이프라인을 순차 진행
  Future<ReelProject?> createReel(NewsArticle article) async {
    if (_generating.containsKey(article.id)) return null;

    _generating[article.id] = 0.0;
    notifyListeners();

    final reel = await _generator.generate(article);
    var current = reel;
    _reels.insert(0, current);
    notifyListeners();

    // 단계별 진행 시뮬레이션 — 실제 렌더 파이프라인의 진행률 훅 지점
    for (final stage in [
      ReelStage.script,
      ReelStage.voice,
      ReelStage.visual,
      ReelStage.render,
    ]) {
      for (var p = 0.0; p < 1.0; p += 0.25) {
        await Future<void>.delayed(const Duration(milliseconds: 130));
        final idx = _reels.indexWhere((r) => r.id == current.id);
        if (idx < 0) return null;
        current = current.copyWith(stage: stage, stageProgress: p + 0.25);
        _reels[idx] = current;
        _generating[article.id] = current.overallProgress;
        notifyListeners();
      }
    }

    final idx = _reels.indexWhere((r) => r.id == current.id);
    if (idx >= 0) {
      current = current.copyWith(stage: ReelStage.ready, stageProgress: 1.0);
      _reels[idx] = current;
    }

    // 원본 기사에 생성 완료 표시
    final ai = _articles.indexWhere((a) => a.id == article.id);
    if (ai >= 0) {
      _articles[ai] = _articles[ai].copyWith(reelCreated: true);
    }

    _generating.remove(article.id);
    notifyListeners();
    return current;
  }

  ReelProject? reelById(String id) {
    for (final r in _reels) {
      if (r.id == id) return r;
    }
    return null;
  }

  void updateReel(ReelProject updated) {
    final idx = _reels.indexWhere((r) => r.id == updated.id);
    if (idx >= 0) {
      _reels[idx] = updated;
      notifyListeners();
    }
  }

  void deleteReel(String id) {
    _reels.removeWhere((r) => r.id == id);
    _uploads.removeWhere((u) => u.reelId == id);
    notifyListeners();
  }

  List<ReelProject> get readyReels =>
      _reels.where((r) => r.isReady).toList();

  // ══════════════════════════════════════════════════════
  // 업로드 큐
  // ══════════════════════════════════════════════════════

  /// 업로드 작업 추가 — 릴스 1개를 여러 플랫폼에 큐잉
  void enqueueUploads(
    ReelProject reel,
    List<UploadPlatform> platforms, {
    DateTime? scheduledAt,
  }) {
    for (final p in platforms) {
      final task = UploadTask(
        id: 'up_${DateTime.now().microsecondsSinceEpoch}_${p.short}',
        reelId: reel.id,
        reelTitle: reel.hookTitle,
        thumbnailUrl: reel.article.imageUrl,
        platform: p,
        status: scheduledAt == null ? UploadStatus.draft : UploadStatus.scheduled,
        platformTitle: _generator.platformTitle(reel, p),
        platformDescription: _generator.platformDescription(reel, p),
        hashtags: reel.hashtags,
        createdAt: DateTime.now(),
        scheduledAt: scheduledAt,
      );
      _uploads.insert(0, task);
    }
    notifyListeners();
  }

  /// 업로드 실행
  ///
  /// 실제 연동 시 이 지점에서 각 플랫폼 API를 호출합니다:
  ///   YouTube — Data API v3 videos.insert (OAuth 2.0)
  ///   TikTok  — Content Posting API (OAuth 2.0)
  ///   Blog    — 워드프레스 REST / 티스토리 Open API
  Future<void> runUpload(String taskId) async {
    var idx = _uploads.indexWhere((u) => u.id == taskId);
    if (idx < 0) return;

    final account = _accounts.firstWhere(
      (a) => a.platform == _uploads[idx].platform,
      orElse: () => PlatformAccount(
        platform: _uploads[idx].platform,
        displayName: '',
        connected: false,
      ),
    );

    if (!account.connected) {
      _uploads[idx] = _uploads[idx].copyWith(
        status: UploadStatus.failed,
        errorMessage: '${account.platform.label} 계정이 연동되지 않았습니다. '
            '내정보 탭에서 계정을 연동해 주세요.',
      );
      notifyListeners();
      return;
    }

    _uploads[idx] = _uploads[idx].copyWith(
      status: UploadStatus.uploading,
      progress: 0,
      errorMessage: null,
    );
    notifyListeners();

    for (var p = 0.0; p < 1.0; p += 0.1) {
      await Future<void>.delayed(const Duration(milliseconds: 160));
      idx = _uploads.indexWhere((u) => u.id == taskId);
      if (idx < 0) return;
      _uploads[idx] = _uploads[idx].copyWith(progress: p + 0.1);
      notifyListeners();
    }

    idx = _uploads.indexWhere((u) => u.id == taskId);
    if (idx < 0) return;

    final reel = reelById(_uploads[idx].reelId);
    final views = reel != null ? (reel.predictedViews * 0.72).round() : 0;

    _uploads[idx] = _uploads[idx].copyWith(
      status: UploadStatus.published,
      progress: 1.0,
      actualViews: views,
    );

    // 계정 통계 반영
    _accounts = _accounts.map((a) {
      if (a.platform != _uploads[idx].platform) return a;
      return a.copyWith(
        publishedCount: a.publishedCount + 1,
        totalViews: a.totalViews + views,
      );
    }).toList();

    notifyListeners();
  }

  /// 큐 전체 발행
  Future<void> runAllPending() async {
    final pending = _uploads
        .where((u) =>
            u.status == UploadStatus.draft ||
            u.status == UploadStatus.scheduled ||
            u.status == UploadStatus.failed)
        .map((u) => u.id)
        .toList();
    for (final id in pending) {
      await runUpload(id);
    }
  }

  void scheduleUpload(String taskId, DateTime at) {
    final idx = _uploads.indexWhere((u) => u.id == taskId);
    if (idx < 0) return;
    _uploads[idx] = _uploads[idx].copyWith(
      status: UploadStatus.scheduled,
      scheduledAt: at,
    );
    notifyListeners();
  }

  void updateUploadMeta(String taskId, {String? title, String? description}) {
    final idx = _uploads.indexWhere((u) => u.id == taskId);
    if (idx < 0) return;
    _uploads[idx] = _uploads[idx].copyWith(
      platformTitle: title,
      platformDescription: description,
    );
    notifyListeners();
  }

  void removeUpload(String id) {
    _uploads.removeWhere((u) => u.id == id);
    notifyListeners();
  }

  List<UploadTask> uploadsByStatus(UploadStatus? status) {
    if (status == null) return _uploads;
    return _uploads.where((u) => u.status == status).toList();
  }

  int get pendingUploadCount => _uploads
      .where((u) =>
          u.status == UploadStatus.draft ||
          u.status == UploadStatus.scheduled ||
          u.status == UploadStatus.failed)
      .length;

  // ══════════════════════════════════════════════════════
  // 벤치마크 학습
  // ══════════════════════════════════════════════════════

  void toggleCreatorLearning(String id) {
    _creators = _creators
        .map((c) => c.id == id ? c.copyWith(learning: !c.learning) : c)
        .toList();
    notifyListeners();
  }

  void addCreator(String handle, String platform) {
    final normalized = handle.startsWith('@') ? handle : '@$handle';
    _creators = [
      ..._creators,
      BenchmarkCreator(
        id: 'c_${DateTime.now().millisecondsSinceEpoch}',
        handle: normalized,
        platform: platform,
        avatarUrl: 'https://sspark.genspark.ai/i/H9sLZfGUfGl37AQy?width=200',
        followers: 0,
        avgViewRate: 0,
        analyzedClips: 0,
      ),
    ];
    notifyListeners();
  }

  void removeCreator(String id) {
    _creators = _creators.where((c) => c.id != id).toList();
    notifyListeners();
  }

  /// 학습 재실행 — 등록된 크리에이터의 최신 클립을 재분석
  bool _learningInProgress = false;
  double _learningProgress = 0;
  bool get learningInProgress => _learningInProgress;
  double get learningProgress => _learningProgress;

  Future<void> retrainModel() async {
    if (_learningInProgress) return;
    _learningInProgress = true;
    _learningProgress = 0;
    notifyListeners();

    for (var p = 0.0; p < 1.0; p += 0.08) {
      await Future<void>.delayed(const Duration(milliseconds: 140));
      _learningProgress = (p + 0.08).clamp(0.0, 1.0);
      notifyListeners();
    }

    // 분석 클립 수 증가 반영
    _creators = _creators
        .map((c) => c.learning
            ? c.copyWith(analyzedClips: c.analyzedClips + 12)
            : c)
        .toList();

    _learningInProgress = false;
    _learningProgress = 1.0;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════
  // 계정 / 설정
  // ══════════════════════════════════════════════════════

  void toggleAccount(UploadPlatform platform) {
    _accounts = _accounts.map((a) {
      if (a.platform != platform) return a;
      return a.copyWith(connected: !a.connected);
    }).toList();
    notifyListeners();
  }

  void setAutoCollect(bool v) {
    _autoCollect = v;
    notifyListeners();
  }

  void setAutoGenerate(bool v) {
    _autoGenerate = v;
    notifyListeners();
  }

  void setAutoUpload(bool v) {
    _autoUpload = v;
    notifyListeners();
  }

  void setMinTrendScore(int v) {
    _minTrendScore = v;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════
  // 통계
  // ══════════════════════════════════════════════════════

  int get totalPublished =>
      _uploads.where((u) => u.status == UploadStatus.published).length;

  int get totalViews => _accounts.fold<int>(0, (s, a) => s + a.totalViews);

  int get todayReelCount {
    final today = DateTime.now();
    return _reels
        .where((r) =>
            r.createdAt.year == today.year &&
            r.createdAt.month == today.month &&
            r.createdAt.day == today.day)
        .length;
  }
}
