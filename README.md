# Tokeni Bar

**한국어** | [English](README.en.md)

[![CI](https://github.com/90ms/tokeni-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/90ms/tokeni-bar/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/90ms/tokeni-bar)](https://github.com/90ms/tokeni-bar/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<p align="center">
  <img src="packaging/AppIcon.png" width="144" alt="Tokeni Bar 도트 앱 아이콘" />
</p>

AI 코딩 에이전트의 **토큰·쿼터 상태**를 메뉴바에서 확인하고, 실제 토큰
사용량으로 픽셀 동반자 **ByteBot**을 키우는 macOS 앱입니다.

## 빠른 설치

```bash
brew install --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app
tokeni-bar
```

| 요구 사항 | 내용 |
|---|---|
| 운영체제 | macOS 14 Sonoma 이상 |
| 빌드 도구 | 최신 Xcode Command Line Tools (`xcode-select --install`) |
| 에이전트 | Codex, Claude Code, Grok, Gemini CLI, OpenCode 중 하나 이상 |

Formula는 사용자 Mac에서 앱을 빌드하고 ad-hoc 서명합니다. Apple Developer
ID와 전체 Xcode 앱은 필요하지 않습니다.

Homebrew가 신뢰를 요구하면 전체 tap 대신 Formula만 신뢰하세요.

```bash
brew trust --formula 90ms/tap/tokeni-bar
brew install --formula tokeni-bar
```

## 무엇을 볼 수 있나요?

| 영역 | 제공하는 정보 |
|---|---|
| 메뉴바 | 가장 낮은 쿼터, 선택 제공자, 월 예상 비용 또는 ByteBot 상태 |
| 사용량 | 제공자별 남은 쿼터, 초기화 시각, 토큰과 참고 비용 |
| 기록 | 최근 24시간·7일·30일의 로컬 집계 |
| 알림 | 제공자별 낮은 잔여량과 월 예산 |
| ByteBot | 성장 단계, 등급, 오늘 에너지, 친밀도와 행동 |
| 도감 | 13개 외형, 완료 세대, 최고 기록과 진화 보장 |

확인할 수 없는 값은 추정하지 않고 **사용 불가** 또는 **오래됨**으로 표시합니다.
쿼터 비율은 항상 **남은 비율**이며 비용은 구독 청구액이 아닌 API 환산
참고값입니다.

## ByteBot 성장 방식

### 1. 토큰이 성장 에너지로 바뀝니다

오늘 확인된 토큰 합계를 `T`라고 할 때:

```text
T = 0  → 0
T > 0  → floor(32 × log2(1 + T / 25,000))
```

| 오늘 사용한 토큰 | 오늘 성장 에너지 |
|---:|---:|
| 10,000 | 15 |
| 25,000 | 32 |
| 50,000 | 50 |
| 100,000 | 74 |
| 250,000 | 110 |
| 500,000 | 140 |
| 1,000,000 | 171 |

일일 상한은 없습니다. 토큰을 더 사용할수록 계속 성장하지만 높은 사용량
구간에서는 에너지 증가 속도가 완만해집니다. 같은 누적값은 여러 번 새로고침해도
한 번만 반영됩니다.

### 2. 네 단계로 진화합니다

| 단계 | 필요한 누적 에너지 | 도달하면 |
|---|---:|---|
| 알 | 0 | 일반 등급으로 시작 |
| 부화 | 80 | 첫 등급 진화 판정 |
| 주니어 | 280 | 두 번째 등급 진화 판정 |
| 성체 | 800 | 마지막 등급 진화 판정 |
| 성체 이후 | 800 초과분 | 친밀도 에너지로 기록 |

작업 중·쿼터 부족·토닥하기·장시간 비활동은 ByteBot의 동작을 바꾸지만 성장
에너지를 추가하지는 않습니다.

### 3. 진화할 때 등급이 오를 수 있습니다

등급은 `일반 → 희귀 → 영웅 → 전설` 순서이며 한번 오른 등급은 내려가지
않습니다.

| 현재 등급 | 유지 | 희귀 | 영웅 | 전설 |
|---|---:|---:|---:|---:|
| 일반 | 75.0% | 21.0% | 3.8% | 0.2% |
| 희귀 | 86.0% | - | 13.0% | 1.0% |
| 영웅 | 97.0% | - | - | 3.0% |
| 전설 | 100% | - | - | - |

일반 알에서 시작해 천장 없이 성체가 되었을 때의 최종 분포는 다음과 같습니다.

| 일반 | 희귀 | 영웅 | 전설 |
|---:|---:|---:|---:|
| 42.2% | 40.9% | 15.5% | 1.4% |

### 4. 낮은 등급이 계속되면 진화를 보장합니다

| 보장 등급 | 최대 완료 세대 |
|---|---:|
| 희귀 이상 | 3세대 |
| 영웅 이상 | 7세대 |
| 전설 | 16세대 |

성체의 여정을 마쳐야 보장 횟수가 진행됩니다. 성체 전에 새 알로 바꾸면 기존
보장은 유지되지만 횟수는 앞당겨지지 않습니다.

### 5. 도감과 새 알

| 선택 | 결과 | 유지되는 것 |
|---|---|---|
| 성체와 계속 지내기 | 추가 에너지가 친밀도로 누적 | 현재 외형과 모든 기록 |
| 성체 여정 마치기 | 최종 등급·친밀도를 기록하고 새 알 시작 | 도감과 진화 보장 |
| 성체 전 이별하기 | 현재 성장 에너지를 버리고 새 알 시작 | 도감과 기존 진화 보장 |

도감은 공통 알 1개와 부화·주니어·성체의 네 등급 외형 12개, 총 13개입니다.
높은 등급을 늦게 만난 경우 해당 등급의 이전 단계 외형도 **계보**로 해금됩니다.

메뉴의 격자 버튼 또는
**설정 → Tokeni → ByteBot 도감 열기**에서 모든 기록을 확인할 수 있습니다.
전체 규칙은 [ByteBot 성장과 도감](docs/bytebot.ko.md)에 정리되어 있습니다.

## 제공자 지원

| 제공자 | 계정 쿼터 | 토큰·비용 표시 | ByteBot 성장 기준 |
|---|---|---|---|
| Codex | 주간·모델별 한도와 충전권 | 일일·이번 달·누적 토큰, 참고 비용 | 확인된 일일 합계 또는 세션 증가분 |
| Claude Code | 5시간·주간·모델별 한도 | 로컬 일일 토큰, 캐시 반영 참고 비용 | 확인된 일일 합계 |
| Grok | 미지원 | 현재 로컬 세션 컨텍스트 | 첫 관측 이후 세션 증가분 |
| Gemini CLI | 미지원 | 최근 로컬 세션 토큰 | 첫 관측 이후 세션 증가분 |
| OpenCode | 미지원 | 로컬 누적 토큰과 기록 비용 | 첫 관측 이후 누적 증가분 |

세션·누적 카운터는 첫 값을 기준선으로 삼아 과거 사용량이 새 성장량으로
지급되는 것을 막습니다. 자세한 집계 기준은
[사용량 표시와 성장 집계](docs/usage.ko.md)를 참고하세요.

## 처음 사용하기

| 순서 | 할 일 |
|---:|---|
| 1 | 사용할 CLI를 터미널에서 한 번 실행하고 로그인 |
| 2 | Tokeni Bar를 실행하고 메뉴바의 차트 아이콘 열기 |
| 3 | **설정 → 일반**에서 제공자와 메뉴바 표시 방식 선택 |
| 4 | Claude 계정 쿼터가 필요하면 **제공자 연결 → 연결** 선택 |
| 5 | 에이전트를 사용하고 ByteBot 성장 확인 |

## 업데이트와 제거

| 작업 | 명령 또는 위치 |
|---|---|
| 앱에서 업데이트 | **설정 → 일반 → 앱 업데이트 → 설치 후 재실행** |
| 터미널 업데이트 | `brew update && brew upgrade --formula 90ms/tap/tokeni-bar` |
| 앱 링크 갱신 | `tokeni-bar --install-app` |
| 앱만 제거 | `tokeni-bar --uninstall-app` |
| Formula 제거 | `brew uninstall --formula tokeni-bar` |

앱은 6시간마다 새 안정 버전을 확인하지만, 사용자가 버튼을 누르기 전에는 설치를
시작하지 않습니다. 이전 Cask 설치본은
[Homebrew 이전 안내](docs/HOMEBREW.ko.md#migrating-from-the-cask)를
참고하세요.

GitHub ZIP으로 직접 설치하려면
[최신 릴리스](https://github.com/90ms/tokeni-bar/releases/latest)를 이용할 수
있습니다. 첫 실행이 차단되면 **시스템 설정 → 개인정보 보호 및 보안**에서
허용하세요.

## 개인정보 보호

| 저장하는 정보 | 저장하지 않는 정보 |
|---|---|
| 집계 쿼터·토큰·예상 비용 | 프롬프트와 모델 응답 |
| ByteBot 단계·등급·도감·보장 | 액세스 토큰·리프레시 토큰·쿠키 |
| 중복 지급 방지용 로컬 체크포인트 | 계정 비밀정보와 서버 텔레메트리 |

사용 기록은 Mac에 30일 동안 보관합니다. ByteBot 상태와 토큰 체크포인트는
분리되어 있으며 분석 도구나 원격 게임 서버를 사용하지 않습니다.

## 문제 해결

| 증상 | 확인할 내용 |
|---|---|
| 앱 창이 보이지 않음 | Dock이 아닌 메뉴바 오른쪽의 차트 아이콘 확인 |
| 제공자가 사용 불가 | 해당 CLI의 설치·로그인 확인 후 한 번 실행 |
| Homebrew 신뢰 오류 | `brew trust --formula 90ms/tap/tokeni-bar` 실행 |
| 이전 ByteBot 진행이 없음 | v0.8.0부터 토큰 기반 새 알로 시작하며 설정·사용 기록은 유지 |

## 개발

```bash
git clone https://github.com/90ms/tokeni-bar.git
cd tokeni-bar
./Scripts/test.sh
swift build
./Scripts/package_app.sh
open "dist/Tokeni Bar.app"
```

기여 규칙은 [AGENTS.md](AGENTS.md), 배포 흐름은
[Homebrew 배포 안내](docs/HOMEBREW.ko.md)를 참고하세요.

## 라이선스

[MIT](LICENSE)
