import "@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { getSupabaseClient } from "../_shared/supabase.ts";
import { predictRegret } from "../_shared/regret_rules.ts";
import type { DecisionData } from "../_shared/regret_rules.ts";

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

    const decisionData = (await req.json()) as DecisionData;

    // ユーザーの同カテゴリの過去フィードバックを取得
    const { data: categoryFeedbacks } = await supabase
      .from("feedbacks")
      .select("regret_score, decisions!inner(category)")
      .eq("decisions.user_id", user.id)
      .eq("decisions.category", decisionData.category);

    let avgRegret = 3.0;
    let variance = 0;
    const scores = (categoryFeedbacks || []).map(
      (f: Record<string, unknown>) => f.regret_score as number,
    );
    if (scores.length > 0) {
      avgRegret = scores.reduce((a: number, b: number) => a + b, 0) / scores.length;
      const mean = avgRegret;
      variance = scores.reduce((sum: number, s: number) => sum + (s - mean) ** 2, 0) /
        scores.length;
    }

    // 最近の後悔トレンド
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    const { data: recentFeedbacks } = await supabase
      .from("feedbacks")
      .select("regret_score")
      .eq("user_id", user.id)
      .gte("created_at", sevenDaysAgo.toISOString());

    let recentTrend = 3.0;
    if (recentFeedbacks && recentFeedbacks.length > 0) {
      recentTrend =
        recentFeedbacks.reduce(
          (sum: number, f: Record<string, unknown>) =>
            sum + (f.regret_score as number),
          0,
        ) / recentFeedbacks.length;
    }

    const result = predictRegret(
      decisionData,
      avgRegret,
      variance,
      scores.length,
      recentTrend,
    );

    // 類似ケース検索
    const { data: similarCases } = await supabase
      .from("decisions")
      .select("*, feedbacks(*)")
      .eq("user_id", user.id)
      .eq("category", decisionData.category)
      .not("feedbacks", "is", null)
      .order("created_at", { ascending: false })
      .limit(5);

    const highRegretCases = (similarCases || [])
      .filter((d: Record<string, unknown>) => {
        const fbs = d.feedbacks as Array<Record<string, unknown>>;
        return fbs?.some((f) => (f.regret_score as number) >= 3);
      })
      .slice(0, 3)
      .map((d: Record<string, unknown>) => {
        const fb = (d.feedbacks as Array<Record<string, unknown>>)[0];
        const reasons = (fb.regret_reasons as string[]) || [];
        return {
          date: d.created_at,
          decision_text: d.decision_text,
          regret_score: fb.regret_score,
          reason: reasons[0] || "理由なし",
        };
      });

    return new Response(
      JSON.stringify({
        ...result,
        similar_cases: highRegretCases,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("Predict error:", error);
    return new Response(
      JSON.stringify({ error: "予測処理中にエラーが発生しました" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
