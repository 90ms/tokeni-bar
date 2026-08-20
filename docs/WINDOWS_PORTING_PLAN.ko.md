# Windows 포팅 계획

이 문서는 Tokeni Bar의 Windows 지원을 위한 살아 있는 구현 계획입니다.
각 단계는 이전 단계의 브랜치 위에 쌓는 stacked PR로 진행하고, PR이 완료될 때마다
이 문서의 상태·결정·검증 결과를 갱신합니다.

## 목표

- 기존 macOS 기능을 유지하면서 Windows 트레이 앱을 추가합니다.
- 사용량 모델, 파서, 기록, 비용 계산, Tokeni 성장 규칙과 펫 게임 규칙은 최대한
  공통 코어로 재사용합니다.
- provider별 Windows 경로와 CLI 동작은 확인된 값만 사용하고, 확인할 수 없으면
  `unavailable` 또는 `stale` 상태를 유지합니다.
- Windows 작업이 진행되는 동안 기존 macOS 빌드와 기능을 회귀시키지 않습니다.

## 목표 구조

```text
TokeniCore
  모델·파서·계산·기록·성장·펫 도메인

TokeniApplication
  사용량 갱신·공통 상태·알림 판정·설정 조정

TokeniPlatformMac
  macOS 경로·프로세스·알림·자동 시작·업데이트 어댑터

TokeniBar
  기존 macOS SwiftUI/AppKit UI

TokeniWindows
  Windows 트레이·창·알림·오버레이 UI
```

현재 `UsageStore`는 상태, 저장, 알림, 업데이트, 펫 조정과 macOS API를 함께
담고 있으므로 전체를 다른 UI에서 직접 재사용하지 않습니다. 공통 상태와 계산은
`TokeniApplication`으로 옮기고 macOS `ObservableObject`는 얇은 브리지로 남깁니다.

## Stacked PR 순서

모든 브랜치는 바로 앞 PR 브랜치에서 생성합니다. PR은 아래 순서로 리뷰·검증·병합하며,
각 PR을 제출하기 전에 문서와 계획 상태를 갱신합니다.

| 단계 | 브랜치 예시 | 범위 | 상태 |
|---|---|---|---|
| PR1 | `windows/01-porting-plan` | 이 계획과 공통화 결정 문서 | PR 생성 |
| PR2 | `windows/02-platform-contracts` | `TokeniCore` Windows 타깃, 플랫폼 프로토콜, 타깃 경계 | 진행 중 |
| PR3 | `windows/03-platform-infrastructure` | 앱 경로, 파일 저장, 프로세스 실행, CLI 탐색, SQLite | 대기 |
| PR4 | `windows/04-application-state` | `UsageStore` 공통 상태 추출과 macOS 브리지 | 대기 |
| PR5 | `windows/05-json-providers` | Copilot·Cline·Grok·Gemini 경로와 fixture | 대기 |
| PR6 | `windows/06-cli-providers` | Codex·Claude 실행 파일과 Windows CLI 계약 | 대기 |
| PR7 | `windows/07-sqlite-providers` | Antigravity·OpenCode SQLite reader와 fixture | 대기 |
| PR8 | `windows/08-windows-runtime` | Windows용 코어 실행/상태 전달 경계 | 대기 |
| PR9 | `windows/09-windows-tray-ui` | 트레이, 사용량, 설정, 기록, 진단 화면 | 대기 |
| PR10 | `windows/10-windows-services` | Toast 알림, 자동 시작, 업데이트, 기본 오버레이 | 대기 |
| PR11 | `windows/11-companion-overlay` | 펫 오버레이, 멀티 모니터, 클릭 통과, 접근성 | 대기 |
| PR12 | `windows/12-packaging-ci` | Windows 설치 패키지, CI, artifact, 배포 문서 | 대기 |
| PR13 | `windows/13-integration` | 최종 통합, macOS 회귀, Windows 실기기 검증 | 대기 |

PR5~PR7은 서로 다른 provider 디렉터리를 담당하지만, 이 저장소의 stacked 흐름에서는
순차적인 층으로 제출합니다. 코드 충돌이 없는 provider 작업은 에이전트가 병렬로
검토·준비할 수 있으나, 통합 브랜치에 적용할 때는 위 순서를 지킵니다.

## 공통화 경계

### 재사용할 영역

- `Sources/TokeniCore/Models`
- provider의 JSON·JSONL·프로토콜 파서와 집계 로직
- `Sources/TokeniCore/History`
- `Sources/TokeniCore/Companion`의 모델·규칙·엔진
- 가격·환율·진단 계산
- 제한된 파일 탐색과 안전한 JSONL 읽기

### 플랫폼 프로토콜로 분리할 영역

- `ApplicationDirectoriesProviding`: 앱 데이터·캐시·provider 루트
- `ExecutableLocating`: CLI와 `.exe`·`.cmd` 탐색
- `ProcessRunning`: 프로세스 실행·환경·취소·종료
- `ReadOnlySQLiteQuerying`: Antigravity/OpenCode DB 조회
- `SettingsStoring`: macOS UserDefaults와 Windows 저장 방식
- `NotificationDelivering`: macOS 알림과 Windows Toast
- `LaunchAtLoginManaging`: macOS ServiceManagement와 Windows 시작 등록
- `AppUpdateInstalling`: Homebrew 재설치와 Windows installer/MSIX/winget
- `MotionSettingsProviding`: 저전력·접근성 모션 정책

`ProcessRunning` 같은 기존 추상화는 유지하되, provider가 `Process()` 또는
`/usr/bin/sqlite3`를 직접 만들지 않도록 모든 OS I/O를 주입 가능한 경계로 옮깁니다.

## Provider 범위와 위험

| provider 그룹 | 주요 Windows 작업 | 위험 |
|---|---|---|
| Codex·Claude | CLI locator, Windows PATH, 양방향 프로세스, 로그인/쿼터 계약 | 높음 |
| Copilot·Cline·Grok·Gemini | `%APPDATA%`/`%LOCALAPPDATA%`와 VS Code 계열 경로, JSONL fixture | 중간 |
| Antigravity·OpenCode | Windows SQLite 실행 또는 내장 reader, WAL 검증 | 매우 높음 |

Gemini와 OpenCode는 구현·테스트가 있지만 현재 기본 `ProviderRegistry`에는 포함되지
않습니다. Windows 정식 지원 범위에서 이 둘을 포함할지는 PR2에서 결정하고 문서에
기록합니다.

## 에이전트 write set

공통 파일은 한 에이전트만 수정합니다.

- 플랫폼 기반 에이전트: `Package.swift`, `Sources/TokeniCore/Infrastructure`,
  `Sources/TokeniCore/Updates`의 공통 계약
- 상태 에이전트: `Sources/TokeniApplication`과 `Sources/TokeniBar/UsageStore.swift`
- provider 에이전트: 각 provider 디렉터리와 대응하는 테스트·fixture만
- Windows UI 에이전트: 새 `TokeniWindows` 프로젝트/디렉터리만
- 배포 에이전트: `packaging/windows`, PowerShell 스크립트, Windows CI job만
- 통합 담당: `ProviderRegistry`, `Package.swift` 최종 조정, 충돌 해결

`Package.swift`, `UsageStore.swift`, `ProviderRegistry`, `.github/workflows`는 여러
에이전트가 동시에 수정하지 않습니다.

## PR 완료 조건

각 PR은 다음을 만족해야 합니다.

1. PR 범위가 하나의 독립적인 설계·기능 단위입니다.
2. 관련 sanitized fixture와 테스트가 포함됩니다.
3. macOS에서 `swift test`와 `swift build`가 통과합니다.
4. Windows 대상 변경은 Windows runner에서 core build/test를 통과합니다.
5. provider가 없거나 데이터가 오래되었을 때 값을 추정하지 않습니다.
6. 사용자에게 보이는 source/packaging 변경에는 고유한 bilingual `.changes` 조각이
   있습니다.
7. 이 문서와 README/운영 문서의 영향을 받은 부분이 최신 상태입니다.
8. 변경된 파일만 커밋하고 stacked PR의 base/head가 올바르게 연결됩니다.

## 현재 결정 로그

- 2026-08-20: Windows 포팅을 13개의 작은 stacked PR로 분리했습니다.
- 2026-08-20: `TokeniCore`의 계산·파서·도메인 로직은 공유하고, OS I/O와 UI는
  플랫폼 어댑터로 분리하기로 했습니다.
- 2026-08-20: `UsageStore` 전체를 Windows UI에서 재사용하지 않고 공통 상태 계층과
  macOS UI 브리지로 나누기로 했습니다.
- 2026-08-20: PR1을 `main` 위에 stacked draft PR #31로 제출하고 PR2를 그 브랜치
  위에 시작했습니다.
- 2026-08-20: SwiftPM의 `platforms` 배열은 배포 버전이 있는 플랫폼만 선언하므로
  Windows는 조건부 타깃으로 제공하고 `.windows`를 `platforms`에 넣지 않기로 했습니다.
