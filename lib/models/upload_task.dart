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
class PlatformAccount {
  final UploadPlatform platform;
  final String displayName;
  final bool connected;
  final int publishedCount;
  final int totalViews;

  const PlatformAccount({
    required this.platform,
    required this.displayName,
    required this.connected,
    this.publishedCount = 0,
    this.totalViews = 0,
  });

  PlatformAccount copyWith({
    bool? connected,
    String? displayName,
    int? publishedCount,
    int? totalViews,
  }) =>
      PlatformAccount(
        platform: platform,
        displayName: displayName ?? this.displayName,
        connected: connected ?? this.connected,
        publishedCount: publishedCount ?? this.publishedCount,
        totalViews: totalViews ?? this.totalViews,
      );
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
