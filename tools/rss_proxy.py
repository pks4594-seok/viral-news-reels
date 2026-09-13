#!/usr/bin/env python3
"""
Trend Reel Studio — RSS 프록시 서버

웹 브라우저의 CORS 정책은 외부 도메인 RSS 피드 직접 호출을 차단합니다.
공개 CORS 프록시는 속도 제한과 차단이 빈번하므로, 이 앱 전용 프록시를
같은 샌드박스에서 운영하여 안정적으로 피드를 중계합니다.

  GET /feed?url=<인코딩된 피드 URL>   → XML 본문을 CORS 헤더와 함께 반환
  GET /health                        → 상태 확인

안드로이드 앱은 이 프록시를 거치지 않고 피드를 직접 호출합니다.
"""

import http.server
import socketserver
import socket
import urllib.parse
import urllib.request
import urllib.error
import gzip
import io
import time
import threading

PORT = 5061
TIMEOUT = 15
CACHE_TTL = 120  # 동일 피드 재요청은 2분간 캐시 사용

# 중계 허용 도메인 — 국내 언론사 피드만 통과시킵니다.
ALLOWED_HOSTS = {
    'www.yna.co.kr',
    'rss.etnews.com',
    'feeds.feedburner.com',
    'www.hani.co.kr',
    'rss.mt.co.kr',
    'www.khan.co.kr',
    'rss.nocutnews.co.kr',
    'www.mk.co.kr',
    'rss.edaily.co.kr',
    'news.sbs.co.kr',
    'www.chosun.com',
    'rss.joins.com',
    'www.donga.com',
    'rss.hankyung.com',
    'www.sedaily.com',
    'www.fnnews.com',
    'biz.heraldcorp.com',
    'www.newsis.com',
}

_cache = {}
_lock = threading.Lock()


def cache_get(url):
    with _lock:
        entry = _cache.get(url)
        if entry and time.time() - entry[0] < CACHE_TTL:
            return entry[1]
    return None


def cache_put(url, body):
    with _lock:
        _cache[url] = (time.time(), body)
        # 캐시 상한
        if len(_cache) > 64:
            oldest = min(_cache.items(), key=lambda kv: kv[1][0])[0]
            _cache.pop(oldest, None)


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, fmt, *args):
        print(f'[proxy] {fmt % args}', flush=True)

    def _cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.send_header('Content-Length', '0')
        self.end_headers()

    def _send(self, code, body, ctype='application/xml; charset=utf-8'):
        data = body if isinstance(body, bytes) else body.encode('utf-8')
        self.send_response(code)
        self._cors()
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        try:
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)

        if parsed.path == '/health':
            self._send(200, '{"status":"ok","cached":%d}' % len(_cache),
                       'application/json')
            return

        if parsed.path != '/feed':
            self._send(404, '{"error":"not found"}', 'application/json')
            return

        qs = urllib.parse.parse_qs(parsed.query)
        target = (qs.get('url') or [''])[0]
        if not target:
            self._send(400, '{"error":"url parameter required"}',
                       'application/json')
            return

        # 허용 도메인 검사
        try:
            host = urllib.parse.urlparse(target).netloc.lower()
        except Exception:
            self._send(400, '{"error":"invalid url"}', 'application/json')
            return

        if host not in ALLOWED_HOSTS:
            self._send(403, '{"error":"host not allowed: %s"}' % host,
                       'application/json')
            return

        # 캐시 확인
        cached = cache_get(target)
        if cached is not None:
            self._send(200, cached)
            return

        # 실제 피드 요청
        try:
            req = urllib.request.Request(
                target,
                headers={
                    'User-Agent': (
                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                        'AppleWebKit/537.36 (KHTML, like Gecko) '
                        'Chrome/120.0 Safari/537.36'
                    ),
                    'Accept': ('application/rss+xml, application/xml, '
                               'text/xml, */*'),
                    'Accept-Encoding': 'gzip, deflate',
                    'Accept-Language': 'ko-KR,ko;q=0.9',
                },
            )
            with urllib.request.urlopen(req, timeout=TIMEOUT) as res:
                raw = res.read()
                if res.headers.get('Content-Encoding') == 'gzip':
                    raw = gzip.GzipFile(fileobj=io.BytesIO(raw)).read()

            cache_put(target, raw)
            self._send(200, raw)

        except urllib.error.HTTPError as e:
            self._send(502, '{"error":"upstream HTTP %d"}' % e.code,
                       'application/json')
        except socket.timeout:
            self._send(504, '{"error":"upstream timeout"}',
                       'application/json')
        except Exception as e:
            self._send(502, '{"error":"%s"}' % str(e)[:120],
                       'application/json')


class ThreadedServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == '__main__':
    print(f'RSS proxy listening on 0.0.0.0:{PORT}', flush=True)
    print(f'allowed hosts: {len(ALLOWED_HOSTS)}', flush=True)
    ThreadedServer(('0.0.0.0', PORT), Handler).serve_forever()
