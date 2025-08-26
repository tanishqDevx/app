import { NextResponse } from "next/server";

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);

  const roll = searchParams.get("roll");
  const year = searchParams.get("year");

  if (!roll || !year) {
    return NextResponse.json(
      { error: "Missing roll or year" },
      { status: 400 }
    );
  }

  // Build external URL
  const rollSuffix = roll.toUpperCase();
  const url = `http://portal.teleuniv.in/public/pics/${year}BD1A0${rollSuffix}.jpg?timer=1`;

  try {
    const res = await fetch(url);

    if (!res.ok) {
      return NextResponse.json({ error: "Image not found" }, { status: 404 });
    }

    const buffer = await res.arrayBuffer();

    return new NextResponse(buffer, {
      headers: {
        "Content-Type": "image/jpeg",
        "Cache-Control": "public, max-age=86400", // 1 day cache
      },
    });
  } catch (err) {
    return NextResponse.json(
      { error: "Failed to fetch image" },
      { status: 500 }
    );
  }
}
