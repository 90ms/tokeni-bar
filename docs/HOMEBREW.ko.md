# Homebrew 배포

**한국어** | [English](HOMEBREW.md)

Tokeni Bar는 공용
[`90ms/homebrew-tap`](https://github.com/90ms/homebrew-tap)의 binary Cask로
배포합니다. Cask는 GitHub Releases에서 버전이 고정된 ZIP을 내려받고 SHA-256
체크섬을 검증합니다.

## 사용자 명령

설치:

```bash
brew install --cask 90ms/tap/tokeni-bar
open -a "Tokeni Bar"
```

업데이트:

```bash
brew update
brew upgrade --cask tokeni-bar
```

설정과 기록을 유지하고 앱만 제거:

```bash
brew uninstall --cask tokeni-bar
```

앱과 로컬 설정 및 기록을 모두 제거:

```bash
brew uninstall --cask --zap tokeni-bar
```

`--zap`은 현재 `TokeniBar` 저장 경로와 이름 변경 전의 호환 경로를 모두
제거합니다.

## 관리자 배포 흐름

첫 Tokeni Bar 릴리스 전 GitHub 저장소 이름이 `90ms/tokeni-bar`인지 확인해야
합니다. 앱의 업데이트 확인, 가격표 URL, 배지, Release 산출물 및 Cask가 이
경로를 사용합니다.

안정 버전 태그 `v<major>.<minor>.<patch>`를 push하면 Release workflow가
`TokeniBar-<version>.zip`과 체크섬을 게시합니다.
`HOMEBREW_TAP_TOKEN`이 설정되어 있으면 새 Cask를 렌더링하고
`90ms/homebrew-tap`에 갱신 PR을 만듭니다. PR은 자동 병합하지 않습니다.

토큰에는 tap 저장소에 브랜치를 push하고 PR을 만들 수 있는 권한만 필요합니다.
Tap CI는 Apple Silicon macOS runner에서 Cask를 설치하고 앱 번들과 코드 서명을
검증한 다음 strict audit과 제거까지 실행합니다.

Cask를 직접 렌더링하려면:

```bash
./Scripts/render_homebrew_cask.sh \
  <version> \
  <release-zip-sha256> \
  /path/to/homebrew-tap/Casks/tokeni-bar.rb
```

저장소의 `Casks/tokeni-bar.rb`는 renderer 테스트 fixture이자 기존
명시적 URL tap 설치를 위한 호환 파일로 유지합니다.
