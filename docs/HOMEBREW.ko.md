# Homebrew 배포

**한국어** | [English](HOMEBREW.md)

Tokeni Bar의 기본 배포 경로는 공용
[`90ms/homebrew-tap`](https://github.com/90ms/homebrew-tap)의 소스 빌드
Formula입니다. Formula는 버전이 고정된 GitHub 소스 아카이브의 SHA-256을
검증하고 사용자 Mac에서 앱을 빌드합니다. 빌드 결과는 ad-hoc 서명하므로 Apple
Developer ID나 전체 Xcode 앱 없이 설치하고 업데이트할 수 있습니다. 최신 Xcode
Command Line Tools는 필요합니다.

기존 binary Cask와 GitHub Release ZIP은 이전 기간의 호환 설치 경로로
유지하지만 앱 내 설치·재실행 기능은 Formula 설치본만 지원합니다.

## 사용자 명령

설치:

```bash
brew install 90ms/tap/tokeni-bar
tokeni-bar --install-app
tokeni-bar
```

`--install-app`은 현재 Homebrew Cellar의 앱을
`~/Applications/Tokeni Bar.app`에 안전하게 연결합니다.

이미 tap을 추가한 뒤 신뢰 오류가 발생했다면 이 Formula만 신뢰합니다.

```bash
brew trust --formula 90ms/tap/tokeni-bar
brew install tokeni-bar
```

업데이트:

```bash
brew update
brew upgrade 90ms/tap/tokeni-bar
tokeni-bar --install-app
```

설정과 기록을 유지하고 앱만 제거:

```bash
tokeni-bar --uninstall-app
brew uninstall tokeni-bar
```

## 앱 내 업데이트

GitHub Releases 확인 결과 새 버전이 있으면 **설정 → 일반 → 앱 업데이트**에서
**설치 후 재실행**을 선택할 수 있습니다.

1. 고정된 경로에서 Homebrew 실행 파일을 찾습니다.
2. 설치된 항목이 `90ms/tap/tokeni-bar` Formula인지 확인합니다.
3. `brew update`와 해당 Formula만 대상으로 한 `brew upgrade`를 실행합니다.
4. `~/Applications` 링크를 새 Cellar 버전으로 교체합니다.
5. 새 앱을 연 뒤 이전 프로세스를 종료합니다.

모든 명령은 셸 문자열이 아닌 고정된 실행 파일과 인자로 실행합니다. 업데이트는
자동으로 확인하지만 설치는 사용자가 버튼을 누른 경우에만 시작합니다.

<a id="migrating-from-the-cask"></a>

## 기존 Cask에서 이전

```bash
brew uninstall --cask tokeni-bar
brew install 90ms/tap/tokeni-bar
tokeni-bar --install-app
tokeni-bar
```

Cask 제거는 앱 번들만 제거하므로 `Application Support`의 설정, 사용 기록 및
ByteBot 상태는 유지됩니다.

## 관리자 배포 흐름

안정 버전 태그 `v<major>.<minor>.<patch>`를 push하면 Release workflow가
`TokeniBar-<version>.zip`과 체크섬을 게시하고 GitHub 태그 소스 아카이브의
SHA-256을 계산합니다. `HOMEBREW_TAP_TOKEN`이 설정되어 있으면 새 Formula와
호환 Cask를 렌더링하고 `90ms/homebrew-tap`에 갱신 PR을 만듭니다. PR은 자동
병합하지 않습니다.

토큰에는 tap 저장소에 브랜치를 push하고 PR을 만들 수 있는 권한만 필요합니다.
Tap CI는 macOS runner에서 Formula를 소스 빌드하고 앱 번들, 런처 및 코드를
검증한 다음 audit과 제거까지 실행해야 합니다.

Formula를 직접 렌더링하려면:

```bash
./Scripts/render_homebrew_formula.sh \
  <version> \
  <source-tarball-sha256> \
  /path/to/homebrew-tap/Formula/tokeni-bar.rb
```

저장소의 `Formula/tokeni-bar.rb`와 `Casks/tokeni-bar.rb`는 renderer 테스트
fixture입니다. Cask renderer는 호환 ZIP 배포 기간 동안 함께 유지합니다.
