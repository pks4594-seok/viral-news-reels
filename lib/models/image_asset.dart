/// 이미지 출처 구분
///
/// 릴스를 외부 플랫폼에 발행할 때 저작권 문제가 발생하지 않도록
/// 모든 이미지의 출처와 사용 가능 범위를 추적합니다.
enum ImageSourceKind {
  /// 언론사 RSS가 제공한 기사 사진 — 저작권 보호 대상
  ///
  /// 앱 내 미리보기(사적 열람)는 가능하나, 영상으로 제작해
  /// 유튜브·틱톡·블로그에 발행하면 복제권·공중송신권 침해입니다.
  pressPhoto(
    label: '언론사 사진',
    shortLabel: '언론사',
    publishSafe: false,
    reason: '언론사가 저작권을 보유한 보도사진입니다. '
        '앱 내 확인용으로만 표시되며 발행 영상에는 사용되지 않습니다.',
  ),

  /// AI가 생성한 배경 — 발행 안전
  ///
  /// 실존 인물·상표·판독 가능한 문자를 포함하지 않도록 생성했습니다.
  aiGenerated(
    label: 'AI 생성 이미지',
    shortLabel: 'AI',
    publishSafe: true,
    reason: '이 앱을 위해 생성한 이미지입니다. '
        '실존 인물·상표·문자를 포함하지 않아 발행에 사용할 수 있습니다.',
  ),

  /// 자유 이용 라이선스 스톡 이미지 — 발행 안전
  stockFree(
    label: '무료 스톡 이미지',
    shortLabel: '스톡',
    publishSafe: true,
    reason: '상업적 이용이 허용된 라이선스의 이미지입니다.',
  ),

  /// 사용자가 직접 올린 이미지 — 발행 안전(책임은 사용자)
  userUploaded(
    label: '직접 등록',
    shortLabel: '내 이미지',
    publishSafe: true,
    reason: '사용자가 직접 등록한 이미지입니다. '
        '저작권 확인 책임은 등록자에게 있습니다.',
  ),

  /// 앱이 그린 추상 배경 (그라디언트 등) — 항상 안전
  generatedGradient(
    label: '앱 생성 배경',
    shortLabel: '기본',
    publishSafe: true,
    reason: '앱이 실시간으로 그리는 배경입니다.',
  );

  const ImageSourceKind({
    required this.label,
    required this.shortLabel,
    required this.publishSafe,
    required this.reason,
  });

  /// 표시용 전체 이름
  final String label;

  /// 배지용 짧은 이름
  final String shortLabel;

  /// 외부 플랫폼 발행에 사용해도 안전한지
  final bool publishSafe;

  /// 사용자에게 보여줄 설명
  final String reason;
}

/// 이미지 에셋 — URL과 출처 정보를 함께 보관
class ImageAsset {
  final String url;
  final ImageSourceKind kind;

  /// 이 이미지가 어떤 주제를 나타내는지 (AI 배경의 경우)
  final String? topic;

  /// 출처 표기 문구 (스톡 이미지의 경우)
  final String? attribution;

  const ImageAsset({
    required this.url,
    required this.kind,
    this.topic,
    this.attribution,
  });

  bool get isPublishSafe => kind.publishSafe;

  /// 언론사 사진을 안전한 대체본으로 교체
  ImageAsset replaceWith(ImageAsset safe) => safe;

  Map<String, dynamic> toJson() => {
        'url': url,
        'kind': kind.name,
        'topic': topic,
        'attribution': attribution,
      };

  factory ImageAsset.fromJson(Map<String, dynamic> j) => ImageAsset(
        url: (j['url'] ?? '') as String,
        kind: ImageSourceKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => ImageSourceKind.generatedGradient,
        ),
        topic: j['topic'] as String?,
        attribution: j['attribution'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is ImageAsset && other.url == url && other.kind == kind;

  @override
  int get hashCode => Object.hash(url, kind);
}

/// 이미지 사용 정책
///
/// 릴스 제작 시 언론사 사진을 어떻게 다룰지 결정합니다.
enum ImagePolicy {
  /// 언론사 사진을 절대 쓰지 않고 항상 AI 배경으로 대체 (기본값·권장)
  alwaysSafe(
    label: '항상 안전 이미지',
    description: '발행 영상에 AI 생성 배경만 사용합니다. 저작권 분쟁 위험이 없습니다.',
  ),

  /// 앱 내 미리보기에서는 언론사 사진, 발행 시에는 AI 배경
  previewOnly(
    label: '미리보기만 원본',
    description: '앱에서 확인할 때는 기사 사진을, 발행 영상에는 AI 배경을 씁니다.',
  ),

  /// 언론사 사진을 그대로 사용 (사용자 책임)
  allowPress(
    label: '원본 사용 (위험)',
    description: '언론사 사진을 발행 영상에 그대로 사용합니다. '
        '저작권 침해 책임은 사용자에게 있습니다.',
  );

  const ImagePolicy({required this.label, required this.description});

  final String label;
  final String description;

  /// 발행용 영상에 언론사 사진을 허용하는지
  bool get allowsPressInPublish => this == ImagePolicy.allowPress;

  /// 앱 내 미리보기에 언론사 사진을 보여주는지
  bool get showsPressInPreview => this != ImagePolicy.alwaysSafe;
}
