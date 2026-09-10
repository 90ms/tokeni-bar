# AI 에이전트 스킬 및 작업 워크플로

Tokeni Bar 프로젝트는 Claude Code, Codex CLI, Antigravity CLI 등 다양한 AI 코딩 에이전트 환경에서 일관된 개발 규칙과 워크플로를 적용할 수 있도록 **`.agents/` 기반의 통합 에이전트 스킬 표준**을 채택하고 있습니다.

## 1. 아키텍처 및 지원 환경

```text
tokeni-bar/
├── AGENTS.md                         # [SSOT] 모든 에이전트 공통 프로젝트 가이드 & 규칙
├── CLAUDE.md -> AGENTS.md            # Claude Code 호환용 심볼릭 링크
├── .agents/
│   └── skills/                       # 표준 에이전트 스킬 디렉터리
│       ├── release-fragment/         # 릴리스 단편(.changes/) 관리
│       ├── project-verify/           # 전체 검증 및 테스트 스위트
│       ├── add-provider/             # 신규 AI 공급자 어댑터 추가
│       ├── package-macos/            # macOS 패키징 및 Homebrew 배포
│       ├── companion-assets/         # 펫 스프라이트 및 매니페스트 관리
│       └── localization/             # 한/영 다국어 문자열 일치성 관리
└── .claude/
    └── skills -> ../.agents/skills   # Claude Code 호환용 심볼릭 링크
```

### CLI별 연동 방식

- **Antigravity CLI**: 프로젝트 루트의 `AGENTS.md`와 `.agents/skills/`를 자동 감지하며, 스킬 설명(Description)을 기반으로 필요한 시점에 스킬을 동적으로 컨텍스트에 로드(Progressive Disclosure)합니다.
- **Codex CLI**: `AGENTS.md`와 `.agents/skills/` 표준을 직접 읽고 작업 절차 및 런북을 따릅니다.
- **Claude Code**: `CLAUDE.md`(`AGENTS.md`의 심볼릭 링크)를 통해 프로젝트 제약과 가이드를 확인하고, `.claude/skills` 링크를 통해 동일한 스킬을 탐색합니다.

---

## 2. 등록된 핵심 스킬 목록

### 1. `release-fragment`
- **경로**: `.agents/skills/release-fragment/SKILL.md`
- **목적**: 사용자가 인지할 수 있는 제품, UI, CLI, 패키징 변경 시 `.changes/` 단편 생성 및 검증
- **주요 검증 명령**:
  ```bash
  ./Scripts/validate_release_notes.sh fragment .changes/<파일명>.md
  ./Scripts/validate_release_notes.sh all
  ```

### 2. `project-verify`
- **경로**: `.agents/skills/project-verify/SKILL.md`
- **목적**: 커밋 및 작업 인계 전 빌드, 유닛 테스트, 스크립트 테스트, 번역, 자산, 릴리스 노트 린터를 포괄하는 종합 검증
- **주요 검증 명령**:
  ```bash
  # SwiftPM 빌드 및 테스트 (Swift 환경)
  swift test && swift build
  # 독립 스크립트 테스트 스위트
  ./Tests/Scripts/ReleaseNotesTests.sh
  ./Tests/Scripts/HomebrewCaskTests.sh
  ./Tests/Scripts/HomebrewFormulaTests.sh
  ./Tests/Scripts/LocalizationCatalogTests.sh
  ./Tests/Scripts/GitHubWorkflowTests.sh
  # 번역 및 펫 자산 검증
  ./Scripts/validate_localizations.sh
  ./Scripts/validate_companion_assets.sh
  # 릴리스 노트 린터
  ./Scripts/validate_release_notes.sh all
  ```

### 3. `add-provider`
- **경로**: `.agents/skills/add-provider/SKILL.md`
- **목적**: 새로운 AI 코딩 도구(Claude, Codex, Gemini 등)의 사용량 파서 및 어댑터 구현
- **원칙**:
  - `Sources/TokeniCore/Providers/<Name>/`에 전용 파서 격리
  - `ProviderRegistry.defaultProviders()`에만 등록 (공유 UI에 provider 분기 코드 추가 금지)
  - 인증 토큰, 쿠키, 프롬프트 내용 일체 비저장 및 비로깅
  - `Tests/TokeniCoreTests/Fixtures/`에 민감 정보가 제거된 Sanitized Fixture 추가 필수

### 4. `package-macos`
- **경로**: `.agents/skills/package-macos/SKILL.md`
- **목적**: macOS 앱 번들(`TokeniBar.app`) 패키징, 스모크 테스트, Homebrew Cask/Formula 파일 갱신
- **주요 실행 명령**:
  ```bash
  ./Scripts/package_app.sh
  ./Scripts/smoke_macos_package.sh
  ./Scripts/render_homebrew_formula.sh <버전> <SHA256> Formula/tokeni-bar.rb
  ./Scripts/render_homebrew_cask.sh <버전> <SHA256> Casks/tokeni-bar.rb
  ```

### 5. `companion-assets`
- **경로**: `.agents/skills/companion-assets/SKILL.md`
- **목적**: 펫 캐릭터 스프라이트, 팔레트 변형, 프레임 수, 매니페스트 템플릿 검증 및 생성
- **원칙**:
  - 펫 성장은 검증된 누적 토큰(60만 토큰 = 1 XP)으로만 산출되며, 사용 시간은 성장에 영향을 주지 않음
  - 펫 상태에는 공급자 이름이나 프롬프트, 토큰 수치가 포함되지 않아야 함
- **주요 실행 명령**:
  ```bash
  ./Scripts/validate_companion_assets.sh
  ./Scripts/generate_companion_species_assets.sh
  ```

### 6. `localization`
- **경로**: `.agents/skills/localization/SKILL.md`
- **목적**: 한국어(`ko.lproj`)와 영어(`en.lproj`) UI 문자열의 1:1 매칭 및 일치성 보장
- **주요 검증 명령**:
  ```bash
  ./Scripts/validate_localizations.sh
  ./Tests/Scripts/LocalizationCatalogTests.sh
  ```

### 7. `prepare-pr`
- **경로**: `.agents/skills/prepare-pr/SKILL.md`
- **목적**: 브랜치 명명 규칙 검사, 변경 단편(.changes/) 검사, 사전 검증 게이트 확인 및 GitHub CLI(`gh pr create`)를 통한 PR 생성
- **주요 검증 명령**:
  ```bash
  ./Scripts/validate_release_notes.sh changed origin/main HEAD
  gh pr create --title "<타입>: <설명>" --body "<템플릿 본문>"
  ```

### 8. `release-deploy`
- **경로**: `.agents/skills/release-deploy/SKILL.md`
- **목적**: 검증된 main 브랜치 커밋 태깅, 한/영 릴리스 노트 렌더링, GitHub Release 게시 및 Homebrew tap 자동 PR 머지 완료
- **주요 실행 명령**:
  ```bash
  ./Scripts/render_release_notes.sh <버전> dist/release-notes.md
  ./Scripts/validate_release_notes.sh release <버전> dist/release-notes.md
  git tag -a v<버전> -m "Tokeni Bar <버전>" HEAD
  git push origin v<버전>
  ```

---


## 3. 새로운 스킬 추가 가이드

새로운 워크플로나 런북이 필요한 경우 아래 규칙을 따라 디렉터리를 추가합니다.

1. `.agents/skills/<skill-name>/` 디렉터리 생성 (소문자 및 하이픈 권장).
2. `SKILL.md` 작성 시 반드시 최상단에 YAML Frontmatter를 포함:
   ```yaml
   ---
   name: <skill-name>
   description: 이 스킬이 수행하는 작업과 에이전트가 이를 호출해야 하는 시점을 제3자 관점으로 명확히 서술합니다.
   ---
   ```
3. 에이전트가 직접 실행할 수 있는 명확한 단계별 CLI 명령과 사전/사후 검증(Verification) 절차를 포함합니다.
4. 내용이 길어지는 경우 `SKILL.md`는 가볍게 유지하고, 세부 설명은 `references/` 하위 마크다운으로 분리하여 점진적으로 참조하게 합니다.
