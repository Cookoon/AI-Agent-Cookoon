import React, { useEffect, useState } from "react";

export default function AdditionalPromptEditor() {
  const [content, setContent] = useState("");
  const [meta, setMeta] = useState(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  const fetchPrompt = async () => {
    try {
      const res = await fetch("/api/additional_prompt");
      if (!res.ok) throw new Error(`Erreur ${res.status}`);
      const data = await res.json();
      setContent(data.content || "");
      setMeta(data);
    } catch (e) {
      console.error(e);
      setError("Impossible de charger le prompt.");
    }
  };

  useEffect(() => {
    fetchPrompt();
  }, []);

  const savePrompt = async () => {
    setSaving(true);
    setError(null);
    try {
      const res = await fetch("/api/additional_prompt", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ content }),
      });
      if (!res.ok) throw new Error(`Erreur ${res.status}`);
      const data = await res.json();
      setMeta(data);
    } catch (e) {
      console.error(e);
      setError("Impossible de sauvegarder le prompt.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="max-w-3xl mx-auto p-6 pt-32">
      <div className="bg-white rounded-lg shadow-md overflow-hidden">
        <div className="px-6 py-4 flex items-center justify-between border-b">
          <h2 className="text-lg font-semibold text-gray-800">Instructions supplémentaires</h2>
        </div>

        <div className="p-6">
          {error && <p className="text-red-500 mb-4">{error}</p>}

          <label className="sr-only">Instructions</label>
          <textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            rows={12}
            className="w-full resize-y font-mono text-sm border border-gray-200 rounded-md p-4 bg-gray-50 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-[#cabb90]"
          />

          <div className="mt-4 flex items-center justify-between gap-4">
            <button
              onClick={savePrompt}
              disabled={saving}
              className="inline-flex items-center px-4 py-2 rounded-md text-white bg-[#cabb90] hover:bg-[#b8a676] disabled:opacity-60 disabled:cursor-not-allowed transition-colors"
            >
              {saving ? "Sauvegarde..." : "Sauvegarder"}
            </button>

            {meta && (
              <p className="text-sm text-gray-500">
                Dernière modification par{" "}
                <strong className="text-gray-700">{meta.updated_by ?? "—"}</strong> le{" "}
                {meta.updated_at ? new Date(meta.updated_at).toLocaleString() : "—"}
              </p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
