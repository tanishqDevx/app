"use client";

import { useState } from "react";

export default function SearchForm() {
  const [code, setCode] = useState("");
  const [year, setYear] = useState("24"); // default year
  const [data, setData] = useState<{ result?: string; photo?: string; error?: string } | null>(null);

  // Regex: 1 digit + 2 alphanumeric chars
  const pattern = /^[0-9][A-Za-z0-9]{2}$/;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!pattern.test(code)) {
      alert("Code must be 1 number + 2 alphanumeric chars (e.g. 1AB, 9z3).");
      return;
    }

    try {
      const res = await fetch(`/api/db?query=${code}&year=${year}`);
      const json = await res.json();
      setData(json);
    } catch (err) {
      setData({ error: "Failed to fetch from server." });
    }
  };

  return (
    <div className="p-4 border rounded max-w-md mx-auto">
      <form onSubmit={handleSubmit} className="flex flex-col gap-3">
        {/* Roll Code Input */}
        <input
          type="text"
          value={code}
          onChange={(e) => setCode(e.target.value)}
          placeholder="last three digit of roll no"
          className="border rounded p-2"
          maxLength={3}
        />

        {/* Year Dropdown */}
        <select
          value={year}
          onChange={(e) => setYear(e.target.value)}
          className="border rounded p-2"
        >
          {[20, 21, 22, 23, 24].map((y) => (
            <option key={y} value={y}>{y}</option>
          ))}
        </select>

        <button type="submit" className="bg-blue-500 text-white px-4 py-2 rounded">
          Search
        </button>
      </form>

      {data && (
        <div className="mt-4 p-3 bg-gray-100 rounded">
          {data.error && <p className="text-red-600 font-semibold">{data.error}</p>}
          {data.result && <p className="font-semibold">{data.result}</p>}
          {data.photo && (
            <div className="mt-2">
              <img
                src={data.photo}
                alt="Student photo"
                className="rounded shadow-md max-w-xs"
              />
            </div>
          )}
        </div>
      )}
    </div>
  );
}
