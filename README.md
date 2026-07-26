# Tokeni Bar

**한국어** | [English](README.en.md)

[![CI](https://github.com/90ms/tokeni-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/90ms/tokeni-bar/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/90ms/tokeni-bar)](https://github.com/90ms/tokeni-bar/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<img src="docs/tokeni-bar-icon.png" alt="Tokeni Bar 아이콘" width="128">

AI 코딩 에이전트의 토큰·쿼터 상태를 한눈에 보고, 실제 토큰 사용량으로 픽셀
동반자 **ByteBot**을 키우는 macOS 메뉴바 앱입니다.

<p align="center">
  <img src="docs/bytebot.png" width="160" alt="Tokeni Bar의 픽셀 동반자 ByteBot" />
</p>

<p align="center">
  <img src="docs/tokeni-bar.png" width="500" alt="여러 AI 코딩 에이전트 사용량을 보여주는 Tokeni Bar" />
</p>

> 화면 예시에는 실제 계정정보가 포함되지 않습니다.

## 설치

### 요구 사항

- macOS 14 Sonoma 이상
- 최신 Xcode Command Line Tools (`xcode-select --install`)
- Codex, Claude Code, Grok, Gemini CLI 또는 OpenCode 중 하나 이상

### Homebrew

```bash
brew install --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app
tokeni-bar
```

Formula는 소스를 사용자 Mac에서 빌드하고 ad-hoc 서명한 뒤
`~/Applications/Tokeni Bar.app`에 연결합니다. Apple Developer ID나 전체
Xcode 앱은 필요하지 않습니다.

Homebrew가 tap 신뢰를 요구하면 Formula만 신뢰하세요.

```bash
brew trust --formula 90ms/tap/tokeni-bar
brew install --formula tokeni-bar
```

### GitHub Release

[최신 릴리스](https://github.com/90ms/tokeni-bar/releases/latest)의 ZIP을 풀어
`Tokeni Bar.app`을 `/Applications`로 옮길 수도 있습니다. 현재 릴리스는 ad-hoc
서명이므로 첫 실행이 막히면 **시스템 설정 → 개인정보 보호 및 보안**에서 실행을
허용하세요.

## 처음 사용하기

1. 모니터링할 CLI를 터미널에서 한 번 실행해 로그인합니다.
2. Tokeni Bar를 실행하고 메뉴바 오른쪽의 차트 아이콘을 엽니다.
3. **설정 → 일반**에서 제공자와 메뉴바 표시 방식을 선택합니다.
4. Claude 계정 쿼터가 필요하면 **제공자 연결 → 연결**을 누르고 키체인 요청을
   승인합니다.
5. 에이전트를 사용하면 확인된 토큰 증가분이 ByteBot 성장 에너지로 바뀝니다.

지원하지 않거나 확인할 수 없는 값은 추정하지 않고 사용 불가 또는 오래된 상태로
표시합니다.

## 주요 기능

- Codex·Claude 계정 쿼터와 초기화 시각
- 지원되는 CLI의 로컬 토큰·비용 기록
- 가장 낮은 잔여량, 선택 제공자, 월 예상 비용 또는 ByteBot 상태를 메뉴바에 표시
- 24시간·7일·30일 로컬 사용 기록과 쿼터·예산 알림
- 토큰 사용량으로 성장하는 ByteBot, 네 단계 진화와 네 등급 외형
- 13개 외형 도감, 진화 보장, 세대별 최고 친밀도 기록
- 한국어·영어, 달러·원화, 컴팩트 모드, 로그인 시 실행

## ByteBot 키우기

ByteBot은 확인된 오늘의 토큰 합계가 많을수록 더 많은 성장 에너지를 얻습니다.
일일 상한은 없지만 초고사용량 구간에서는 에너지 증가 속도가 완만해집니다.

| 오늘 토큰 | 성장 에너지 |
|---:|---:|
| 10,000 | 15 |
| 25,000 | 32 |
| 100,000 | 74 |
| 500,000 | 140 |
| 1,000,000 | 171 |

에너지 `80`에 부화하고, `280`에 주니어, `800`에 성체가 됩니다. 진화할 때
`일반 → 희귀 → 영웅 → 전설` 등급이 확률적으로 오르며 한번 오른 등급은
내려가지 않습니다. 성체를 완성할수록 희귀·영웅·전설 진화를 보장하는 천장이
진행됩니다.

성체와 계속 지내며 친밀도를 쌓거나, 여정을 마치고 새 알을 받을 수 있습니다.
성체 전에도 다시 시작할 수 있지만 현재 에너지는 사라지고 천장은 진행되지
않습니다. 도감과 기존 천장은 유지됩니다.

메뉴의 격자 버튼 또는 **설정 → Tokeni → ByteBot 도감 열기**에서 외형,
완성 세대, 최고 등급, 친밀도와 진화 보장을 확인할 수 있습니다.

성장 공식, 등급 확률과 집계 기준은 [ByteBot 성장과 도감](docs/bytebot.ko.md)을
참고하세요.

## 제공자 지원

| 제공자 | 계정 쿼터 | 토큰·비용 표시 | ByteBot 성장 기준 |
|---|---|---|---|
| Codex | 주간·모델별 한도와 충전권 | 최근 일일·이번 달·누적 계정 토큰, API 환산 참고값 | 확인된 일일 합계, 없으면 현재 세션 증가분 |
| Claude Code | 5시간·주간·모델별 한도 | 중복 제거된 로컬 일일 토큰, 캐시 반영 추정 비용 | 확인된 일일 합계 |
| Grok | 미지원 | 현재 로컬 세션 컨텍스트 | 첫 관측 이후 세션 증가분 |
| Gemini CLI | 미지원 | 최근 로컬 세션 토큰 | 첫 관측 이후 세션 증가분 |
| OpenCode | 미지원 | 로컬 누적 토큰과 기록 비용 | 첫 관측 이후 누적 증가분 |

세션·누적 카운터는 처음 본 값을 기준선으로 삼으므로 기존 사용량을 새 성장량으로
오인하지 않습니다. 상세 규칙은 [사용량 표시 안내](docs/usage.ko.md)에 있습니다.

## 업데이트와 제거

```bash
# 업데이트
brew update
brew upgrade --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app

# 설정과 기록을 남기고 앱만 제거
tokeni-bar --uninstall-app
brew uninstall --formula tokeni-bar
```

앱은 6시간마다 새 안정 버전을 확인합니다. Formula 설치본은
**설정 → 일반 → 앱 업데이트 → 설치 후 재실행**으로 Homebrew 갱신, 빌드,
앱 교체와 재실행까지 할 수 있습니다. 설치는 버튼을 누르기 전에는 시작되지
않습니다.

이전 Cask에서 Formula로 옮기는 방법은
[Homebrew 배포 안내](docs/HOMEBREW.ko.md#migrating-from-the-cask)를 참고하세요.

## 개인정보 보호

- 프롬프트와 모델 응답을 표시하거나 보관하지 않습니다.
- 인증 토큰, 리프레시 토큰과 쿠키를 로그나 앱 저장소에 기록하지 않습니다.
- 사용 기록은 집계 쿼터·토큰·예상 비용만 30일 동안 로컬에 보관합니다.
- ByteBot 상태와 토큰 체크포인트는 분리하며 원문 콘텐츠는 어느 쪽에도 없습니다.
- 분석 도구나 서버 텔레메트리를 사용하지 않습니다.

Tokeni Bar는 기존 CLI 로그인을 재사용합니다. 쿼터 비율은 항상 **남은 비율**이고,
비용은 구독 청구액이 아닌 API 환산 참고값입니다.

## 문제 해결

### 앱은 실행 중이지만 창이 보이지 않음

Dock이 아닌 메뉴바에서 동작합니다. 메뉴바 오른쪽의 차트 아이콘을 확인하세요.

### 제공자가 사용 불가로 표시됨

해당 CLI를 한 번 실행하고 설치·로그인 상태를 확인하세요. 사용하지 않는 제공자는
**설정 → 일반**에서 끌 수 있습니다.

### 메뉴를 누르면 앱이 종료됨

`v0.7.2` 이전 설치본의 리소스 패키징 문제입니다. 터미널에서 갱신하세요.

```bash
brew update
brew upgrade --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app
tokeni-bar
```

### 기존 ByteBot 진행이 사라짐

`v0.8.0`은 활동 시간 기반의 시험판 진행을 제거하고 토큰 기반 게임으로
교체했습니다. 이전 펫 상태는 변환하지 않으며 새 알부터 시작합니다. 설정과 사용
기록은 그대로 유지됩니다.

## 개발

```bash
git clone https://github.com/90ms/tokeni-bar.git
cd tokeni-bar
./Scripts/test.sh
swift build
./Scripts/package_app.sh
open "dist/Tokeni Bar.app"
```

구조와 기여 규칙은 [AGENTS.md](AGENTS.md), 배포 흐름은
[Homebrew 배포 안내](docs/HOMEBREW.ko.md)를 참고하세요.

## 라이선스

[MIT](LICENSE)
