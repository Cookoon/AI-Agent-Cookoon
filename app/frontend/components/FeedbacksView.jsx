import { useEffect, useMemo, useState } from "react";
import NavBar from "./NavBar";
import Identification from "./Identification";

export default function FeedbackView() {
  const [feedbacks, setFeedbacks] = useState([]);
  const [loading, setLoading] = useState(false);
  const [query, setQuery] = useState("");

  const fetchFeedbacks = async () => {
    setLoading(true);
    try {
      const res = await fetch("/api/feedbacks");
      if (!res.ok) throw new Error(`Erreur ${res.status} lors de la récupération des feedbacks`);
      const data = await res.json();
      setFeedbacks(data);
    } catch (err) {
      console.error(err);
      alert("Impossible de récupérer les feedbacks : " + err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchFeedbacks();
  }, []);

  const handleDelete = async (id) => {
    if (!window.confirm("Voulez-vous vraiment supprimer ce feedback ?")) return;
    try {
      const res = await fetch(`/api/feedbacks/${id}`, { method: "DELETE" });
      if (res.status === 404) throw new Error("Feedback non trouvé pour suppression");
      if (!res.ok) throw new Error(`Erreur ${res.status} lors de la suppression`);
      setFeedbacks((prev) => prev.filter((f) => f.id !== id));
    } catch (err) {
      console.error(err);
      alert("Impossible de supprimer le feedback : " + err.message);
    }
  };

  const filtered = useMemo(() => {
    return feedbacks
      .filter((f) =>
        [f.prompt_text, f.result_text]
          .join(" ")
          .toLowerCase()
          .includes(query.trim().toLowerCase())
      )
      .sort((a, b) => (b.created_at || 0) - (a.created_at || 0));
  }, [feedbacks, query]);

  return (
    <>
      <NavBar />
      <Identification />
      <div className="p-6 max-w-6xl mx-auto">
        <h1 className="text-2xl sm:text-3xl font-extrabold text-gray-900 mb-16 pt-16">
          Feedbacks
        </h1>

        {loading ? (
          <div className="flex items-center justify-center py-16">
            <div className="animate-pulse text-gray-500">Chargement des feedbacks...</div>
          </div>
        ) : filtered.length === 0 ? (
          <div className="text-center py-12 text-gray-500">Aucun feedback pour le moment.</div>
        ) : (
          <div className="space-y-4">
            {filtered.map((fb) => (
              <article key={fb.id} className="bg-white shadow-sm border rounded-lg p-4 flex flex-col sm:flex-row sm:items-start gap-4">
                <div className="w-full sm:w-56 flex-shrink-0">
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-yellow-600 font-medium">{fb.rating ? `${fb.rating} ★` : "—"}</span>
                  </div>
                  <p className="mt-3 text-xs text-gray-500">
                    {fb.created_at ? new Date(fb.created_at).toLocaleString() : "Date inconnue"}
                  </p>
                </div>

                <div className="flex-1">
                  <h3 className="text-sm font-semibold text-gray-900 mb-1">Prompt</h3>
                  <p className="text-sm text-gray-700 bg-gray-50 p-2 rounded-md whitespace-pre-wrap">{fb.prompt_text || "—"}</p>

                  <h4 className="text-sm font-semibold text-gray-900 mt-3 mb-1">Résultat</h4>
                  <div className="max-h-32 overflow-y-auto bg-gray-50 p-2 rounded-md">
                    <p className="text-xs text-gray-700 whitespace-pre-wrap">{fb.result_text || "—"}</p>
                  </div>

                  <div className="mt-4 flex items-center justify-end gap-2">
                    <button
                      onClick={() => handleDelete(fb.id)}
                      className="text-sm bg-red-500 hover:bg-red-600 text-white px-3 py-1 rounded-md"
                    >
                      Supprimer
                    </button>
                  </div>
                </div>
              </article>
            ))}
          </div>
        )}
      </div>
    </>
  );
}
