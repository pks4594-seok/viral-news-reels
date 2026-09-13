# Trend Reel Studio

> 헤드라인이 릴스로 태어나는 곳 — 뉴스 수집부터 숏폼 발행까지, 1인 미디어 공장

국내 언론사 RSS를 실시간 수집하고, 조회수 높은 숏폼 크리에이터의 편집 문법을
학습해 도출한 **바이럴 공식**으로 릴스 스크립트·자막·메타데이터를 자동 생성합니다.

**패키지**: `com.trendreelstudio.creator` · **Flutter** 3.35.4 / **Dart** 3.9.2

---

## 화면 구성

5개 탭이 하나의 컨베이어를 이룹니다.

| 탭 | 역할 |
|---|---|
| **뉴스** | 11개 언론사 RSS 실시간 수집 · 트렌드 점수 링 · 관심도 스파크라인 |
| **트렌드** | 급상승 키워드 / 벤치마크 크리에이터 학습 / 도출된 바이럴 공식 |
| **스튜디오** | 생성된 릴스를 9:16 세로 카드로 관리 |
| **업로드** | 플랫폼별 발행 큐 · 예약 발행 · 진행률 추적 |
| **내정보** | 플랫폼 계정 연동 · 자동화 파이프라인 · 뉴스 소스 관리 |

---

## 핵심 엔진

### 1. 뉴스 수집 (`services/rss_parser.dart`)

RSS 2.0 / Atom 1.0 / RDF 세 형식을 통합 처리합니다.

- **날짜 파싱** — ISO 8601 + RFC 822 (타임존 오프셋 보정 포함)
- **이미지 추출** — `media:content` → `media:thumbnail` → `enclosure` →
  `image` → description 내 `img` 태그, 5경로 순차 탐색
- **본문 정제** — CDATA · HTML 태그 · 엔티티(숫자 엔티티 포함) 제거
- **플랫폼 분기** — 네이티브는 직접 호출, 웹은 CORS 프록시 3단 폴백

검증된 피드 11개: 연합뉴스(정치·경제·산업·스포츠·연예·사회), 전자신문,
ZDNet Korea, 한겨레, 머니투데이, 경향신문

### 2. 트렌드 스코어 (`services/news_feed_service.dart`)

4개 신호를 가중 합산해 0~100점을 산출합니다.

```
신선도 30% + 관심도 상승기울기 30% + 제목 후킹력 25% + 카테고리 숏폼친화도 15%
```

**후킹력 평가 항목** — 수치 포함, 의문/감탄 부호, 감정 강도어 24종,
발언 인용, 적정 길이(18~48자)

**부가 처리** — 키워드 120개 가중 매칭 기반 카테고리 자동 분류,
한국어 조사 제거 키워드 추출, 통신사 서두 `(서울=연합뉴스) OO 기자 =` 자동 제거

### 3. 바이럴 패턴 학습 (`services/viral_learning_service.dart`)

벤치마크 크리에이터의 상위 조회수 클립에서 지표를 추출합니다.

- 시청 유지율 · 컷 밀도(cuts/sec) · 후킹 문구 유형 · 자막 스타일 · 영상 길이
- 유지율 가중 클러스터링 → 5개 공식 도출

| 공식 | 신뢰도 | 유지율 | 권장 스펙 |
|---|---|---|---|
| 감탄 리액션형 | 93% | 89% | 21초 / 9컷 |
| 속보 임팩트형 | 91% | 84% | 28초 / 13컷 |
| 숫자 충격형 | 88% | 79% | 32초 / 14컷 |
| 결론 선행형 | 82% | 72% | 42초 / 11컷 |
| 의문 유발형 | 79% | 68% | 38초 / 12컷 |

**자동 매칭** — 스포츠·연예 → 감탄형, 경제+수치 → 숫자형,
30분 내 속보 → 즉시성 우선 오버라이드

### 4. 릴스 재생 (`services/reel_player_controller.dart`)

`Ticker`로 프레임마다 경과 시간을 누적해 절대 시각 기반 타임라인을
구동합니다. 릴스 길이가 20~45초이고 씬·자막이 각자 다른 구간을
점유하므로, AnimationController보다 절대 시각 제어가 정확합니다.

- **켄번스 모션** — 줌 인/아웃, 좌우 팬, 상하 슬라이드, 대각 이동,
  고정(미세 호흡) 6종을 `easeInOutSine`으로 보간
- **씬 크로스페이드** — 전환 직전 0.35초 구간에서 다음 씬을 겹침
- **자막 동기화** — 타임코드 기준 현재 자막 추출, 0.28초 페이드·슬라이드 인
- **공식별 자막 배치** — 감탄형은 중앙 네온 글로우, 결론형은 상단 요약,
  속보형은 하단 박스
- **탐색** — 진행률/초/씬/자막 단위 seek, 반복 재생 토글
- **방어 로직** — 탭 전환 복귀 시 과도한 델타(>200ms)를 무시해 점프 방지

**플레이어 UI** (`widgets/reel_player.dart`, `widgets/reel_stage.dart`)

- 인라인 플레이어 — 탭 재생/일시정지, 드래그 탐색, 씬 이동 버튼
- 전장 몰입 재생 (`screens/reel_playback_screen.dart`) —
  세로 스와이프로 릴스 전환, 좌우 25% 탭으로 씬 이동,
  길게 눌러 UI 숨기기
- 자막 타임라인이 재생 위치를 실시간 추종하며 현재 자막을 강조,
  항목 탭 시 해당 시점으로 탐색

### 5. 릴스 생성 (`services/reel_generator_service.dart`)

뉴스 1건을 5단계로 변환합니다.

1. **공식 매칭** — 카테고리·신선도 기반 최적 공식 선택
2. **후킹 제목** — 템플릿 + 키워드 주입, 수치 끌어올림, 46자 방어
3. **자막 스크립트** — 문장 분해 → 컷 배분 → 타임코드 부여
   (후킹 2.2초, 나머지 균등). 뉴스체를 숏폼체로 압축하고 어절 경계에서 절단
4. **씬 구성** — 이미지 + 카메라 무브(줌인·팬·켄번스) 배치
5. **플랫폼별 메타** — YouTube 96자+검색키워드 / TikTok 38자+인라인태그 /
   Blog SEO+스크립트 전문

---

## 프로젝트 구조

```
lib/
├── main.dart
├── models/
│   ├── news_article.dart       뉴스 기사 · 소스 · 카테고리
│   ├── viral_pattern.dart      벤치마크 크리에이터 · 클립 · 공식 · 키워드
│   ├── reel_project.dart       릴스 프로젝트 · 자막 · 씬 · 제작 단계
│   └── upload_task.dart        업로드 작업 · 플랫폼 계정 · 상태
├── services/
│   ├── rss_parser.dart         RSS/Atom/RDF 파서
│   ├── news_feed_service.dart  수집 + 분류 + 트렌드 스코어
│   ├── viral_learning_service.dart  패턴 학습 + 공식 도출
│   ├── reel_generator_service.dart  릴스 생성 파이프라인
│   └── reel_player_controller.dart  재생 타임라인 컨트롤러
├── state/
│   └── app_state.dart          Provider 전역 상태
├── screens/
│   ├── app_shell.dart          5탭 셸 + 글래스 내비게이션
│   ├── news_screen.dart
│   ├── trend_screen.dart
│   ├── studio_screen.dart
│   ├── reel_detail_screen.dart
│   ├── reel_playback_screen.dart   전장 몰입 재생
│   ├── upload_screen.dart
│   └── profile_screen.dart
├── widgets/
│   ├── common.dart             글래스 카드 · 네온 버튼 · 스파크라인 · 파형
│   ├── reel_stage.dart         9:16 무대 (켄번스 + 자막 합성)
│   ├── reel_player.dart         인라인 플레이어 + 컨트롤 바
│   └── platform_picker.dart    플랫폼 선택 + 예약 시각
└── theme/
    └── app_theme.dart          네온 다크 디자인 시스템
```

---

## 실행

```bash
flutter pub get

# 웹 프리뷰 — RSS 프록시를 먼저 띄웁니다
# (브라우저 CORS 정책으로 외부 피드 직접 호출이 불가하므로 필요합니다)
python3 tools/rss_proxy.py &

flutter build web --release --dart-define=RSS_PROXY=http://localhost:5061
python3 -m http.server 5060 --directory build/web --bind 0.0.0.0

# 안드로이드
# 안드로이드는 CORS 제약이 없어 프록시 없이 언론사 서버를 직접 호출합니다
flutter build apk --release          # 직접 설치용
flutter build appbundle --release    # Google Play 업로드용
```

**릴리스 서명** — `android/key.properties`에 keystore 정보를 작성합니다.
(이 파일과 `*.jks`는 `.gitignore`로 저장소에서 제외됩니다.)

```properties
storePassword=<비밀번호>
keyPassword=<비밀번호>
keyAlias=<별칭>
storeFile=<keystore 경로>
```

---

## 구현 범위

### 완성된 것

- 국내 언론사 RSS 실시간 수집 (11개 피드 검증 완료)
- 트렌드 스코어 산출 · 카테고리 자동 분류 · 키워드 추출
- 바이럴 패턴 학습 및 공식 도출
- 릴스 스크립트 · 자막 타임코드 · 씬 구성 · 플랫폼별 메타데이터 생성
- **릴스 재생** — 켄번스 모션 + 타이밍 자막 + 씬 크로스페이드
- **전장 몰입 재생** — 세로 스와이프 전환, 탭 제어
- 업로드 큐 · 예약 발행 관리 · 플랫폼 계정 3단 상태 관리
- 뉴스 원문 열기 (Android `Intent.ACTION_VIEW`)

### 연동이 필요한 것

| 기능 | 필요 조건 |
|---|---|
| **YouTube 발행** | Google Cloud Console → YouTube Data API v3 → OAuth 2.0 클라이언트 ID |
| **TikTok 발행** | TikTok for Developers → Content Posting API 권한 승인 |
| **MP4 파일 내보내기** | 현재는 앱 내 재생만 지원. 파일 출력은 프레임 캡처 + FFmpeg 합성 필요 |
| **TTS 내레이션** | 음성 합성 API 연동 (현재는 자막만 표시) |

계정 카드는 **① 미연동 → ② 인증 필요 → ③ 인증 완료** 3단으로 상태를
구분하며, 자격증명이 없으면 발행을 시도하지 않고 사유를 안내합니다.
발행 건수·조회수는 이 앱을 통해 실제 발행한 결과만 집계합니다.

---

## 의존성

```yaml
provider: 6.1.5+1            # 상태 관리
http: 1.5.0                  # RSS 수집
xml: ^6.6.1                  # RSS/Atom 파싱
url_launcher: ^6.3.2         # 원문 열기 · OAuth 리다이렉트
shared_preferences: 2.5.3    # 설정 저장
hive: 2.2.3                  # 로컬 문서 DB
hive_flutter: 1.1.0
intl: ^0.20.2                # 날짜 형식
```
