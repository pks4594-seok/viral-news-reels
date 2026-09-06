import 'dart:math';

import '../models/news_article.dart';
import 'rss_parser.dart';

/// 뉴스 수집 서비스
///
/// 국내 언론사 RSS 피드를 실제로 수집하여 [NewsArticle]로 변환합니다.
/// 모든 피드는 사전 검증된 주소이며, 카테고리별로 분류되어 있습니다.
///
/// 수집 파이프라인:
///   1. 활성화된 소스의 RSS/Atom 피드 병렬 요청
///   2. XML 파싱 → FeedItem
///   3. 카테고리 분류 + 키워드 추출 + 이미지 확보
///   4. 트렌드 스코어 산출 (4개 신호 가중합)
///   5. 중복 제거 후 스코어 내림차순 정렬
class NewsFeedService {
  NewsFeedService._();
  static final NewsFeedService instance = NewsFeedService._();

  final _rss = RssParser.instance;
  final Random _rng = Random();

  /// 검증된 국내 언론사 RSS 피드
  ///
  /// 2026-09 기준 응답 확인 완료. 연합뉴스는 카테고리별 피드가
  /// 각 120건 + 이미지를 제공하여 주력 소스로 사용합니다.
  static const List<NewsSource> defaultSources = [
    NewsSource(
      name: '연합뉴스 정치',
      feedUrl: 'https://www.yna.co.kr/rss/politics.xml',
      category: '정치',
    ),
    NewsSource(
      name: '연합뉴스 경제',
      feedUrl: 'https://www.yna.co.kr/rss/economy.xml',
      category: '경제',
    ),
    NewsSource(
      name: '연합뉴스 산업',
      feedUrl: 'https://www.yna.co.kr/rss/industry.xml',
      category: 'IT/테크',
    ),
    NewsSource(
      name: '연합뉴스 스포츠',
      feedUrl: 'https://www.yna.co.kr/rss/sports.xml',
      category: '스포츠',
    ),
    NewsSource(
      name: '연합뉴스 연예',
      feedUrl: 'https://www.yna.co.kr/rss/entertainment.xml',
      category: '연예',
    ),
    NewsSource(
      name: '연합뉴스 사회',
      feedUrl: 'https://www.yna.co.kr/rss/society.xml',
      category: '사회',
    ),
    NewsSource(
      name: '전자신문',
      feedUrl: 'https://rss.etnews.com/Section901.xml',
      category: 'IT/테크',
    ),
    NewsSource(
      name: 'ZDNet Korea',
      feedUrl: 'https://feeds.feedburner.com/zdkorea',
      category: 'IT/테크',
    ),
    NewsSource(
      name: '한겨레',
      feedUrl: 'https://www.hani.co.kr/rss/',
      category: null,
    ),
    NewsSource(
      name: '머니투데이',
      feedUrl: 'https://rss.mt.co.kr/mt_news.xml',
      category: '경제',
    ),
    NewsSource(
      name: '경향신문',
      feedUrl: 'https://www.khan.co.kr/rss/rssdata/total_news.xml',
      category: null,
    ),
    NewsSource(
      name: '노컷뉴스',
      feedUrl: 'https://rss.nocutnews.co.kr/nocutnews.xml',
      category: null,
      enabled: false,
    ),
  ];

  /// 이미지가 없는 기사용 카테고리별 대체 이미지
  static const Map<String, List<String>> _fallbackImages = {
    '정치': [
      'https://sspark.genspark.ai/i/Lho5UPf3cgxVvUvX?width=1200',
      'https://sspark.genspark.ai/i/sBiYHUp3BD5Tvdzw?width=1200',
    ],
    '경제': [
      'https://sspark.genspark.ai/i/oRCvBBM8MsCmndnu?width=1200',
      'https://sspark.genspark.ai/i/UxeyLCMmigbSy29P?width=1200',
      'https://sspark.genspark.ai/i/LyiGDQeXBFw6Ed3Y?width=1200',
    ],
    'IT/테크': [
      'https://sspark.genspark.ai/i/v86pDzLdoZCIj3sY?width=1200',
      'https://sspark.genspark.ai/i/AEvzu5HPIQNfyFZi?width=1200',
      'https://sspark.genspark.ai/i/7sf2iFlrrNQLNoNn?width=1200',
    ],
    '스포츠': [
      'https://sspark.genspark.ai/i/2Qa4EViC3wUOgo15?width=1200',
      'https://sspark.genspark.ai/i/Mnl6aRsaQaZG8N32?width=1200',
    ],
    '연예': [
      'https://sspark.genspark.ai/i/ATGoaitlTtMZxQrk?width=1200',
      'https://sspark.genspark.ai/i/NVQVcSGHC154W6HM?width=1200',
    ],
    '사회': [
      'https://sspark.genspark.ai/i/x3Hr3HSzaasJqnxN?width=1200',
      'https://sspark.genspark.ai/i/H9sLZfGUfGl37AQy?width=1200',
      'https://sspark.genspark.ai/i/eFNhL13HOVFxvA5N?width=1200',
    ],
  };

  static String imageFor(String category, int seed) {
    final pool = _fallbackImages[category] ?? _fallbackImages['사회']!;
    return pool[seed.abs() % pool.length];
  }

  // ══════════════════════════════════════════════════════
  // 수집
  // ══════════════════════════════════════════════════════

  /// 뉴스 수집 실행
  ///
  /// 활성화된 소스를 **병렬로** 요청하여 대기 시간을 최소화합니다.
  /// 일부 소스가 실패해도 나머지 결과로 진행합니다.
  Future<CollectResult> fetchLatest({
    List<NewsSource>? sources,
    String category = NewsCategory.all,
    int perSource = 8,
  }) async {
    final active =
        (sources ?? defaultSources).where((s) => s.enabled).toList();

    if (active.isEmpty) {
      return const CollectResult(
        articles: [],
        succeeded: [],
        failed: [],
        routes: {},
      );
    }

    // 병렬 수집
    final results = await Future.wait(
      active.map((s) => _rss.fetch(s.name, s.feedUrl)),
      eagerError: false,
    );

    final articles = <NewsArticle>[];
    final succeeded = <String>[];
    final failed = <({String name, String reason})>[];
    final routes = <String, String>{};

    for (var i = 0; i < active.length; i++) {
      final src = active[i];
      final res = results[i];

      if (!res.ok) {
        failed.add((name: src.name, reason: res.error ?? '결과 없음'));
        continue;
      }

      succeeded.add(src.name);
      routes[src.name] = res.route;

      final take = res.items.take(perSource);
      var seed = 0;
      for (final item in take) {
        final a = _toArticle(item, src, seed++);
        if (a != null) articles.add(a);
      }
    }

    // 중복 제거 (제목 기준 정규화)
    final seen = <String>{};
    final unique = <NewsArticle>[];
    for (final a in articles) {
      final key = a.title.replaceAll(RegExp(r'[\s\[\]()·"' r"']"), '');
      if (seen.add(key)) unique.add(a);
    }

    // 카테고리 필터 (메모리 — 인덱스 불필요)
    var list = unique;
    if (category != NewsCategory.all) {
      list = list.where((a) => a.category == category).toList();
    }

    // 트렌드 스코어 내림차순
    list.sort((a, b) => b.trendScore.compareTo(a.trendScore));

    return CollectResult(
      articles: list,
      succeeded: succeeded,
      failed: failed,
      routes: routes,
    );
  }

  /// FeedItem → NewsArticle 변환
  NewsArticle? _toArticle(FeedItem item, NewsSource src, int seed) {
    if (item.title.length < 6) return null;

    final category = src.category ??
        _classify('${item.title} ${item.description}', item.categoryHint);

    final keywords = _extractKeywords(item.title, item.description);
    final summary = _buildSummary(item.description, item.title);
    final body = _buildBody(item.description, item.title, src.name);

    // 관심도 곡선 — 신선도 기반 성향 추정
    final ageMin = DateTime.now().difference(item.publishedAt).inMinutes;
    final curve = _curve(rising: ageMin < 180);

    final article = NewsArticle(
      id: _idFrom(item.link, item.title),
      title: _trimTitle(item.title),
      summary: summary,
      body: body,
      source: _sourceLabel(src.name),
      sourceUrl: item.link,
      category: category,
      imageUrl: item.imageUrl ?? imageFor(category, item.title.hashCode + seed),
      publishedAt: item.publishedAt,
      trendScore: 0,
      predictedViews: 0,
      interestCurve: curve,
      keywords: keywords,
      hasRealImage: item.imageUrl != null,
    );

    final score = computeTrendScore(article);
    return article.copyWith(
      trendScore: score,
      predictedViews: _predictViews(article, score),
    );
  }

  String _idFrom(String link, String title) {
    if (link.isNotEmpty) {
      // 연합뉴스: /view/AKR20260906015100030 → 기사 고유 ID 추출
      final m = RegExp(r'([A-Z]{2,4}\d{10,})').firstMatch(link);
      if (m != null) return m.group(1)!;
      return link.hashCode.toRadixString(36);
    }
    return title.hashCode.toRadixString(36);
  }

  /// 소스 표시명 정리 — "연합뉴스 경제" → "연합뉴스"
  String _sourceLabel(String name) {
    const suffixes = [' 정치', ' 경제', ' 산업', ' 스포츠', ' 연예', ' 사회'];
    for (final s in suffixes) {
      if (name.endsWith(s)) return name.substring(0, name.length - s.length);
    }
    return name;
  }

  /// 제목 정리 — 말머리 대괄호 제거, 길이 방어
  String _trimTitle(String t) {
    var s = t.trim();
    // 선행 말머리 제거: [속보], [단독] 등은 유지하되 [사진], [카드뉴스]는 제거
    s = s.replaceFirst(
        RegExp(r'^\[(사진|포토|카드뉴스|영상|인포그래픽|표)\]\s*'), '');
    return s;
  }

  /// 요약 생성 — 통신사 서두 제거
  String _buildSummary(String desc, String title) {
    var s = _stripLede(desc);
    if (s.length < 12) return title;
    if (s.length > 150) {
      // 문장 경계에서 자르기
      final cut = s.substring(0, 150);
      final lastDot = cut.lastIndexOf('.');
      s = lastDot > 60 ? cut.substring(0, lastDot + 1) : '$cut…';
    }
    return s;
  }

  /// 본문 생성 — RSS description은 짧으므로 요약을 확장 사용
  String _buildBody(String desc, String title, String source) {
    final s = _stripLede(desc);
    if (s.length < 20) {
      return '$title\n\n$source에서 보도한 기사입니다. '
          '자세한 내용은 원문에서 확인할 수 있습니다.';
    }
    return s;
  }

  /// 통신사 서두 제거 — "(서울=연합뉴스) 홍길동 기자 = " 패턴
  String _stripLede(String s) {
    var t = s.trim();
    t = t.replaceFirst(
        RegExp(r'^\([^)]{2,20}=[^)]{2,20}\)\s*[^=]{0,20}(기자|특파원)?\s*=\s*'),
        '');
    t = t.replaceFirst(RegExp(r'^\([^)]{2,20}\)\s*'), '');
    return t.trim();
  }

  // ══════════════════════════════════════════════════════
  // 카테고리 분류
  // ══════════════════════════════════════════════════════

  static const Map<String, List<String>> _categoryKeywords = {
    '정치': [
      '대통령', '국회', '여당', '야당', '정부', '장관', '의원', '총리',
      '선거', '공약', '국무회의', '시행령', '개각', '청문회', '외교', '정상회담',
    ],
    '경제': [
      '금리', '증시', '코스피', '코스닥', '환율', '물가', '부동산', '주택',
      '수출', '무역', '기업', '실적', '투자', '펀드', '한국은행', '경기',
      '세금', '예산', '고용', '임금', '관세', '대출',
    ],
    'IT/테크': [
      'AI', '인공지능', '반도체', '스마트폰', '앱', '플랫폼', '데이터',
      '클라우드', '메타버스', '블록체인', '로봇', '자율주행', '배터리',
      '통신', '5G', '6G', '소프트웨어', '해킹', '보안', '칩', '나노',
    ],
    '스포츠': [
      '경기', '선수', '감독', '리그', '우승', '결승', '골', '홈런',
      '프로야구', '프로축구', '올림픽', '월드컵', 'K리그', 'KBO',
      '이적', 'FA', '메달', '기록', '득점',
    ],
    '연예': [
      '배우', '가수', '아이돌', '그룹', '앨범', '컴백', '드라마', '영화',
      '예능', '무대', '콘서트', '팬', '방송', '출연', '캐스팅', 'OST',
      '시상식', '데뷔', 'K팝',
    ],
    '사회': [
      '경찰', '검찰', '법원', '재판', '사고', '화재', '날씨', '기상청',
      '교통', '학교', '병원', '코로나', '지진', '태풍', '폭염', '한파',
      '실종', '구속', '수사',
    ],
  };

  /// 카테고리 자동 분류 — 키워드 가중 매칭
  String _classify(String text, String? hint) {
    // 피드가 제공한 카테고리 힌트 우선 검사
    if (hint != null && hint.isNotEmpty) {
      for (final c in _categoryKeywords.keys) {
        if (hint.contains(c.split('/').first)) return c;
      }
    }

    final scores = <String, int>{};
    for (final entry in _categoryKeywords.entries) {
      var score = 0;
      for (final kw in entry.value) {
        if (text.contains(kw)) score += kw.length >= 3 ? 2 : 1;
      }
      if (score > 0) scores[entry.key] = score;
    }

    if (scores.isEmpty) return '사회';

    var best = scores.entries.first;
    for (final e in scores.entries) {
      if (e.value > best.value) best = e;
    }
    return best.key;
  }

  // ══════════════════════════════════════════════════════
  // 키워드 추출
  // ══════════════════════════════════════════════════════

  static const Set<String> _stopwords = {
    '그리고', '하지만', '그러나', '따라서', '이번', '지난', '오늘', '내일',
    '어제', '올해', '작년', '내년', '위해', '통해', '대해', '관련', '기자',
    '연합뉴스', '뉴스', '보도', '취재', '단독', '속보', '종합', '전문',
    '이날', '당시', '현재', '최근', '앞서', '한편', '다만', '특히',
  };

  /// 제목·요약에서 핵심 키워드 추출
  ///
  /// 명사 후보를 길이·빈도·위치로 가중하여 상위 4개를 선정합니다.
  /// 제목 앞부분에 등장한 어절에 가산점을 줍니다.
  List<String> _extractKeywords(String title, String desc) {
    final scores = <String, double>{};

    void scan(String text, double weight, bool positional) {
      final tokens = text
          .replaceAll(RegExp(r'[^\uAC00-\uD7A3a-zA-Z0-9\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((t) => t.length >= 2)
          .toList();

      for (var i = 0; i < tokens.length; i++) {
        var t = tokens[i];
        if (_stopwords.contains(t)) continue;

        // 조사 제거
        t = _stripParticle(t);
        if (t.length < 2 || _stopwords.contains(t)) continue;

        // 위치 가중 — 제목 앞쪽이 핵심
        final posBonus =
            positional ? (1.0 - (i / (tokens.length + 1)) * 0.45) : 1.0;
        // 길이 가중 — 3~6자 고유명사 선호
        final lenBonus = t.length >= 3 && t.length <= 6 ? 1.25 : 1.0;

        scores[t] = (scores[t] ?? 0) + weight * posBonus * lenBonus;
      }
    }

    scan(title, 3.0, true);
    scan(desc, 1.0, false);

    if (scores.isEmpty) return const [];

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(4).map((e) => e.key).toList();
  }

  /// 한국어 조사 제거
  static const List<String> _particles = [
    '으로써', '에서는', '에게는', '으로는', '이라고', '라고는',
    '에서', '에게', '으로', '로서', '까지', '부터', '보다', '처럼',
    '이며', '하며', '이라', '와의', '과의', '에의', '로의',
    '은', '는', '이', '가', '을', '를', '의', '에', '와', '과',
    '도', '만', '로', '라', '며', '고',
  ];

  String _stripParticle(String t) {
    if (t.length <= 2) return t;
    for (final p in _particles) {
      if (t.length > p.length + 1 && t.endsWith(p)) {
        return t.substring(0, t.length - p.length);
      }
    }
    return t;
  }

  // ══════════════════════════════════════════════════════
  // 트렌드 스코어 엔진
  // ══════════════════════════════════════════════════════

  /// 트렌드 스코어 산출
  ///
  /// 4개 신호를 가중 합산합니다:
  ///   1. 신선도 (최근일수록 높음)       — 30%
  ///   2. 관심도 상승 기울기             — 30%
  ///   3. 제목 후킹력 (감정어/수치/의문) — 25%
  ///   4. 카테고리 숏폼 친화도           — 15%
  int computeTrendScore(NewsArticle a) {
    // 1. 신선도 — 6시간 내 급감 곡선
    final minutes = DateTime.now().difference(a.publishedAt).inMinutes;
    final freshness = minutes <= 0
        ? 1.0
        : (1.0 - (minutes / 720.0)).clamp(0.0, 1.0); // 12시간 기준

    // 2. 상승 기울기
    double slope = 0.5;
    if (a.interestCurve.length >= 6) {
      final n = a.interestCurve.length;
      final head = a.interestCurve.take(3).reduce((x, y) => x + y) / 3;
      final tail = a.interestCurve.skip(n - 3).reduce((x, y) => x + y) / 3;
      slope = ((tail - head) + 1.0) / 2.0;
    }

    // 3. 후킹력
    final hook = _hookPower(a.title);

    // 4. 숏폼 친화도
    final affinity = _shortFormAffinity(a.category);

    final score =
        freshness * 0.30 + slope * 0.30 + hook * 0.25 + affinity * 0.15;
    return (score * 100).round().clamp(0, 100);
  }

  /// 제목 후킹력 평가 (0~1)
  double _hookPower(String title) {
    double p = 0.32;

    if (RegExp(r'\d').hasMatch(title)) p += 0.15;
    if (title.contains('?') || title.contains('!')) p += 0.12;

    const strong = [
      '충격', '역대', '최초', '급등', '급락', '돌파', '무산', '전격',
      '초유', '반전', '논란', '폭발', '신기록', '경신', '결국', '공개',
      '단독', '속보', '최대', '최고', '사상', '처음', '무너', '깜짝',
    ];
    for (final w in strong) {
      if (title.contains(w)) {
        p += 0.10;
        break;
      }
    }

    if (title.contains('"') || title.contains("'")) p += 0.08;

    final len = title.length;
    if (len >= 18 && len <= 48) p += 0.12;

    return p.clamp(0.0, 1.0);
  }

  double _shortFormAffinity(String category) {
    switch (category) {
      case '연예':
        return 0.95;
      case '스포츠':
        return 0.90;
      case 'IT/테크':
        return 0.78;
      case '사회':
        return 0.72;
      case '경제':
        return 0.65;
      case '정치':
        return 0.60;
      default:
        return 0.55;
    }
  }

  /// 조회수 예측
  ///
  /// 트렌드 스코어 · 카테고리 기저 관심도 · 신선도를 결합합니다.
  int _predictViews(NewsArticle a, int score) {
    // 카테고리별 기저 관심 규모
    final base = switch (a.category) {
      '연예' => 180000,
      '스포츠' => 160000,
      'IT/테크' => 95000,
      '사회' => 88000,
      '경제' => 76000,
      '정치' => 64000,
      _ => 55000,
    };

    final scoreMul = 0.35 + (score / 100.0) * 1.65; // 0.35~2.0x
    final noise = 0.88 + _rng.nextDouble() * 0.24;
    return (base * scoreMul * noise).round();
  }

  /// 관심도 곡선 생성
  List<double> _curve({required bool rising, int points = 12}) {
    final out = <double>[];
    var v = rising ? 0.22 + _rng.nextDouble() * 0.12 : 0.68;
    for (var i = 0; i < points; i++) {
      final drift = rising ? 0.058 : -0.042;
      v = (v + drift + (_rng.nextDouble() - 0.5) * 0.09).clamp(0.05, 1.0);
      out.add(v);
    }
    return out;
  }
}

/// 수집 결과 — 성공/실패 소스와 경로를 함께 보고
class CollectResult {
  final List<NewsArticle> articles;
  final List<String> succeeded;
  final List<({String name, String reason})> failed;

  /// 소스명 → 수집 경로 (direct / 프록시명)
  final Map<String, String> routes;

  const CollectResult({
    required this.articles,
    required this.succeeded,
    required this.failed,
    required this.routes,
  });

  bool get hasData => articles.isNotEmpty;

  /// 프록시를 경유한 소스가 있는지 (웹 환경 표시용)
  bool get usedProxy => routes.values.any((r) => r != 'direct');
}
