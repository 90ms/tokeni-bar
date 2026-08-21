# Windows 실기기 검증 runbook

현재 portable Windows ZIP을 interactive Windows 실기기에서 검증할 때 이 문서를
사용합니다. 이 검증은 hosted CI를 보완하며 build·unit test·package 검사를 대체하지
않습니다. 각 release candidate에서 해당 case를 반복하고 완료 기록을 PR 또는 release
issue에 연결합니다.

English: [Windows physical-device validation runbook](WINDOWS_DEVICE_VALIDATION.md)

## 안전 및 증거 규칙

- 전용 test account, 폐기 가능한 VM 또는 승인된 test device를 사용합니다. test 상태를
  만들기 위해 사용자의 provider database나 usage log를 변경·이름 변경·복사·삭제하지
  않습니다.
- credential, cookie, prompt, response, provider database 내용, usage total, quota
  percentage, cost, account name, email, username, machine name, IP, serial number와
  device ID를 수집하지 않습니다.
- dashboard, provider 상세, usage 값, notification, prompt, response 또는 account UI가
  포함된 screenshot·video를 첨부하지 않습니다. 결과는 `available 상태 표시, 값 미기록`
  같은 정제된 text로만 기록합니다.
- OS 설정 screenshot은 사용자·device 식별자가 없고 검증한 display 설정만 crop한 경우에만
  허용합니다. 가능하면 text를 사용합니다.
- raw log, database, settings file, crash dump, registry export와 process environment
  dump를 첨부하지 않습니다. 아래 allowlist의 증거만 기록합니다.
- provider 선택 case의 증거에는 안정적인 제품 provider 이름과 `enabled` 또는
  `disabled` 상태만 포함할 수 있습니다. raw settings, 저장되었거나 알 수 없는 provider
  ID, total, quota, cost, account 정보, prompt, response와 dashboard capture는 금지합니다.
- Explorer 종료를 자동화하지 않습니다. 이 문서의 Explorer 복구 case는 interactive test
  device에서 의도적으로 수행하는 수동 작업입니다.
- 실제 사용자 데이터를 노출하거나 변경하지 않고 필요한 상태를 만들 수 없으면 중단하고
  `Blocked`로 기록합니다.

## 결과 값

해당하는 각 case에는 다음 중 정확히 하나만 사용합니다.

- `Pass`: 모든 예상 결과를 관찰하고 정제된 증거를 기록했습니다.
- `Fail`: 예상 결과 중 하나라도 관찰하지 못했습니다. issue를 만들거나 연결합니다.
- `Blocked`: 안전하게 실행할 수 없거나 필요한 device·상태가 없습니다. blocker와 담당자를
  기록하며 pass로 보고하지 않습니다.
- `N/A`: 선언한 대상 matrix 밖입니다. 이유를 기록합니다.

## Hosted CI가 증명하는 범위

| 영역 | Hosted Windows CI가 증명 | 실기기 검증에서 추가로 증명 |
|---|---|---|
| Build·test | Swift test 실행과 release executable link | 선언한 Windows edition·build·device에서의 동작 |
| Portable ZIP | checksum, 필수 파일·resource, runtime DLL load, offline smoke 종료 | Explorer 실행, endpoint 경고, tray 발견성과 정상 종료 |
| SQLite | 고정 executable hash/version, 실제 read-only JSON 왕복, DB byte 불변 | 깨끗한 PATH와 승인된 실제 provider 환경의 packaged provider 상태 |
| Dashboard | 결정적 presentation과 비대화면 smoke | 열기·숨기기·다시 열기·focus·refresh·keyboard navigation |
| Tray·Explorer | native 복구 코드 compile과 unit contract | 실제 icon, 좌·우 click과 수동 Explorer 재시작 후 복구 |
| Display·접근성 | geometry·formatting unit contract | 100/150/200% 배율, mixed-DPI monitor, keyboard·보조 기술 |

Hosted workflow가 성공해도 interactive case의 pass 증거로 사용하면 안 됩니다.

## Test 기록 header

artifact와 device 조합마다 Markdown 기록 하나를 만듭니다. 이 allowlist 밖의 식별자는
포함하지 않습니다.

```text
Artifact version/tag:
Artifact SHA-256:
Source commit:
Test date (YYYY-MM-DD) and timezone:
Tester role or non-identifying alias:
Device alias (예: win11-vm-a, machine name 금지):
Windows edition:
Windows version and OS build (winver에서 text로 옮김):
Architecture: x64
Installation type: portable ZIP
Endpoint warning observed: yes/no/not tested
Display matrix: monitor label, resolution, scale, relative arrangement
Input/accessibility tools: keyboard only / Narrator / 승인된 기타 도구
Provider test profile: unavailable / approved test account / both
Related PR or release issue:
```

`Get-FileHash -Algorithm SHA256`으로 다운로드한 ZIP을 검증하고 게시된 `.sha256`과
비교합니다. artifact hash만 기록하며 local path나 username은 기록하지 않습니다. 이전
candidate의 파일을 재사용하지 말고 새 test directory에 압축을 풉니다.

## 핵심 matrix

| ID | 시나리오 | 필수 matrix |
|---|---|---|
| ENV-01 | 대상 OS와 artifact 증거 | 모든 device/artifact |
| SMK-01 | Offline `--smoke-test`에 사용자 노출 부작용이 없음 | 모든 artifact |
| LIFE-01 | Clean launch와 정상 종료 | 모든 device/artifact |
| TRAY-01 | 좌 click, 숨김/재열기, 우 click, refresh | 모든 device/artifact |
| EXP-01 | Dashboard를 한 번도 열지 않은 상태의 Explorer restart | Windows 10·11 대상 |
| EXP-02 | Dashboard가 숨겨진 상태의 Explorer restart | Windows 10·11 대상 |
| EXP-03 | Dashboard가 열린 상태의 Explorer restart | Windows 10·11 대상 |
| SEL-01 | Mouse 다중 toggle과 재시작 후 복원 | 각 대상 OS |
| SEL-02 | 전체 disabled 중립 상태와 재활성화 | 각 대상 OS |
| SEL-03 | Keyboard·보조 기술을 사용한 provider 선택 | Windows 11과 지원 접근성 baseline |
| DPI-01 | 단일 monitor 100%, 150%, 200% scale | 지원하는 각 scale |
| DPI-02 | Mixed-DPI 다중 monitor 이동 | 실제 또는 virtual multi-monitor device 하나 이상 |
| A11Y-01 | Keyboard만 사용한 tray·dashboard 조작 | 각 대상 OS |
| A11Y-02 | 접근성 검사 | Windows 11과 지원 접근성 baseline |
| SQL-01 | Bundled SQLite가 있고 PATH SQLite가 없을 때 provider unavailable | 깨끗한 test profile |
| SQL-02 | Bundled SQLite가 있고 PATH SQLite가 없을 때 provider available | 승인된 provider test profile |

## 절차

### ENV-01 — 대상 증거와 clean extraction

1. allowlist header를 기록합니다. `winver`에서 edition·version·build를 text로 옮기고
   식별 정보가 보이면 screenshot을 찍지 않습니다.
2. ZIP SHA-256을 게시 checksum과 비교합니다.
3. 새 directory에 압축을 풀고 `TokeniWindows.exe`, `Tools\sqlite3.exe`,
   `Tools\sqlite-tools.json`, `THIRD-PARTY-NOTICES.txt`,
   `Resources\CompanionAssets`가 존재하는지 확인합니다.
4. Task Manager에 기존 `TokeniWindows.exe` process가 없는지 확인합니다.

artifact hash가 일치하고 필수 파일이 있으며 이후 결과를 기록한 OS/device 구성에 연결할
수 있으면 pass입니다.

### SMK-01 — 부작용 없는 package smoke

1. 깨끗한 test profile을 사용하거나 Tokeni Bar application-data directory가 이미 있다면
   파일 내용을 열지 않고 존재 여부와 수정 시각만 기록합니다.
2. 압축을 푼 directory에서 `TokeniWindows.exe --smoke-test`를 실행하고 exit code와
   고정 `TOKENI_WINDOWS_SMOKE_OK` marker만 기록합니다.
3. tray icon, dashboard, notification, companion overlay가 나타나지 않았는지 확인합니다.
4. `TokeniWindows.exe` process가 남지 않고 Tokeni Bar settings/history file이 생성되거나
   수정되지 않았는지 확인합니다.
5. provider login·authorization UI가 나타나지 않았는지 확인합니다. provider file은
   검사하지 않습니다.

명령이 marker와 함께 성공 종료하고 나열한 부작용이 없으면 pass입니다.

### LIFE-01 — clean launch와 정상 종료

1. 압축을 푼 directory에서 `TokeniWindows.exe`를 한 번 실행합니다.
2. 정확히 한 process가 남고 notification area 또는 overflow panel에 Tokeni Bar icon
   하나가 나타나는지 확인합니다. SmartScreen·endpoint 경고는 `관찰` 또는 `미관찰`로만
   기록합니다.
3. tray context menu에서 `Quit Tokeni Bar`를 선택합니다.
4. tray icon이 사라지고 10초 안에 process가 종료되며 error dialog가 남지 않는지
   확인합니다.
5. 다시 실행하고 종료해 이전 종료로 portable directory가 손상되거나 stale process
   상태가 남지 않았는지 확인합니다.

### TRAY-01 — dashboard와 tray control

1. tray icon을 좌 click해 modeless dashboard 하나가 열리고 focus를 받는지 확인합니다.
2. 정상 close control로 dashboard를 닫거나 숨기고 tray process가 계속 실행되는지
   확인합니다.
3. 다시 좌 click해 duplicate window·tray icon 없이 dashboard가 돌아오는지 확인합니다.
4. tray icon을 우 click해 context menu가 열리고 닫히며 dashboard를 막지 않는지
   확인합니다.
5. `Refresh now`를 선택합니다. UI가 멈추거나 window가 중복되거나 unavailable 값을
   만들어내지 않고 refresh 상태에 들어갔다가 나오는지 확인합니다.
6. dashboard가 이미 열린 상태에서 좌 click과 refresh를 한 번 더 반복합니다.

화면의 usage 값은 기록하지 않고 상태 전환과 반응성만 기록합니다.

### EXP-01/02/03 — 수동 Explorer restart 복구

서로 분리한 clean app launch에서 세 case를 모두 실행합니다.

- `EXP-01`: Tokeni Bar를 실행하되 dashboard를 열지 않습니다.
- `EXP-02`: dashboard를 한 번 연 뒤 app은 실행한 채 숨기거나 닫습니다.
- `EXP-03`: dashboard를 표시하고 focus된 상태로 둡니다.

각 상태에서 다음을 수행합니다.

1. 작업 전 Tokeni Bar process와 tray icon이 각각 하나인지 확인합니다.
2. Task Manager를 열고 `Windows Explorer`를 선택한 뒤 Task Manager의 수동 `Restart`
   동작을 사용합니다. Explorer를 종료하는 script나 command를 실행하지 않습니다.
3. taskbar와 notification area가 돌아올 때까지 기다립니다.
4. Tokeni Bar를 재실행하지 않아도 tray icon이 돌아오고 duplicate icon·process가 없는지
   확인합니다.
5. 복구된 icon을 좌·우 click해 dashboard open/focus와 context menu를 확인합니다.
6. `EXP-02`에서는 요청 전까지 dashboard가 숨겨져 있는지 확인합니다. `EXP-03`에서는
   표시 중이던 dashboard가 복구 중에도 표시·사용 가능한지 기록합니다.
7. 정상 종료하고 process가 깨끗이 종료되는지 확인합니다.
8. provider 선택 candidate에서는 기본값이 아닌 선택으로 `EXP-02`와 `EXP-03`을 반복하고
   복구 중 enabled/disabled 상태가 바뀌지 않는지 확인합니다.

icon 누락·중복, menu 접근 불가, dashboard 중복, crash 또는 visibility 상태 변경은
모두 fail이며 issue link가 필요합니다.

### SEL-01 — mouse 다중 toggle과 재시작 후 복원

1. pointer로 provider 선택 control을 엽니다. 가능한 경우 provider row를 세 개 이상
   사용하고, 그렇지 않으면 모든 row를 사용한 뒤 catalog가 작다는 사실만 기록합니다.
2. 각 안정적인 제품 provider 이름과 `enabled` 또는 `disabled`만으로 baseline을
   기록합니다. 화면의 provider 값은 기록하지 않습니다.
3. 여러 provider를 독립적으로 toggle합니다. 각 checkbox가 즉시 바뀌고 다른 row는
   그대로이며 dashboard가 멈추거나 control이 중복되지 않는지 확인합니다.
4. `Refresh now`를 실행하고 선택 상태가 바뀌지 않는지 확인합니다.
5. 정상 종료하고 같은 portable ZIP을 재실행한 뒤 refresh 전후에 정확한
   enabled/disabled 선택이 복원되는지 확인합니다.
6. 이 선택으로 `EXP-02`와 `EXP-03` 복구를 반복합니다. Explorer 복구가 선택을
   초기화하지 않고 control을 계속 사용할 수 있는지 확인합니다.

독립 toggle과 재시작 복원이 정확히 일치해야 pass입니다. 증거는 안정적인 제품 이름을
사용한 `Codex: disabled; Claude: enabled` 같은 항목으로 제한합니다.

### SEL-02 — 전체 disabled 중립 상태와 재활성화

1. 모든 provider를 disable하고 모든 provider checkbox가 unchecked인지 확인합니다.
2. dashboard가 stale provider를 active로 표시하거나 값을 만들어내지 않고 중립적인
   provider 미활성 상태를 나타내는지 확인합니다. dashboard를 capture하지 않습니다.
3. refresh하고 정상 종료한 뒤 재실행합니다. 전체 disabled 선택이 유지되고 provider
   authorization UI를 열지 않으며 app이 반응하는지 확인합니다.
4. provider 하나만 다시 enable합니다. 해당 row만 checked이고 refresh가 동작하며 다른
   provider가 암묵적으로 활성화되지 않는지 확인합니다.
5. 지원하는 100%, 150%, 200% scale에서 한 번씩 반복하고, mixed-DPI 경계를 넘어
   dashboard를 이동한 뒤에도 한 번 반복합니다.

전체 disabled가 안정적으로 지원되는 상태이고 provider 하나의 재활성화가 독립적이며
되돌릴 수 있어야 pass입니다. provider의 dashboard 값은 기록하지 않습니다.

### SEL-03 — keyboard·보조 기술을 사용한 provider 선택

1. pointer 없이 `Tab`과 `Shift+Tab`으로 모든 provider checkbox를 순회합니다. 보이는
   focus indicator, 안정적인 catalog 순서와 keyboard trap 없음을 확인합니다.
2. `Space`로 provider를 두 개 이상 toggle합니다. 각 checked state가 한 번씩 바뀌고
   keyboard에서 이해 가능하며 정상 재시작 후에도 유지되는지 확인합니다.
3. Narrator 또는 승인된 accessibility inspector로 group과 각 row가 의미 있는 안정적
   provider 이름, checkbox role과 checked state를 노출하는지 확인합니다.
4. 접근 가능한 name·description에 usage total, quota, cost, account 정보, prompt,
   response, raw setting 또는 저장된 알 수 없는 provider ID가 없는지 확인합니다.
5. 200% scale과 승인된 high-contrast theme에서 순회를 반복합니다. 해당 matrix가 있으면
   mixed-DPI monitor 경계를 넘어 focus를 계속 사용할 수 있는지 확인합니다.

안정적인 provider 이름, enabled/disabled 전환, 누락된 role/name과 navigation 동작만
기록합니다. Narrator transcript, screenshot 또는 dashboard capture를 첨부하지 않습니다.

### DPI-01 — 단일 monitor scale

100%, 150%, 200%에서 반복합니다. 지원되는 Windows 흐름으로 display 설정을 적용한 뒤
Tokeni Bar를 새로 실행합니다.

1. 해당 scale에서 tray로 dashboard를 엽니다.
2. text, icon, control, focus indicator, border가 선명하고 잘리지 않는지 확인합니다.
3. dashboard가 work area 안에 완전히 있고 각 가장자리로 이동 가능한지 확인합니다.
4. 숨겼다가 다시 열어 크기와 hit target을 계속 사용할 수 있는지 확인합니다.
5. tray context menu의 anchor와 선택 target이 올바른지 확인합니다.
6. candidate에서 companion overlay를 사용한다면 geometry, click-through, rendering만
   확인하고 provider·usage 내용은 캡처하지 않습니다.
7. provider 선택 candidate에서는 각 scale에서 모든 provider checkbox를 순회하고
   toggle합니다. label, checkbox, checked state와 focus indicator가 잘리거나 겹치지
   않는지 확인하고 `SEL-01`부터 `SEL-03`에서 허용한 증거만 남깁니다.

scale·resolution과 fail 시 정제한 defect 측정값만 기록합니다.

### DPI-02 — mixed-DPI와 multi-monitor 이동

scale이 다른 monitor 두 대 이상을 사용하며, 가능하면 하나는 100%, 다른 하나는 150%
또는 200%로 설정합니다. secondary monitor를 primary의 왼쪽이나 위에 둬 virtual desktop에
negative coordinate가 생기는 배치도 포함합니다.

1. primary monitor에서 실행하고 dashboard를 엽니다.
2. 각 monitor 경계를 천천히 넘어가고 모든 monitor 안쪽으로 완전히 이동합니다.
3. 경계마다 한 번 rescale되고 선명하며 사용 가능한 크기를 유지하고 화면 밖으로
   이동하거나 접근 불가능해지지 않는지 확인합니다.
4. 사용할 수 있는 각 taskbar 구성에서 숨기기·재열기를 확인합니다.
5. device에서 안전하게 지원한다면 secondary display를 분리·재연결하거나 primary를
   바꾸고 dashboard가 유효 work area에서 접근 가능한지 확인합니다.
6. 이동 후 context menu와 정상 종료를 다시 확인합니다.
7. provider 선택 candidate에서는 focus된 provider list를 각 DPI 경계 너머로 이동합니다.
   선택이 바뀌지 않고 focus가 보이며 전체 list와 control이 겹치거나 화면 밖으로 나가지
   않고 접근 가능한지 확인합니다.

일반화한 monitor label, resolution, scale, 상대 배치만 기록합니다.

### A11Y-01/02 — keyboard와 접근성

1. mouse 없이 `Win+B`와 arrow key로 Tokeni Bar tray icon에 이동합니다. `Enter`와
   keyboard context-menu command로 dashboard와 tray menu를 엽니다.
2. dashboard에서 `Tab`·`Shift+Tab`으로 모든 interactive control을 순회합니다. 보이는
   focus indicator, 논리적 순서, focus trap 없음과 keyboard activation을 확인합니다.
3. pointer 없이 표준 close/hide와 reopen 흐름이 동작하는지 확인합니다.
4. Narrator 또는 승인된 accessibility inspector로 dashboard, usage detail 영역,
   refresh control과 tray menu가 의미 있는 name·role·state·enabled status를
   노출하는지 확인합니다.
5. 200% text/display scale과 승인된 high-contrast theme에서 중요한 control이 보이고
   구분되는지 확인합니다.
6. 이 case의 provider 선택 부분으로 `SEL-03`을 실행합니다. dashboard 값이나 접근성
   음성이 포함된 중복 증거를 만들지 않습니다.

누락된 label·role과 navigation 동작만 기록하며 읽히거나 보이는 provider 값은 기록하지
않습니다.

### SQL-01 — packaged SQLite와 provider unavailable

Antigravity conversation database가 없는 깨끗한 test profile을 사용합니다. 이 상태를
만들려고 기존 database를 삭제하지 않습니다.

1. `Tools\sqlite3.exe`가 `Tools\sqlite-tools.json`의 hash와 일치하는지 확인합니다.
2. `where.exe sqlite3`가 다른 executable을 찾는지 기록합니다. PATH 결과가 없는 matrix가
   우선이며 이를 위해 사용자 PATH를 변경하지 않습니다.
3. Tokeni Bar를 실행하고 refresh합니다.
4. database 기반 provider가 unavailable을 표시하고 fabricated quota·cost·usage 값을
   노출하지 않으며 crash·credential 요청이 없는지 확인합니다.
5. app이 반응하고 정상 종료되는지 확인합니다.

### SQL-02 — packaged SQLite와 provider available

정제된 test activity가 있는 승인된 provider test account/profile만 사용합니다.
database, prompt, response와 값을 증거에 복사하지 않습니다.

1. `SQL-01`처럼 packaged executable hash를 확인하고 가능하면 `where.exe sqlite3`에 PATH
   결과가 없는 device를 사용합니다.
2. 승인된 provider를 정상 실행해 사전 승인한 민감하지 않은 test activity만 만듭니다.
   종료하거나 locking test plan에 필요한 상태로 둡니다.
3. Tokeni Bar를 실행하고 refresh합니다.
4. provider가 `available`에 도달하고 dashboard가 반응하는지 확인합니다. 증거에는
   `available 상태 표시, 값 미기록`만 기록합니다.
5. provider가 닫힌 상태와 안전하다면 실행 중인 상태에서 refresh합니다. database lock은
   fabricated 값이나 crash가 아니라 정직한 unavailable/stale/failure 상태여야 합니다.
6. Tokeni Bar를 정상 종료하고 원래 provider가 database를 계속 사용할 수 있는지
   확인합니다.

승인된 정제 provider profile이 없으면 `Blocked`로 기록합니다.

## Case 결과와 issue template

case마다 다음 block을 복사합니다.

```text
Case ID:
Result: Pass / Fail / Blocked / N/A
Artifact SHA-256:
Device alias and OS build:
Display/input configuration:
Start state:
Observed state transitions (선택 case는 안정적 provider 이름 + enabled/disabled만):
Evidence: sanitized text / 허용된 OS-setting crop / none
Issue: owner/repository#number, Pass이면 `none`
Blocker and owner (Blocked only):
Retest artifact/commit and result:
Notes (privacy-reviewed):
```

fail issue에는 case ID, expected와 observed state, 재현 빈도, 대상 OS/build, display 구성과
알 수 있다면 최초 bad artifact를 포함합니다. issue에도 같은 privacy 규칙을 적용합니다.

## 완료 조건

다음을 모두 만족해야 실기기 검증이 완료됩니다.

- 필수 case가 모두 `Pass`이거나 이유와 함께 명시적으로 수용한 `N/A`입니다.
- 모든 `Fail`에 issue와 release disposition이 있습니다.
- 모든 `Blocked`에 담당자가 있고 coverage처럼 표현하지 않았습니다.
- artifact hash, source commit, 대상 OS/build, architecture, display matrix와 input
  matrix를 기록했습니다.
- provider 선택 candidate에서 `SEL-01`, `SEL-02`, `SEL-03`과 해당 Explorer·DPI 교차
  검증이 pass했습니다.
- 증거에 금지된 내용이 없는지 검토했습니다.
- 완료 기록을 coordinating PR 또는 release issue에 연결했습니다.

이 runbook은 release 게시 권한이 아닙니다. repository release workflow와 필수
main-branch CI는 별도의 gate입니다.
