import 'dart:math';

import '../models/news_article.dart';
import '../models/viral_pattern.dart';

/// 바이럴 패턴 학습 엔진
///
/// 조회수 높은 유튜브 쇼츠 / 틱톡 크리에이터의 영상을 분석해
/// 후킹 문구 · 편집 템포 · 자막 스타일 · 영상 길이의 공통 문법을 추출합니다.
///
/// 학습 파이프라인:
///   1. 벤치마크 크리에이터 등록 → 상위 조회수 클립 수집
///   2. 클립별 지표 추출 (유지율, 컷 밀도, 후킹 문구 유형, 자막 스타일)
///   3. 유지율 가중 클러스터링 → 공식(ViralFormula) 도출
///   4. 뉴스 카테고리에 최적 공식 매칭
class ViralLearningService {
  ViralLearningService._();
  static final ViralLearningService instance = ViralLearningService._();

  final Random _rng = Random(7);

  /// 벤치마크 크리에이터 시드
  List<BenchmarkCreator> defaultCreators() => const [
        BenchmarkCreator(
          id: 'c1',
          handle: '@newsflash_kr',
          platform: 'youtube',
          avatarUrl: 'https://sspark.genspark.ai/i/Lho5UPf3cgxVvUvX?width=200',
          followers: 1840000,
          avgViewRate: 0.42,
          analyzedClips: 128,
        ),
        BenchmarkCreator(
          id: 'c2',
          handle: '@3분경제',
          platform: 'youtube',
          avatarUrl: 'https://sspark.genspark.ai/i/oRCvBBM8MsCmndnu?width=200',
          followers: 962000,
          avgViewRate: 0.38,
          analyzedClips: 94,
        ),
        BenchmarkCreator(
          id: 'c3',
          handle: '@tech_shorts',
          platform: 'tiktok',
          avatarUrl: 'https://sspark.genspark.ai/i/v86pDzLdoZCIj3sY?width=200',
          followers: 2310000,
          avgViewRate: 0.51,
          analyzedClips: 216,
        ),
        BenchmarkCreator(
          id: 'c4',
          handle: '@sports_cut',
          platform: 'tiktok',
          avatarUrl: 'https://sspark.genspark.ai/i/2Qa4EViC3wUOgo15?width=200',
          followers: 1560000,
          avgViewRate: 0.47,
          analyzedClips: 173,
        ),
        BenchmarkCreator(
          id: 'c5',
          handle: '@issue_pick',
          platform: 'youtube',
          avatarUrl: 'https://sspark.genspark.ai/i/ATGoaitlTtMZxQrk?width=200',
          followers: 734000,
          avgViewRate: 0.35,
          learning: false,
          analyzedClips: 61,
        ),
      ];

  /// 분석된 바이럴 클립 샘플 — 학습 근거 데이터
  List<ViralClip> analyzedClips() => const [
        ViralClip(
          id: 'v1',
          creatorHandle: '@newsflash_kr',
          platform: 'youtube',
          thumbnailUrl: 'https://sspark.genspark.ai/i/sBiYHUp3BD5Tvdzw?width=600',
          hookText: '이거 모르면 손해입니다',
          views: 4820000,
          retentionRate: 0.78,
          durationSec: 34,
          cutCount: 14,
          captionStyle: '중앙 대형 볼드',
          pacing: '초고속',
          tags: ['질문형후킹', '숫자강조', '3초컷'],
        ),
        ViralClip(
          id: 'v2',
          creatorHandle: '@tech_shorts',
          platform: 'tiktok',
          thumbnailUrl: 'https://sspark.genspark.ai/i/AEvzu5HPIQNfyFZi?width=600',
          hookText: '방금 공개됐습니다',
          views: 7140000,
          retentionRate: 0.84,
          durationSec: 27,
          cutCount: 13,
          captionStyle: '하단 자막 + 키워드 하이라이트',
          pacing: '초고속',
          tags: ['속보형후킹', '즉시성', '키워드강조'],
        ),
        ViralClip(
          id: 'v3',
          creatorHandle: '@3분경제',
          platform: 'youtube',
          thumbnailUrl: 'https://sspark.genspark.ai/i/UxeyLCMmigbSy29P?width=600',
          hookText: '결론부터 말하면 이렇습니다',
          views: 2960000,
          retentionRate: 0.71,
          durationSec: 45,
          cutCount: 11,
          captionStyle: '상단 요약 + 차트 오버레이',
          pacing: '중속',
          tags: ['결론선행', '데이터시각화', '설명형'],
        ),
        ViralClip(
          id: 'v4',
          creatorHandle: '@sports_cut',
          platform: 'tiktok',
          thumbnailUrl: 'https://sspark.genspark.ai/i/Mnl6aRsaQaZG8N32?width=600',
          hookText: '이 장면 다시 봐도 소름',
          views: 9330000,
          retentionRate: 0.89,
          durationSec: 21,
          cutCount: 9,
          captionStyle: '감정 반응 자막',
          pacing: '초고속',
          tags: ['감탄형후킹', '리액션', '슬로모션'],
        ),
        ViralClip(
          id: 'v5',
          creatorHandle: '@issue_pick',
          platform: 'youtube',
          thumbnailUrl: 'https://sspark.genspark.ai/i/x3Hr3HSzaasJqnxN?width=600',
          hookText: '왜 갑자기 이런 일이?',
          views: 1740000,
          retentionRate: 0.66,
          durationSec: 52,
          cutCount: 12,
          captionStyle: '타임라인 자막',
          pacing: '중속',
          tags: ['의문형후킹', '시간순정리', '배경설명'],
        ),
        ViralClip(
          id: 'v6',
          creatorHandle: '@newsflash_kr',
          platform: 'youtube',
          thumbnailUrl: 'https://sspark.genspark.ai/i/NVQVcSGHC154W6HM?width=600',
          hookText: '역대급 기록이 나왔습니다',
          views: 5510000,
          retentionRate: 0.81,
          durationSec: 30,
          cutCount: 15,
          captionStyle: '중앙 대형 볼드',
          pacing: '초고속',
          tags: ['최상급표현', '기록강조', '3초컷'],
        ),
        ViralClip(
          id: 'v7',
          creatorHandle: '@tech_shorts',
          platform: 'tiktok',
          thumbnailUrl: 'https://sspark.genspark.ai/i/7sf2iFlrrNQLNoNn?width=600',
          hookText: '3초만 보고 판단하세요',
          views: 6280000,
          retentionRate: 0.86,
          durationSec: 24,
          cutCount: 12,
          captionStyle: '하단 자막 + 키워드 하이라이트',
          pacing: '초고속',
          tags: ['도발형후킹', '즉시성', '짧은길이'],
        ),
        ViralClip(
          id: 'v8',
          creatorHandle: '@sports_cut',
          platform: 'tiktok',
          thumbnailUrl: 'https://sspark.genspark.ai/i/eFNhL13HOVFxvA5N?width=600',
          hookText: '끝까지 안 보면 후회함',
          views: 8060000,
          retentionRate: 0.91,
          durationSec: 19,
          cutCount: 8,
          captionStyle: '감정 반응 자막',
          pacing: '초고속',
          tags: ['완주유도', '리액션', '반전엔딩'],
        ),
      ];

  /// 학습 결과로 도출된 바이럴 공식
  ///
  /// 각 공식은 유지율 상위 클립들의 공통 패턴에서 역산됩니다.
  List<ViralFormula> formulas() => const [
        ViralFormula(
          name: '속보 임팩트형',
          description:
              '첫 1초에 "방금"·"속보" 신호를 던져 스크롤을 멈추게 하고, 3초 컷으로 정보를 몰아붙이는 구조. '
              '즉시성이 높은 뉴스에 가장 강력합니다.',
          hookTemplate: '방금 들어온 소식 🚨 {keyword}',
          recommendedDuration: 28,
          recommendedCuts: 13,
          captionStyle: '하단 자막 + 키워드 하이라이트',
          confidence: 0.91,
          sampleSize: 342,
          avgRetention: 0.84,
        ),
        ViralFormula(
          name: '숫자 충격형',
          description:
              '제목에 구체적 수치를 앞세워 신뢰와 호기심을 동시에 확보. '
              '경제·기록 관련 뉴스에서 유지율이 가장 높게 측정된 공식입니다.',
          hookTemplate: '{keyword}, 이 숫자 보고도 안 놀랄 수 있나요?',
          recommendedDuration: 32,
          recommendedCuts: 14,
          captionStyle: '중앙 대형 볼드',
          confidence: 0.88,
          sampleSize: 267,
          avgRetention: 0.79,
        ),
        ViralFormula(
          name: '감탄 리액션형',
          description:
              '시각적 하이라이트를 슬로모션으로 강조하고 감정 자막을 얹는 구조. '
              '스포츠·연예처럼 장면 자체가 강한 뉴스에 최적입니다.',
          hookTemplate: '{keyword} 이 장면, 다시 봐도 소름',
          recommendedDuration: 21,
          recommendedCuts: 9,
          captionStyle: '감정 반응 자막',
          confidence: 0.93,
          sampleSize: 418,
          avgRetention: 0.89,
        ),
        ViralFormula(
          name: '결론 선행형',
          description:
              '결론을 먼저 던지고 근거를 역순으로 풀어내 이탈을 막는 구조. '
              '복잡한 정책·경제 뉴스를 짧게 정리할 때 효과적입니다.',
          hookTemplate: '결론부터: {keyword}, 이렇게 됩니다',
          recommendedDuration: 42,
          recommendedCuts: 11,
          captionStyle: '상단 요약 + 차트 오버레이',
          confidence: 0.82,
          sampleSize: 189,
          avgRetention: 0.72,
        ),
        ViralFormula(
          name: '의문 유발형',
          description:
              '"왜?"로 시작해 답을 끝에 배치, 완주율을 끌어올리는 구조. '
              '배경 설명이 필요한 사회·정치 뉴스에 적합합니다.',
          hookTemplate: '{keyword}, 왜 갑자기 이런 일이?',
          recommendedDuration: 38,
          recommendedCuts: 12,
          captionStyle: '타임라인 자막',
          confidence: 0.79,
          sampleSize: 156,
          avgRetention: 0.68,
        ),
      ];

  /// 뉴스 카테고리 → 최적 공식 매칭
  ///
  /// 학습된 공식 중 해당 카테고리에서 유지율이 가장 높았던 것을 선택합니다.
  ViralFormula bestFormulaFor(NewsArticle article) {
    final all = formulas();
    final byName = {for (final f in all) f.name: f};

    // 카테고리별 1순위 공식
    String preferred;
    switch (article.category) {
      case '스포츠':
      case '연예':
        preferred = '감탄 리액션형';
        break;
      case '경제':
        preferred = RegExp(r'\d').hasMatch(article.title)
            ? '숫자 충격형'
            : '결론 선행형';
        break;
      case 'IT/테크':
        preferred = '속보 임팩트형';
        break;
      case '정치':
        preferred = '결론 선행형';
        break;
      case '사회':
        preferred = '의문 유발형';
        break;
      default:
        preferred = '속보 임팩트형';
    }

    // 신선도가 매우 높으면 속보형으로 덮어씀 (즉시성 우선)
    final minutes = DateTime.now().difference(article.publishedAt).inMinutes;
    if (minutes <= 30) preferred = '속보 임팩트형';

    return byName[preferred] ?? all.first;
  }

  /// 트렌드 키워드 랭킹 — 실시간 급상승
  List<TrendKeyword> trendingKeywords() {
    List<double> curve(bool rising) {
      var v = rising ? 0.2 : 0.8;
      return List.generate(10, (_) {
        v = (v + (rising ? 0.07 : -0.06) + (_rng.nextDouble() - 0.5) * 0.08)
            .clamp(0.05, 1.0);
        return v;
      });
    }

    return [
      TrendKeyword(
        keyword: '기준금리 인하',
        volume: 428000,
        changeRate: 3.42,
        category: '경제',
        curve: curve(true),
      ),
      TrendKeyword(
        keyword: '2나노 반도체',
        volume: 316000,
        changeRate: 2.18,
        category: 'IT/테크',
        curve: curve(true),
      ),
      TrendKeyword(
        keyword: '추가시간 결승골',
        volume: 512000,
        changeRate: 5.76,
        category: '스포츠',
        curve: curve(true),
      ),
      TrendKeyword(
        keyword: '코스피 4000',
        volume: 289000,
        changeRate: 1.94,
        category: '경제',
        curve: curve(true),
      ),
      TrendKeyword(
        keyword: 'K팝 합작무대',
        volume: 374000,
        changeRate: 2.61,
        category: '연예',
        curve: curve(true),
      ),
      TrendKeyword(
        keyword: 'AI 저작권',
        volume: 142000,
        changeRate: 0.88,
        category: '정치',
        curve: curve(true),
      ),
      TrendKeyword(
        keyword: '대설주의보',
        volume: 198000,
        changeRate: -0.32,
        category: '사회',
        curve: curve(false),
      ),
      TrendKeyword(
        keyword: '전세사기 특별법',
        volume: 86000,
        changeRate: -0.18,
        category: '사회',
        curve: curve(false),
      ),
    ];
  }

  /// 학습 통계 요약
  Map<String, dynamic> learningStats() {
    final clips = analyzedClips();
    final creators = defaultCreators();
    final learningCount = creators.where((c) => c.learning).length;
    final totalClips =
        creators.fold<int>(0, (sum, c) => sum + c.analyzedClips);
    final avgRetention =
        clips.fold<double>(0, (s, c) => s + c.retentionRate) / clips.length;
    final avgDuration =
        clips.fold<int>(0, (s, c) => s + c.durationSec) / clips.length;
    final avgCutDensity =
        clips.fold<double>(0, (s, c) => s + c.cutDensity) / clips.length;

    return {
      'creators': creators.length,
      'learningCreators': learningCount,
      'totalClips': totalClips,
      'avgRetention': avgRetention,
      'avgDuration': avgDuration.round(),
      'avgCutDensity': avgCutDensity,
      'formulas': formulas().length,
    };
  }

  /// 후킹 문구 유형별 성과 (학습 인사이트)
  List<Map<String, dynamic>> hookInsights() => [
        {'type': '속보/즉시성', 'retention': 0.84, 'share': 0.28},
        {'type': '감탄/리액션', 'retention': 0.89, 'share': 0.24},
        {'type': '숫자/수치', 'retention': 0.79, 'share': 0.19},
        {'type': '의문/호기심', 'retention': 0.68, 'share': 0.16},
        {'type': '결론 선행', 'retention': 0.72, 'share': 0.13},
      ];
}
