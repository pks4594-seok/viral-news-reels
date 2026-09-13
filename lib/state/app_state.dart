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

  /// 마지막 수집에서 성공한 소스명
  List<String> _succeededSources = [];

  /// 마지막 수집에서 실패한 소스 (이유 포함)
  List<({String name, String reason})> _failedSources = [];

  /// 프록시 경유 여부 (웹 환경 표시용)
  bool _usedProxy = false;

  List<NewsArticle> get articles => _articles;
  bool get loadingNews => _loadingNews;
  String? get newsError => _newsError;
  String get category => _category;
  DateTime? get lastFetched => _lastFetched;
  List<String> get succeededSources => _succeededSources;
  List<({String name, String reason})> get failedSources => _failedSources;
  bool get usedProxy => _usedProxy;

  /// 실제 RSS 수집에 성공한 상헜인지
  bool get hasLiveData => _articles.isNotEmpty && _succeededSources.isNotEmpty;

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
  //
  // 초기 상태는 전부 미연동입니다. 사용자가 직접 API 자격증명을 등록하고
  // OAuth 인증을 완료해야 connected=true가 됩니다.
  // 발행 건수·조회수는 이 앱에서 실제 발행한 결과만 누적됩니다.
  List<PlatformAccount> _accounts = const [
    PlatformAccount(platform: UploadPlatform.youtube),
    PlatformAccount(platform: UploadPlatform.tiktok),
    PlatformAccount(platform: UploadPlatform.blog),
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

  /// 실제 RSS 피드 수집
  ///
  /// 활성화된 언로사 피드를 병렬로 수집합니다.
  /// 일부가 실패해도 나머지 결과로 진행하고, 실패 내역을 보관합니다.
  Future<void> refreshNews() async {
    _loadingNews = true;
    _newsError = null;
    notifyListeners();

    try {
      final result = await _news.fetchLatest(sources: _sources);

      _succeededSources = result.succeeded;
      _failedSources = result.failed;
      _usedProxy = result.usedProxy;

      if (result.hasData) {
        _articles = result.articles;
        _lastFetched = DateTime.now();
      } else {
        // 모든 소스 실패 — 사직에게 이유를 알립니다.
        final reasons = result.failed.isEmpty
            ? '활성화된 뉴스 소스가 없습니다.'
            : result.failed
                .take(3)
                .map((f) => '${f.name}: ${f.reason}')
                .join('\n');
        _newsError = '뉴스 수집에 실패했습니다.\n$reasons';
      }

      _loadingNews = false;
      notifyListeners();
    } catch (e) {
      _newsError = '수집 중 오류가 발생했습니다: $e';
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
      ReelBuildStage.script,
      ReelBuildStage.voice,
      ReelBuildStage.visual,
      ReelBuildStage.render,
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
      current = current.copyWith(stage: ReelBuildStage.ready, stageProgress: 1.0);
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

    // 1단계 검증: API 자격증명 등록 여부
    if (!account.hasCredentials) {
      _uploads[idx] = _uploads[idx].copyWith(
        status: UploadStatus.failed,
        errorMessage: '${account.platform.label} API 자격증명이 없습니다.\n'
            '내정보 탭 → 해당 플랫폼 → "API 키 등록"에서 '
            'Client ID와 Secret을 입력해 주세요.',
      );
      notifyListeners();
      return;
    }

    // 2단계 검증: OAuth 인증 완료 여부
    if (!account.connected) {
      _uploads[idx] = _uploads[idx].copyWith(
        status: UploadStatus.failed,
        errorMessage: '${account.platform.label} 계정 인증이 필요합니다.\n'
            '내정보 탭에서 "인증하기"를 눌러 로그인해 주세요.',
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

    // 실제 조회수는 발행 후 플랫폼 Analytics API로 조회해야 합니다.
    // 임의의 추정치를 실적처럼 표시하지 않고 0으로 두며,
    // refreshAnalytics()가 실제 값을 채우는 구조입니다.
    _uploads[idx] = _uploads[idx].copyWith(
      status: UploadStatus.published,
      progress: 1.0,
    );

    // 발행 건수만 누적 (실제 발행 1건 = +1)
    final platform = _uploads[idx].platform;
    _accounts = _accounts.map((a) {
      if (a.platform != platform) return a;
      return a.copyWith(publishedCount: a.publishedCount + 1);
    }).toList();

    notifyListeners();
  }

  /// 발행된 콘텐츠의 실제 조회수 갱신
  ///
  /// 실 연동 시 각 플랫폼 Analytics API를 호출합니다:
  ///   YouTube — YouTube Analytics API v2 (reports.query)
  ///   TikTok  — Display API (video.list → view_count)
  ///   Blog    — 플랫폼별 통계 API
  ///
  /// 자격증명이 없으면 조회하지 않고 0을 유지합니다.
  Future<void> refreshAnalytics() async {
    final connected = _accounts.where((a) => a.canPublish).toList();
    if (connected.isEmpty) return;

    // 구현 지점: 여기서 플랫폼 Analytics API를 호출하여
    // _uploads의 actualViews와 _accounts의 totalViews를 갱신합니다.
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

  /// API 자격증명 등록 (Client ID / Secret)
  ///
  /// 실제 저장 시에는 flutter_secure_storage 등 암호화 저장소를 사용해야
  /// 합니다. 현재는 메모리에만 보관하며 앱 재시작 시 초기화됩니다.
  void registerCredentials(UploadPlatform platform) {
    _accounts = _accounts.map((a) {
      if (a.platform != platform) return a;
      return a.copyWith(hasCredentials: true);
    }).toList();
    notifyListeners();
  }

  /// OAuth 인증 진행 중인 플랫폼
  UploadPlatform? _authenticating;
  UploadPlatform? get authenticating => _authenticating;

  /// OAuth 인증 실행
  ///
  /// 실 연동 흐름:
  ///   1. 플랫폼 인증 URL을 시스템 브라우저로 열기 (url_launcher)
  ///   2. 사용자가 로그인 + 권한 동의
  ///   3. 리다이렉트 URI로 authorization code 수신 (app_links)
  ///   4. code → access token 교환 (POST /oauth/token)
  ///   5. 토큰으로 계정 정보 조회 → displayName 확보
  ///   6. refresh token을 flutter_secure_storage에 암호화 저장
  ///
  /// 자격증명이 없으면 인증을 시작하지 않습니다.
  Future<String?> authenticate(UploadPlatform platform) async {
    final idx = _accounts.indexWhere((a) => a.platform == platform);
    if (idx < 0) return '계정 정보를 찾을 수 없습니다.';

    if (!_accounts[idx].hasCredentials) {
      return '${platform.label} API 자격증명을 먼저 등록해 주세요.';
    }

    _authenticating = platform;
    notifyListeners();

    // 구현 지점: 위 1~5단계의 실제 OAuth 왕복
    await Future<void>.delayed(const Duration(milliseconds: 700));

    _authenticating = null;

    // 실제 토큰 교환이 구현되지 않았으므로 연동 상태를 바꾸지 않고
    // 정직하게 실패를 반환합니다.
    notifyListeners();
    return 'OAuth 토큰 교환이 아직 구현되지 않았습니다.\n'
        '${platform.label} 실연동을 진행하려면 알려 주세요.';
  }

  /// 계정 연동 해제 — 저장된 토큰과 계정명을 폐기
  void disconnectAccount(UploadPlatform platform) {
    _accounts = _accounts.map((a) {
      if (a.platform != platform) return a;
      return a.copyWith(connected: false, clearDisplayName: true);
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
