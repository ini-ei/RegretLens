import "@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { getSupabaseClient } from "../_shared/supabase.ts";
import { predictRegret } from "../_shared/regret_rules.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;

const SYSTEM_PROMPT = `あなたは「RegretLens」という後悔予測AIアシスタントです。
ユーザーの意思決定を支援し、後悔を減らす手助けをします。

## あなたの役割
- ユーザーが迷っている意思決定について、自然な会話を通じて相談に乗る
- 過去の後悔パターンを参照して、同じ過ちを繰り返さないようアドバイスする
- ユーザーのメッセージからAmazonやGoogleマップのURLを検出し、商品/場所の選択について助言する
- フィードバックを促し、学びを蓄積する

## 会話のスタイル
- 友達のように親しみやすく、でも的確に
- 押し付けがましくなく、ユーザー自身が考えるきっかけを与える
- 具体的な体験や数字を使って説明する

## 意思決定を検出した場合
会話の中で意思決定に関する内容を検出したら、以下のJSON形式で抽出してレスポンスのmetadataに含めてください：
{
  "decision_detected": true,
  "category": "食事|買い物|仕事|学習|娯楽|その他",
  "decision_text": "検出した意思決定の要約",
  "decision_factors": {
    "price": 金額（円）,
    "taste_expectation": 期待値(1-5),
    "health_value": 健康価値(1-5),
    "time_required": 所要時間（分）
  },
  "context": {
    "mood": 気分(1-5),
    "stress_level": ストレス(1-5),
    "hunger_level": 空腹度(1-5)
  },
  "source_url": "検出したURL（あれば）",
  "source_type": "amazon|google_maps|other|null"
}

## URL検出時の対応
- Amazonリンク: 商品についてレビューの傾向（後悔しやすいポイント）を推測し助言
- Googleマップリンク: 場所/店舗についてレビューの傾向を推測し助言
- URLを検出したら、数日後のフォローアップ通知を提案する

## 重要なルール
- 後悔予測スコアが高い場合は、なぜリスクが高いか理由を説明する
- ユーザーの過去のパターンに基づいてパーソナライズされたアドバイスをする
- 最終判断は必ずユーザーに委ねる`;

interface ChatRequest {
  message: string;
  conversation_history?: Array<{ role: string; content: string }>;
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

    const { message, conversation_history = [] } = await req.json() as ChatRequest;

    // ユーザーの過去データを取得
    const [patternsRes, statsRes, recentDecisionsRes] = await Promise.all([
      supabase
        .from("regret_patterns")
        .select("*")
        .eq("user_id", user.id)
        .order("occurrence_count", { ascending: false })
        .limit(5),
      supabase.rpc("get_user_category_stats", { p_user_id: user.id }).maybeSingle(),
      supabase
        .from("decisions")
        .select("*, feedbacks(*)")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false })
        .limit(10),
    ]);

    const patterns = patternsRes.data || [];
    const recentDecisions = recentDecisionsRes.data || [];

    // ユーザーコンテキストをシステムプロンプトに追加
    let contextPrompt = SYSTEM_PROMPT;

    if (patterns.length > 0) {
      contextPrompt += "\n\n## ユーザーの後悔パターン\n";
      for (const p of patterns) {
        contextPrompt += `- ${p.pattern_type}（${p.occurrence_count}回発生、平均後悔度${p.average_regret.toFixed(1)}）\n`;
      }
    }

    if (recentDecisions.length > 0) {
      contextPrompt += "\n\n## 最近の意思決定（直近10件）\n";
      for (const d of recentDecisions) {
        const fb = d.feedbacks?.[0];
        const regretInfo = fb ? `→ 後悔度${fb.regret_score}/5` : "→ フィードバック未回答";
        contextPrompt += `- [${d.category}] ${d.decision_text} ${regretInfo}\n`;
      }
    }

    // OpenAI API呼び出し
    const messages = [
      { role: "system", content: contextPrompt },
      ...conversation_history.slice(-20),
      { role: "user", content: message },
    ];

    const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o",
        messages,
        temperature: 0.7,
        max_tokens: 1000,
        functions: [
          {
            name: "extract_decision",
            description: "会話から意思決定情報を抽出する",
            parameters: {
              type: "object",
              properties: {
                decision_detected: { type: "boolean" },
                category: {
                  type: "string",
                  enum: ["食事", "買い物", "仕事", "学習", "娯楽", "その他"],
                },
                decision_text: { type: "string" },
                decision_factors: {
                  type: "object",
                  properties: {
                    price: { type: "number" },
                    taste_expectation: { type: "number", minimum: 1, maximum: 5 },
                    health_value: { type: "number", minimum: 1, maximum: 5 },
                    time_required: { type: "number" },
                  },
                },
                context: {
                  type: "object",
                  properties: {
                    mood: { type: "number", minimum: 1, maximum: 5 },
                    stress_level: { type: "number", minimum: 1, maximum: 5 },
                    hunger_level: { type: "number", minimum: 1, maximum: 5 },
                  },
                },
                source_url: { type: "string" },
                source_type: {
                  type: "string",
                  enum: ["amazon", "google_maps", "other", "null"],
                },
                suggest_followup_days: {
                  type: "number",
                  description: "フォローアップ通知を何日後に送るか（URLが検出された場合）",
                },
              },
              required: ["decision_detected"],
            },
          },
        ],
      }),
    });

    const openaiData = await openaiRes.json();
    const choice = openaiData.choices[0];
    let assistantMessage = "";
    let decisionMetadata = null;
    let regretPrediction = null;

    if (choice.message.function_call) {
      // Function callが返された場合、意思決定が検出された
      decisionMetadata = JSON.parse(choice.message.function_call.arguments);

      if (decisionMetadata.decision_detected) {
        // 後悔予測を実行
        const categoryStats = await supabase
          .from("feedbacks")
          .select("regret_score, decisions!inner(category)")
          .eq("decisions.user_id", user.id)
          .eq("decisions.category", decisionMetadata.category);

        let avgRegret = 3.0;
        let variance = 0;
        const scores = (categoryStats.data || []).map(
          (f: Record<string, unknown>) => f.regret_score as number,
        );
        if (scores.length > 0) {
          avgRegret = scores.reduce((a: number, b: number) => a + b, 0) / scores.length;
          const mean = avgRegret;
          variance = scores.reduce((sum: number, s: number) => sum + (s - mean) ** 2, 0) /
            scores.length;
        }

        regretPrediction = predictRegret(
          {
            category: decisionMetadata.category,
            decision_text: decisionMetadata.decision_text,
            context: decisionMetadata.context || {},
            decision_factors: decisionMetadata.decision_factors || {},
          },
          avgRegret,
          variance,
          scores.length,
          avgRegret,
        );

        // 意思決定をDBに保存
        const { data: savedDecision } = await supabase.from("decisions").insert({
          user_id: user.id,
          category: decisionMetadata.category,
          decision_text: decisionMetadata.decision_text,
          context: decisionMetadata.context || {},
          decision_factors: decisionMetadata.decision_factors || {},
          predicted_regret_score: regretPrediction.regret_score,
          risk_level: regretPrediction.risk_level,
          warnings: regretPrediction.warnings,
          source_url: decisionMetadata.source_url || null,
          source_type: decisionMetadata.source_type === "null"
            ? null
            : decisionMetadata.source_type,
        }).select().single();

        // URL検出時のフォローアップ通知スケジュール
        if (
          savedDecision && decisionMetadata.source_url &&
          decisionMetadata.suggest_followup_days
        ) {
          const notifyAt = new Date();
          notifyAt.setDate(
            notifyAt.getDate() + (decisionMetadata.suggest_followup_days || 3),
          );

          await supabase.from("scheduled_notifications").insert({
            user_id: user.id,
            decision_id: savedDecision.id,
            notify_at: notifyAt.toISOString(),
            message:
              `「${decisionMetadata.decision_text}」について、その後どうでしたか？購入した場合、使ってみた感想を教えてください。`,
          });
        }

        // GPTに予測結果を含めて再度応答を生成
        const followUpMessages = [
          ...messages,
          {
            role: "function" as const,
            name: "extract_decision",
            content: JSON.stringify({
              ...decisionMetadata,
              regret_prediction: regretPrediction,
            }),
          },
        ];

        const followUpRes = await fetch(
          "https://api.openai.com/v1/chat/completions",
          {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${OPENAI_API_KEY}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              model: "gpt-4o",
              messages: followUpMessages,
              temperature: 0.7,
              max_tokens: 1000,
            }),
          },
        );

        const followUpData = await followUpRes.json();
        assistantMessage = followUpData.choices[0].message.content;
      }
    } else {
      assistantMessage = choice.message.content;
    }

    // チャットメッセージをDBに保存
    await Promise.all([
      supabase.from("chat_messages").insert({
        user_id: user.id,
        role: "user",
        content: message,
      }),
      supabase.from("chat_messages").insert({
        user_id: user.id,
        role: "assistant",
        content: assistantMessage,
        decision_context: decisionMetadata,
        metadata: regretPrediction ? { regret_prediction: regretPrediction } : {},
      }),
    ]);

    return new Response(
      JSON.stringify({
        message: assistantMessage,
        decision: decisionMetadata,
        regret_prediction: regretPrediction,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("Chat error:", error);
    return new Response(
      JSON.stringify({ error: "チャット処理中にエラーが発生しました" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
