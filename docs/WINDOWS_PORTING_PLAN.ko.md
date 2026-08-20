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
| PR2 | `windows/02-platform-contracts` | `TokeniCore` Windows 타깃, 플랫폼 프로토콜, 타깃 경계 | CI 통과 |
| PR3 | `windows/03-platform-infrastructure` | 앱 경로, 파일 저장, 프로세스 실행, CLI 탐색, SQLite | CI 통과 |
| PR4 | `windows/04-application-refresh` | 공통 provider 갱신 코디네이터와 macOS `UsageStore` 연결 | CI 통과 |
| PR5 | `windows/05-application-history` | 공통 기록 로딩·저장·삭제와 macOS 브리지 | CI 통과 |
| PR6 | `windows/06-application-growth` | 검증된 token observation과 growth ledger 처리 경계 | CI 통과 |
| PR7 | `windows/07-application-preferences` | 설정 저장소·알림 판정·macOS 브리지 | CI 통과 |
| PR8 | `windows/08-json-providers` | Copilot·Cline·Grok·Gemini 경로와 fixture | CI 통과 |
| PR9 | `windows/09-cli-providers` | Codex·Claude 실행 파일과 Windows CLI 계약 | CI 통과 |
| PR10 | `windows/10-sqlite-providers` | Antigravity·OpenCode SQLite reader와 fixture | CI 통과 |
| PR11 | `windows/11-windows-runtime` | Windows용 코어 실행/상태 전달 경계 | CI 통과 |
| PR12 | `windows/12-windows-tray-ui` | Windows 실행 타깃·호스트 수명주기·상태 소비 경계 | CI 통과 |
| PR13 | `windows/13-windows-tray-surface` | Win32 트레이 셸·사용량 표시 모델과 기본 tooltip | CI 통과 |
| PR14 | `windows/14-settings-storage` | Windows 파일 기반 설정 저장소와 공통 preference 연결 경계 | CI 통과 |
| PR15 | `windows/15-memory-lifecycle` | 기존 macOS 사용량 갱신의 메모리 증가 원인 수정 | CI 통과 |
| PR16 | `windows/16-claude-reset-time` | Claude 5시간 quota reset 시각의 검증된 전달·표시 | CI 통과 |
| PR17 | `windows/17-windows-services` | Windows 알림·자동 시작 서비스 어댑터 | CI 통과 |
| PR18 | `windows/18-windows-updates` | Windows 업데이트 설치 계약과 안전한 미지원 상태 | CI 통과 |
| PR19 | `windows/19-companion-overlay` | 펫 오버레이, 멀티 모니터, 클릭 통과, 접근성 | CI 통과 |
| PR20 | `windows/20-packaging-ci` | Windows 설치 패키지, CI, artifact, 배포 문서 | 진행 중 |
| PR21 | `windows/21-integration` | 최종 통합, macOS 회귀, Windows 실기기 검증 | 대기 |

PR8의 Cline과 Grok/Gemini 작업은 서로 다른 provider 디렉터리와 테스트를 담당하므로
에이전트가 병렬로 검토·준비했고, 공통 문서와 릴리스 노트는 통합 담당자가 관리합니다.
stacked PR은 리뷰·검증 순서를 보장하기 위해 하나의 PR 층으로 제출합니다.

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
않습니다. 이번 경로 이식 단계에서는 기존 macOS provider 노출 동작을 바꾸지 않고,
기본 registry 포함 여부는 통합 단계에서 별도 결정합니다.

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

- 2026-08-20: Windows 포팅과 회귀 수정을 21개의 작은 stacked PR로 분리했습니다. 큰
  `UsageStore` 작업은 refresh·history·growth·preferences 네 층으로 나눴습니다.
- 2026-08-20: `TokeniCore`의 계산·파서·도메인 로직은 공유하고, OS I/O와 UI는
  플랫폼 어댑터로 분리하기로 했습니다.
- 2026-08-20: `UsageStore` 전체를 Windows UI에서 재사용하지 않고 공통 상태 계층과
  macOS UI 브리지로 나누기로 했습니다.
- 2026-08-20: PR1을 `main` 위에 stacked draft PR #31로 제출하고 PR2를 그 브랜치
  위에 시작했습니다.
- 2026-08-20: SwiftPM의 `platforms` 배열은 배포 버전이 있는 플랫폼만 선언하므로
  Windows는 조건부 타깃으로 제공하고 `.windows`를 `platforms`에 넣지 않기로 했습니다.
- 2026-08-20: PR2의 release-note 검사와 SwiftPM manifest 오류를 수정하고 macOS CI를
  통과했습니다. PR3를 그 브랜치 위에 시작했습니다.
- 2026-08-20: PR3에서 앱 경로·실행 파일·SQLite 기반을 추가하고 macOS CI를
  통과했습니다. `UsageStore` 전체 이동은 너무 큰 단위이므로 provider 갱신,
  기록, 성장, 설정·알림의 작은 application PR로 나눴습니다.
- 2026-08-20: PR4의 `TokeniApplication` provider 갱신 코디네이터와 macOS 브리지가
  macOS CI를 통과했습니다. PR5는 history 저장 경계만 다루도록 시작합니다.
- 2026-08-20: PR5의 공통 history 코디네이터와 macOS 브리지가 macOS CI를
  통과했습니다. PR6은 companion 표시·보상과 분리된 growth ledger 저장 경계를
  다룹니다.
- 2026-08-20: PR6의 growth ledger 코디네이터가 macOS CI를 통과했습니다. PR7은
  설정 저장과 알림 정책을 provider·companion UI와 분리합니다.
- 2026-08-20: PR7의 설정 저장 계약, macOS adapter, 공통 alert preference 모델이
  macOS CI를 통과했습니다.
- 2026-08-20: PR8에서 Cline의 macOS 전용 앱 지원 경로를 주입 가능한 플랫폼 경계로
  옮기고, Gemini·Grok의 사용자 데이터 루트도 주입할 수 있게 했습니다. Copilot은
  기존 홈 상대 경로와 환경 변수 계약이 플랫폼 중립적이어서 변경하지 않았습니다.
- 2026-08-20: PR8의 provider 테스트·macOS 앱 빌드·번들 검증 CI가 통과했습니다. PR9는
  Codex·Claude CLI의 Windows 실행 파일과 프로세스 계약을 다룹니다.
- 2026-08-20: PR9를 PR8 위에 시작했습니다. Codex와 Claude provider는 서로 다른
  디렉터리 write set으로 병렬 검토하고, 공통 CLI 실행 경계는 통합 담당자가 조정합니다.
- 2026-08-20: PR9 provider 변경을 통합했습니다. Codex·Claude의 Windows 실행 파일,
  PATH 구분자, 공식 설정 루트 override와 sanitized locator 테스트를 포함하며,
  기존 macOS CLI·local fallback 동작은 유지합니다.
- 2026-08-20: PR9의 CLI provider 테스트와 macOS 앱 빌드·번들 검증 CI가 통과했습니다.
  PR10은 Antigravity·OpenCode의 SQLite reader와 Windows 데이터베이스 접근 경계를
  다룹니다.
- 2026-08-20: PR10에 공통 SQLite 실행 파일 탐색·read-only query runner를 추가하고,
  Antigravity·OpenCode reader를 주입 가능한 경계로 옮겼습니다. Windows에서 SQLite가
  없으면 사용량을 만들어내지 않고 기존 unavailable/failed 상태를 유지합니다.
- 2026-08-20: PR10의 SQLite provider 테스트와 macOS 앱 빌드·번들 검증 CI가 통과했습니다.
  PR11은 Windows 실행 파일에서 공통 application 상태를 소비하는 runtime 경계를
  다룹니다.
- 2026-08-20: PR11에서 `UsageApplicationRuntime` actor와 `UsageApplicationState`를
  추가해 provider 갱신·기록·growth ledger 전환을 UI와 분리했습니다. macOS
  `UsageStore`도 이 경계를 사용하도록 연결했고, Windows UI는 다음 단계에서 같은
  상태를 소비합니다.
- 2026-08-20: PR11의 macOS 테스트·앱 빌드·번들 검증 CI가 통과했습니다. 다음은
  이 상태 경계를 소비하는 Windows 트레이 UI 단계입니다.
- 2026-08-20: 원래 PR12의 범위가 실행 타깃·호스트 수명주기와 실제 트레이 화면을
  함께 포함해 커질 수 있으므로, PR12를 호스트 경계로 먼저 분리하고 이후 단계를
  한 층씩 뒤로 이동했습니다. PR13부터 실제 Win32 트레이 표면을 구현합니다.
- 2026-08-20: PR12의 공통 application session 테스트·macOS 앱 빌드·번들 검증 CI가
  통과했습니다. PR13은 이 session을 소비하는 실제 Win32 트레이 표면을 다룹니다.
- 2026-08-20: PR13에서 사용 가능한 snapshot만 표시하는 공통 presentation model과
  Win32 notification-area shell 경계를 추가했습니다. 트레이의 실제 설정·기록·진단
  화면은 이 shell 위에 이어서 연결합니다.
- 2026-08-20: PR13의 macOS 공통 테스트·앱 빌드·번들 검증 CI가 통과했습니다.
  Windows toolchain 빌드 검증은 Windows CI 단계에서 별도로 추가합니다.
- 2026-08-20: PR14의 설정 저장 범위가 알림·자동 시작·업데이트와 함께 묶이면
  검토 단위가 커지므로, Windows 파일 기반 설정 저장소를 먼저 별도 PR로 분리합니다.
- 2026-08-20: PR14의 macOS 테스트·앱 빌드·번들 검증 CI가 통과했습니다. 기존
  macOS에서 관찰된 메모리 증가와 Claude reset 시각 누락은 Windows 서비스와
  독립적인 회귀 수정 PR로 분리합니다.
- 2026-08-20: PR15에서 companion overlay의 retain cycle과 반복 저장 task 누적
  경계를 정리했고 macOS 테스트·앱 빌드·번들 검증 CI가 통과했습니다. PR16은
  Claude CLI의 여러 줄 사용량 응답에서 5시간 reset 시각을 연결합니다.
- 2026-08-20: PR16의 Claude parser 테스트·macOS 앱 빌드·번들 검증 CI가 통과했습니다.
  Windows 알림·자동 시작과 업데이트 설치는 API·권한·배포 위험이 달라 PR17과
  PR18로 다시 분리합니다.
- 2026-08-20: PR17에서 Win32 알림 풍선과 HKCU 사용자별 자동 시작 등록을
  공통 계약 뒤의 Windows 어댑터로 분리했고, macOS 테스트·앱 빌드·번들 검증 CI가
  통과했습니다. PR18은 실제 설치 패키지 계약이 준비되기 전 업데이트 자동 설치를
  가장하지 않는 안전한 경계로 시작합니다.
- 2026-08-20: PR18은 Windows 설치 패키지의 형식·서명·업데이트 명령이 확정되기
  전까지 `AppUpdateInstalling`이 임의 다운로드나 `winget` 실행을 하지 않도록
  명시적인 미지원 상태를 반환하고, PR20에서 실제 패키징 전략을 주입할 수 있게
  분리합니다.
- 2026-08-20: PR18의 안전한 업데이트 경계와 Windows 전용 테스트가 macOS
  테스트·앱 빌드·번들 검증 CI를 통과했습니다. PR19는 companion 상태·표현은
  공통으로 유지하고, Win32 오버레이 창·멀티 모니터·click-through만 별도 경계로
  연결합니다.
- 2026-08-20: PR19는 실제 companion 자산이나 상태를 복제하지 않고, 투명 Win32
  오버레이의 lifecycle·멀티 모니터 위치 보정·click-through만 먼저 격리합니다.
  공통 companion 상태와 렌더링 자산은 Windows 패키징·최종 통합 단계에서 연결합니다.
- 2026-08-20: PR19의 Win32 오버레이 경계와 C fallback 정적 검사가 macOS 테스트·앱
  빌드·번들 검증 CI를 통과했습니다. PR20은 Windows SDK 빌드, 테스트, artifact와
  설치 패키지 계약을 연결하는 배포 단계로 시작합니다.
- 2026-08-20: PR20은 공식 Windows Swift 설치 경로와 Windows runner의 SDK를
  사용해 `TokeniWindows` 테스트·release 빌드를 실행하고, 코드 서명 전 단계의
  portable ZIP artifact를 생성합니다. MSIX·서명·자동 업데이트는 별도 배포 계약으로
  남겨 임의의 설치 명령을 추가하지 않습니다.
