import { neon } from "npm:@neondatabase/serverless";

// Neon serverless driver (HTTPベース、Deno Deploy対応)
export const sql = neon(Deno.env.get("DATABASE_URL")!);
