---
description: Interpret question and plan arXiv exploration
agent: plan
subtask: true
---
사용자 질문:
$ARGUMENTS

목표:
- 질문의 의도를 명확히 분류한다.
- q-fin arXiv 탐색 계획만 수립한다.
- 아직 논문 수집/요약 실행은 하지 않는다.

중요:
- 반드시 아래 2개 섹션을 순서대로 출력한다.
- `[PLAN_JSON]`은 `/research`가 그대로 재사용하므로, 키 이름을 변경하거나 생략하지 않는다.
- JSON은 유효한 단일 객체여야 하며, 주석/후행 콤마를 넣지 않는다.

출력 형식:
1) `[HUMAN_READABLE]`
- 의도 분류 (입문/연구질문/개념탐색/기타) + 근거 1-2줄
- 핵심 키워드 3-7개
- 유사어/확장 키워드
- arXiv 검색 전략
  - 사용할 카테고리 (예: q-fin.* 또는 세부 카테고리)
  - 검색 쿼리 후보 2-3개
  - 필터링 기준 (최신성, 관련도, 최소 abstract 길이 등)
- 예상 결과물
  - 어떤 기준으로 최대 3편을 고를지
  - 요약 시 중점 섹션

2) `[PLAN_JSON]`
```json
{
  "query": "원문 사용자 질문",
  "intent": "입문|연구질문|개념탐색|기타",
  "intent_rationale": "의도 분류 근거 1-2문장",
  "core_keywords": ["핵심 키워드 3-7개"],
  "expanded_keywords": ["유사어/확장 키워드"],
  "categories": ["q-fin.TR", "q-fin.ST", "q-fin.CP"],
  "query_candidates": [
    "arXiv 검색 쿼리 1",
    "arXiv 검색 쿼리 2",
    "arXiv 검색 쿼리 3"
  ],
  "filters": {
    "require_qfin": true,
    "min_keyword_match": 1,
    "min_abstract_words": 80,
    "recency_years": 5,
    "prefer_beginner_friendly": true
  },
  "ranking": {
    "keyword_relevance": 0.4,
    "category_fit": 0.2,
    "abstract_quality": 0.15,
    "recency": 0.15,
    "reproducibility": 0.1
  },
  "selection_policy": {
    "max_papers": 3,
    "allow_less_than_max": true
  },
  "summary_focus": [
    "문제 정의 및 배경",
    "핵심 가설/아이디어",
    "데이터",
    "방법론",
    "실험/결과",
    "재현성",
    "한계 및 실패 사례",
    "확장 아이디어"
  ]
}
```
