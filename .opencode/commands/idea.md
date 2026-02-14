---
description: Synthesize saved paper summaries into testable trading ideas
agent: general
subtask: false
---

입력:
- 기본 입력은 `data/papers/*/summary.md`와 `data/papers/*/meta.json`이다.
- `$ARGUMENTS`는 선택 입력이며, 아래 형태를 권장한다:
  - `topic=<키워드>` (예: microstructure, order flow, execution)
  - `lookback=<N>` (최근 N편, 기본 10)
  - `style=<conservative|balanced|aggressive>` (기본 balanced)
  - `max_ideas=<N>` (기본 3, 최대 5)

목표:
- 저장된 논문 요약들을 묶어 공통 패턴/충돌 가설을 정리한다.
- "테스트 가능한" 아이디어를 최대 5개 생성한다.
- 아이디어는 구현 최소 요건(데이터/규칙/검증)을 포함해야 한다.
- 생성 결과를 파일로 저장하고, 기존 아이디어 재탐색(중복 생성)을 방지한다.

실행 절차:
1) 입력 스코프 결정
- `lookback`이 있으면 최신 N편 우선.
- 없으면 기본 최근 10편.
- `topic`이 있으면 제목/요약 키워드 매칭으로 우선순위 조정.

2) 요약 집계
- 각 `summary.md`에서 다음 항목을 추출:
  - 핵심 가설/아이디어
  - 데이터
  - 방법론
  - 실험/결과
  - 재현성
  - 한계 및 실패 사례

3) 패턴 통합
- 공통 신호(예: OFI, spread, impact), 공통 리스크(슬리피지, 레짐 변화), 재현성 단서(데이터 빈도/공개 여부) 정리.
- 서로 상충하는 주장/결과는 별도 표시.

4) 아이디어 생성
- 각 아이디어는 반드시 아래를 포함:
  - 아이디어 이름 (한 줄)
  - 핵심 논리 (왜 작동한다고 보는지)
  - 진입/청산 규칙 (간단 명료)
  - 필요 데이터 (최소 단위, 예: 1s LOB, 체결, 스프레드)
  - 검증 설계 (walk-forward/거래비용/레짐 분리)
  - 실패 조건 (언제 깨지는지)
  - 구현 난이도 (하/중/상)

5) 품질 필터
- 과도하게 복잡한 모델(즉시 구현 어려움)은 감점.
- 거래비용/슬리피지/지연 고려 없는 아이디어는 제외 또는 경고.
- 최종 `max_ideas`개만 반환.

6) 저장 및 중복 방지(파일 기반)
- DB는 사용하지 않는다.
- 저장 경로:
  - `data/ideas/{idea_id}/idea.md`
  - `data/ideas/{idea_id}/meta.json`
  - `data/ideas/index/ideas-YYYY-MM.jsonl` (append-only 인덱스)
- 아이디어별 `signature`를 생성한다(완전 동일 중복 기준):
  - 입력: `이름 + 핵심 논리 + 진입/청산 규칙 + 정렬된 근거 arXiv ID`
  - 정규화: 소문자, 연속 공백 축소, 앞뒤 공백 제거
  - 해시: `sha256(normalized_text)`
- 저장 전 최근 인덱스(기본 12개월 shard)에서 동일 `signature`를 검색한다.
- 동일 `signature`가 있으면 신규 생성/저장을 건너뛰고 기존 `idea_id`를 재사용한다.
- 신규일 때만 `idea.md`, `meta.json`, `jsonl` 인덱스에 기록한다.

7) 아이디어 상태 관리(파일 기반)
- `meta.json`에 `status` 필드를 포함한다: `new | testing | archived`
- 초기 생성 상태는 `new`로 저장한다.

출력 형식:
1) `[RUN_SUMMARY]`
- 사용한 논문 수
- 입력 인자 해석 결과(topic/lookback/style/max_ideas)
- 아이디어 생성 개수
- 신규 저장 개수 / 중복 재사용 개수

2) `[CROSS_PAPER_PATTERNS]`
- 공통 패턴 3~7개
- 충돌/불확실성 1~3개

3) `[IDEAS]`
- 아이디어별:
  - 이름
  - idea_id
  - 근거 논문(arXiv ID 1~3개)
  - 규칙(진입/청산)
  - 데이터 요구사항
  - 검증 프로토콜
  - 실패 조건
  - 난이도/실전 전이성/과최적화 위험 (각 1~5)
  - signature
  - 저장 경로(`idea.md`, `meta.json`)

4) `[NEXT_TEST_PLAN]`
- 오늘 바로 돌릴 최소 백테스트 1~2개
- 필요한 로그/메트릭 체크리스트

5) `[NOTES]`
- 본 결과는 연구/실험 목적이며 실제 트레이딩 리스크 관리는 사용자 책임임을 명시
