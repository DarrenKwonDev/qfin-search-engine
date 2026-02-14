---
description: Execute q-fin paper collection, ranking, and structured summaries
agent: general
subtask: false
---

인자 원문:
$ARGUMENTS

입력:
- 기본 입력은 직전 `/ask`의 `[PLAN_JSON]`을 사용한다.
- 인자 원문(`$ARGUMENTS`)은 선택 입력이다. 직전 `[PLAN_JSON]`이 없을 때만 사용한다.
- 주의: 렌더링 이슈를 피하기 위해 아래부터는 `$ARGUMENTS` 대신 `인자 원문`이라고 표기한다.

중요 동작 규칙(견고성):
- 직전 `/ask` 출력이 코드블록(```json) 안에 있어도 `[PLAN_JSON]` 객체를 추출해 사용한다.
- 직전 `/ask`를 찾지 못하면, 인자 원문이 아래 중 하나인지 먼저 확인한다.
  1) 순수 JSON 객체
  2) `[PLAN_JSON]` 섹션을 포함한 텍스트
- 위 1) 또는 2)에서 추출 가능한 경우 `ask_plan`과 동일하게 취급해 계속 진행한다.

입력 우선순위:
1) 직전 `/ask`의 `[PLAN_JSON]`
2) 인자 원문 기반으로 동일 스키마의 계획을 내부 생성
3) 둘 다 없으면 실행 중단 후, 질문 또는 ask 결과가 필요하다고 명시

목표:
- 질문 의도에 맞는 q-fin 논문을 실제로 수집/선별/요약한다.
- 최대 3편까지 반환하되, 적합 후보가 적으면 더 적게 반환한다.
- 저장 정책에 맞춰 산출물을 파일로 저장한다.

실행 절차:
1) 계획 확보
- `[PLAN_JSON]`이 있으면 해당 값을 그대로 사용한다.
- 없으면 질문에서 intent/core_keywords/expanded_keywords/query_candidates/filters/ranking/summary_focus를 생성한다.

2) 후보 수집 (arXiv API)
- arXiv 공식 API(ATOMPUB)로 수집한다.
- 카테고리 우선순위는 계획의 `categories`를 따른다.
- 중복 제거 후 메타를 정규화한다:
  - title, authors, arxiv_id, published_at, categories, abstract, abs_url, pdf_url

3) 최소 적합 필터
- `filters.require_qfin=true`이면 q-fin 카테고리만 허용
- 제목/초록에서 핵심 키워드 매칭 수가 `filters.min_keyword_match` 이상
- abstract 단어 수가 `filters.min_abstract_words` 이상

4) 선별/랭킹
- 계획의 `ranking` 가중치를 사용해 점수화한다.
- 기본 점수 축: keyword_relevance, category_fit, abstract_quality, recency, reproducibility
- 입문(intent=입문) 또는 `filters.prefer_beginner_friendly=true`이면,
  해석 가능한 단순 방법론/재현 가능성 높은 논문을 가점한다.
- 상위 후보 중 최종 최대 `selection_policy.max_papers`편 선택
- 적합 후보가 부족하면 `selection_policy.allow_less_than_max=true`에 따라 더 적게 반환

5) 본문 처리 및 요약
- PDF 파일은 로컬에 저장하지 않는다.
- `meta.json`에 `pdf_url`을 포함해 원문 PDF 경로를 기록한다.
- 요약은 abstract 기반으로 작성하며, 본문(PDF) 미열람 기반임을 명시한다.
- 요약은 한국어로 작성하되 핵심 용어는 원문 병기 가능.
- 논문당 `summary.md`는 1개만 생성한다.

6) 저장 정책
- 선택 논문마다 아래 경로를 사용한다:
  - `data/papers/{arxiv_id}/meta.json` (항상 저장)
  - `data/papers/{arxiv_id}/summary.md` (항상 저장)
- `paper.pdf`는 저장하지 않는다. PDF 경로는 `meta.json`의 `pdf_url`로만 관리한다.
- 저장 실패 시 항목별 실패 사유를 결과에 포함한다.

출력 형식:
1) `[RUN_SUMMARY]`
- 사용 입력 소스: `ask_plan | arguments_generated_plan`
- intent
- 사용 쿼리 2-3개
- 후보 수집 수 / 필터 통과 수 / 최종 선택 수

2) `[SELECTED_PAPERS]` (최대 3편)
- 각 논문별:
  - 메타: 제목, 저자, arXiv ID, 공개일, 링크
  - 선택 이유: 질문 적합성 + 방법 난이도 + 실전 전이성
  - 구조화 요약(계획의 `summary_focus` 기준)
  - 저장 경로:
    - meta.json
    - summary.md

3) `[EXCLUDED_CANDIDATES]` (선택)
- 상위 제외 후보 2-5개와 제외 사유

4) `[NOTES]`
- 본 결과는 연구 탐색/이해 목적이며 실제 트레이딩 적용과 리스크 관리는 사용자 책임임을 명시
