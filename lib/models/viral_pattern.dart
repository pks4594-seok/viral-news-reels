/// 벤치마크 크리에이터 — 학습 대상 계정
class BenchmarkCreator {
  final String id;
  final String handle;
  final String platform; // youtube / tiktok
  final String avatarUrl;
  final int followers;
  final double avgViewRate; // 평균 조회 도달률
  final bool learning; // 학습 활성화 여부
  final int analyzedClips;

  const BenchmarkCreator({
    required this.id,
    required this.handle,
    required this.platform,
    required this.avatarUrl,
    required this.followers,
    required this.avgViewRate,
    this.learning = true,
    this.analyzedClips = 0,
  });

  BenchmarkCreator copyWith({bool? learning, int? analyzedClips}) =>
      BenchmarkCreator(
        id: id,
        handle: handle,
        platform: platform,
        avatarUrl: avatarUrl,
        followers: followers,
        avgViewRate: avgViewRate,
        learning: learning ?? this.learning,
        analyzedClips: analyzedClips ?? this.analyzedClips,
      );
}

/// 분석된 바이럴 클립 (학습 샘플)
class ViralClip {
  final String id;
  final String creatorHandle;
  final String platform;
  final String thumbnailUrl;
  final String hookText; // 첫 3초 후킹 문구
  final int views;
  final double retentionRate; // 시청 유지율
  final int durationSec;
  final int cutCount; // 컷 전환 횟수
  final String captionStyle; // 자막 스타일
  final String pacing; // 편집 템포
  final List<String> tags;

  const ViralClip({
    required this.id,
    required this.creatorHandle,
    required this.platform,
    required this.thumbnailUrl,
    required this.hookText,
    required this.views,
    required this.retentionRate,
    required this.durationSec,
    required this.cutCount,
    required this.captionStyle,
    required this.pacing,
    required this.tags,
  });

  /// 초당 컷 전환 밀도 — 템포 지표
  double get cutDensity => cutCount / durationSec;
}

/// 학습으로 도출된 바이럴 공식
class ViralFormula {
  final String name;
  final String description;

  /// 권장 후킹 템플릿 (뉴스 제목을 {title}, 키워드를 {keyword}로 치환)
  final String hookTemplate;

  /// 권장 영상 길이(초)
  final int recommendedDuration;

  /// 권장 컷 수
  final int recommendedCuts;

  /// 자막 스타일
  final String captionStyle;

  /// 이 공식의 학습 신뢰도 (0~1)
  final double confidence;

  /// 근거가 된 샘플 수
  final int sampleSize;

  /// 평균 유지율
  final double avgRetention;

  const ViralFormula({
    required this.name,
    required this.description,
    required this.hookTemplate,
    required this.recommendedDuration,
    required this.recommendedCuts,
    required this.captionStyle,
    required this.confidence,
    required this.sampleSize,
    required this.avgRetention,
  });

  String applyHook(String title, String keyword) {
    return hookTemplate
        .replaceAll('{title}', title)
        .replaceAll('{keyword}', keyword);
  }
}

/// 트렌드 키워드
class TrendKeyword {
  final String keyword;
  final int volume; // 검색/언급량
  final double changeRate; // 변화율 (+1.0 = +100%)
  final String category;
  final List<double> curve;

  const TrendKeyword({
    required this.keyword,
    required this.volume,
    required this.changeRate,
    required this.category,
    required this.curve,
  });

  bool get isRising => changeRate > 0;

  String get changeLabel {
    final pct = (changeRate * 100).abs().toStringAsFixed(0);
    return '${isRising ? '+' : '-'}$pct%';
  }
}
