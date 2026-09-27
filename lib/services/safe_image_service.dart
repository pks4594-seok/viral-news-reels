import 'dart:math';

import '../models/image_asset.dart';
import '../models/news_article.dart';

/// 저작권 안전 이미지 서비스
///
/// 언론사 RSS가 제공하는 보도사진은 언론사가 저작권을 보유합니다.
/// 이를 영상으로 만들어 유튜브·틱톡·블로그에 올리면 복제권과
/// 공중송신권 침해가 됩니다.
///
/// 이 서비스는 발행용 영상에 쓸 **안전한 이미지**를 공급합니다.
///
/// 선택 우선순위:
///   1. 주제 매칭 AI 배경  — 기사 키워드와 가장 가까운 배경
///   2. 카테고리 AI 배경   — 같은 분야의 배경
///   3. 범용 AI 배경       — 뉴스 일반 배경
///
/// 모든 AI 배경은 실존 인물·상표·판독 가능한 문자를 포함하지 않도록
/// 생성했으며, 9:16 세로 비율에 중앙 자막 공간을 비워 두었습니다.
class SafeImageService {
  SafeImageService._();
  static final SafeImageService instance = SafeImageService._();

  final Random _rng = Random();

  // ══════════════════════════════════════════════════════
  // AI 생성 배경 라이브러리
  // ══════════════════════════════════════════════════════

  /// 카테고리별 AI 배경 (앱에 내장된 로컬 에셋)
  ///
  /// 각 항목은 (에셋 경로, 주제 태그) 쌍입니다. 주제 태그는 기사 키워드와
  /// 매칭해 더 어울리는 배경을 고르는 데 사용합니다.
  ///
  /// 네트워크 이미지가 아닌 로컬 에셋을 쓰는 이유:
  ///   · 오프라인에서도 릴스 제작 가능
  ///   · 외부 URL 만료·차단 위험 없음
  ///   · 로딩 지연 없이 즉시 렌더링
  static const Map<String, List<(String, List<String>)>> _library = {
    '정치': [
      (
        'assets/bg/politics_1.jpg',
        ['국회', '의회', '본회의', '법안', '표결', '정부', '정책', '예산'],
      ),
      (
        'assets/bg/politics_2.jpg',
        ['발표', '회견', '연설', '브리핑', '대통령', '장관', '성명', '담화'],
      ),
    ],
    '경제': [
      (
        'assets/bg/economy_1.jpg',
        ['증시', '코스피', '주가', '금리', '환율', '지수', '투자', '차트', '상승'],
      ),
      (
        'assets/bg/economy_2.jpg',
        ['기업', '부동산', '도시', '건설', '산업', '경기', '무역', '수출'],
      ),
    ],
    'IT/테크': [
      (
        'assets/bg/tech_1.jpg',
        ['반도체', '칩', '나노', '웨이퍼', '공정', '양산', '메모리', '파운드리'],
      ),
      (
        'assets/bg/tech_2.jpg',
        ['AI', '인공지능', '데이터', '알고리즘', '모델', '학습', '클라우드', '플랫폼'],
      ),
    ],
    '스포츠': [
      (
        'assets/bg/sports_1.jpg',
        ['경기', '축구', '야구', '구장', '리그', '우승', '결승', '관중', '골'],
      ),
      (
        'assets/bg/sports_2.jpg',
        ['기록', '육상', '선수', '훈련', '메달', '올림픽', '신기록', 'FA'],
      ),
    ],
    '연예': [
      (
        'assets/bg/entertain_1.jpg',
        ['무대', '콘서트', '공연', '아이돌', '컴백', '앨범', '팬', 'K팝'],
      ),
      (
        'assets/bg/entertain_2.jpg',
        ['시상식', '수상', '트로피', '영화', '드라마', '배우', '흥행', '관객'],
      ),
    ],
    '사회': [
      (
        'assets/bg/society_1.jpg',
        ['도시', '거리', '날씨', '교통', '시민', '생활', '비', '눈', '폭염'],
      ),
      (
        'assets/bg/society_2.jpg',
        ['법원', '재판', '검찰', '경찰', '수사', '판결', '구속', '선고', '기소'],
      ),
    ],
  };

  /// 범용 배경 — 카테고리 매칭이 없을 때
  static const List<(String, List<String>)> _universal = [
    (
      'assets/bg/universal_breaking.jpg',
      ['속보', '긴급', '단독', '뉴스룸', '보도', '발표'],
    ),
    (
      'assets/bg/universal_data.jpg',
      ['데이터', '분석', '통계', '추이', '네트워크', '조사'],
    ),
    (
      'assets/bg/universal_global.jpg',
      ['국제', '세계', '글로벌', '해외', '외교', '정상회담'],
    ),
  ];

  /// 전체 안전 이미지 개수
  int get libraryCount =>
      _library.values.fold<int>(0, (s, v) => s + v.length) +
      _universal.length;

  /// 카테고리 목록
  List<String> get categories => _library.keys.toList();

  // ══════════════════════════════════════════════════════
  // 선택 로직
  // ══════════════════════════════════════════════════════

  /// 기사에 가장 어울리는 안전 배경을 선택합니다.
  ///
  /// [sceneIndex]를 주면 같은 기사 안에서도 씬마다 다른 배경을
  /// 고르도록 순환시켜 영상이 단조로워지지 않게 합니다.
  ImageAsset pickFor(NewsArticle article, {int sceneIndex = 0}) {
    final pool = <(String, List<String>)>[
      ...(_library[article.category] ?? const []),
      ..._universal,
    ];

    if (pool.isEmpty) {
      return const ImageAsset(
        url: '',
        kind: ImageSourceKind.generatedGradient,
        topic: '기본 배경',
      );
    }

    // 키워드 매칭 점수 계산
    final haystack = '${article.title} ${article.summary} '
        '${article.keywords.join(' ')}';

    final scored = <({int score, String url, String topic})>[];
    for (final (url, tags) in pool) {
      var score = 0;
      for (final tag in tags) {
        if (haystack.contains(tag)) score += tag.length >= 3 ? 3 : 2;
      }
      scored.add((score: score, url: url, topic: tags.first));
    }

    // 점수 내림차순 정렬 (동점이면 원래 순서 유지)
    scored.sort((a, b) => b.score.compareTo(a.score));

    // 상위 후보 중에서 씬 인덱스로 순환 선택
    //   → 같은 기사의 여러 씬이 서로 다른 배경을 갖게 됩니다.
    final topCount = scored.where((s) => s.score > 0).length;
    final candidates = topCount >= 2
        ? scored.take(topCount).toList()
        : scored.take(min(3, scored.length)).toList();

    final chosen = candidates[sceneIndex % candidates.length];

    return ImageAsset(
      url: chosen.url,
      kind: ImageSourceKind.aiGenerated,
      topic: chosen.topic,
    );
  }

  /// 카테고리만으로 배경 선택 (기사 정보가 없을 때)
  ImageAsset pickForCategory(String category, {int index = 0}) {
    final pool = _library[category] ?? _universal;
    final (url, tags) = pool[index.abs() % pool.length];
    return ImageAsset(
      url: url,
      kind: ImageSourceKind.aiGenerated,
      topic: tags.first,
    );
  }

  /// 무작위 안전 배경
  ImageAsset pickRandom() {
    final all = <(String, List<String>)>[
      for (final v in _library.values) ...v,
      ..._universal,
    ];
    final (url, tags) = all[_rng.nextInt(all.length)];
    return ImageAsset(
      url: url,
      kind: ImageSourceKind.aiGenerated,
      topic: tags.first,
    );
  }

  /// 기사 원본 이미지를 ImageAsset으로 감싸기
  ///
  /// 언론사가 제공한 사진인지, 앱이 채운 대체 이미지인지 구분합니다.
  ImageAsset wrapArticleImage(NewsArticle article) {
    if (article.hasRealImage && article.imageUrl.isNotEmpty) {
      return ImageAsset(
        url: article.imageUrl,
        kind: ImageSourceKind.pressPhoto,
        attribution: article.source,
      );
    }
    // hasRealImage가 false면 이미 앱이 채운 AI 배경입니다.
    return ImageAsset(
      url: article.imageUrl,
      kind: ImageSourceKind.aiGenerated,
      topic: article.category,
    );
  }

  /// 정책에 따라 표시할 이미지를 결정합니다.
  ///
  /// [forPublish]가 true면 발행용 영상에 들어갈 이미지를 고릅니다.
  /// 이 경우 정책이 [ImagePolicy.allowPress]가 아닌 한 언론사 사진은
  /// 반드시 안전 배경으로 대체됩니다.
  ImageAsset resolve(
    NewsArticle article, {
    required ImagePolicy policy,
    required bool forPublish,
    int sceneIndex = 0,
  }) {
    final original = wrapArticleImage(article);

    // 원본이 이미 안전하면 그대로 사용
    if (original.isPublishSafe) return original;

    // 발행용 — 정책이 허용하지 않으면 무조건 대체
    if (forPublish) {
      if (policy.allowsPressInPublish) return original;
      return pickFor(article, sceneIndex: sceneIndex);
    }

    // 미리보기용 — 정책에 따라
    if (policy.showsPressInPreview) return original;
    return pickFor(article, sceneIndex: sceneIndex);
  }

  /// 릴스 전체 씬에 쓸 안전 이미지 목록을 만듭니다.
  ///
  /// 씬 수만큼 서로 다른 배경을 배정해 단조로움을 피합니다.
  List<ImageAsset> buildSceneImages(
    NewsArticle article,
    int sceneCount, {
    required ImagePolicy policy,
  }) {
    // 원본 사진을 그대로 쓰는 정책이면 첫 씬만 원본, 나머지는 안전 배경
    //   (같은 사진을 반복하면 영상이 지루하므로)
    final useOriginalFirst =
        policy.allowsPressInPublish && article.hasRealImage;

    return List.generate(sceneCount, (i) {
      if (useOriginalFirst && i == 0) {
        return wrapArticleImage(article);
      }
      return pickFor(article, sceneIndex: i);
    });
  }
}
