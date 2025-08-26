import { NextResponse } from "next/server";

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const query = searchParams.get("query");

  if (!query) {
    return NextResponse.json({ error: "Missing query" }, { status: 400 });
  }

  const roll_suffix = query.toUpperCase();

  return NextResponse.json({
    result: `You searched for: ${query}`,
    photo: `/api/photo?roll=${roll_suffix}`, // send proxy URL
  });
}
