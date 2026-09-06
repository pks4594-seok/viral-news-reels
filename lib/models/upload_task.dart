/// 업로드 플랫폼
enum UploadPlatform {
  youtube('YouTube Shorts', 'YT'),
  tiktok('TikTok', 'TT'),
  blog('Blog', 'BL');

  const UploadPlatform(this.label, this.short);
  final String label;
  final String short;
}

/// 업로드 상태
enum UploadStatus {
  draft('초안'),
  scheduled('예약됨'),
  uploading('업로드 중'),
  published('발행 완료'),
  failed('실패');

  const UploadStatus(this.label);
  final String label;
}

/// 플랫폼 연동 계정
///
/// [connected]는 사용자가 실제로 OAuth 인증을 마쳤을 때만 true가 됩니다.
/// 임의의 초기값이나 더미 통계를 넣지 않습니다 — 모든 수치는
/// 이 앱에서 실제로 발행한 결과만 누적됩니다.
class PlatformAccount {
  final UploadPlatform platform;

  /// OAuth 인증 후 플랫폼에서 받아온 계정명. 미연동 시 null.
  final String? displayName;

  /// OAuth 인증 완료 여부
  final bool connected;

  /// 이 앱을 통해 발행한 건수 (실제 발행만 카운트)
  final int publishedCount;

  /// 이 앱을 통해 발행한 콘텐츠의 조회수 합계
  final int totalViews;

  /// API 자격증명 등록 여부 (Client ID / Secret)
  final bool hasCredentials;

  const PlatformAccount({
    required this.platform,
    this.displayName,
    this.connected = false,
    this.publishedCount = 0,
    this.totalViews = 0,
    this.hasCredentials = false,
  });

  PlatformAccount copyWith({
    bool? connected,
    String? displayName,
    int? publishedCount,
    int? totalViews,
    bool? hasCredentials,
    bool clearDisplayName = false,
  }) =>
      PlatformAccount(
        platform: platform,
        displayName:
            clearDisplayName ? null : (displayName ?? this.displayName),
        connected: connected ?? this.connected,
        publishedCount: publishedCount ?? this.publishedCount,
        totalViews: totalViews ?? this.totalViews,
        hasCredentials: hasCredentials ?? this.hasCredentials,
      );

  /// 발행 가능 여부 — 자격증명 등록 + 인증 완료 둘 다 필요
  bool get canPublish => hasCredentials && connected;

  /// OAuth 인증에 필요한 개발자 콘솔 안내
  String get credentialGuide {
    switch (platform) {
      case UploadPlatform.youtube:
        return 'Google Cloud Console → YouTube Data API v3 활성화 → '
            'OAuth 2.0 클라이언트 ID 발급';
      case UploadPlatform.tiktok:
        return 'TikTok for Developers → 앱 생성 → '
            'Content Posting API 권한 신청';
      case UploadPlatform.blog:
        return '워드프레스 애플리케이션 비밀번호 또는 '
            '티스토리 Open API 앱 등록';
    }
  }

  /// 필요한 권한 범위
  List<String> get requiredScopes {
    switch (platform) {
      case UploadPlatform.youtube:
        return ['youtube.upload', 'youtube.readonly'];
      case UploadPlatform.tiktok:
        return ['video.publish', 'user.info.basic'];
      case UploadPlatform.blog:
        return ['posts.write'];
    }
  }
}

/// 업로드 작업 (릴스 1개 × 플랫폼 1개)
class UploadTask {
  final String id;
  final String reelId;
  final String reelTitle;
  final String thumbnailUrl;
  final UploadPlatform platform;
  final UploadStatus status;

  /// 예약 발행 시각 (null이면 즉시)
  final DateTime? scheduledAt;

  /// 업로드 진행률 0~1
  final double progress;

  /// 플랫폼별 최적화 제목
  final String platformTitle;

  /// 플랫폼별 설명
  final String platformDescription;

  final List<String> hashtags;

  /// 발행 후 실제 조회수
  final int actualViews;

  final String? errorMessage;

  final DateTime createdAt;

  const UploadTask({
    required this.id,
    required this.reelId,
    required this.reelTitle,
    required this.thumbnailUrl,
    required this.platform,
    required this.status,
    required this.platformTitle,
    required this.platformDescription,
    required this.hashtags,
    required this.createdAt,
    this.scheduledAt,
    this.progress = 0,
    this.actualViews = 0,
    this.errorMessage,
  });

  UploadTask copyWith({
    UploadStatus? status,
    DateTime? scheduledAt,
    double? progress,
    String? platformTitle,
    String? platformDescription,
    int? actualViews,
    String? errorMessage,
  }) =>
      UploadTask(
        id: id,
        reelId: reelId,
        reelTitle: reelTitle,
        thumbnailUrl: thumbnailUrl,
        platform: platform,
        status: status ?? this.status,
        platformTitle: platformTitle ?? this.platformTitle,
        platformDescription: platformDescription ?? this.platformDescription,
        hashtags: hashtags,
        createdAt: createdAt,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        progress: progress ?? this.progress,
        actualViews: actualViews ?? this.actualViews,
        errorMessage: errorMessage,
      );

  String get scheduleLabel {
    if (scheduledAt == null) return '즉시 발행';
    final d = scheduledAt!;
    final now = DateTime.now();
    final diff = d.difference(now);
    if (diff.isNegative) return '발행 시각 경과';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 후';
    if (diff.inHours < 24) return '${diff.inHours}시간 후';
    return '${d.month}월 ${d.day}일 '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}
