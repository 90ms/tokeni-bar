# 데이터 모델, 개인정보, 마이그레이션

## 1. 데이터 경계

게임 상태와 사용량 관측을 분리한다.

### 펫/도감 상태

저장 가능:

- 펫 계열 ID, 세대 ID와 세대 번호
- 단계, 등급, 지급된 누적 성장 에너지
- 어덜트 이후 누적 친밀도 에너지
- 생성·진화·상호작용 시각
- 보지 못한 연출 이벤트 ID
- 발견 도감과 육성 완료 횟수
- 등급별 천장 카운터

저장 금지:

- 제공자 이름 또는 ID
- 원본 토큰 합계와 세부 토큰
- 비용, 계정 정보
- 프롬프트, 응답 내용
- 인증 토큰, 쿠키, 세션 본문

### 성장 관측 원장

사용량 계층에서만 저장:

- 불투명 관측 키
- 범위 종류와 범위 ID 해시
- 마지막으로 확인한 누적 토큰과 최고점
- 관측 날짜·시각, 지급한 날짜별 에너지
- 중복 방지 이벤트 ID

기존 `usage-history.json`에 이미 토큰 합계와 제공자 정보가 있으므로 가능한 경우
이 기록을 확장하고 별도 원본 복제본을 만들지 않는다. 펫 상태는 지급 결과만
참조한다.

## 2. 개념 모델

### CurrentCompanion

```text
schemaVersion
generationID
generationNumber
speciesID
stage
rarity
growthEnergy
bondEnergy
createdAt / updatedAt
evolvedAtByStage
lastPattedAt / celebrationUntil
pendingPresentationEventIDs
```

### Collection

```text
unlockedFormID -> unlockKind(encountered/lineage), firstUnlockedAt
encounteredFormID -> firstSeenAt, lastSeenAt, seenCount
completedAdultCountByRarity
totalCompletedGenerations
highestRarity
highestBondEnergy
recentCompletedGenerations (최대 20)
```

### PityState

```text
adultsWithoutRareOrHigher
adultsWithoutEpicOrHigher
adultsWithoutLegendary
```

### GrowthLedger

```text
dateKey
measurement checkpoints
deduplicatedDailyTokens
targetEnergy
awardedEnergy
appliedEventIDs
closedAt
```

실제 구현에서는 하나의 원자적 저장 문서나 작은 이벤트 저널을 선택할 수 있지만,
현재 펫·도감·천장은 서로 다른 시점에 저장되어서는 안 된다.

## 3. 불변 조건

- `growthEnergy >= 0`
- 단계는 성장 임계점과 일치하며 뒤로 가지 않는다.
- 등급은 진화 전보다 낮아지지 않는다.
- 같은 진화 이벤트 ID는 한 번만 적용된다.
- `awardedEnergy <= targetEnergy`
- 같은 날짜·관측 키의 동일 토큰은 한 번만 반영된다.
- 도감의 발견 횟수는 감소하지 않는다.
- 실제 만나지 않은 계보 외형의 만남 횟수는 증가시키지 않는다.
- 천장 카운터는 어덜트 완료 외의 행동으로 증가하지 않는다.
- Legendary 완료 후 Legendary 카운터는 0이다.
- 펫 상태에는 제공자와 원본 토큰 정보가 없다.

디코딩 후 불변 조건을 위반하면 조용히 임의 보정하지 않는다. 안전한 범위의
마이그레이션만 수행하고, 그 외에는 백업 후 복구 안내를 표시한다.

## 4. 원자성

진화와 여정 마치기는 여러 값을 함께 바꾼다.

### 진화

- 현재 단계·등급
- 새 발견 도감 항목
- 지급 에너지 이벤트
- 보지 못한 진화 연출

### 여정 마치기

- 완료 기록
- 천장 카운터
- 새 세대와 알

임시 파일에 전체 새 상태를 쓰고 fsync 가능한 범위에서 완료한 뒤 원자적으로
교체한다. 시작할 때 임시 파일이나 저널이 남아 있으면 이벤트 ID를 보고 완료 또는
롤백한다.

## 5. 보존과 백업

- 사용량 관측 체크포인트: 기존 정책과 맞춰 최근 30일
- 닫힌 일간 성장 원장: 지연 정산을 고려해 최소 7일
- 발견 도감과 요약 카운터: 무기한
- 최근 완료 세대: 최대 20개
- 현재 펫: 1개

첫 스키마 변경 전에 기존 파일을 `*.backup-<schema>-<timestamp>` 형태로 한 번
보존한다. 민감한 내용이 추가되지 않도록 백업도 같은 데이터 경계를 따른다.

## 6. 기존 v1 펫 처리 — 확정

현재 버전의 활동 분당 XP 상태는 새 시스템에서 사용하지 않는다. 아직 실제
사용자가 없으므로 Legacy 기록과 v1 진행률 변환을 구현하지 않는다.

- 새 스키마를 읽을 수 없거나 기존 v1 파일이면 기존 파일을 제거하고 새 알 생성
- 도감, 천장, 친밀도는 모두 빈 상태에서 시작
- v1 전용 모델과 테스트는 새 모델 도입 커밋에서 제거
- 공개 문서에는 마이그레이션 안내를 노출하지 않음

## 7. 성장 기준선 마이그레이션

새 버전 최초 실행 시:

1. 사용량 기록을 읽되 과거 30일 전체를 새 펫에 소급하지 않는다.
2. 완전한 오늘 일간 누적만 오늘의 최초 에너지로 반영할 수 있다.
3. 전체/세션 누적은 현재 값을 기준선으로 저장하고 이후 증가분부터 반영한다.
4. 소스가 불완전하면 `데이터 준비 중`으로 두고 추정하지 않는다.

이 규칙은 업데이트 직후 즉시 어덜트가 되거나 같은 과거 토큰을 여러 소스에서
받는 문제를 막는다.

## 8. 내보내기와 진단

첫 버전의 필수 기능은 아니지만 복구를 위해 다음을 고려한다.

- 게임 상태만 JSON으로 내보내기
- 원본 프롬프트나 인증 정보가 없다는 확인 문구
- 가져오기 전 스키마, 체크섬, 불변 조건 검증
- 진단 보고서에는 원본 토큰 대신 날짜별 에너지와 관측 상태만 기본 포함
- 사용자가 명시적으로 선택할 때만 토큰 체크포인트 포함
