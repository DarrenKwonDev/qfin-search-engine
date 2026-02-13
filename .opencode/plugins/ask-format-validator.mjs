const pendingAsk = new Map();

const REQUIRED_KEYS = [
  "query",
  "intent",
  "intent_rationale",
  "core_keywords",
  "expanded_keywords",
  "categories",
  "query_candidates",
  "filters",
  "ranking",
  "selection_policy",
  "summary_focus",
];

const INTENTS = ["입문", "연구질문", "개념탐색", "기타"];

function inferIntent(query, text) {
  const source = `${query} ${text}`;
  if (/초심자|입문|기초|처음|간단/.test(source)) return "입문";
  if (/왜|정의|개념|설명|차이|무엇/.test(source)) return "개념탐색";
  if (/가설|검증|실험|성능|비교|연구/.test(source)) return "연구질문";
  return "기타";
}

function extractKeywords(query) {
  const tokens = query
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s-]/gu, " ")
    .split(/\s+/)
    .filter(Boolean)
    .filter((token) => token.length >= 2)
    .filter((token) => !["기반", "전략", "무엇", "있는가", "있을까"].includes(token));

  const unique = [...new Set(tokens)].slice(0, 7);
  if (unique.length >= 3) return unique;

  return ["market microstructure", "order flow", "limit order book"];
}

function buildFallbackPlan(query, rawText) {
  const intent = inferIntent(query, rawText);
  const core = extractKeywords(query);
  return {
    query,
    intent,
    intent_rationale: "형식 검증 실패로 질의문 기반 기본 계획을 자동 생성했습니다.",
    core_keywords: core,
    expanded_keywords: [
      "market microstructure",
      "limit order book",
      "order flow imbalance",
      "bid-ask spread",
      "liquidity",
    ],
    categories: ["q-fin.TR", "q-fin.ST", "q-fin.CP"],
    query_candidates: [
      'cat:q-fin.TR AND ("market microstructure" OR "limit order book")',
      'cat:q-fin.TR AND ("order flow" OR "bid-ask spread" OR liquidity)',
      '(cat:q-fin.TR OR cat:q-fin.ST) AND (intraday OR "high-frequency") AND (empirical OR baseline)',
    ],
    filters: {
      require_qfin: true,
      min_keyword_match: 1,
      min_abstract_words: 80,
      recency_years: 5,
      prefer_beginner_friendly: intent === "입문",
    },
    ranking: {
      keyword_relevance: 0.4,
      category_fit: 0.2,
      abstract_quality: 0.15,
      recency: 0.15,
      reproducibility: 0.1,
    },
    selection_policy: {
      max_papers: 3,
      allow_less_than_max: true,
    },
    summary_focus: [
      "문제 정의 및 배경",
      "핵심 가설/아이디어",
      "데이터",
      "방법론",
      "실험/결과",
      "재현성",
      "한계 및 실패 사례",
      "확장 아이디어",
    ],
  };
}

function extractPlanJson(text) {
  const match = text.match(/\[PLAN_JSON\][\s\S]*?```json\s*([\s\S]*?)\s*```/i);
  if (!match) return null;

  try {
    return JSON.parse(match[1]);
  }
  catch {
    return null;
  }
}

function isValidPlan(plan) {
  if (!plan || typeof plan !== "object") return false;
  for (const key of REQUIRED_KEYS) {
    if (!(key in plan)) return false;
  }
  if (!INTENTS.includes(plan.intent)) return false;
  if (!Array.isArray(plan.core_keywords) || plan.core_keywords.length < 1) return false;
  if (!Array.isArray(plan.query_candidates) || plan.query_candidates.length < 1) return false;
  return true;
}

function extractHumanSection(text) {
  const match = text.match(/\[HUMAN_READABLE\]([\s\S]*?)(?:\n\s*\[PLAN_JSON\]|$)/i);
  if (match?.[1]?.trim()) return match[1].trim();

  const trimmed = text.trim();
  if (!trimmed) return "형식 검증기로 인해 기본 요약만 제공됩니다.";
  return trimmed;
}

function formatOutput(humanReadable, plan) {
  return [
    "[HUMAN_READABLE]",
    humanReadable,
    "",
    "[PLAN_JSON]",
    "```json",
    JSON.stringify(plan, null, 2),
    "```",
  ].join("\n");
}

function normalizeAskOutput(rawText, query) {
  const parsed = extractPlanJson(rawText);
  const plan = isValidPlan(parsed) ? parsed : buildFallbackPlan(query, rawText);
  const human = extractHumanSection(rawText);
  return formatOutput(human, plan);
}

export default async function AskFormatValidatorPlugin() {
  return {
    "chat.message": async (input, output) => {
      const text = output?.message?.parts
        ?.filter((part) => part.type === "text")
        .map((part) => part.text)
        .join("\n")
        .trim();

      if (!text) return;

      if (text.startsWith("/ask")) {
        const query = text.replace(/^\/ask\s*/u, "").trim();
        pendingAsk.set(input.sessionID, query);
      }
    },
    "command.execute.before": async (input) => {
      if (input.command !== "ask") return;
      pendingAsk.set(input.sessionID, input.arguments ?? "");
    },
    "experimental.text.complete": async (input, output) => {
      const query = pendingAsk.get(input.sessionID);
      if (query === undefined) return;

      output.text = normalizeAskOutput(output.text ?? "", query);
      pendingAsk.delete(input.sessionID);
    },
  };
}
