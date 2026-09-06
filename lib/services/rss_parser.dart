import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// RSS/Atom 피드에서 파싱한 원시 항목
class FeedItem {
  final String title;
  final String link;
  final String description;
  final String? imageUrl;
  final DateTime publishedAt;
  final String? categoryHint;

  const FeedItem({
    required this.title,
    required this.link,
    required this.description,
    required this.publishedAt,
    this.imageUrl,
    this.categoryHint,
  });
}

/// 피드 수집 결과
class FeedResult {
  final List<FeedItem> items;
  final String sourceName;
  final String? error;

  /// 어떤 경로로 성공했는지 (직접 / 프록시명)
  final String route;

  const FeedResult({
    required this.items,
    required this.sourceName,
    required this.route,
    this.error,
  });

  bool get ok => error == null && items.isNotEmpty;
}

/// 실제 RSS/Atom 파서
///
/// 국내 언론사 피드는 형식이 제각각입니다:
///   · RSS 2.0        — `rss > channel > item`
///   · Atom 1.0       — `feed > entry`
///   · RDF/RSS 1.0    — `rdf:RDF > item`
/// 세 형식을 모두 처리하고, 이미지는 5개 경로에서 순차 탐색합니다.
///
/// 웹 플랫폼은 브라우저 CORS 정책으로 외부 피드 직접 호출이 차단됩니다.
/// 따라서 웹에서는 공개 CORS 프록시를 순차 시도하며,
/// 안드로이드/iOS에서는 직접 호출합니다.
class RssParser {
  RssParser._();
  static final RssParser instance = RssParser._();

  static const Duration _timeout = Duration(seconds: 12);

  /// 웹 전용 CORS 프록시 후보 (순차 폴백)
  static const List<({String name, String Function(String) build})> _proxies = [
    (
      name: 'allorigins',
      build: _allOrigins,
    ),
    (
      name: 'codetabs',
      build: _codeTabs,
    ),
    (
      name: 'thingproxy',
      build: _corsProxyIo,
    ),
  ];

  static String _allOrigins(String url) =>
      'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';

  static String _codeTabs(String url) =>
      'https://api.codetabs.com/v1/proxy?quest=${Uri.encodeComponent(url)}';

  static String _corsProxyIo(String url) =>
      'https://corsproxy.io/?${Uri.encodeComponent(url)}';

  /// 피드 수집 — 플랫폼에 따라 경로를 자동 선택
  Future<FeedResult> fetch(String sourceName, String feedUrl) async {
    // 네이티브(안드로이드/iOS): 직접 호출
    if (!kIsWeb) {
      try {
        final body = await _get(feedUrl);
        final items = parse(body);
        return FeedResult(
          items: items,
          sourceName: sourceName,
          route: 'direct',
        );
      } catch (e) {
        return FeedResult(
          items: const [],
          sourceName: sourceName,
          route: 'direct',
          error: _friendlyError(e),
        );
      }
    }

    // 웹: 직접 시도 → 실패하면 프록시 순차 폴백
    try {
      final body = await _get(feedUrl);
      final items = parse(body);
      if (items.isNotEmpty) {
        return FeedResult(
          items: items,
          sourceName: sourceName,
          route: 'direct',
        );
      }
    } catch (_) {
      // CORS 차단 예상 — 프록시로 진행
    }

    String? lastError;
    for (final proxy in _proxies) {
      try {
        final body = await _get(proxy.build(feedUrl));
        final items = parse(body);
        if (items.isNotEmpty) {
          return FeedResult(
            items: items,
            sourceName: sourceName,
            route: proxy.name,
          );
        }
        lastError = '피드가 비어 있습니다';
      } catch (e) {
        lastError = _friendlyError(e);
      }
    }

    return FeedResult(
      items: const [],
      sourceName: sourceName,
      route: 'proxy',
      error: lastError ?? '수집 실패',
    );
  }

  Future<String> _get(String url) async {
    final res = await http
        .get(Uri.parse(url), headers: {
          'Accept': 'application/rss+xml, application/xml, text/xml, */*',
          'User-Agent': 'TrendReelStudio/1.0',
        })
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}');
    }

    // 한글 피드는 UTF-8이 표준이나, 일부는 EUC-KR을 씁니다.
    // Content-Type 헤더를 먼저 확인하고, 없으면 UTF-8로 디코딩합니다.
    final ct = res.headers['content-type']?.toLowerCase() ?? '';
    if (ct.contains('euc-kr') || ct.contains('ks_c_5601')) {
      // EUC-KR은 dart:convert 기본 지원 밖이므로 latin1 경유 후
      // XML 선언에 의존합니다. 대부분 국내 피드는 UTF-8입니다.
      return latin1.decode(res.bodyBytes, allowInvalid: true);
    }
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('TimeoutException')) return '응답 시간 초과';
    if (s.contains('XMLHttpRequest') || s.contains('ClientException')) {
      return 'CORS 차단 (웹 제약)';
    }
    if (s.contains('SocketException')) return '네트워크 연결 실패';
    if (s.contains('HTTP 4')) return '피드 주소 오류';
    if (s.contains('HTTP 5')) return '언론사 서버 오류';
    return '파싱 실패';
  }

  // ══════════════════════════════════════════════════════
  // XML 파싱 — RSS 2.0 / Atom 1.0 / RDF 통합 처리
  // ══════════════════════════════════════════════════════

  /// XML 본문 → FeedItem 목록
  List<FeedItem> parse(String xmlBody) {
    // BOM / 선행 공백 제거
    var body = xmlBody.trimLeft();
    if (body.startsWith('\uFEFF')) body = body.substring(1);
    if (!body.startsWith('<')) {
      final i = body.indexOf('<');
      if (i < 0) return const [];
      body = body.substring(i);
    }

    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(body);
    } catch (_) {
      return const [];
    }

    // RSS 2.0 / RDF: <item>
    var nodes = doc.findAllElements('item').toList();
    // Atom 1.0: <entry>
    if (nodes.isEmpty) {
      nodes = doc.findAllElements('entry').toList();
    }
    if (nodes.isEmpty) return const [];

    final out = <FeedItem>[];
    for (final n in nodes) {
      final item = _mapNode(n);
      if (item != null) out.add(item);
    }
    return out;
  }

  FeedItem? _mapNode(XmlElement n) {
    final title = _clean(_text(n, ['title']));
    if (title.isEmpty) return null;

    final link = _extractLink(n);

    final rawDesc = _text(n, [
      'description',
      'summary',
      'content:encoded',
      'content',
      'subtitle',
    ]);
    final description = _clean(rawDesc);

    final published = _extractDate(n);
    final imageUrl = _extractImage(n, rawDesc);
    final category = _text(n, ['category']).trim();

    return FeedItem(
      title: title,
      link: link,
      description: description,
      publishedAt: published,
      imageUrl: imageUrl,
      categoryHint: category.isEmpty ? null : category,
    );
  }

  /// 자식 엘리먼트 텍스트 추출 (여러 후보 이름 순차 탐색)
  String _text(XmlElement n, List<String> names) {
    for (final name in names) {
      // 네임스페이스 접두어가 붙은 경우까지 처리
      for (final el in n.children.whereType<XmlElement>()) {
        final local = el.name.local;
        final qualified = el.name.qualified;
        if (local == name || qualified == name) {
          final v = el.innerText.trim();
          if (v.isNotEmpty) return v;
        }
      }
    }
    return '';
  }

  /// 링크 추출 — RSS는 link 엘리먼트 텍스트, Atom은 link의 href 속성
  String _extractLink(XmlElement n) {
    for (final el in n.children.whereType<XmlElement>()) {
      if (el.name.local != 'link') continue;

      // Atom: rel="alternate" 우선
      final href = el.getAttribute('href');
      if (href != null && href.isNotEmpty) {
        final rel = el.getAttribute('rel');
        if (rel == null || rel == 'alternate') return href;
      }

      final txt = el.innerText.trim();
      if (txt.isNotEmpty) return txt;
    }
    // 폴백: guid가 URL 형태인 경우
    final guid = _text(n, ['guid', 'id']);
    if (guid.startsWith('http')) return guid;
    return '';
  }

  /// 발행 시각 추출 — 5개 필드 후보 + 3개 포맷
  DateTime _extractDate(XmlElement n) {
    final raw = _text(n, [
      'pubDate',
      'published',
      'updated',
      'dc:date',
      'date',
    ]);
    if (raw.isEmpty) return DateTime.now();

    // ISO 8601 (Atom)
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso.toLocal();

    // RFC 822 (RSS 2.0) — "Sat, 06 Sep 2025 09:12:00 +0900"
    final rfc = _parseRfc822(raw);
    if (rfc != null) return rfc;

    return DateTime.now();
  }

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  DateTime? _parseRfc822(String s) {
    // 요일 접두 제거
    var t = s.trim();
    final comma = t.indexOf(',');
    if (comma >= 0 && comma <= 4) t = t.substring(comma + 1).trim();

    final m = RegExp(
      r'^(\d{1,2})\s+([A-Za-z]{3})\w*\s+(\d{4})\s+'
      r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*'
      r'([+-]\d{4}|[A-Z]{2,4})?',
    ).firstMatch(t);
    if (m == null) return null;

    final day = int.tryParse(m.group(1)!) ?? 1;
    final mon = _months[m.group(2)!.toLowerCase()] ?? 1;
    final year = int.tryParse(m.group(3)!) ?? DateTime.now().year;
    final hour = int.tryParse(m.group(4)!) ?? 0;
    final min = int.tryParse(m.group(5)!) ?? 0;
    final sec = int.tryParse(m.group(6) ?? '0') ?? 0;

    var dt = DateTime.utc(year, mon, day, hour, min, sec);

    // 타임존 오프셋 보정
    final tz = m.group(7);
    if (tz != null && (tz.startsWith('+') || tz.startsWith('-'))) {
      final sign = tz[0] == '-' ? 1 : -1; // UTC로 되돌리므로 반대 부호
      final h = int.tryParse(tz.substring(1, 3)) ?? 0;
      final mi = int.tryParse(tz.substring(3, 5)) ?? 0;
      dt = dt.add(Duration(hours: sign * h, minutes: sign * mi));
    }
    return dt.toLocal();
  }

  /// 이미지 추출 — 5개 경로 순차 탐색
  ///
  ///   1. `media:content` 의 url 속성  — 대부분 국내 언론사
  ///   2. `media:thumbnail` 의 url 속성
  ///   3. `enclosure` (type이 image로 시작)
  ///   4. `image` 하위의 url
  ///   5. description HTML 안의 첫 img 태그  — 최후 수단
  String? _extractImage(XmlElement n, String rawDesc) {
    for (final el in n.descendants.whereType<XmlElement>()) {
      final local = el.name.local;

      if (local == 'content' || local == 'thumbnail') {
        final url = el.getAttribute('url');
        if (_isImageUrl(url)) return url;
      }

      if (local == 'enclosure') {
        final type = el.getAttribute('type') ?? '';
        final url = el.getAttribute('url');
        if (type.startsWith('image') && url != null && url.isNotEmpty) {
          return url;
        }
        if (_isImageUrl(url)) return url;
      }

      if (local == 'image') {
        final url = el.getAttribute('href') ?? el.getAttribute('url');
        if (_isImageUrl(url)) return url;
        for (final c in el.children.whereType<XmlElement>()) {
          if (c.name.local == 'url' && _isImageUrl(c.innerText.trim())) {
            return c.innerText.trim();
          }
        }
      }
    }

    // description HTML 안의 첫 img 태그
    final imgMatch =
        RegExp(r'''<img[^>]+src=["']([^"']+)["']''', caseSensitive: false)
            .firstMatch(rawDesc);
    if (imgMatch != null) {
      final url = imgMatch.group(1);
      if (url != null && url.startsWith('http')) return url;
    }

    return null;
  }

  bool _isImageUrl(String? url) {
    if (url == null || url.isEmpty || !url.startsWith('http')) return false;
    final lower = url.toLowerCase();
    // 확장자 또는 이미지 CDN 경로 패턴
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('.gif') ||
        lower.contains('/image') ||
        lower.contains('/photo') ||
        lower.contains('/thumb');
  }

  /// HTML 태그, 엔티티, CDATA 제거
  String _clean(String s) {
    if (s.isEmpty) return '';
    var t = s;

    // CDATA
    t = t.replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '');
    // script/style 블록 통째로
    t = t.replaceAll(
        RegExp(r'<(script|style)[^>]*>.*?</\1>',
            caseSensitive: false, dotAll: true),
        '');
    // 줄바꿈 유발 태그를 공백으로
    t = t.replaceAll(
        RegExp(r'</(p|div|br|li|h[1-6])>', caseSensitive: false), ' ');
    // 나머지 태그 제거
    t = t.replaceAll(RegExp(r'<[^>]+>'), '');
    // HTML 엔티티
    t = t
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&hellip;', '…')
        .replaceAll('&middot;', '·')
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"');
    // 숫자 엔티티
    t = t.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      return code != null ? String.fromCharCode(code) : '';
    });
    // 공백 정리
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => 'HttpException: $message';
}
