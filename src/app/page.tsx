"use client";

import { useState } from "react";

export default function SearchForm() {
  const [code, setCode] = useState("");
  const [data, setData] = useState<{ result?: string; photo?: string; error?: string } | null>(null);

  const pattern = /^[0-9][A-Za-z0-9]{2}$/;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!pattern.test(code)) {
      alert("Code must be 1 number + 2 alphanumeric chars (e.g. 1AB, 9z3).");
      return;
    }

    try {
      const res = await fetch(`/api/db?query=${code}`);
      const json = await res.json();
      setData(json);
    } catch (err) {
      setData({ error: "Failed to fetch from server." });
    }
  };

  return (
    <div className="p-4 border rounded max-w-md mx-auto">
      <form onSubmit={handleSubmit} className="flex gap-2">
        <input
          type="text"
          value={code}
          onChange={(e) => setCode(e.target.value)}
          placeholder="e.g. 1AB"
          className="border rounded p-2 flex-1"
          maxLength={3}
        />
        <button
          type="submit"
          className="bg-blue-500 text-white px-4 py-2 rounded"
        >
          Search
        </button>
      </form>

      {data && (
        <div className="mt-4 p-3 bg-gray-100 rounded">
          {data.error && <p className="text-red-600 font-semibold">{data.error}</p>}
          {data.result && <p className="font-semibold">{data.result}</p>}
          {data.photo && (
            <div className="mt-2">
              <img src={data.photo} alt="Student photo" className="rounded shadow-md max-w-xs" />
            </div>
          )}
        </div>
      )}
    </div>
  );
}
