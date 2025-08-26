import { NextResponse } from "next/server";

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const query = searchParams.get("query"); // roll suffix
  const year = searchParams.get("year");   // 20–25

  if (!query || !year) {
    return NextResponse.json({ error: "Missing query or year" }, { status: 400 });
  }

  const roll_suffix = query.toUpperCase();

  return NextResponse.json({
    result: `You searched for: ${year}-${query}`,
    photo: `/api/photo?roll=${roll_suffix}&year=${year}`, // pass both
  });
}
