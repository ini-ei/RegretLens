import "@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders } from "../_shared/cors.ts";

const PLACES_API_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY")!;

interface PlacesRequest {
  lat: number;
  lng: number;
  query?: string;
  type?: string; // restaurant, cafe, etc.
  radius?: number;
}

interface PlaceResult {
  place_id: string;
  name: string;
  rating: number;
  user_ratings_total: number;
  vicinity: string;
  price_level?: number;
  opening_hours?: { open_now: boolean };
  types: string[];
  reviews_summary?: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { lat, lng, query, type, radius = 800 } = (await req.json()) as PlacesRequest;

    // Nearby Search
    const params = new URLSearchParams({
      location: `${lat},${lng}`,
      radius: radius.toString(),
      language: "ja",
      key: PLACES_API_KEY,
    });
    if (query) params.set("keyword", query);
    if (type) params.set("type", type);

    const searchRes = await fetch(
      `https://maps.googleapis.com/maps/api/place/nearbysearch/json?${params}`,
    );
    const searchData = await searchRes.json();

    if (searchData.status !== "OK") {
      return new Response(
        JSON.stringify({ error: `Places API: ${searchData.status}`, places: [] }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // 上位5件のレビューを取得
    const places: PlaceResult[] = [];
    const topResults = searchData.results.slice(0, 5);

    await Promise.all(
      topResults.map(async (place: Record<string, unknown>) => {
        const detailParams = new URLSearchParams({
          place_id: place.place_id as string,
          fields: "name,rating,user_ratings_total,formatted_address,price_level,opening_hours,reviews,types",
          language: "ja",
          key: PLACES_API_KEY,
        });

        const detailRes = await fetch(
          `https://maps.googleapis.com/maps/api/place/details/json?${detailParams}`,
        );
        const detailData = await detailRes.json();
        const detail = detailData.result;

        if (!detail) return;

        // レビューを要約
        let reviewsSummary = "";
        const reviews = detail.reviews as Array<Record<string, unknown>> || [];
        if (reviews.length > 0) {
          const lowReviews = reviews.filter((r) => (r.rating as number) <= 3);
          const highReviews = reviews.filter((r) => (r.rating as number) >= 4);

          if (highReviews.length > 0) {
            reviewsSummary += "良い点: " + highReviews.slice(0, 2).map((r) => {
              const text = (r.text as string) || "";
              return text.length > 50 ? text.substring(0, 50) + "..." : text;
            }).join(" / ");
          }
          if (lowReviews.length > 0) {
            reviewsSummary += " | 注意点: " + lowReviews.slice(0, 2).map((r) => {
              const text = (r.text as string) || "";
              return text.length > 50 ? text.substring(0, 50) + "..." : text;
            }).join(" / ");
          }
        }

        places.push({
          place_id: place.place_id as string,
          name: detail.name || "",
          rating: detail.rating || 0,
          user_ratings_total: detail.user_ratings_total || 0,
          vicinity: detail.formatted_address || "",
          price_level: detail.price_level,
          opening_hours: detail.opening_hours ? { open_now: detail.opening_hours.open_now } : undefined,
          types: detail.types || [],
          reviews_summary: reviewsSummary || undefined,
        });
      }),
    );

    // 評価順にソート
    places.sort((a, b) => b.rating - a.rating);

    return new Response(
      JSON.stringify({ places }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("Places error:", error);
    return new Response(
      JSON.stringify({ error: `Places検索エラー: ${error.message}` }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
