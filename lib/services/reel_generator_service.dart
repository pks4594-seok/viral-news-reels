import 'dart:math';

import '../models/news_article.dart';
import '../models/reel_project.dart';
import '../models/upload_task.dart';
import '../models/viral_pattern.dart';
import 'viral_learning_service.dart';

/// 릴스 생성 엔진
///
/// 뉴스 기사 + 학습된 바이럴 공식 → 릴스 프로젝트로 변환합니다.
///
/// 생성 파이프라인:
///   1. 공식 매칭        — 카테고리·신선도 기반 최적 공식 선택
///   2. 후킹 제목 생성    — 공식 템플릿 + 핵심 키워드 결합
///   3. 자막 스크립트 생성 — 본문을 컷 단위로 분해, 타임코드 부여
///   4. 씬 구성          — 이미지 + 카메라 무브 배치
///   5. 메타데이터 생성   — 설명, 해시태그, 플랫폼별 최적화
class ReelGeneratorService {
  ReelGeneratorService._();
  static final ReelGeneratorService instance = ReelGeneratorService._();

  final Random _rng = Random();
  final _learning = ViralLearningService.instance;

  static const List<String> _motions = [
    '줌 인',
    '줌 아웃',
    '좌→우 팬',
    '상→하 슬라이드',
    '켄번스',
    '고정 + 자막',
  ];

  static const List<String> _bgmPool = [
    'Impact Rise (긴장 상승)',
    'Neon Pulse (빠른 비트)',
    'Breaking Signal (속보 톤)',
    'Cinematic Drop (임팩트)',
    'Chill News (차분한 톤)',
  ];

  static const List<String> _voicePool = [
    '차분한 여성 아나운서',
    '신뢰감 있는 남성 앵커',
    '에너제틱 여성 크리에이터',
    '빠른 템포 남성 내레이터',
  ];

  /// 릴스 생성 — 뉴스 1건 → ReelProject 1건
  Future<ReelProject> generate(NewsArticle article) async {
    final formula = _learning.bestFormulaFor(article);

    final keyword = article.keywords.isNotEmpty
        ? article.keywords.first
        : article.title.split(' ').first;

    final hookTitle = _buildHookTitle(article, formula, keyword);
    final captions = _buildCaptions(article, formula);
    final scenes = _buildScenes(article, formula, captions);
    final hashtags = _buildHashtags(article, formula);
    final description = _buildDescription(article, formula);
    final viralScore = _computeViralScore(article, formula);
    final predicted = _predictViews(article, formula, viralScore);

    return ReelProject(
      id: 'reel_${DateTime.now().millisecondsSinceEpoch}',
      article: article,
      hookTitle: hookTitle,
      description: description,
      hashtags: hashtags,
      captions: captions,
      scenes: scenes,
      formulaName: formula.name,
      stage: ReelBuildStage.script,
      stageProgress: 0.0,
      durationSec: formula.recommendedDuration,
      predictedViews: predicted,
      viralScore: viralScore,
      bgm: _bgmPool[article.category.hashCode.abs() % _bgmPool.length],
      voiceName: _voicePool[article.id.hashCode.abs() % _voicePool.length],
      createdAt: DateTime.now(),
    );
  }

  /// 후킹 제목 생성
  ///
  /// 공식 템플릿에 키워드를 주입하고, 플랫폼 제목 길이(40자 내외)에 맞춰 다듬습니다.
  String _buildHookTitle(
      NewsArticle article, ViralFormula formula, String keyword) {
    var hook = formula.applyHook(article.title, keyword);

    // 수치가 있으면 제목에 끌어올림 (숫자 충격형 강화)
    final numMatch = RegExp(r'([\d.,]+\s*(%p|%|조|억|만원|만|포인트|나노|년|배|선))')
        .firstMatch(article.title);
    if (numMatch != null && !hook.contains(numMatch.group(1)!)) {
      hook = '$hook — ${numMatch.group(1)!}';
    }

    // 제목 길이 방어 (숏폼 자막 가독 한계)
    if (hook.length > 46) {
      hook = '${hook.substring(0, 44)}…';
    }
    return hook;
  }

  /// 자막 스크립트 생성
  ///
  /// 본문을 문장 단위로 쪼개고 공식의 권장 컷 수에 맞춰 배분,
  /// 각 컷에 타임코드를 부여합니다. 첫 컷은 항상 후킹 자막입니다.
  List<CaptionLine> _buildCaptions(NewsArticle article, ViralFormula formula) {
    final sentences = article.body
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length > 6)
        .toList();

    final keyword = article.keywords.isNotEmpty
        ? article.keywords.first
        : article.category;

    // 컷 목록 구성: 후킹 → 핵심 문장들 → 마무리 CTA
    final lines = <String>[];
    lines.add(_hookCaption(formula, keyword));

    // 요약을 두 번째 컷으로 (핵심 먼저)
    lines.add(_compress(article.summary, 34));

    for (final s in sentences) {
      if (lines.length >= formula.recommendedCuts - 1) break;
      lines.add(_compress(s, 32));
    }

    lines.add(_ctaCaption(formula));

    // 타임코드 배분 — 후킹은 짧고 강하게, 뒤로 갈수록 균등
    final total = formula.recommendedDuration.toDouble();
    final count = lines.length;
    final hookDur = min(2.2, total * 0.09);
    final rest = total - hookDur;
    final per = rest / (count - 1);

    final captions = <CaptionLine>[];
    var t = 0.0;
    for (var i = 0; i < count; i++) {
      final dur = i == 0 ? hookDur : per;
      captions.add(CaptionLine(
        startSec: double.parse(t.toStringAsFixed(1)),
        endSec: double.parse((t + dur).toStringAsFixed(1)),
        text: lines[i],
        emphasis: i == 0 || i == count - 1 || _containsNumber(lines[i]),
      ));
      t += dur;
    }
    return captions;
  }

  String _hookCaption(ViralFormula formula, String keyword) {
    switch (formula.name) {
      case '속보 임팩트형':
        return '🚨 방금 들어온 소식';
      case '숫자 충격형':
        return '이 숫자, 진짜입니다';
      case '감탄 리액션형':
        return '이 장면 보고 가세요';
      case '결론 선행형':
        return '결론부터 말합니다';
      case '의문 유발형':
        return '왜 갑자기 이런 일이?';
      default:
        return keyword;
    }
  }

  String _ctaCaption(ViralFormula formula) {
    switch (formula.name) {
      case '감탄 리액션형':
        return '다시 보고 싶다면 저장 👆';
      case '결론 선행형':
        return '자세한 내용은 프로필 링크';
      case '의문 유발형':
        return '당신 생각은? 댓글로 👇';
      default:
        return '더 빠른 소식은 팔로우 👆';
    }
  }

  /// 자막 압축 — 숏폼 가독 한계(한 줄 기준)에 맞춰 다듬기
  String _compress(String text, int maxLen) {
    var t = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('것으로 알려졌다', '으로 확인')
        .replaceAll('것으로 보인다', '전망')
        .replaceAll('라고 밝혔다', '"')
        .replaceAll('라고 말했다', '"')
        .replaceAll('하기로 결정했다', '결정')
        .replaceAll('들어갔다', '시작')
        .trim();

    if (t.length <= maxLen) return t;

    // 어절 경계에서 자르기
    final words = t.split(' ');
    final buf = StringBuffer();
    for (final w in words) {
      if (buf.length + w.length + 1 > maxLen) break;
      if (buf.isNotEmpty) buf.write(' ');
      buf.write(w);
    }
    final result = buf.toString();
    return result.isEmpty ? t.substring(0, maxLen) : result;
  }

  bool _containsNumber(String s) => RegExp(r'\d').hasMatch(s);

  /// 씬 구성 — 컷별 이미지 + 카메라 무브
  List<ReelScene> _buildScenes(
    NewsArticle article,
    ViralFormula formula,
    List<CaptionLine> captions,
  ) {
    final sceneCount = min(captions.length, formula.recommendedCuts);
    return List.generate(sceneCount, (i) {
      final cap = captions[i];
      return ReelScene(
        index: i,
        imageUrl: NewsFeedImages.forCategory(article.category, i),
        motion: i == 0 ? '줌 인' : _motions[(i * 3 + 1) % _motions.length],
        durationSec: double.parse((cap.endSec - cap.startSec).toStringAsFixed(1)),
        narration: cap.text,
      );
    });
  }

  /// 해시태그 생성 — 뉴스 키워드 + 카테고리 + 플랫폼 관행 태그
  List<String> _buildHashtags(NewsArticle article, ViralFormula formula) {
    final tags = <String>{};
    for (final k in article.keywords.take(4)) {
      tags.add(k.replaceAll(' ', ''));
    }
    tags.add(article.category.replaceAll('/', ''));
    tags.add('뉴스');
    tags.add('속보');
    tags.add('shorts');
    tags.add('오늘의뉴스');

    if (formula.name == '감탄 리액션형') tags.add('하이라이트');
    if (formula.name == '숫자 충격형') tags.add('데이터');

    return tags.take(10).toList();
  }

  /// 설명문 / 블로그 본문 생성
  String _buildDescription(NewsArticle article, ViralFormula formula) {
    final b = StringBuffer();
    b.writeln('📌 ${article.title}');
    b.writeln();
    b.writeln(article.summary);
    b.writeln();
    b.writeln('━━━━━━━━━━━━━━');
    b.writeln('🔎 핵심 포인트');
    final sentences = article.body
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length > 10)
        .take(3);
    for (final s in sentences) {
      b.writeln('· $s');
    }
    b.writeln('━━━━━━━━━━━━━━');
    b.writeln();
    b.writeln('📰 출처: ${article.source}');
    b.writeln('🕐 보도: ${article.relativeTime}');
    b.writeln('🎬 편집 공식: ${formula.name}');
    return b.toString();
  }

  /// 바이럴 적합도 점수
  ///
  /// 뉴스의 트렌드 스코어와 공식의 학습 신뢰도·유지율을 결합합니다.
  int _computeViralScore(NewsArticle article, ViralFormula formula) {
    final trend = article.trendScore / 100.0;
    final conf = formula.confidence;
    final ret = formula.avgRetention;

    // 길이 적정성 — 짧을수록 완주율 유리 (20~35초 최적)
    final d = formula.recommendedDuration;
    final lenFit = d <= 35 ? 1.0 : (1.0 - ((d - 35) / 60.0)).clamp(0.5, 1.0);

    final score = trend * 0.40 + ret * 0.30 + conf * 0.20 + lenFit * 0.10;
    return (score * 100).round().clamp(0, 100);
  }

  /// 조회수 예측
  ///
  /// 뉴스 자체 관심도 × 공식 성과 배수 × 유지율 보정
  int _predictViews(NewsArticle article, ViralFormula formula, int viralScore) {
    final base = article.predictedViews.toDouble();
    final formulaMultiplier = 0.7 + formula.avgRetention * 0.9; // 1.3~1.5x
    final scoreMultiplier = 0.6 + (viralScore / 100.0) * 0.9; // 0.6~1.5x
    final noise = 0.92 + _rng.nextDouble() * 0.16;
    return (base * formulaMultiplier * scoreMultiplier * noise).round();
  }

  /// 플랫폼별 제목 최적화
  ///
  /// 플랫폼마다 제목 길이 제한과 톤이 다릅니다.
  ///   YouTube Shorts — 100자, 검색 키워드 중요
  ///   TikTok         — 짧고 감각적, 해시태그 인라인
  ///   Blog           — 완결형 문장, SEO 키워드 포함
  String platformTitle(ReelProject reel, UploadPlatform platform) {
    switch (platform) {
      case UploadPlatform.youtube:
        final kw = reel.article.keywords.take(2).join(' ');
        var t = '${reel.hookTitle} | $kw #shorts';
        if (t.length > 96) t = '${t.substring(0, 93)}...';
        return t;
      case UploadPlatform.tiktok:
        var t = reel.hookTitle;
        if (t.length > 40) t = '${t.substring(0, 38)}…';
        return '$t ${reel.hashtags.take(3).map((h) => '#$h').join(' ')}';
      case UploadPlatform.blog:
        return '[${reel.article.category}] ${reel.article.title}';
    }
  }

  /// 플랫폼별 설명 최적화
  String platformDescription(ReelProject reel, UploadPlatform platform) {
    switch (platform) {
      case UploadPlatform.youtube:
        return '${reel.description}\n\n${reel.hashtagLine}';
      case UploadPlatform.tiktok:
        return '${reel.article.summary}\n\n${reel.hashtagLine}';
      case UploadPlatform.blog:
        final b = StringBuffer(reel.description);
        b.writeln();
        b.writeln('## 영상 스크립트');
        for (final c in reel.captions) {
          b.writeln('**${c.timeLabel}** — ${c.text}');
        }
        b.writeln();
        b.writeln(reel.hashtagLine);
        return b.toString();
    }
  }
}

/// 카테고리별 이미지 매핑 (씬 구성용)
class NewsFeedImages {
  NewsFeedImages._();

  static const Map<String, List<String>> _pool = {
    '정치': [
      'https://sspark.genspark.ai/i/Lho5UPf3cgxVvUvX?width=900',
      'https://sspark.genspark.ai/i/sBiYHUp3BD5Tvdzw?width=900',
    ],
    '경제': [
      'https://sspark.genspark.ai/i/oRCvBBM8MsCmndnu?width=900',
      'https://sspark.genspark.ai/i/UxeyLCMmigbSy29P?width=900',
      'https://sspark.genspark.ai/i/LyiGDQeXBFw6Ed3Y?width=900',
    ],
    'IT/테크': [
      'https://sspark.genspark.ai/i/v86pDzLdoZCIj3sY?width=900',
      'https://sspark.genspark.ai/i/AEvzu5HPIQNfyFZi?width=900',
      'https://sspark.genspark.ai/i/7sf2iFlrrNQLNoNn?width=900',
    ],
    '스포츠': [
      'https://sspark.genspark.ai/i/2Qa4EViC3wUOgo15?width=900',
      'https://sspark.genspark.ai/i/Mnl6aRsaQaZG8N32?width=900',
    ],
    '연예': [
      'https://sspark.genspark.ai/i/ATGoaitlTtMZxQrk?width=900',
      'https://sspark.genspark.ai/i/NVQVcSGHC154W6HM?width=900',
    ],
    '사회': [
      'https://sspark.genspark.ai/i/x3Hr3HSzaasJqnxN?width=900',
      'https://sspark.genspark.ai/i/H9sLZfGUfGl37AQy?width=900',
      'https://sspark.genspark.ai/i/eFNhL13HOVFxvA5N?width=900',
    ],
  };

  static String forCategory(String category, int index) {
    final list = _pool[category] ?? _pool['사회']!;
    return list[index % list.length];
  }
}
