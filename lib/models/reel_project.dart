import 'news_article.dart';

/// 릴스 제작 단계
enum ReelBuildStage {
  script('스크립트', 0),
  voice('음성', 1),
  visual('비주얼', 2),
  render('렌더링', 3),
  ready('완료', 4);

  const ReelBuildStage(this.label, this.order);
  final String label;
  final int order;
}

/// 자막 한 줄 (타임코드 포함)
class CaptionLine {
  final double startSec;
  final double endSec;
  final String text;
  final bool emphasis; // 강조 자막 여부

  const CaptionLine({
    required this.startSec,
    required this.endSec,
    required this.text,
    this.emphasis = false,
  });

  String get timeLabel =>
      '${startSec.toStringAsFixed(1)}s → ${endSec.toStringAsFixed(1)}s';

  Map<String, dynamic> toJson() => {
        'startSec': startSec,
        'endSec': endSec,
        'text': text,
        'emphasis': emphasis,
      };

  factory CaptionLine.fromJson(Map<String, dynamic> j) => CaptionLine(
        startSec: (j['startSec'] as num).toDouble(),
        endSec: (j['endSec'] as num).toDouble(),
        text: j['text'] as String,
        emphasis: (j['emphasis'] ?? false) as bool,
      );
}

/// 영상 컷 (씬)
class ReelScene {
  final int index;
  final String imageUrl;
  final String motion; // 카메라 무브 (줌인/팬/슬라이드)
  final double durationSec;
  final String narration;

  const ReelScene({
    required this.index,
    required this.imageUrl,
    required this.motion,
    required this.durationSec,
    required this.narration,
  });
}

/// 릴스 프로젝트 — 뉴스 → 영상 변환의 결과물
class ReelProject {
  final String id;
  final NewsArticle article;

  /// AI 생성 제목 (플랫폼별 최적화)
  final String hookTitle;

  /// 상세 설명 / 블로그 본문
  final String description;

  /// 해시태그
  final List<String> hashtags;

  /// 자막 스크립트
  final List<CaptionLine> captions;

  /// 씬 구성
  final List<ReelScene> scenes;

  /// 적용된 바이럴 공식 이름
  final String formulaName;

  /// 현재 단계
  final ReelBuildStage stage;

  /// 현재 단계 진행률 0~1
  final double stageProgress;

  /// 총 길이(초)
  final int durationSec;

  /// 예측 조회수
  final int predictedViews;

  /// 바이럴 적합도 점수
  final int viralScore;

  /// BGM 이름
  final String bgm;

  /// 내레이션 음성 이름
  final String voiceName;

  final DateTime createdAt;

  const ReelProject({
    required this.id,
    required this.article,
    required this.hookTitle,
    required this.description,
    required this.hashtags,
    required this.captions,
    required this.scenes,
    required this.formulaName,
    required this.stage,
    required this.stageProgress,
    required this.durationSec,
    required this.predictedViews,
    required this.viralScore,
    required this.bgm,
    required this.voiceName,
    required this.createdAt,
  });

  ReelProject copyWith({
    String? hookTitle,
    String? description,
    List<String>? hashtags,
    List<CaptionLine>? captions,
    ReelBuildStage? stage,
    double? stageProgress,
    int? predictedViews,
    int? viralScore,
    String? bgm,
    String? voiceName,
  }) {
    return ReelProject(
      id: id,
      article: article,
      hookTitle: hookTitle ?? this.hookTitle,
      description: description ?? this.description,
      hashtags: hashtags ?? this.hashtags,
      captions: captions ?? this.captions,
      scenes: scenes,
      formulaName: formulaName,
      stage: stage ?? this.stage,
      stageProgress: stageProgress ?? this.stageProgress,
      durationSec: durationSec,
      predictedViews: predictedViews ?? this.predictedViews,
      viralScore: viralScore ?? this.viralScore,
      bgm: bgm ?? this.bgm,
      voiceName: voiceName ?? this.voiceName,
      createdAt: createdAt,
    );
  }

  bool get isReady => stage == ReelBuildStage.ready;

  /// 전체 진행률 (단계 + 단계 내 진행)
  double get overallProgress {
    final total = ReelBuildStage.values.length - 1;
    return ((stage.order + stageProgress) / total).clamp(0.0, 1.0);
  }

  String get viewsLabel => NewsArticle.formatCount(predictedViews);

  String get hashtagLine => hashtags.map((h) => '#$h').join(' ');
}
