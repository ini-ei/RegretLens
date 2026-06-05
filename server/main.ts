import { sql } from "./db.ts";
import { predictRegret } from "./regret_rules.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
const PLACES_API_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY") || "";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

// ============ システムプロンプト & ツール ============

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
3. ユーザーの返答をもとにsearch_nearby_placesで絞り込み検索
4. 具体的な店を2〜3件、後悔しにくいものから提案。各店舗に以下を含める:
   - 店名 + Googleマップリンク
   - ジャンル・雰囲気の一言紹介（15-30字）
   - 評価と主なレビュー傾向（良い点/注意点）
5. 位置情報は常に提供されている前提で動く。「位置情報をください」とは絶対に言わない。

## show_quick_repliesの使い所（限定的に使用）
- 予算感を聞く時、後悔度を聞く時、Yes/No的な明確な選択のみ
- 食事ジャンルなどは会話で自然に聞く方が良い。チップに頼りすぎない

## 予算感の把握
- ユーザーの過去の意思決定から予算感を読み取る
- 一度聞いたら会話中は覚えておき、予算に合った提案をする

## 出力のスタイル
- 回答は簡潔に。200文字以内を目安に
- 箇条書きは3つまで
- お店を提案する時はGoogleマップのリンクを必ず全店舗に含める`;

const TOOLS = [
  {
    type: "function" as const,
    function: {
      name: "show_quick_replies",
      description: "ユーザーにタップ可能な選択肢を提示する。予算や評価など明確な選択時のみ。",
      parameters: {
        type: "object",
        properties: { options: { type: "array", items: { type: "string" } } },
        required: ["options"],
      },
    },
  },
  {
    type: "function" as const,
    function: {
      name: "search_nearby_places",
      description: "ユーザーの位置情報をもとに近くのお店を検索する。",
      parameters: {
        type: "object",
        properties: {
          query: { type: "string" },
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
          decision_text: { type: "string" },
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

// ============ ヘルパー ============

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

interface PlaceItem {
  name: string;
  lat: number;
  lng: number;
  rating: number;
  map_url: string;
}

async function searchPlaces(
  lat: number,
  lng: number,
  query: string,
  type?: string,
): Promise<{ text: string; places: PlaceItem[] }> {
  if (!PLACES_API_KEY) return { text: "Places APIキーが未設定です", places: [] };
  const delta = 0.003;
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
      "X-Goog-FieldMask": "places.displayName,places.rating,places.userRatingCount,places.formattedAddress,places.priceLevel,places.reviews,places.primaryTypeDisplayName,places.editorialSummary,places.types,places.location",
    },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  const places = data.places || [];
  if (places.length === 0) return { text: "近くにお店が見つかりませんでした", places: [] };

  let result = "";
  const items: PlaceItem[] = [];
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
    if (high.length) result += `良い点: ${high.map((r) => ((r.text as Record<string, string>)?.text || "").substring(0, 60)).join(" / ")}\n`;
    if (low.length) result += `注意点: ${low.map((r) => ((r.text as Record<string, string>)?.text || "").substring(0, 60)).join(" / ")}\n`;

    if (p.location) {
      items.push({ name, lat: p.location.latitude, lng: p.location.longitude, rating, map_url: mapUrl });
    }
  }
  return { text: result, places: items };
}

// ============ ハンドラ ============

async function handleChat(body: Record<string, unknown>) {
  const message = body.message as string;
  const conversation_history = (body.conversation_history as Array<Record<string, unknown>>) || [];
  const user_id = body.user_id as string | undefined;
  const lat = body.lat as number | undefined;
  const lng = body.lng as number | undefined;

  if (!OPENAI_API_KEY) return json({ error: "OPENAI_API_KEY未設定" }, 500);

  let contextAddition = "";
  if (user_id) {
    const patterns = await sql`SELECT * FROM regret_patterns WHERE user_id = ${user_id} ORDER BY occurrence_count DESC LIMIT 5`;
    const decisions = await sql`
      SELECT d.*, COALESCE(json_agg(json_build_object('regret_score', f.regret_score)) FILTER (WHERE f.id IS NOT NULL), '[]') as feedbacks
      FROM decisions d LEFT JOIN feedbacks f ON f.decision_id = d.id
      WHERE d.user_id = ${user_id} GROUP BY d.id ORDER BY d.created_at DESC LIMIT 10`;
    if (patterns.length > 0) {
      contextAddition += "\n\n## ユーザーの後悔パターン\n";
      for (const p of patterns) contextAddition += `- ${p.pattern_type}（${p.occurrence_count}回、平均${Number(p.average_regret).toFixed(1)}）\n`;
    }
    if (decisions.length > 0) {
      contextAddition += "\n\n## 最近の意思決定\n";
      for (const d of decisions) {
        const fb = (d.feedbacks as Array<Record<string, unknown>>)?.[0];
        contextAddition += `- [${d.category}] ${d.decision_text} ${fb ? `→後悔${fb.regret_score}/5` : ""}\n`;
      }
    }
  }
  if (lat && lng) contextAddition += `\n\n## ユーザーの現在位置\n緯度${lat}, 経度${lng}\nsearch_nearby_placesが使用可能。`;

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

  let res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { Authorization: `Bearer ${OPENAI_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: "gpt-5.4-mini", messages, temperature: 0.7, max_completion_tokens: 800, tools: TOOLS, tool_choice: "auto" }),
  });
  if (!res.ok) {
    console.error("OpenAI error:", res.status, await res.text());
    return json({ error: `OpenAI APIエラー: ${res.status}` }, 502);
  }
  let data = await res.json();
  let choice = data.choices[0];
  let assistantMessage = choice.message.content || "";
  let savedDecision = null;
  let regretPrediction = null;
  let quickReplies: string[] = [];
  let mapData: { center: { lat: number; lng: number }; places: PlaceItem[] } | null = null;

  while (choice.message.tool_calls?.length > 0) {
    if (choice.message.content) assistantMessage = choice.message.content;
    const toolResults: Array<Record<string, unknown>> = [];
    messages.push(choice.message);

    for (const tc of choice.message.tool_calls) {
      const args = JSON.parse(tc.function.arguments);
      if (tc.function.name === "show_quick_replies") {
        quickReplies = args.options || [];
        toolResults.push({ role: "tool", tool_call_id: tc.id, content: "選択肢を表示しました。ユーザーの選択を待ちます。" });
      } else if (tc.function.name === "search_nearby_places") {
        if (lat && lng) {
          const sr = await searchPlaces(lat, lng, args.query, args.type);
          toolResults.push({ role: "tool", tool_call_id: tc.id, content: sr.text });
          if (sr.places.length > 0) {
            mapData = { center: { lat, lng }, places: sr.places };
          }
        } else {
          toolResults.push({ role: "tool", tool_call_id: tc.id, content: "位置情報なし。一般的な提案を。" });
        }
      } else if (tc.function.name === "save_decision") {
        regretPrediction = predictRegret(
          { category: args.category, decision_text: args.decision_text, context: { stress_level: args.stress_level || 3 }, decision_factors: { price: args.price || 0 } },
          3.0, 0, 0, 3.0,
        );
        if (user_id) {
          const rows = await sql`
            INSERT INTO decisions (user_id, category, decision_text, context, decision_factors, predicted_regret_score, risk_level, warnings, source_url, source_type)
            VALUES (${user_id}, ${args.category}, ${args.decision_text},
              ${JSON.stringify({ stress_level: args.stress_level || 3 })},
              ${JSON.stringify({ price: args.price || 0 })},
              ${regretPrediction.regret_score}, ${regretPrediction.risk_level},
              ${JSON.stringify(regretPrediction.warnings)}, ${args.source_url || null}, ${args.source_type || null})
            RETURNING *`;
          savedDecision = rows[0];
          if (savedDecision && args.followup_days) {
            const notifyAt = new Date(Date.now() + args.followup_days * 86400000).toISOString();
            await sql`INSERT INTO scheduled_notifications (user_id, decision_id, notify_at, message)
              VALUES (${user_id}, ${savedDecision.id}, ${notifyAt}, ${`「${args.decision_text}」その後どうでしたか？`})`;
          }
        }
        toolResults.push({ role: "tool", tool_call_id: tc.id, content: JSON.stringify({ saved: true, regret_prediction: regretPrediction }) });
      }
    }

    const onlyQuick = choice.message.tool_calls.every((tc: Record<string, unknown>) => (tc.function as Record<string, unknown>).name === "show_quick_replies");
    if (onlyQuick) {
      if (!assistantMessage) assistantMessage = "どれにする？";
      break;
    }

    messages.push(...toolResults);
    res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${OPENAI_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model: "gpt-5.4-mini", messages, temperature: 0.7, max_completion_tokens: 800, tools: TOOLS, tool_choice: "auto" }),
    });
    data = await res.json();
    choice = data.choices[0];
    assistantMessage = choice.message.content || assistantMessage;
  }

  if (user_id) {
    await sql`INSERT INTO chat_messages (user_id, role, content) VALUES (${user_id}, 'user', ${message})`;
    await sql`INSERT INTO chat_messages (user_id, role, content, metadata) VALUES (${user_id}, 'assistant', ${assistantMessage}, ${JSON.stringify(regretPrediction ? { regret_prediction: regretPrediction } : {})})`;
  }

  return json({ message: assistantMessage, decision: savedDecision, regret_prediction: regretPrediction, quick_replies: quickReplies, map: mapData });
}

async function handleFeedback(body: Record<string, unknown>) {
  const user_id = body.user_id as string;
  if (!user_id) return json({ error: "user_id必須" }, 400);

  const rows = await sql`
    INSERT INTO feedbacks (decision_id, user_id, regret_score, satisfaction_score, regret_reasons, would_change, feedback_timing, feedback_text)
    VALUES (${body.decision_id}, ${user_id}, ${body.regret_score}, ${body.satisfaction_score},
      ${JSON.stringify(body.regret_reasons || [])}, ${body.would_change || false}, ${body.feedback_timing || null}, ${body.feedback_text || null})
    RETURNING *`;

  await updatePatterns(user_id);
  return json({ feedback: rows[0], message: "保存しました" });
}

async function updatePatterns(userId: string) {
  const decisions = await sql`SELECT * FROM decisions WHERE user_id = ${userId} ORDER BY created_at DESC`;
  if (decisions.length === 0) return;
  const feedbacks = await sql`SELECT * FROM feedbacks WHERE user_id = ${userId}`;
  if (feedbacks.length === 0) return;

  await sql`DELETE FROM regret_patterns WHERE user_id = ${userId}`;

  const patterns = new Map<string, { pattern_type: string; trigger_conditions: Record<string, unknown>; regret_scores: number[]; occurrence_count: number }>();
  const add = (key: string, cond: Record<string, unknown>, score: number) => {
    const e = patterns.get(key);
    if (e) { e.regret_scores.push(score); e.occurrence_count++; }
    else patterns.set(key, { pattern_type: key, trigger_conditions: cond, regret_scores: [score], occurrence_count: 1 });
  };

  for (const d of decisions) {
    const ctx = (d.context as Record<string, unknown>) || {};
    const fac = (d.decision_factors as Record<string, unknown>) || {};
    const cat = d.category as string;
    const fb = feedbacks.find((f: Record<string, unknown>) => f.decision_id === d.id);
    if (!fb) continue;
    const rs = fb.regret_score as number;
    if ((ctx.stress_level as number) >= 4 && rs >= 4) add(`高ストレス時の${cat}選択`, { stress_level_min: 4, category: cat }, rs);
    if ((fac.price as number) > 1000 && rs >= 3) add("高額購入時の後悔", { price_min: 1000 }, rs);
    if ((fac.taste_expectation as number) <= 2 && rs >= 3) add("低期待値の選択", { expectation_max: 2 }, rs);
    const dow = ctx.day_of_week as string;
    if (dow && rs >= 4) add(`${dow}の${cat}`, { day_of_week: dow, category: cat }, rs);
  }

  for (const p of patterns.values()) {
    if (p.occurrence_count >= 2) {
      const avg = p.regret_scores.reduce((a, b) => a + b, 0) / p.regret_scores.length;
      await sql`INSERT INTO regret_patterns (user_id, pattern_type, trigger_conditions, average_regret, occurrence_count)
        VALUES (${userId}, ${p.pattern_type}, ${JSON.stringify(p.trigger_conditions)}, ${avg}, ${p.occurrence_count})`;
    }
  }
}

async function handleDecisions(userId: string, limit: number, offset: number) {
  const rows = await sql`
    SELECT d.*, COALESCE(json_agg(f.*) FILTER (WHERE f.id IS NOT NULL), '[]') as feedbacks
    FROM decisions d LEFT JOIN feedbacks f ON f.decision_id = d.id
    WHERE d.user_id = ${userId} GROUP BY d.id ORDER BY d.created_at DESC LIMIT ${limit} OFFSET ${offset}`;
  return json({ decisions: rows });
}

async function handleChatHistory(userId: string, limit: number) {
  const rows = await sql`SELECT * FROM chat_messages WHERE user_id = ${userId} ORDER BY created_at ASC LIMIT ${limit}`;
  return json({ messages: rows });
}

async function handlePatterns(userId: string) {
  const rows = await sql`SELECT * FROM regret_patterns WHERE user_id = ${userId} ORDER BY occurrence_count DESC`;
  return json({ patterns: rows });
}

async function handleStats(userId: string) {
  const stats = await sql`SELECT
    (SELECT count(*) FROM decisions WHERE user_id = ${userId}) as total_decisions,
    (SELECT count(*) FROM feedbacks WHERE user_id = ${userId}) as total_feedbacks`;
  const cats = await sql`
    SELECT d.category, avg(f.regret_score) as avg_regret
    FROM decisions d JOIN feedbacks f ON f.decision_id = d.id
    WHERE d.user_id = ${userId} GROUP BY d.category`;
  const categoryStats: Record<string, number> = {};
  for (const c of cats) categoryStats[c.category as string] = Number(c.avg_regret);
  return json({
    total_decisions: Number(stats[0].total_decisions),
    total_feedbacks: Number(stats[0].total_feedbacks),
    category_stats: categoryStats,
  });
}

// ============ ルーター ============

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const url = new URL(req.url);
  const path = url.pathname;

  try {
    if (path === "/chat" && req.method === "POST") return await handleChat(await req.json());
    if (path === "/feedback" && req.method === "POST") return await handleFeedback(await req.json());

    if (path === "/decisions" && req.method === "GET") {
      const uid = url.searchParams.get("user_id");
      if (!uid) return json({ error: "user_id必須" }, 400);
      return await handleDecisions(uid, Number(url.searchParams.get("limit") || 20), Number(url.searchParams.get("offset") || 0));
    }
    if (path === "/chat_history" && req.method === "GET") {
      const uid = url.searchParams.get("user_id");
      if (!uid) return json({ error: "user_id必須" }, 400);
      return await handleChatHistory(uid, Number(url.searchParams.get("limit") || 50));
    }
    if (path === "/patterns" && req.method === "GET") {
      const uid = url.searchParams.get("user_id");
      if (!uid) return json({ error: "user_id必須" }, 400);
      return await handlePatterns(uid);
    }
    if (path === "/stats" && req.method === "GET") {
      const uid = url.searchParams.get("user_id");
      if (!uid) return json({ error: "user_id必須" }, 400);
      return await handleStats(uid);
    }
    if (path === "/") return json({ status: "ok", service: "RegretLens API" });

    return json({ error: "Not Found" }, 404);
  } catch (e) {
    console.error("Error:", e);
    return json({ error: `サーバーエラー: ${(e as Error).message}` }, 500);
  }
});
