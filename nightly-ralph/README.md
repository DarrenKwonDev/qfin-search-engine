# Nightly Ralph 운영 가이드

## 목적
- 수동 토픽 리스트 없이, 하나의 미션(`nightly-mission.json`)만으로 `ask -> research -> idea`를 밤새 반복 실행한다.
- 토픽은 미션 목표/제약을 바탕으로 자동 생성되며, 중복을 피하면서 큐를 유지한다.

## 폴더 구조
- `nightly-ralph/nightly-ralph.sh`: 단일 실행 엔트리포인트(bash)
- `nightly-ralph/nightly-mission.json`: 미션 템플릿(운영 정책 포함)
- `nightly-ralph/reset-state.sh`: state 초기화 스크립트
- `nightly-ralph/logs/`: 실행 로그 및 락 파일
- `nightly-ralph/state/`: 토픽 큐/중복 시그니처/완료 이력/스킵 이력

## 빠른 시작
- 미션 편집: `nightly-ralph/nightly-mission.json`
- 실행:

```bash
./nightly-ralph/nightly-ralph.sh
```

- 백그라운드 실행:

```bash
nohup ./nightly-ralph/nightly-ralph.sh > nightly-ralph/logs/nohup.log 2>&1 &
```

- state 초기화:

```bash
./nightly-ralph/reset-state.sh --yes
```

## 미션 파일 핵심 필드
- `goal`: 전체 조사 목표(자유 문장)
- `constraints.forbidden_keywords`: 생성/탐색에서 제외할 키워드
- `constraints.required_keywords`: 반드시 반영할 키워드 축
- `generation.batch_size`: 한 번에 큐에 보충할 신규 토픽 수
- `generation.low_watermark`: 큐 길이가 이 값 미만이면 보충 시작
- `stop.max_rounds`: 토픽 보충 라운드 최대 횟수
- `stop.max_topics`: 전체 처리 토픽 상한
- `stop.min_new_topic_ratio`: 보충 시 신규 비율 임계치(미만이면 종료)
- `idea.lookback/style/max_ideas`: `/idea` 실행 파라미터
- `idea.max_retries/retry_delay_seconds`: idea 저장 검증 실패 시 재시도 횟수/대기 시간

## 구동 과정
1. 스크립트가 미션을 읽고 로그/상태 디렉토리를 준비한다.
2. 큐가 비어 있으면 미션 기반으로 후보 토픽을 생성하고, 금지 키워드/중복 시그니처를 필터링해 큐에 넣는다.
3. 큐에서 토픽 하나를 꺼내 `ask -> research -> idea`를 순서대로 실행한다.
4. 결과는 토픽별 로그로 저장하고, 성공/실패 여부를 `state/topic-done.jsonl`에 기록한다.
5. `idea` 결과에서 저장 산출물(`data/ideas/...`)이 검증되지 않으면 같은 토픽에서 `idea`를 재시도한다.
6. 재시도 한도 내에서도 저장 검증이 실패하면 런을 중단한다(다음 ask로 진행하지 않음).
7. 큐가 `low_watermark` 미만이면 다음 라운드 토픽을 다시 생성한다.
8. 아래 조건 중 하나를 만족하면 종료한다.
   - `stop.max_topics` 도달
   - `stop.max_rounds` 도달 후 큐 고갈
   - 새로 생성된 토픽 비율이 `stop.min_new_topic_ratio` 미만

## state 파일 설명
- `state/topic-queue.txt`: 대기 중인 토픽 큐
- `state/topic-signatures.sha256`: 중복 방지용 토픽 해시
- `state/topic-done.jsonl`: 처리 결과(success/failed, 실패 단계)
- `state/topic-skip.jsonl`: 중복 등으로 스킵된 토픽

## 운영 팁
- 미션을 크게 1개만 던지고, 제약(`forbidden_keywords`)으로 조사 범위를 제어하는 방식이 가장 안정적이다.
- 실험 사이클을 완전히 새로 시작하고 싶으면 `reset-state.sh --yes`로 state를 비우고 재실행한다.
- 로그는 실행 시각별로 `nightly-ralph/logs/<run_id>/` 아래에 쌓인다.
