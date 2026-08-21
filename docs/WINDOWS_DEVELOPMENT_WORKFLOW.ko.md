# Windows 멀티에이전트 개발 운영

이 문서는 Tokeni Bar의 Windows 기능 동등성 작업을 여러 에이전트가 병렬로
진행할 때 사용하는 실행 기준입니다. 기술 경계와 기존 포팅 이력은
[Windows 포팅 계획](WINDOWS_PORTING_PLAN.ko.md)에 보존하고, 앞으로 진행할 작업의
순서·담당·PR·검증 상태는 이 문서에서 갱신합니다.

## 목표

- macOS 제품 기능을 공통 application 계층과 Windows 전용 UI·서비스로 분리해
  Windows에서도 제공합니다.
- 에이전트마다 독립된 worktree와 짧은 수명의 브랜치를 사용합니다.
- 공유 파일을 동시에 수정하지 않고, CI를 통과한 작은 PR만 순서대로 병합합니다.
- PR이 병합될 때마다 최신 `main`에서 다음 작업을 시작합니다.
- 확인되지 않은 provider 값이나 플랫폼 동작을 추정하지 않습니다.

## 운영 원칙

1. `main`에서 직접 개발하거나 커밋하지 않습니다.
2. 모든 브랜치는 `codex/` 접두사를 사용합니다.
3. 한 PR은 하나의 독립된 기능 또는 구조 변경만 포함합니다.
4. 총괄을 포함해 최대 네 에이전트를 동시에 운영합니다.
5. `Package.swift`, 앱 진입점, provider registry, workflow와 공통 계획 문서는
   총괄 에이전트만 수정합니다.
6. `UsageStore.swift`는 동시에 두 브랜치에서 수정하지 않습니다.
7. 먼저 병합된 변경에 의존하는 작업은 오래된 브랜치를 재사용하지 않고 최신
   `main`에서 새 worktree를 만듭니다.
8. 사용자의 기존 변경과 작업 범위 밖 파일은 수정하거나 커밋하지 않습니다.

## 역할과 write set

| 역할 | 담당 영역 | 기본 write set |
|---|---|---|
| 총괄 에이전트 | 작업 분해, 공유 파일, 통합, CI·리뷰 확인, 병합 | `Package.swift`, 앱 진입점, 공통 registry, 계획 문서 |
| Application 에이전트 | 플랫폼 중립 상태와 use case, macOS 얇은 브리지 | `Sources/TokeniApplication`, 승인된 `Sources/TokeniBar/UsageStore.swift`, application tests |
| Windows UI 에이전트 | 대시보드·설정·기록·펫 UI와 Win32/WinUI adapter | `Sources/TokeniWindows`, `Sources/TokeniWindowsNative`, Windows UI tests |
| Validation 에이전트 | provider Windows 계약, SQLite, CI, packaging, 실기기 검증 | 할당된 provider와 fixture, `Tests`, `Scripts`, `packaging/windows` |

하나의 wave에서 실제 범위가 좁아지면 역할 이름보다 PR별 write set을 우선합니다.
두 에이전트가 같은 파일을 필요로 하면 총괄이 공통 변경을 선행 PR로 분리하거나
한 에이전트에게만 소유권을 부여합니다.

## Worktree와 브랜치

worktree는 기본 checkout 밖의 전용 디렉터리에 생성합니다. 실제 root는 개발
환경에 맞게 정하되, 각 worktree는 하나의 브랜치만 소유합니다.

```powershell
git fetch origin
git switch main
git pull --ff-only origin main
git worktree add <worktree-root>\application-services `
  -b codex/windows-application-services origin/main
git worktree add <worktree-root>\windows-ui `
  -b codex/windows-ui-shell origin/main
git worktree add <worktree-root>\windows-validation `
  -b codex/windows-validation origin/main
```

worktree를 제거하기 전에 변경이 없고 PR 브랜치가 원격에 push되었는지 확인합니다.
재귀 삭제로 제거하지 않고 `git worktree remove`를 사용합니다. 병합된 브랜치는
worktree 제거 후 삭제합니다.

## 준비 단계 결정

- Wave 1 UI는 기존 Swift application/core와 Win32 host를 유지합니다. 첫 화면은
  표준 Win32 control로 만든 modeless dashboard이며, 안정적인 host-neutral API가
  준비된 뒤 WinUI 3 전환 여부를 다시 평가합니다.
- 개발·CI artifact는 기존 portable ZIP을 유지합니다. 정식 installer, app identity,
  서명과 자동 update 계약은 Wave 4에서 함께 확정하며, 그전에는 자동 설치를
  활성화하지 않습니다.
- GitHub-hosted Windows runner는 비대화면 EXE·package smoke까지만 release gate로
  사용합니다. tray, notification, overlay, DPI와 virtual desktop은 interactive
  self-hosted runner 또는 실기기 검증 항목으로 유지합니다. 해당 matrix는
  [Windows 실기기 검증 runbook](WINDOWS_DEVICE_VALIDATION.ko.md)으로 실행하고 기록합니다.
- SQLite provider는 사용자 PATH에 조용히 의존하지 않습니다. bundled executable과
  linked library 중 배포 전략을 별도 PR에서 결정하고, 준비 전에는 확인 가능한
  `unavailable` 상태를 유지합니다.
- Wave 1은 provider preference 기반, modeless dashboard, packaged smoke의 세 독립
  PR로 시작합니다. 공통 진입점이나 manifest 변경은 총괄이 후속 통합 PR에서만
  수행합니다.

## 작업 Wave

### 준비 단계

- Windows UI 기술과 Swift core 연결 방식을 확정합니다.
- portable 개발 artifact와 정식 설치 형식의 경계를 확정합니다.
- Windows 기능 계약과 지원하지 않는 OS 동작을 문서화합니다.
- 로컬 Windows toolchain과 EXE smoke test를 준비합니다.

### Wave 1 — 공통 기반과 대시보드

| 트랙 | 범위 | 의존성 |
|---|---|---|
| Application | `UsageStore`의 설정·예산·알림·companion use case를 `TokeniApplication`으로 이동 | 준비 단계 |
| Windows UI | tray 클릭으로 여는 대시보드, navigation과 상태 표시 골격 | 공통 presentation 계약 |
| Validation | provider 경로·SQLite 전략, EXE 실행/종료 smoke CI | 준비 단계 |

통합 기준은 Windows에서 tray를 통해 대시보드를 열고, 사용량과 provider 상태를
확인하며, 앱을 정상 종료할 수 있는 것입니다.

### Wave 2 — 주요 사용자 기능

| 트랙 | 범위 |
|---|---|
| Application | 설정, 기록, 진단, 비용·예산 application service |
| Windows UI | 사용량 상세, provider 선택, 기록·진단·현지화 UI |
| Validation | Codex·Claude·Copilot·Cline·Antigravity 등의 Windows 실기기 계약 |

### Wave 3 — Companion 기능

| 트랙 | 범위 |
|---|---|
| Application | 펫 관리, 부화·진화·판매, 도감·상점·보상·booster use case |
| Windows UI | 펫 관리·도감·상점 UI와 animation |
| Native | overlay 이동·크기·잠금·click-through, DPI·다중 monitor·접근성 |

Windows 공개 API로 macOS의 모든 Space 동작을 정확히 재현할 수 없는 경우에는
현재 virtual desktop에서의 보장 범위를 명시하고 비공개 shell API에 의존하지
않습니다.

### Wave 4 — 배포와 제품화

| 트랙 | 범위 |
|---|---|
| Notification | Windows App Notification, 클릭 activation, 설정과 중복 억제 |
| Distribution | 서명, installer, update와 rollback 계약, x64·ARM64 |
| Quality | UI automation, 설치·업데이트 E2E, 실기기 matrix와 release gate |

## PR 생명주기

1. 최신 `origin/main`에서 worktree와 브랜치를 만듭니다.
2. PR 설명에 범위, write set, 의존 PR과 검증 계획을 기록합니다.
3. 할당된 파일만 수정하고 관련 fixture·test를 함께 추가합니다.
4. 사용자에게 보이는 source 또는 packaging 변경에는 고유한 bilingual
   `.changes` fragment를 추가합니다.
5. `swift test`와 `swift build`를 실행하고 Windows 변경은 Windows runner에서도
   검증합니다.
6. 변경한 경로만 명시적으로 stage하고 commit·push합니다.
7. draft PR을 생성하고 CI 결과와 diff를 검토합니다.
8. 검증이 끝나면 ready 상태로 전환합니다.
9. 실패한 check나 review 요청은 같은 브랜치에서 수정합니다.
10. 병합 조건을 모두 만족하면 저장소의 기본 merge 정책으로 병합합니다.
11. 기본 checkout에서 `git pull --ff-only origin main`을 실행합니다.
12. 병합된 worktree를 제거하고 다음 작업은 새 `main`에서 분기합니다.

이미 동일한 base/head의 PR이 있으면 새 PR을 만들지 않고 기존 PR을 이어서
사용합니다. 병합된 PR 브랜치 위에 다음 작업을 계속 쌓지 않습니다.

## 자동 병합 조건

다음 조건을 모두 만족할 때만 총괄 에이전트가 병합할 수 있습니다.

- required check와 해당 플랫폼 CI가 모두 성공했습니다.
- `swift test`와 `swift build`가 성공하거나, 로컬에서 실행할 수 없으면 Windows
  CI의 동일 검증 결과가 확인되었습니다.
- 해결되지 않은 review thread와 change request가 없습니다.
- PR이 최신 base와 충돌하지 않고 mergeable 상태입니다.
- sanitized fixture, privacy 규칙과 provider-neutral growth 규칙을 지켰습니다.
- 필요한 `.changes` fragment와 문서 갱신이 포함되어 있습니다.
- PR 범위 밖 사용자 변경이나 다른 에이전트의 파일이 포함되지 않았습니다.

사람의 승인, branch protection, 서명 키, 외부 계정 또는 배포 권한이 필요하면 이를
우회하지 않습니다. 해당 PR은 준비된 상태로 유지하고 필요한 승인만 요청합니다.
CI 실패는 원인을 확인하지 않은 채 반복 실행하지 않으며, 확인된 일시적 장애에만
선별적으로 rerun을 사용합니다.

## 동기화와 충돌 처리

- 활성 PR이 base 갱신을 반드시 필요로 할 때만 `origin/main`을 해당 브랜치에
  merge합니다. 공유된 PR 브랜치를 force-push하지 않습니다.
- 충돌은 총괄이 양쪽 기능과 test를 읽은 뒤 해결합니다.
- 동일 파일 충돌이 예상되면 병렬 작업을 중단하고 선행 PR과 후속 PR로 재분리합니다.
- PR 병합 후 남은 에이전트는 오래된 patch를 자동 적용하지 않고 새 base에서 diff를
  재검토합니다.
- 병합 순서는 의존성이 없는 변경, 공통 application 계약, UI 통합, packaging 순서를
  기본으로 하되 실제 의존 관계가 우선합니다.

## 상태 보드

상태는 `대기`, `진행`, `PR`, `CI`, `병합`, `차단` 중 하나를 사용합니다. PR을 만들거나
병합할 때 총괄 에이전트가 이 표와 결정 로그를 같은 PR 또는 바로 다음 통합 PR에서
갱신합니다.

| Wave | 트랙 | 브랜치/PR | 상태 | 다음 조건 |
|---|---|---|---|---|
| 준비 | 기술·배포 계약 | `codex/windows-preparation-decisions` / #64 | 병합 | Wave 1 실행 |
| 1 | Provider preference | `codex/windows-provider-preferences` / #65 | 병합 | Session 연결 |
| 1 | Packaged smoke CI | `codex/windows-package-smoke` / #66 | 병합 | 실기기 package 검증 |
| 1 | Windows dashboard | `codex/windows-dashboard` / #67 | 병합 | 실기기 DPI 검증 |
| 1 | Provider preference session | `codex/windows-provider-preference-session` / #68 | 병합 | Windows host 연결 |
| 1 | Explorer tray 복구 | `codex/windows-explorer-tray-recovery` / #69 | 병합 | 실기기 Explorer 재시작 검증 |
| 1 | Bundled SQLite | `codex/windows-bundled-sqlite` / #70 | 병합 | 실기기 provider 검증 |
| 1 | Windows host preference 연결 | 미정 | 대기 | 현재 `main`에서 시작 |
| 1 | Interactive 검증 runbook | `codex/windows-device-validation-runbook` / 미정 | 진행 | 대상 기기에서 matrix 실행 |

## 결정 로그

- 2026-08-21: 장기 stacked branch 대신 짧은 수명의 wave별 worktree와 PR을
  사용하기로 했습니다.
- 2026-08-21: 총괄 한 명과 최대 세 구현 에이전트를 운영하고, 파일 write set과
  공유 파일 소유권으로 충돌을 예방하기로 했습니다.
- 2026-08-21: 모든 PR은 draft로 시작해 CI·review가 완료된 뒤 ready와 merge로
  진행하며, 병합 후 최신 `main`에서 다음 wave를 시작하기로 했습니다.
- 2026-08-21: Wave 1은 Swift+Win32 host와 portable ZIP을 유지하고, WinUI 3와 정식
  installer·app identity는 공통 API와 배포 계약이 성숙한 뒤 재평가하기로 했습니다.
- 2026-08-21: hosted runner는 비대화면 package smoke를 담당하고, tray·overlay·DPI
  같은 interactive 동작은 실기기 검증으로 분리했습니다.
- 2026-08-21: 준비 PR #64와 초기 Wave 1 PR #65–#67, session 연결 #68,
  Explorer tray 복구 #69를 병합했습니다.
- 2026-08-21: bundled SQLite PR #70이 CI를 진행하는 동안 shared
  `TokeniWindowsApp.swift`의 후속 수정을 보류하고, #70 병합 후 최신 `main`에서
  Windows host preference 연결을 시작하기로 했습니다.
- 2026-08-21: hosted CI가 성공해도 Explorer 재시작 복구, per-monitor DPI와 대상
  Windows 기기의 interactive 검증은 완료된 것으로 간주하지 않습니다.
- 2026-08-21: bundled SQLite PR #70을 병합하고 tray, Explorer 복구, DPI, 접근성과
  provider 검증에 사용할 privacy-safe 실기기 runbook 하나를 확정했습니다.
