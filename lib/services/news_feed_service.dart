import 'dart:math';

import '../models/news_article.dart';

/// 뉴스 수집 서비스
///
/// 실제 운영 시 [fetchFromRss]가 포털/신문사 RSS를 파싱합니다.
/// 웹 프리뷰 환경에서는 CORS 제약으로 RSS 직접 호출이 차단되므로,
/// 동일한 파이프라인을 통과하는 시드 데이터로 동작을 재현합니다.
class NewsFeedService {
  NewsFeedService._();
  static final NewsFeedService instance = NewsFeedService._();

  final Random _rng = Random(42);

  /// 등록된 뉴스 소스 목록 (포털 + 신문사 RSS)
  static const List<NewsSource> defaultSources = [
    NewsSource(name: '연합뉴스', feedUrl: 'https://www.yna.co.kr/rss/news.xml'),
    NewsSource(name: '조선일보', feedUrl: 'https://www.chosun.com/arc/outboundfeeds/rss/'),
    NewsSource(name: '중앙일보', feedUrl: 'https://rss.joins.com/joins_news_list.xml'),
    NewsSource(name: '한겨레', feedUrl: 'https://www.hani.co.kr/rss/'),
    NewsSource(name: '매일경제', feedUrl: 'https://www.mk.co.kr/rss/30000001/'),
    NewsSource(name: '전자신문', feedUrl: 'https://rss.etnews.com/Section901.xml'),
    NewsSource(name: 'ZDNet Korea', feedUrl: 'https://feeds.feedburner.com/zdkorea'),
    NewsSource(name: 'SBS 뉴스', feedUrl: 'https://news.sbs.co.kr/news/RssFeed.do'),
  ];

  /// 뉴스 이미지 풀 — 카테고리별 매핑
  static const Map<String, List<String>> _imagePool = {
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
    final pool = _imagePool[category] ?? _imagePool['사회']!;
    return pool[seed % pool.length];
  }

  /// 뉴스 수집 실행
  ///
  /// [sources] 활성화된 소스만 수집합니다.
  Future<List<NewsArticle>> fetchLatest({
    List<NewsSource>? sources,
    String category = NewsCategory.all,
  }) async {
    // 실제 네트워크 수집 지연 재현
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final enabled = (sources ?? defaultSources)
        .where((s) => s.enabled)
        .map((s) => s.name)
        .toSet();

    var list = _seedArticles()
        .where((a) => enabled.isEmpty || enabled.contains(a.source))
        .toList();

    if (category != NewsCategory.all) {
      list = list.where((a) => a.category == category).toList();
    }

    // 트렌드 스코어 재계산 (수집 시점 기준)
    list = list.map((a) => a.copyWith(trendScore: computeTrendScore(a))).toList();

    // 스코어 내림차순 정렬 (인덱스 없이 메모리 정렬)
    list.sort((a, b) => b.trendScore.compareTo(a.trendScore));
    return list;
  }

  /// RSS 파싱 (실 운영 진입점)
  ///
  /// 웹 프리뷰에서는 CORS로 차단되므로 프록시 또는 서버 사이드 수집이 필요합니다.
  /// Android 빌드에서는 직접 호출이 동작합니다.
  Future<List<NewsArticle>> fetchFromRss(NewsSource source) async {
    // 구현 지점: http.get(Uri.parse(source.feedUrl)) → XML 파싱 → NewsArticle 매핑
    // 현재는 시드 데이터 경로로 위임합니다.
    return fetchLatest(sources: [source]);
  }

  /// 트렌드 스코어 산출 엔진
  ///
  /// 4개 신호를 가중 합산합니다:
  ///   1. 신선도 (최근일수록 높음)      — 30%
  ///   2. 관심도 상승 기울기            — 30%
  ///   3. 제목 후킹력 (감정어/수치/의문) — 25%
  ///   4. 카테고리 숏폼 친화도          — 15%
  int computeTrendScore(NewsArticle a) {
    // 1. 신선도
    final hours = DateTime.now().difference(a.publishedAt).inMinutes / 60.0;
    final freshness = (1.0 - (hours / 24.0)).clamp(0.0, 1.0);

    // 2. 상승 기울기 — 후반 3점 평균 vs 전반 3점 평균
    double slope = 0.5;
    if (a.interestCurve.length >= 6) {
      final n = a.interestCurve.length;
      final head = a.interestCurve.take(3).reduce((x, y) => x + y) / 3;
      final tail = a.interestCurve.skip(n - 3).reduce((x, y) => x + y) / 3;
      slope = ((tail - head) + 1.0) / 2.0; // -1~1 → 0~1
    }

    // 3. 후킹력
    final hook = _hookPower(a.title);

    // 4. 숏폼 친화도
    final affinity = _shortFormAffinity(a.category);

    final score = freshness * 0.30 + slope * 0.30 + hook * 0.25 + affinity * 0.15;
    return (score * 100).round().clamp(0, 100);
  }

  /// 제목 후킹력 평가 (0~1)
  double _hookPower(String title) {
    double p = 0.35;

    // 수치 포함 — 구체성
    if (RegExp(r'\d').hasMatch(title)) p += 0.15;
    // 의문/감탄 — 호기심 유발
    if (title.contains('?') || title.contains('!')) p += 0.12;
    // 감정 강도어
    const strong = [
      '충격', '역대', '최초', '급등', '급락', '돌파', '무산', '전격',
      '초유', '반전', '논란', '폭발', '신기록', '경신', '결국', '공개',
    ];
    for (final w in strong) {
      if (title.contains(w)) {
        p += 0.10;
        break;
      }
    }
    // 인용/따옴표 — 발언 인용은 클릭률 높음
    if (title.contains('"') || title.contains('\'')) p += 0.08;
    // 적정 길이 (숏폼 자막에 맞는 20~45자)
    final len = title.length;
    if (len >= 18 && len <= 48) p += 0.12;

    return p.clamp(0.0, 1.0);
  }

  /// 카테고리별 숏폼 친화도
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

  /// 관심도 곡선 생성 (상승/하강 성향 반영)
  List<double> _curve({required bool rising, int points = 12}) {
    final base = <double>[];
    var v = rising ? 0.25 : 0.75;
    for (var i = 0; i < points; i++) {
      final drift = rising ? 0.055 : -0.045;
      v = (v + drift + (_rng.nextDouble() - 0.5) * 0.09).clamp(0.05, 1.0);
      base.add(v);
    }
    return base;
  }

  /// 시드 뉴스 — 실제 뉴스 구조를 그대로 따르는 샘플
  List<NewsArticle> _seedArticles() {
    final now = DateTime.now();
    var i = 0;

    NewsArticle mk({
      required String title,
      required String summary,
      required String body,
      required String source,
      required String category,
      required int minutesAgo,
      required int views,
      required bool rising,
      required List<String> keywords,
    }) {
      final idx = i++;
      return NewsArticle(
        id: 'news_${idx.toString().padLeft(3, '0')}',
        title: title,
        summary: summary,
        body: body,
        source: source,
        // 실제 RSS 연동 시 <link> 항목의 원문 URL이 들어갑니다.
        // 시드 데이터에는 실제 기사 URL이 없으므로 비워 둡니다.
        sourceUrl: '',
        category: category,
        imageUrl: imageFor(category, idx),
        publishedAt: now.subtract(Duration(minutes: minutesAgo)),
        trendScore: 0, // computeTrendScore로 채워짐
        predictedViews: views,
        interestCurve: _curve(rising: rising),
        keywords: keywords,
      );
    }

    return [
      mk(
        title: '한국은행 기준금리 0.25%p 전격 인하… 3년 만의 완화 전환',
        summary:
            '한국은행 금융통화위원회가 기준금리를 연 2.75%로 0.25%포인트 인하했다. 시장 예상을 앞선 결정으로 증시가 즉각 반응했다.',
        body:
            '한국은행 금융통화위원회는 오늘 통화정책방향 회의에서 기준금리를 연 3.00%에서 2.75%로 0.25%포인트 인하하기로 결정했다. '
            '이는 2022년 이후 처음 있는 완화 전환으로, 내수 부진과 물가 안정세를 반영한 조치로 해석된다. '
            '발표 직후 코스피는 1.8% 상승 마감했으며, 원/달러 환율은 8원 하락했다. '
            '금통위는 "물가 상승률이 목표 수준에 근접했고 성장 하방 위험이 커졌다"고 배경을 설명했다. '
            '시장에서는 연내 추가 인하 가능성도 거론되고 있다.',
        source: '매일경제',
        category: '경제',
        minutesAgo: 14,
        views: 184000,
        rising: true,
        keywords: ['기준금리', '한국은행', '금리인하', '코스피'],
      ),
      mk(
        title: '국내 첫 2나노 AI 반도체 양산 개시… "글로벌 판도 흔든다"',
        summary:
            '2나노 공정 AI 가속기 칩이 국내 최초로 양산에 들어갔다. 전력 효율이 이전 세대 대비 40% 개선됐다.',
        body:
            '차세대 2나노 공정을 적용한 AI 가속기 칩 양산이 국내에서 처음으로 시작됐다. '
            '해당 칩은 이전 세대 3나노 제품 대비 전력 효율이 약 40% 개선되고, 연산 성능은 1.6배 향상된 것으로 알려졌다. '
            '데이터센터용 대형 고객사와의 공급 계약도 병행 논의 중이다. '
            '업계는 이번 양산이 글로벌 AI 반도체 공급망에서 국내 기업의 위상을 끌어올릴 분기점이 될 것으로 본다. '
            '다만 수율 안정화까지는 수개월이 더 필요하다는 신중론도 함께 나온다.',
        source: '전자신문',
        category: 'IT/테크',
        minutesAgo: 38,
        views: 226000,
        rising: true,
        keywords: ['2나노', 'AI반도체', '반도체', '양산'],
      ),
      mk(
        title: '손흥민 후반 91분 역전 결승골… 원정 3연패 사슬 끊었다',
        summary:
            '경기 종료 직전 터진 극장골로 팀이 2-1 역전승을 거뒀다. 시즌 12호 골이다.',
        body:
            '후반 추가시간 1분, 페널티 박스 왼쪽에서 감아 올린 슈팅이 골망 상단을 갈랐다. '
            '0-1로 뒤지던 팀은 후반 78분 동점골에 이어 극적인 역전골로 원정 3연패를 끊었다. '
            '이날 골로 시즌 12호 골을 기록하며 득점 순위 공동 4위로 올라섰다. '
            '경기 후 인터뷰에서 그는 "마지막 1초까지 포기하지 않은 동료들 덕분"이라고 말했다. '
            '중계 화면에 잡힌 벤치의 환호 장면은 SNS에서 빠르게 확산되고 있다.',
        source: 'SBS 뉴스',
        category: '스포츠',
        minutesAgo: 52,
        views: 412000,
        rising: true,
        keywords: ['손흥민', '결승골', '역전승', '추가시간'],
      ),
      mk(
        title: '"AI 저작권 가이드라인" 국무회의 통과… 내년 3월 시행',
        summary:
            '생성형 AI 학습 데이터의 저작권 처리 기준을 담은 시행령이 국무회의를 통과했다.',
        body:
            '생성형 AI의 학습 데이터 활용 범위와 저작권자 보상 체계를 규정한 시행령 개정안이 국무회의를 통과했다. '
            '개정안은 상업적 목적의 대규모 학습에 대해 사전 고지 의무와 옵트아웃 절차를 명시했다. '
            '창작자 단체는 "최소한의 방어선이 마련됐다"며 환영했으나, 산업계는 "국내 AI 경쟁력 위축" 우려를 제기했다. '
            '시행은 내년 3월 1일부터이며, 6개월간의 유예 기간이 부여된다.',
        source: '연합뉴스',
        category: '정치',
        minutesAgo: 76,
        views: 98000,
        rising: true,
        keywords: ['AI저작권', '국무회의', '시행령', '생성형AI'],
      ),
      mk(
        title: '역대 최대 규모 K-팝 합작 무대 확정… 7개 그룹 한자리',
        summary:
            '연말 시상식에서 7개 그룹이 참여하는 합작 스테이지가 공식 확정됐다.',
        body:
            '연말 시상식 무대에서 7개 그룹이 함께 오르는 합작 스테이지가 공식 확정됐다. '
            '기획사 간 협의가 3개월간 진행됐으며, 무대 구성은 4개 파트 12분 분량으로 알려졌다. '
            '티켓 예매 서버는 오픈 3분 만에 전량 매진됐고, 리셀 시장에서는 정가의 5배 이상 호가가 형성됐다. '
            '해외 팬덤의 실시간 스트리밍 요청도 폭증하고 있어 글로벌 동시 송출이 검토 중이다.',
        source: '중앙일보',
        category: '연예',
        minutesAgo: 105,
        views: 356000,
        rising: true,
        keywords: ['K팝', '합작무대', '시상식', '매진'],
      ),
      mk(
        title: '전국 첫눈 관측… 수도권 대설주의보, 출근길 교통 혼잡',
        summary:
            '올가을 첫 대설주의보가 수도권에 발효됐다. 시간당 3cm 이상 눈이 쌓였다.',
        body:
            '기상청은 오늘 새벽 수도권에 대설주의보를 발효했다. '
            '시간당 3cm 이상의 강한 눈이 내려 주요 간선도로 정체가 평시 대비 2배 이상 길어졌다. '
            '지하철은 일부 지상 구간에서 서행 운행 중이며, 항공편 12편이 결항됐다. '
            '기상청은 "오후까지 5~15cm의 추가 적설이 예상된다"며 대중교통 이용을 권고했다.',
        source: '한겨레',
        category: '사회',
        minutesAgo: 130,
        views: 145000,
        rising: false,
        keywords: ['첫눈', '대설주의보', '교통혼잡', '기상청'],
      ),
      mk(
        title: '코스피 사상 첫 4000선 돌파… 외국인 7조 순매수',
        summary:
            '코스피가 장중 4000선을 처음으로 넘어섰다. 외국인 자금이 7조원 유입됐다.',
        body:
            '코스피 지수가 장중 4012.6포인트까지 오르며 사상 처음으로 4000선을 돌파했다. '
            '이달 들어 외국인 순매수 규모는 7조1000억원으로 월간 기준 최대치를 기록했다. '
            '반도체와 2차전지 대형주가 지수 상승을 주도했으며, 시가총액 상위 10개 종목 중 8개가 상승 마감했다. '
            '증권가는 목표 지수를 상향 조정하면서도 "단기 과열 구간"이라는 경계 신호를 함께 내놓았다.',
        source: '조선일보',
        category: '경제',
        minutesAgo: 160,
        views: 268000,
        rising: true,
        keywords: ['코스피', '4000선', '외국인순매수', '사상최고'],
      ),
      mk(
        title: '온디바이스 AI 탑재 스마트폰 공개… 통신 없이 실시간 통역',
        summary:
            '네트워크 연결 없이 12개 언어 실시간 통역이 가능한 온디바이스 AI 폰이 공개됐다.',
        body:
            '통신 연결 없이도 12개 언어의 실시간 통역과 문서 요약이 가능한 온디바이스 AI 스마트폰이 공개됐다. '
            '전용 NPU가 초당 45조회 연산을 처리하며, 모든 처리가 기기 내에서 완결돼 데이터가 외부로 전송되지 않는다. '
            '개인정보 보호 측면에서 의미 있는 진전이라는 평가가 나온다. '
            '출고가는 전작보다 12만원 인상됐으며, 사전 예약은 다음 주 시작된다.',
        source: 'ZDNet Korea',
        category: 'IT/테크',
        minutesAgo: 195,
        views: 172000,
        rising: false,
        keywords: ['온디바이스AI', '실시간통역', 'NPU', '스마트폰'],
      ),
      mk(
        title: '프로야구 FA 최대어, 4년 180억 계약… 리그 최고액 경신',
        summary:
            'FA 시장 최대어가 4년 총액 180억원에 계약하며 역대 최고액 기록을 새로 썼다.',
        body:
            'FA 시장 최대어로 꼽혔던 선수가 4년 총액 180억원 조건으로 계약을 마쳤다. '
            '보장 금액 150억원에 옵션 30억원 구조로, 기존 리그 최고액을 22억원 경신했다. '
            '해당 구단은 지난 시즌 마운드 붕괴가 최대 약점으로 지목돼 왔다. '
            '전문가들은 "단기 전력 상승은 확실하지만 샐러리 구조 경직 위험도 함께 안았다"고 분석했다.',
        source: '연합뉴스',
        category: '스포츠',
        minutesAgo: 240,
        views: 134000,
        rising: false,
        keywords: ['FA계약', '프로야구', '최고액', '180억'],
      ),
      mk(
        title: '여야 예산안 합의 무산… 준예산 편성 초읽기',
        summary:
            '내년도 예산안 협상이 최종 결렬됐다. 준예산 체제 돌입 가능성이 커졌다.',
        body:
            '내년도 예산안을 둘러싼 여야 협상이 법정 처리 기한을 넘기며 최종 결렬됐다. '
            '쟁점은 지역화폐 예산과 연구개발 예산 증액 규모로, 양측 격차는 4조원대에서 좁혀지지 않았다. '
            '준예산이 편성되면 신규 사업 집행이 전면 중단되고 기존 사업도 전년 수준으로 묶인다. '
            '정부는 "국민 생활에 직접적 차질이 우려된다"며 조속한 처리를 촉구했다.',
        source: '중앙일보',
        category: '정치',
        minutesAgo: 300,
        views: 87000,
        rising: false,
        keywords: ['예산안', '준예산', '여야협상', '결렬'],
      ),
      mk(
        title: '천만 관객 돌파 영화 감독, 차기작 전격 공개… "AI와 인간"',
        summary:
            '천만 관객을 기록한 감독이 차기작 제작 소식을 공개했다. AI를 소재로 한다.',
        body:
            '올해 천만 관객을 돌파한 작품의 감독이 차기작 제작 소식을 공개했다. '
            '차기작은 인간과 AI의 공존을 다루는 SF 드라마로, 제작비 규모는 약 420억원으로 알려졌다. '
            '주연 배우 캐스팅 논의가 마무리 단계이며, 내년 상반기 촬영 시작이 목표다. '
            '해외 스트리밍 플랫폼 3곳이 이미 판권 확보 경쟁에 뛰어든 상태다.',
        source: '조선일보',
        category: '연예',
        minutesAgo: 355,
        views: 119000,
        rising: false,
        keywords: ['천만관객', '차기작', 'SF드라마', '캐스팅'],
      ),
      mk(
        title: '전세사기 특별법 개정… 피해 구제 범위 2배 확대',
        summary:
            '전세사기 피해자 구제 범위를 대폭 확대하는 특별법 개정안이 시행된다.',
        body:
            '전세사기 피해자 구제 범위를 기존의 2배 수준으로 확대하는 특별법 개정안이 시행에 들어갔다. '
            '보증금 한도가 5억원으로 상향되고, 우선매수권 행사 기간도 6개월 연장됐다. '
            '피해자 단체는 "실질적 구제에 한 걸음 다가섰다"고 평가했다. '
            '국토부는 전담 창구를 전국 17개 시도로 확대 운영한다고 밝혔다.',
        source: '한겨레',
        category: '사회',
        minutesAgo: 420,
        views: 76000,
        rising: false,
        keywords: ['전세사기', '특별법', '피해구제', '우선매수권'],
      ),
    ];
  }
}
