# Homebrew 배포

**한국어** | [English](HOMEBREW.md)

Tokeni Bar의 기본 배포 경로는 공용
[`90ms/homebrew-tap`](https://github.com/90ms/homebrew-tap)의 소스 빌드
Formula입니다. Formula는 버전이 고정된 GitHub 소스 아카이브의 SHA-256을
검증하고 사용자 Mac에서 앱을 빌드합니다. 빌드 결과는 ad-hoc 서명하므로 Apple
Developer ID나 전체 Xcode 앱 없이 설치하고 업데이트할 수 있습니다. 최신 Xcode
Command Line Tools는 필요합니다.

앱 내 설치·재실행 기능은 Formula 설치본에서 지원합니다.

## 사용자 명령

설치:

```bash
brew install --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app
tokeni-bar
```

`--install-app`은 현재 Homebrew Cellar의 앱을
`~/Applications/Tokeni Bar.app`에 안전하게 연결합니다.

이미 tap을 추가한 뒤 신뢰 오류가 발생했다면 이 Formula만 신뢰합니다.

```bash
brew trust --formula 90ms/tap/tokeni-bar
brew install --formula tokeni-bar
```

업데이트:

```bash
brew update
brew upgrade --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app
```

설정과 기록을 유지하고 앱만 제거:

```bash
tokeni-bar --uninstall-app
brew uninstall --formula tokeni-bar
```

## 앱 내 업데이트

GitHub Releases 확인 결과 새 버전이 있으면 **설정 → 일반 → 앱 업데이트**에서
**설치 후 재실행**을 선택할 수 있습니다.

새 버전 확인은 자동이지만 설치는 사용자가 버튼을 누른 경우에만 시작합니다.
터미널에서 직접 업데이트한 경우 `tokeni-bar --install-app`을 다시 실행해 앱
링크를 최신 버전으로 맞추세요.

## GitHub 릴리스로 직접 설치

```bash
gh attestation verify TokeniBar-<version>.zip --repo 90ms/tokeni-bar
shasum -a 256 -c TokeniBar-<version>.zip.sha256
```

[최신 GitHub 릴리스](https://github.com/90ms/tokeni-bar/releases/latest)에서
ZIP과 체크섬을 받을 수 있습니다. 위 명령으로 빌드 출처와 파일 무결성을
확인한 뒤 앱을 실행하세요. 첫 실행이 차단되면 **시스템 설정 → 개인정보 보호
및 보안**에서 허용할 수 있습니다.

## 문제 해결

- 신뢰 오류가 나면 tap 전체가 아니라 `tokeni-bar` Formula만 신뢰했는지
  확인하세요.
- 업데이트 뒤 이전 버전이 열리면 `tokeni-bar --install-app`을 다시
  실행하세요.
- 실행 직후 종료되면 터미널에서 Formula를 업데이트한 뒤 앱 링크를
  새로 만드세요.
