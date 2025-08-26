"use client";

import { useState } from "react";

export default function StudentPhotoPage() {
  const [roll, setRoll] = useState("");
  const [year, setYear] = useState("24"); // default year
  const [photoUrl, setPhotoUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setPhotoUrl(null);

    if (!roll || !year) {
      setError("Please enter both roll and year.");
      return;
    }

    // Build the API URL
    const url = `/api/photo?roll=${encodeURIComponent(
      roll.toUpperCase()
    )}&year=${encodeURIComponent(year)}`;

    try {
      // Fetch as blob
      const res = await fetch(url);
      if (!res.ok) throw new Error("Failed to fetch image");

      const blob = await res.blob();
      const objectUrl = URL.createObjectURL(blob);
      setPhotoUrl(objectUrl);
    } catch (err) {
      setError("Failed to fetch from server.");
    }
  };

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4">Student Photo Search</h1>

      <form onSubmit={handleSubmit} className="space-y-2">
        <input
          type="text"
          placeholder="Roll (e.g., 51U)"
          value={roll}
          onChange={(e) => setRoll(e.target.value)}
          className="border p-2 w-full"
        />
        <input
          type="text"
          placeholder="Year (e.g., 24)"
          value={year}
          onChange={(e) => setYear(e.target.value)}
          className="border p-2 w-full"
        />
        <button type="submit" className="bg-blue-500 text-white p-2 w-full">
          Search
        </button>
      </form>

      {error && <p className="text-red-500 mt-2">{error}</p>}

      {photoUrl && (
        <div className="mt-4">
          <img src={photoUrl} alt="Student Photo" className="border" />
        </div>
      )}
    </div>
  );
}
