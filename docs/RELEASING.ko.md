# 릴리스 및 배포 절차

[English](RELEASING.md) | **한국어**

Tokeni Bar 릴리스는 앱 저장소의 검증된 `main` 커밋과 구조화된 한영 변경 조각을
기준으로 만듭니다. GitHub Release를 먼저 게시한 뒤 자동 생성된 Homebrew tap
PR을 검증하고 병합해야 Formula와 Cask 배포가 완료됩니다.

## 1. 변경 준비

1. 사용자에게 보이는 소스 또는 패키징 변경마다 `.changes/`에 고유한 한영 변경
   조각을 추가합니다.
2. Formula 관련 Homebrew 명령은 같은 이름의 Cask와 혼동되지 않도록 항상
   `--formula`를 명시합니다.
3. 다음 검증을 실행합니다.

```bash
swift test
swift build
Scripts/validate_companion_assets.sh
Scripts/validate_localizations.sh
Tests/Scripts/ReleaseNotesTests.sh
Tests/Scripts/GitHubWorkflowTests.sh
git diff --check
```

변경 성격과 무관한 검증은 생략할 수 있지만 `swift test`와 `swift build`는 항상
실행합니다. 로컬 도구가 없으면 PR의 macOS CI에서 동일 검사를 통과했는지 반드시
확인합니다.

## 2. PR과 main 검증

1. 기능 브랜치에 의도한 파일만 커밋하고 푸시합니다.
2. PR의 `macOS required gate`와 `Windows required gate`가 모두 성공한 뒤
   병합합니다. 변경 범위에 해당하는 플랫폼 작업이 생략되더라도 두 게이트 이름은
   항상 표시되며, 저장소 계약 검사는 릴리스 조각·워크플로·영한 번역 키와 포맷을
   검사합니다.
3. macOS 대상 변경에서는 Swift 테스트, release 빌드, 앱 패키징, 번들 메타데이터와
   패키징된 실행 파일 스모크 테스트가 모두 성공했는지 확인합니다. Windows 대상
   변경에서는 Swift 테스트, native 상태 머신, portable 패키징, 자산 검사와 압축 해제
   실행 스모크 테스트를 확인합니다.
4. 병합 커밋에서 새로 시작된 `main` CI가 성공할 때까지 태그를 만들지 않습니다.

## 3. 릴리스 노트와 태그

패치·기능·호환성 변화에 맞는 다음 시맨틱 버전을 선택하고 태그 전에 릴리스 노트를
렌더링합니다.

```bash
Scripts/render_release_notes.sh <version> /tmp/tokeni-bar-release-notes.md
Scripts/validate_release_notes.sh release <version> /tmp/tokeni-bar-release-notes.md
```

한국어와 영어의 내용, 사용자 조치, 설치 명령을 직접 검토합니다. 성공한 `main`
merge commit에 주석 태그를 만들고 푸시합니다.

```bash
git tag -a v<version> -m "Tokeni Bar <version>" <main-merge-sha>
git push origin v<version>
```

게시한 태그를 다른 커밋으로 옮기지 않습니다. 일시적이거나 외부 요인인 실패에만 기존
태그를 대상으로 `Release` 워크플로를 다시 실행합니다. source 또는 workflow code 수정이
필요하면 `.changes/README.md` 절차에 따라 게시되지 않은 각 변경 조각을 새 고유 파일명으로
승계하고 다음 patch 버전의 릴리스 노트를 렌더링합니다.

## 4. GitHub Release 검증

`Release` 워크플로가 다음 작업을 모두 성공했는지 확인합니다.

- Windows 릴리스 전용 테스트 실행
- 기존에 서명되지 않은 모든 Windows 앱 binary를 Microsoft Artifact Signing으로 서명
- 패키지의 Windows executable과 DLL 서명을 모두 확인한 뒤 portable ZIP 재생성 및 게시 전 검증
- 태그 버전 확인 및 구조화된 한영 릴리스 노트 렌더링
- macOS 앱 빌드와 ad-hoc 서명
- 사용자 데이터에 접근하지 않는 패키징된 macOS 실행 파일 스모크 테스트
- macOS와 Windows ZIP 및 각 SHA-256 생성
- 두 archive의 GitHub 빌드 증명 생성
- 검증된 `--notes-file`로 정식 GitHub Release 게시
- Homebrew Formula/Cask 갱신 PR 생성

게시된 파일을 직접 확인합니다.

```bash
shasum -a 256 -c TokeniBar-<version>.zip.sha256
gh attestation verify TokeniBar-<version>.zip --repo 90ms/tokeni-bar
shasum -a 256 -c Tokeni-Bar-Windows-<version>.zip.sha256
gh attestation verify Tokeni-Bar-Windows-<version>.zip --repo 90ms/tokeni-bar
```

## 5. Homebrew 배포 완료

자동 생성된 `90ms/homebrew-tap` PR에서 다음 검사가 모두 성공한 뒤 merge commit
방식으로 병합합니다.

- Tokeni Bar Formula 소스 빌드와 실행 경로 검사
- Tokeni Bar Cask 설치·감사
- tap의 나머지 Formula/Cask 회귀 검사

병합 후 tap의 `Formula/tokeni-bar.rb`와 `Casks/tokeni-bar.rb`가 새 버전 및 각각의
정확한 SHA-256을 가리키는지 확인합니다. 마지막으로 아래 실제 사용자 경로를
확인하면 배포가 끝납니다.

```bash
brew update
brew upgrade --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app
```
