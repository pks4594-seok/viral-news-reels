/// 수집된 뉴스 기사
class NewsArticle {
  final String id;
  final String title;
  final String summary;
  final String body;
  final String source;
  final String sourceUrl;
  final String category;
  final String imageUrl;
  final DateTime publishedAt;

  /// 트렌드 스코어 (0~100) — 바이럴 가능성 예측
  final int trendScore;

  /// 예측 조회수
  final int predictedViews;

  /// 최근 24시간 관심도 추이 (스파크라인용, 0~1 정규화)
  final List<double> interestCurve;

  /// 키워드 추출 결과
  final List<String> keywords;

  /// 이미 릴스로 만들었는지
  final bool reelCreated;

  /// 언로사가 제공한 실제 기사 사진인지 (false면 카테고리 대집 이미지)
  final bool hasRealImage;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.source,
    required this.sourceUrl,
    required this.category,
    required this.imageUrl,
    required this.publishedAt,
    required this.trendScore,
    required this.predictedViews,
    required this.interestCurve,
    required this.keywords,
    this.reelCreated = false,
    this.hasRealImage = false,
  });

  NewsArticle copyWith({
    int? trendScore,
    int? predictedViews,
    bool? reelCreated,
  }) {
    return NewsArticle(
      id: id,
      title: title,
      summary: summary,
      body: body,
      source: source,
      sourceUrl: sourceUrl,
      category: category,
      imageUrl: imageUrl,
      publishedAt: publishedAt,
      trendScore: trendScore ?? this.trendScore,
      predictedViews: predictedViews ?? this.predictedViews,
      interestCurve: interestCurve,
      keywords: keywords,
      reelCreated: reelCreated ?? this.reelCreated,
      hasRealImage: hasRealImage,
    );
  }

  /// 원부 기사 링크가 있는지
  bool get hasSourceLink => sourceUrl.startsWith('http');

  /// "12분 전" 형태의 상대 시간
  String get relativeTime {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  /// 조회수 축약 표기 (12.4만)
  String get viewsLabel => formatCount(predictedViews);

  static String formatCount(int n) {
    if (n >= 100000000) return '${(n / 100000000).toStringAsFixed(1)}억';
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}만';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}천';
    return '$n';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'body': body,
        'source': source,
        'sourceUrl': sourceUrl,
        'category': category,
        'imageUrl': imageUrl,
        'publishedAt': publishedAt.toIso8601String(),
        'trendScore': trendScore,
        'predictedViews': predictedViews,
        'interestCurve': interestCurve,
        'keywords': keywords,
        'reelCreated': reelCreated,
      };

  factory NewsArticle.fromJson(Map<String, dynamic> j) => NewsArticle(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        summary: (j['summary'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        source: (j['source'] ?? '') as String,
        sourceUrl: (j['sourceUrl'] ?? '') as String,
        category: (j['category'] ?? '기타') as String,
        imageUrl: (j['imageUrl'] ?? '') as String,
        publishedAt:
            DateTime.tryParse((j['publishedAt'] ?? '') as String) ??
                DateTime.now(),
        trendScore: (j['trendScore'] ?? 0) as int,
        predictedViews: (j['predictedViews'] ?? 0) as int,
        interestCurve: ((j['interestCurve'] ?? const <dynamic>[]) as List)
            .map((e) => (e as num).toDouble())
            .toList(),
        keywords: ((j['keywords'] ?? const <dynamic>[]) as List)
            .map((e) => e.toString())
            .toList(),
        reelCreated: (j['reelCreated'] ?? false) as bool,
      );
}

/// 뉴스 카테고리 상수
class NewsCategory {
  NewsCategory._();
  static const String all = '전체';
  static const List<String> values = [
    '전체',
    '정치',
    '경제',
    'IT/테크',
    '스포츠',
    '연예',
    '사회',
  ];
}

/// 뉴스 소스 (포털/신문사)
class NewsSource {
  final String name;
  final String feedUrl;
  final bool enabled;

  /// 이 피드가 단일 카테고리 전용이면 고정 카테고리.
  /// null이면 기사 내용으로 자동 분류합니다.
  final String? category;

  const NewsSource({
    required this.name,
    required this.feedUrl,
    this.enabled = true,
    this.category,
  });

  NewsSource copyWith({bool? enabled}) => NewsSource(
        name: name,
        feedUrl: feedUrl,
        enabled: enabled ?? this.enabled,
        category: category,
      );

  /// 피드 도메인 (표시용)
  String get domain {
    try {
      return Uri.parse(feedUrl).host.replaceFirst('www.', '');
    } catch (_) {
      return feedUrl;
    }
  }
}
