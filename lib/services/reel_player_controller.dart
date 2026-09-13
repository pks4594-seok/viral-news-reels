import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../models/reel_project.dart';

/// 릴스 재생 컨트롤러
///
/// [Ticker]로 프레임마다 경과 시간을 누적해 타임라인을 구동합니다.
/// AnimationController를 쓰지 않는 이유는, 릴스 길이가 20~45초로 길고
/// 씬·자막이 각자 다른 구간을 점유하므로 절대 시각(초) 기반 제어가
/// 더 정확하기 때문입니다.
///
/// 제공하는 것:
///   · 재생 / 일시정지 / 정지 / 탐색(seek)
///   · 현재 씬 인덱스와 씬 내부 진행률 (켄번스 모션용)
///   · 현재 자막 라인과 표시 진행률 (등장 애니메이션용)
///   · 반복 재생 토글
class ReelPlayerController extends ChangeNotifier {
  ReelPlayerController({required this.reel, TickerProvider? vsync}) {
    _totalMs = (reel.durationSec * 1000).clamp(1000, 600000);
    if (vsync != null) attach(vsync);
  }

  final ReelProject reel;

  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  /// 현재 재생 위치 (밀리초)
  double _positionMs = 0;

  /// 총 길이 (밀리초)
  late final int _totalMs;

  bool _playing = false;
  bool _loop = true;
  bool _disposed = false;

  // ── 조회 ────────────────────────────────────────────

  bool get isPlaying => _playing;
  bool get isLooping => _loop;
  bool get isFinished => !_loop && _positionMs >= _totalMs;

  /// 현재 재생 위치 (초)
  double get positionSec => _positionMs / 1000.0;

  /// 총 길이 (초)
  double get totalSec => _totalMs / 1000.0;

  /// 전체 진행률 0~1
  double get progress => (_positionMs / _totalMs).clamp(0.0, 1.0);

  /// "0:12 / 0:28" 형태
  String get timeLabel => '${_fmt(positionSec)} / ${_fmt(totalSec)}';

  static String _fmt(double sec) {
    final s = sec.floor();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ── 씬 ─────────────────────────────────────────────

  /// 현재 재생 중인 씬 인덱스
  int get sceneIndex {
    if (reel.scenes.isEmpty) return 0;
    var acc = 0.0;
    for (var i = 0; i < reel.scenes.length; i++) {
      acc += reel.scenes[i].durationSec * 1000;
      if (_positionMs < acc) return i;
    }
    return reel.scenes.length - 1;
  }

  /// 현재 씬
  ReelScene? get currentScene {
    if (reel.scenes.isEmpty) return null;
    return reel.scenes[sceneIndex];
  }

  /// 현재 씬 내부 진행률 0~1 — 켄번스 모션 보간에 사용
  double get sceneProgress {
    if (reel.scenes.isEmpty) return 0;
    var acc = 0.0;
    for (var i = 0; i < reel.scenes.length; i++) {
      final dur = reel.scenes[i].durationSec * 1000;
      if (_positionMs < acc + dur) {
        return dur <= 0 ? 0 : ((_positionMs - acc) / dur).clamp(0.0, 1.0);
      }
      acc += dur;
    }
    return 1.0;
  }

  /// 다음 씬 (크로스페이드 프리로드용)
  ReelScene? get nextScene {
    final i = sceneIndex + 1;
    return i < reel.scenes.length ? reel.scenes[i] : null;
  }

  /// 씬 전환 직전 크로스페이드 비율 (마지막 0.35초 구간)
  double get crossfade {
    final scene = currentScene;
    if (scene == null || nextScene == null) return 0;
    final remainMs = scene.durationSec * 1000 * (1 - sceneProgress);
    const fadeMs = 350.0;
    if (remainMs >= fadeMs) return 0;
    return ((fadeMs - remainMs) / fadeMs).clamp(0.0, 1.0);
  }

  // ── 자막 ────────────────────────────────────────────

  /// 현재 시각에 표시할 자막
  CaptionLine? get currentCaption {
    final t = positionSec;
    for (final c in reel.captions) {
      if (t >= c.startSec && t < c.endSec) return c;
    }
    // 마지막 자막은 끝까지 유지
    if (reel.captions.isNotEmpty && t >= reel.captions.last.startSec) {
      return reel.captions.last;
    }
    return null;
  }

  /// 현재 자막의 인덱스 (-1이면 없음)
  int get captionIndex {
    final c = currentCaption;
    if (c == null) return -1;
    return reel.captions.indexOf(c);
  }

  /// 자막 등장 진행률 0~1 — 첫 0.28초에 페이드·슬라이드 인
  double get captionEntry {
    final c = currentCaption;
    if (c == null) return 0;
    final elapsed = positionSec - c.startSec;
    const enterSec = 0.28;
    return (elapsed / enterSec).clamp(0.0, 1.0);
  }

  /// 자막 내부 진행률 — 글자 단위 노출(타이핑 효과)에 사용
  double get captionProgress {
    final c = currentCaption;
    if (c == null) return 0;
    final dur = c.endSec - c.startSec;
    if (dur <= 0) return 1;
    return ((positionSec - c.startSec) / dur).clamp(0.0, 1.0);
  }

  // ── 제어 ────────────────────────────────────────────

  /// Ticker 연결 — State의 initState에서 호출
  void attach(TickerProvider vsync) {
    _ticker?.dispose();
    _ticker = vsync.createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    if (_disposed) return;

    final deltaMs =
        (elapsed - _lastTick).inMicroseconds / 1000.0;
    _lastTick = elapsed;

    // 첫 프레임 또는 비정상 델타 방어 (탭 전환 복귀 시 큰 점프 방지)
    if (deltaMs <= 0 || deltaMs > 200) {
      notifyListeners();
      return;
    }

    _positionMs += deltaMs;

    if (_positionMs >= _totalMs) {
      if (_loop) {
        _positionMs = _positionMs % _totalMs;
      } else {
        _positionMs = _totalMs.toDouble();
        _playing = false;
        _ticker?.stop();
      }
    }

    notifyListeners();
  }

  void play() {
    if (_disposed || _playing) return;
    if (!_loop && _positionMs >= _totalMs) _positionMs = 0;
    _playing = true;
    _lastTick = Duration.zero;
    _ticker?.start();
    notifyListeners();
  }

  void pause() {
    if (_disposed || !_playing) return;
    _playing = false;
    _ticker?.stop();
    notifyListeners();
  }

  void toggle() => _playing ? pause() : play();

  void stop() {
    _playing = false;
    _ticker?.stop();
    _positionMs = 0;
    notifyListeners();
  }

  /// 진행률(0~1)로 탐색
  void seekRatio(double ratio) {
    _positionMs = (ratio.clamp(0.0, 1.0) * _totalMs);
    _lastTick = Duration.zero;
    notifyListeners();
  }

  /// 초 단위 탐색
  void seekSec(double sec) =>
      seekRatio((sec * 1000) / _totalMs);

  /// 특정 씬의 시작 지점으로 이동
  void seekScene(int index) {
    if (reel.scenes.isEmpty) return;
    final i = index.clamp(0, reel.scenes.length - 1);
    var acc = 0.0;
    for (var k = 0; k < i; k++) {
      acc += reel.scenes[k].durationSec * 1000;
    }
    _positionMs = acc;
    _lastTick = Duration.zero;
    notifyListeners();
  }

  /// 특정 자막의 시작 지점으로 이동
  void seekCaption(int index) {
    if (reel.captions.isEmpty) return;
    final i = index.clamp(0, reel.captions.length - 1);
    _positionMs = reel.captions[i].startSec * 1000;
    _lastTick = Duration.zero;
    notifyListeners();
  }

  void nextSceneJump() => seekScene(sceneIndex + 1);
  void prevSceneJump() => seekScene(sceneIndex - 1);

  void setLoop(bool v) {
    _loop = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _playing = false;
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}
