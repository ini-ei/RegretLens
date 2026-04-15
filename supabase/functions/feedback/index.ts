import "@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { getSupabaseClient } from "../_shared/supabase.ts";

interface FeedbackRequest {
  decision_id: string;
  regret_score: number;
  satisfaction_score: number;
  regret_reasons?: string[];
  would_change?: boolean;
  feedback_timing?: string;
  feedback_text?: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "認証が必要です" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const supabase = getSupabaseClient(authHeader);
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "認証エラー" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const body = (await req.json()) as FeedbackRequest;

    // フィードバック保存
    const { data: feedback, error: fbError } = await supabase
      .from("feedbacks")
      .insert({
        decision_id: body.decision_id,
        user_id: user.id,
        regret_score: body.regret_score,
        satisfaction_score: body.satisfaction_score,
        regret_reasons: body.regret_reasons || [],
        would_change: body.would_change || false,
        feedback_timing: body.feedback_timing,
        feedback_text: body.feedback_text,
      })
      .select()
      .single();

    if (fbError) {
      return new Response(
        JSON.stringify({ error: "フィードバックの保存に失敗しました" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // パターン分析を更新
    await updateRegretPatterns(supabase, user.id);

    return new Response(
      JSON.stringify({ feedback, message: "フィードバックを保存しました" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("Feedback error:", error);
    return new Response(
      JSON.stringify({ error: "フィードバック処理中にエラーが発生しました" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

/**
 * pattern_analyzer.py のロジックをTypeScriptに移植
 */
async function updateRegretPatterns(
  supabase: ReturnType<typeof getSupabaseClient>,
  userId: string,
) {
  // ユーザーの全履歴を取得
  const { data: decisions } = await supabase
    .from("decisions")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });

  if (!decisions || decisions.length === 0) return;

  const decisionIds = decisions.map((d: Record<string, unknown>) => d.id);
  const { data: feedbacks } = await supabase
    .from("feedbacks")
    .select("*")
    .in("decision_id", decisionIds);

  if (!feedbacks || feedbacks.length === 0) return;

  // 既存パターンを削除
  await supabase.from("regret_patterns").delete().eq("user_id", userId);

  const patterns: Map<
    string,
    {
      pattern_type: string;
      trigger_conditions: Record<string, unknown>;
      regret_scores: number[];
      occurrence_count: number;
    }
  > = new Map();

  for (const decision of decisions) {
    const context = (decision.context as Record<string, unknown>) || {};
    const factors = (decision.decision_factors as Record<string, unknown>) || {};
    const category = decision.category as string;

    const feedback = feedbacks.find(
      (f: Record<string, unknown>) => f.decision_id === decision.id,
    );
    if (!feedback) continue;

    const regretScore = feedback.regret_score as number;

    // パターン1: 高ストレス時のカテゴリ別後悔
    if ((context.stress_level as number) >= 4 && regretScore >= 4) {
      const key = `高ストレス時の${category}選択`;
      const existing = patterns.get(key);
      if (existing) {
        existing.regret_scores.push(regretScore);
        existing.occurrence_count++;
      } else {
        patterns.set(key, {
          pattern_type: key,
          trigger_conditions: { stress_level_min: 4, category },
          regret_scores: [regretScore],
          occurrence_count: 1,
        });
      }
    }

    // パターン2: 高額購入の後悔
    if ((factors.price as number) > 1000 && regretScore >= 3) {
      const key = "高額購入時の後悔";
      const existing = patterns.get(key);
      if (existing) {
        existing.regret_scores.push(regretScore);
        existing.occurrence_count++;
      } else {
        patterns.set(key, {
          pattern_type: key,
          trigger_conditions: { price_min: 1000 },
          regret_scores: [regretScore],
          occurrence_count: 1,
        });
      }
    }

    // パターン3: 低期待値の選択
    if ((factors.taste_expectation as number) <= 2 && regretScore >= 3) {
      const key = "低期待値の選択";
      const existing = patterns.get(key);
      if (existing) {
        existing.regret_scores.push(regretScore);
        existing.occurrence_count++;
      } else {
        patterns.set(key, {
          pattern_type: key,
          trigger_conditions: { expectation_max: 2 },
          regret_scores: [regretScore],
          occurrence_count: 1,
        });
      }
    }

    // パターン4: 曜日別パターン
    const dayOfWeek = context.day_of_week as string;
    if (dayOfWeek && regretScore >= 4) {
      const key = `${dayOfWeek}の${category}`;
      const existing = patterns.get(key);
      if (existing) {
        existing.regret_scores.push(regretScore);
        existing.occurrence_count++;
      } else {
        patterns.set(key, {
          pattern_type: key,
          trigger_conditions: { day_of_week: dayOfWeek, category },
          regret_scores: [regretScore],
          occurrence_count: 1,
        });
      }
    }
  }

  // 2回以上発生したパターンのみ保存
  const inserts = [];
  for (const pattern of patterns.values()) {
    if (pattern.occurrence_count >= 2) {
      const avgRegret =
        pattern.regret_scores.reduce((a, b) => a + b, 0) /
        pattern.regret_scores.length;
      inserts.push({
        user_id: userId,
        pattern_type: pattern.pattern_type,
        trigger_conditions: pattern.trigger_conditions,
        average_regret: avgRegret,
        occurrence_count: pattern.occurrence_count,
      });
    }
  }

  if (inserts.length > 0) {
    await supabase.from("regret_patterns").insert(inserts);
  }
}
