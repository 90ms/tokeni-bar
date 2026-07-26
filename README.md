# Agents Status Bar

**한국어** | [English](README.en.md)

[![CI](https://github.com/90ms/agents-status-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/90ms/agents-status-bar/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/90ms/agents-status-bar)](https://github.com/90ms/agents-status-bar/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<img src="docs/agents-status-bar-icon.png" alt="Agents Status Bar 아이콘" width="128">

AI 코딩 에이전트의 쿼터, 토큰 활동 및 API 환산 참고 비용을 한곳에서 확인하는
개인정보 보호 중심의 macOS 메뉴바 앱입니다.

<p align="center">
  <img src="docs/agents-status-bar.png" width="500" alt="Codex, Claude Code 및 Gemini CLI 사용량을 보여주는 Agents Status Bar" />
</p>

> 현재 `main` UI를 기준으로 샘플 값만 사용한 이미지이며 실제 계정정보는
> 포함하지 않습니다.

Agents Status Bar는 기존 CLI 로그인을 재사용합니다. 프롬프트, 응답, 액세스 토큰,
리프레시 토큰 또는 쿠키를 저장하지 않습니다. 쿼터 비율은 항상 **남은 비율**이며,
비용은 구독 청구액이 아닌 참고값입니다.

## 주요 기능

- Codex와 Claude의 쿼터, 초기화 시각 및 계정 상태 표시
- 확인 가능한 계정 활동과 로컬 토큰·비용 기록 통합
- 메뉴바에 가장 낮은 잔여량, 선택 제공자 또는 월 예상 비용 표시
- 프롬프트나 응답을 읽지 않고 파일 변경 시각으로 로컬 세션 활동 감지
- 24시간, 7일 및 30일 집계 기록을 로컬에 보관
- 제공자별 잔여량 및 월 예산 알림
- 한국어·영어, 달러·원화, 컴팩트 모드 및 로그인 시 실행 지원

## 설치

### 요구 사항

- macOS 14 Sonoma 이상
- Apple Silicon
- Codex, Claude Code, Grok, Gemini CLI 또는 OpenCode 중 하나 이상 설치 및 로그인

### Homebrew

```bash
brew install --cask 90ms/tap/agents-status-bar
open -a "Agents Status Bar"
```

완전한 이름으로 설치하면 `90ms/tap` 저장소가 자동으로 추가됩니다. Tap 신뢰가
필요한 Homebrew 버전에서는 전체 저장소가 아니라 이 Cask만 신뢰합니다.

### 직접 다운로드

[최신 GitHub Release](https://github.com/90ms/agents-status-bar/releases/latest)에서
ZIP을 내려받아 압축을 풀고 `Agents Status Bar.app`을 `/Applications`로 옮깁니다.

Developer ID 서명을 구성하기 전까지 릴리스는 ad-hoc 서명을 사용합니다. macOS가
첫 실행을 차단하면 **시스템 설정 → 개인정보 보호 및 보안**에서 앱 실행을
허용하세요. Gatekeeper를 전체적으로 비활성화할 필요는 없습니다.

## 첫 실행

1. 모니터링할 CLI를 터미널에서 한 번 실행해 로그인합니다.
2. Agents Status Bar를 열고 메뉴바 오른쪽의 차트 아이콘을 선택합니다.
3. **설정 → 일반**에서 사용할 제공자를 켜고 메뉴바 표시 방식을 선택합니다.
4. Claude Code 계정 쿼터를 사용하려면 **제공자 연결**에서 **연결**을 선택하고
   키체인 요청을 승인합니다.

설치되지 않았거나 로그인되지 않은 제공자, 현재 CLI 형식에서 지원하지 않는
제공자는 임의의 값을 표시하지 않고 사용 불가 상태로 남습니다.

## 업데이트와 제거

```bash
# 업데이트
brew update
brew upgrade --cask agents-status-bar

# 설정과 기록을 남기고 앱만 제거
brew uninstall --cask agents-status-bar

# 앱, 설정 및 로컬 집계 기록을 모두 제거
brew uninstall --cask --zap agents-status-bar
```

앱은 6시간마다 GitHub Releases에서 새 안정 버전을 확인하고 링크를 표시합니다.
Homebrew 설치본의 다운로드와 설치는 Homebrew가 담당합니다.

## 제공자 지원

| 제공자 | 계정 쿼터 | 토큰 및 비용 데이터 |
|---|---|---|
| Codex | 주간·모델별 한도와 사용 가능한 한도 초기화 충전권 | 실험적인 Codex app-server에서 가져온 최근 일일·이번 달·누적 계정 토큰과 거친 API 환산 참고값 |
| Claude Code | 5시간, 주간 및 모델별 한도 | 중복 제거된 로컬 일일 토큰과 캐시 유형을 반영한 추정 |
| Grok | 현재 미지원 | 현재 로컬 세션 컨텍스트, 비용 추정 미지원 |
| Gemini CLI | 현재 미지원 | 최근 로컬 세션 토큰, 비용 추정 미지원 |
| OpenCode | 현재 미지원 | 로컬 집계 토큰과 기록된 비용 |

Codex·Claude 계정 엔드포인트와 로컬 CLI 파일 형식은 공개 호환성 규격이 아니므로
변경될 수 있습니다. 검증된 데이터를 가져오지 못하면 값을 만들지 않고 오래된
상태나 사용 불가 상태를 표시합니다.

Codex 버킷, Claude 메뉴바 쿼터 및 비용 추정 방식은
[사용량 표시 안내](docs/usage.ko.md)를 참고하세요.

## 개인정보 보호

- 프롬프트와 모델 응답을 표시하거나 보관하지 않습니다.
- 인증 토큰, 리프레시 토큰 및 쿠키를 로그나 앱 저장소에 기록하지 않습니다.
- 명시적인 승인으로 가져온 Claude 인증정보는 만료되거나 앱이 종료될 때까지만
  메모리에 유지합니다.
- 활동 감지는 프롬프트나 응답이 아닌 파일 메타데이터만 읽습니다.
- 기록에는 집계 비율, 토큰 합계 및 예상 비용만 포함하며 30일 동안 보관합니다.
- 복사 가능한 진단 정보에서 인증정보, 제공자 상세 내용 및 파일 경로를 제외합니다.
- 분석 도구나 텔레메트리를 사용하지 않습니다.

## 문제 해결

### 제공자가 사용 불가로 표시됨

해당 CLI를 한 번 실행하고 설치 및 로그인 상태를 확인하세요. 사용하지 않는
제공자는 **설정 → 일반**에서 끌 수 있습니다.

Claude Code의 OAuth 인증정보가 macOS 키체인에 있으면 사용자가 직접 **연결**을
선택해야 할 수 있습니다. 백그라운드 갱신은 키체인 승인 창을 열지 않습니다.

### 앱은 실행 중이지만 창이 보이지 않음

Agents Status Bar는 Dock이 아닌 메뉴바에서 동작합니다. macOS 메뉴바 오른쪽의
차트 아이콘을 확인하세요.

### Homebrew에서 신뢰하지 않는 tap 오류가 발생함

위의 완전한 이름으로 설치하세요. 이미 추가한 tap의 Cask만 직접 신뢰하려면:

```bash
brew trust --cask 90ms/tap/agents-status-bar
brew install --cask agents-status-bar
```

### 비용이 구독 청구액과 다름

비용은 각 제공자가 제공하는 토큰 상세 정보와 공개 API 단가로 계산한 거친
API 환산 참고값입니다. API 청구서나 Codex, ChatGPT, Claude 또는 Grok 구독
청구액이 아닙니다.

## 소스에서 빌드

```bash
git clone https://github.com/90ms/agents-status-bar.git
cd agents-status-bar
./Scripts/test.sh
swift build
./Scripts/package_app.sh
open "dist/Agents Status Bar.app"
```

`Scripts/package_app.sh`는 기본적으로 ad-hoc 서명을 사용합니다. 다른 로컬 서명
인증서를 사용하려면 `APP_SIGN_IDENTITY`를 설정하세요.

배포 관리 방법은 [Homebrew 배포 가이드](docs/HOMEBREW.ko.md), 기여 규칙은
[AGENTS.md](AGENTS.md)를 참고하세요.

## 라이선스

[MIT](LICENSE)
