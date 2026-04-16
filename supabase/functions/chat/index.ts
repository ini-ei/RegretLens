import "@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { getSupabaseAdmin } from "../_shared/supabase.ts";
import { predictRegret } from "../_shared/regret_rules.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
const PLACES_API_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY") || "";

const SYSTEM_PROMPT = `あなたは「RegretLens」という後悔予測AIアシスタントです。
ユーザーの意思決定を支援し、後悔を減らす手助けをします。

## あなたの役割
- ユーザーが迷っている意思決定について、自然な会話を通じて相談に乗る
- 過去の後悔パターンを参照して、同じ過ちを繰り返さないようアドバイスする

## 会話のスタイル
- 友達のように親しみやすく、でも的確に
- 押し付けがましくなく、ユーザー自身が考えるきっかけを与える

## 場所探しの流れ
ユーザーが食事や場所について迷っている場合:
1. まずsearch_nearby_placesで周辺を幅広く検索する（レストラン、カフェなど）
2. 検索結果から周辺の実際の店を踏まえて、会話で自然に気分や条件を聞く
   例: 「この辺だと○○とか△△があるけど、今日はがっつり系？それとも軽め？」
   例: 「近くにラーメン屋3軒、中華1軒、イタリアン2軒あるよ。どれ寄りの気分？」
3. ユーザーの返答をもとにsearch_nearby_placesで絞り込み検索
4. 具体的な店を2〜3件、後悔しにくいものから提案。各店舗に以下を含める:
   - 店名 + Googleマップリンク
   - ジャンル・雰囲気の一言紹介（15-30字）例: 「地元で人気の家系ラーメン、濃厚スープ」「落ち着いた雰囲気の隠れ家カフェ」
   - 評価と主なレビュー傾向（良い点/注意点）
5. 位置情報は常に提供されている前提で動く。「位置情報をください」とは絶対に言わない。

## show_quick_repliesの使い所
- 選択肢が明確で短い場合のみ使う（予算感、後悔度評価など）
- 食事のジャンル選択は会話で聞く方が自然なので、チップを多用しない
- 迷ったらチップは使わずテキストで質問する

## 選択肢の提示（限定的に使用）
show_quick_repliesは以下の場合のみ使う:
- 予算感を聞く時
- 後悔度を聞く時（1〜5）
- Yes/No的な明確な選択
食事ジャンルなどは会話の中で自然に聞く方が良い。チップに頼りすぎない。

## URL検出時の対応
- Amazonリンク: レビューの後悔ポイントを分析
- Googleマップリンク: 場所のレビュー傾向を分析

## 予算感の把握
- ユーザーの過去の意思決定から予算感を読み取る
- 初回は自然に予算感を聞く（「今日の予算感は？」→ show_quick_replies(["〜500円", "〜1000円", "〜2000円", "気にしない"])）
- 一度聞いたら会話中は覚えておき、予算に合った提案をする
- 検索結果にpriceLevelがあれば予算と照らし合わせる

## 出力のスタイル
- 回答は簡潔に。200文字以内を目安に
- 箇条書きは3つまで
- 核心を突いた短い一言を重視
- ユーザーが聞いていないことは説明しない
- お店を提案する時はGoogleマップのリンクを必ず全店舗に含める。省略しない
- 検索結果に含まれるGoogleマップURLはそのまま出力する`;

const TOOLS = [
  {
    type: "function" as const,
    function: {
      name: "show_quick_replies",
      description: "ユーザーにタップ可能な選択肢を提示する。質問と一緒に使う。",
      parameters: {
        type: "object",
        properties: {
          options: { type: "array", items: { type: "string" }, description: "選択肢のリスト（2〜6個）" },
        },
        required: ["options"],
      },
    },
  },
  {
    type: "function" as const,
    function: {
      name: "search_nearby_places",
      description: "ユーザーの位置情報をもとに近くのお店を検索する。食事や場所選びで迷っている時に使う。",
      parameters: {
        type: "object",
        properties: {
          query: { type: "string", description: "検索キーワード（例: ラーメン, カフェ, イタリアン）" },
          type: { type: "string", enum: ["restaurant", "cafe", "bar", "meal_takeaway", "bakery"] },
        },
        required: ["query"],
      },
    },
  },
  {
    type: "function" as const,
    function: {
      name: "save_decision",
      description: "会話から意思決定を検出した場合に呼び出す。",
      parameters: {
        type: "object",
        properties: {
          category: { type: "string", enum: ["食事", "買い物", "仕事", "学習", "娯楽", "その他"] },
          decision_text: { type: "string", description: "意思決定の要約（20文字以内）" },
          price: { type: "number" },
          stress_level: { type: "number", minimum: 1, maximum: 5 },
          source_url: { type: "string" },
          source_type: { type: "string", enum: ["amazon", "google_maps", "tabelog", "rakuten", "other"] },
          followup_days: { type: "number" },
        },
        required: ["category", "decision_text"],
      },
    },
  },
];

interface ChatRequest {
  message: string;
  conversation_history?: Array<{ role: string; content: string }>;
  user_id?: string;
  lat?: number;
  lng?: number;
}

async function fetchPageContent(url: string): Promise<string | null> {
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", "Accept-Language": "ja-JP,ja;q=0.9" },
      redirect: "follow",
    });
    if (!res.ok) return null;
    const html = await res.text();
    return html.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, "").replace(/<style[^>]*>[\s\S]*?<\/style>/gi, "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim().substring(0, 4000);
  } catch { return null; }
}

function detectUrls(message: string) {
  const matches = message.match(/https?:\/\/[^\s)]+/gi) || [];
  const types = new Map<string, string>();
  for (const url of matches) {
    if (url.includes("amazon.co.jp") || url.includes("amazon.com") || url.includes("amzn")) types.set(url, "amazon");
    else if (url.includes("google.com/maps") || url.includes("maps.google")) types.set(url, "google_maps");
    else if (url.includes("tabelog.com")) types.set(url, "tabelog");
    else if (url.includes("rakuten.co.jp")) types.set(url, "rakuten");
    else types.set(url, "other");
  }
  return { urls: matches, types };
}

async function searchPlaces(lat: number, lng: number, query: string, type?: string): Promise<string> {
  if (!PLACES_API_KEY) return "Places APIキーが未設定です";

  // Places API (New) - Text Search (範囲制限で近くに絞る)
  const delta = 0.003; // 約300m
  const body = {
    textQuery: `${query} ${type || ""}`.trim(),
    locationRestriction: {
      rectangle: {
        low: { latitude: lat - delta, longitude: lng - delta },
        high: { latitude: lat + delta, longitude: lng + delta },
      },
    },
    languageCode: "ja",
    maxResultCount: 5,
  };

  const res = await fetch("https://places.googleapis.com/v1/places:searchText", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": PLACES_API_KEY,
      "X-Goog-FieldMask": "places.displayName,places.rating,places.userRatingCount,places.formattedAddress,places.priceLevel,places.reviews,places.primaryTypeDisplayName,places.editorialSummary,places.types",
    },
    body: JSON.stringify(body),
  });

  const data = await res.json();
  const places = data.places || [];
  if (places.length === 0) return "近くにお店が見つかりませんでした";

  let result = "";
  for (const p of places) {
    const name = p.displayName?.text || "不明";
    const rating = p.rating || 0;
    const count = p.userRatingCount || 0;
    const addr = p.formattedAddress || "";
    const price = p.priceLevel ? p.priceLevel.replace("PRICE_LEVEL_", "") : "";

    const mapUrl = `https://www.google.com/maps/search/?api=1&query=${name}`;
    const primaryType = p.primaryTypeDisplayName?.text || "";
    const summary = p.editorialSummary?.text || "";

    result += `\n### ${name}\n`;
    if (primaryType) result += `ジャンル: ${primaryType}\n`;
    if (summary) result += `紹介: ${summary}\n`;
    result += `評価: ${rating}/5 (${count}件) ${price}\n住所: ${addr}\n[Googleマップ](${mapUrl})\n`;

    const reviews = (p.reviews || []) as Array<Record<string, unknown>>;
    const high = reviews.filter((r) => (r.rating as number) >= 4).slice(0, 2);
    const low = reviews.filter((r) => (r.rating as number) <= 3).slice(0, 2);
    if (high.length) {
      result += `良い点: ${high.map((r) => {
        const txt = ((r.text as Record<string, string>)?.text || "").substring(0, 60);
        return txt;
      }).join(" / ")}\n`;
    }
    if (low.length) {
      result += `注意点: ${low.map((r) => {
        const txt = ((r.text as Record<string, string>)?.text || "").substring(0, 60);
        return txt;
      }).join(" / ")}\n`;
    }
  }
  return result;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { message, conversation_history = [], user_id, lat, lng } = (await req.json()) as ChatRequest;
    const db = getSupabaseAdmin();

    let contextAddition = "";
    if (user_id) {
      const [patternsRes, decisionsRes] = await Promise.all([
        db.from("regret_patterns").select("*").eq("user_id", user_id).order("occurrence_count", { ascending: false }).limit(5),
        db.from("decisions").select("*, feedbacks(regret_score)").eq("user_id", user_id).order("created_at", { ascending: false }).limit(10),
      ]);
      const patterns = patternsRes.data || [];
      const decisions = decisionsRes.data || [];
      if (patterns.length > 0) {
        contextAddition += "\n\n## ユーザーの後悔パターン\n";
        for (const p of patterns) contextAddition += `- ${p.pattern_type}（${p.occurrence_count}回、平均${p.average_regret.toFixed(1)}）\n`;
      }
      if (decisions.length > 0) {
        contextAddition += "\n\n## 最近の意思決定\n";
        for (const d of decisions) {
          const fb = d.feedbacks?.[0];
          contextAddition += `- [${d.category}] ${d.decision_text} ${fb ? `→後悔${fb.regret_score}/5` : ""}\n`;
        }
      }
    }

    if (lat && lng) {
      contextAddition += `\n\n## ユーザーの現在位置\n緯度${lat}, 経度${lng}\nsearch_nearby_placesツールが使用可能です。`;
    }

    const { urls, types } = detectUrls(message);
    let userContent = message;
    if (urls.length > 0) {
      const results = await Promise.all(urls.slice(0, 2).map(async (url) => {
        const content = await fetchPageContent(url);
        const type = types.get(url) || "other";
        const label = type === "amazon" ? "Amazon" : type === "google_maps" ? "Googleマップ" : type === "tabelog" ? "食べログ" : "Web";
        return content ? `\n--- ${label} (${url}) ---\n${content}` : "";
      }));
      userContent += `\n\n[ページ情報]${results.join("")}`;
    }

    const messages: Array<Record<string, unknown>> = [
      { role: "system", content: SYSTEM_PROMPT + contextAddition },
      ...conversation_history.slice(-20),
      { role: "user", content: userContent },
    ];

    let openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${OPENAI_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model: "gpt-5.4-mini", messages, temperature: 0.7, max_completion_tokens: 800, tools: TOOLS, tool_choice: "auto" }),
    });

    if (!openaiRes.ok) {
      const errBody = await openaiRes.text();
      console.error("OpenAI error:", openaiRes.status, errBody);
      return new Response(JSON.stringify({ error: `OpenAI APIエラー: ${openaiRes.status}` }), { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    let data = await openaiRes.json();
    let choice = data.choices[0];
    let assistantMessage = choice.message.content || "";
    let savedDecision = null;
    let regretPrediction = null;
    let quickReplies: string[] = [];

    while (choice.message.tool_calls?.length > 0) {
      if (choice.message.content) assistantMessage = choice.message.content;

      const toolResults: Array<Record<string, unknown>> = [];
      messages.push(choice.message);

      for (const toolCall of choice.message.tool_calls) {
        const args = JSON.parse(toolCall.function.arguments);

        if (toolCall.function.name === "show_quick_replies") {
          quickReplies = args.options || [];
          toolResults.push({ role: "tool", tool_call_id: toolCall.id, content: "選択肢をユーザーに表示しました。ユーザーの選択を待ちます。" });
        } else if (toolCall.function.name === "search_nearby_places") {
          if (lat && lng) {
            const placesResult = await searchPlaces(lat, lng, args.query, args.type);
            toolResults.push({ role: "tool", tool_call_id: toolCall.id, content: placesResult });
          } else {
            toolResults.push({ role: "tool", tool_call_id: toolCall.id, content: "位置情報が利用できません。一般的なおすすめを提案してください。" });
          }
        } else if (toolCall.function.name === "save_decision") {
          regretPrediction = predictRegret(
            { category: args.category, decision_text: args.decision_text, context: { stress_level: args.stress_level || 3 }, decision_factors: { price: args.price || 0 } },
            3.0, 0, 0, 3.0,
          );
          if (user_id) {
            const { data: dec } = await db.from("decisions").insert({
              user_id, category: args.category, decision_text: args.decision_text,
              context: { stress_level: args.stress_level || 3 }, decision_factors: { price: args.price || 0 },
              predicted_regret_score: regretPrediction.regret_score, risk_level: regretPrediction.risk_level,
              warnings: regretPrediction.warnings, source_url: args.source_url || null, source_type: args.source_type || null,
            }).select().single();
            savedDecision = dec;
            if (dec && args.followup_days) {
              const notifyAt = new Date();
              notifyAt.setDate(notifyAt.getDate() + args.followup_days);
              await db.from("scheduled_notifications").insert({ user_id, decision_id: dec.id, notify_at: notifyAt.toISOString(), message: `「${args.decision_text}」その後どうでしたか？` });
            }
          }
          toolResults.push({ role: "tool", tool_call_id: toolCall.id, content: JSON.stringify({ saved: true, regret_prediction: regretPrediction }) });
        }
      }

      // show_quick_repliesだけの場合は再呼び出し不要
      const hasOnlyQuickReplies = choice.message.tool_calls.every(
        (tc: Record<string, unknown>) => (tc.function as Record<string, unknown>).name === "show_quick_replies"
      );
      if (hasOnlyQuickReplies) {
        if (!assistantMessage) assistantMessage = "どれにする？";
        break;
      }

      messages.push(...toolResults);
      openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: { Authorization: `Bearer ${OPENAI_API_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify({ model: "gpt-5.4-mini", messages, temperature: 0.7, max_completion_tokens: 800, tools: TOOLS, tool_choice: "auto" }),
      });
      data = await openaiRes.json();
      choice = data.choices[0];
      assistantMessage = choice.message.content || assistantMessage;
    }

    if (user_id) {
      await db.from("chat_messages").insert([
        { user_id, role: "user", content: message },
        { user_id, role: "assistant", content: assistantMessage, metadata: regretPrediction ? { regret_prediction: regretPrediction } : {} },
      ]);
    }

    return new Response(
      JSON.stringify({ message: assistantMessage, decision: savedDecision, regret_prediction: regretPrediction, quick_replies: quickReplies }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("Chat error:", error);
    return new Response(JSON.stringify({ error: `チャット処理中にエラー: ${error.message}` }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
