/**
 * ml_engine.py のルールベース後悔予測ロジックをTypeScriptに移植
 */

export interface DecisionFeatures {
  price: number;
  taste_expectation: number;
  health_value: number;
  time_required: number;
  mood_score: number;
  stress_level: number;
  hunger_level: number;
  budget_remaining: number;
  with_others: number;
  hour_of_day: number;
  is_lunch_time: number;
  is_dinner_time: number;
  day_of_week: number;
  weather_encoded: number;
  user_average_regret_this_category: number;
  user_regret_variance: number;
  similar_past_decisions_count: number;
  recent_regret_trend: number;
}

export interface DecisionData {
  category: string;
  decision_text: string;
  context: Record<string, unknown>;
  decision_factors: Record<string, unknown>;
}

export interface PredictionResult {
  regret_score: number;
  risk_level: string;
  warnings: string[];
  prediction_method: string;
}

const DAY_MAPPING: Record<string, number> = {
  "月曜日": 0, "火曜日": 1, "水曜日": 2, "木曜日": 3,
  "金曜日": 4, "土曜日": 5, "日曜日": 6,
};

const WEATHER_MAPPING: Record<string, number> = {
  "晴れ": 1, "曇り": 2, "雨": 3, "雪": 4,
};

export function extractFeatures(
  decisionData: DecisionData,
  categoryAvgRegret: number,
  categoryRegretVariance: number,
  similarCount: number,
  recentTrend: number,
): DecisionFeatures {
  const factors = decisionData.decision_factors || {};
  const context = decisionData.context || {};

  const timeStr = (context.time_of_day as string) || "12:00";
  let hour = 12;
  try {
    hour = parseInt(timeStr.split(":")[0]);
  } catch {
    hour = 12;
  }

  return {
    price: Number(factors.price ?? 0),
    taste_expectation: Number(factors.taste_expectation ?? 3),
    health_value: Number(factors.health_value ?? 3),
    time_required: Number(factors.time_required ?? 0),
    mood_score: Number(context.mood ?? 3),
    stress_level: Number(context.stress_level ?? 3),
    hunger_level: Number(context.hunger_level ?? 3),
    budget_remaining: Number(context.budget_remaining ?? 0),
    with_others: context.with_others ? 1 : 0,
    hour_of_day: hour,
    is_lunch_time: hour >= 11 && hour <= 13 ? 1 : 0,
    is_dinner_time: hour >= 18 && hour <= 20 ? 1 : 0,
    day_of_week: DAY_MAPPING[(context.day_of_week as string) || "月曜日"] ?? 0,
    weather_encoded: WEATHER_MAPPING[(context.weather as string) || "晴れ"] ?? 1,
    user_average_regret_this_category: categoryAvgRegret,
    user_regret_variance: categoryRegretVariance,
    similar_past_decisions_count: similarCount,
    recent_regret_trend: recentTrend,
  };
}

export function calculateRegretScore(features: DecisionFeatures): number {
  // 各要因を 0〜1 の寄与度に変換して重み付き合計。飽和しにくい連続スコア。
  let raw = 0;

  // ストレス（3が中立、5で最大）
  raw += clamp01((features.stress_level - 3) / 2) * 0.20;

  // 価格（1000円から効き始め、20000円で最大）
  if (features.price > 1000) {
    raw += clamp01((features.price - 1000) / 19000) * 0.18;
  }

  // 同カテゴリの過去後悔（3が中立、5で最大）— 効きすぎないよう緩やかに
  raw += clamp01((features.user_average_regret_this_category - 3) / 2) * 0.18;

  // 直近の後悔トレンド
  raw += clamp01((features.recent_regret_trend - 3) / 2) * 0.12;

  // 期待値の低さ（3が中立、1で最大）
  raw += clamp01((3 - features.taste_expectation) / 2) * 0.12;

  // 気分の低さ
  raw += clamp01((3 - features.mood_score) / 2) * 0.08;

  // 空腹（4以上で効く）
  if (features.hunger_level >= 4) {
    raw += clamp01((features.hunger_level - 3) / 2) * 0.08;
  }

  // 予算超過（budget_remainingが正の値の時だけ判定。デフォルト0は無視）
  if (features.budget_remaining > 0 && features.budget_remaining < features.price) {
    raw += 0.12;
  }

  // ベース 0.25 + 寄与（最大約0.33 → 上限0.95程度に収まる）
  const score = 0.25 + raw;
  return Math.min(1.0, Math.max(0.0, score));
}

function clamp01(x: number): number {
  return Math.min(1, Math.max(0, x));
}

export function getRiskLevel(score: number): string {
  if (score >= 0.7) return "高";
  if (score >= 0.4) return "中";
  return "低";
}

export function generateWarnings(
  features: DecisionFeatures,
  category: string,
): string[] {
  const warnings: string[] = [];

  if (features.stress_level >= 4) {
    warnings.push(
      `⚠️ ストレスが高い状態です。${category}の選択で後悔しやすい傾向があります`,
    );
  }
  if (features.price > 1000) {
    warnings.push("💰 高額な選択です。本当に必要か考えてみましょう");
  }
  if (features.taste_expectation <= 2) {
    warnings.push("📉 期待値が低い選択は後悔につながりやすいです");
  }
  if (features.hunger_level >= 5) {
    warnings.push("🍽️ 極度の空腹時は判断力が低下します。落ち着いて選択しましょう");
  }
  if (features.budget_remaining > 0 && features.budget_remaining < features.price) {
    warnings.push("💸 予算を超過しています。経済的なストレスにつながる可能性があります");
  }
  if (features.user_average_regret_this_category >= 4) {
    warnings.push(
      `📊 ${category}カテゴリでの過去の平均後悔度が高いです（${features.user_average_regret_this_category.toFixed(1)}/5.0）`,
    );
  }
  if (features.mood_score <= 2) {
    warnings.push("😔 気分が低い時の決定は後悔しやすい傾向があります");
  }

  return warnings;
}

export function predictRegret(
  decisionData: DecisionData,
  categoryAvgRegret: number = 3.0,
  categoryRegretVariance: number = 0,
  similarCount: number = 0,
  recentTrend: number = 3.0,
): PredictionResult {
  const features = extractFeatures(
    decisionData,
    categoryAvgRegret,
    categoryRegretVariance,
    similarCount,
    recentTrend,
  );

  const regretScore = calculateRegretScore(features);
  const riskLevel = getRiskLevel(regretScore);
  const warnings = generateWarnings(features, decisionData.category);

  return {
    regret_score: Math.round(regretScore * 100) / 100,
    risk_level: riskLevel,
    warnings,
    prediction_method: "rule_based",
  };
}
