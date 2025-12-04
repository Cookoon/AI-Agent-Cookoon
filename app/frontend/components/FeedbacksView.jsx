import { useEffect, useState } from "react";

export default function FeedbackView() {
  const [feedbacks, setFeedbacks] = useState([]);
  const [loading, setLoading] = useState(false);

  // Récupère tous les feedbacks
  const fetchFeedbacks = async () => {
    setLoading(true);
    try {
      const res = await fetch("/api/feedbacks");
      if (!res.ok) throw new Error("Erreur lors de la récupération des feedbacks");
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

  // Supprime un feedback
  const handleDelete = async (id) => {
    if (!confirm("Voulez-vous vraiment supprimer ce feedback ?")) return;
    try {
      const res = await fetch(`/api/feedbacks/${id}`, { method: "DELETE" });
      if (!res.ok) throw new Error("Erreur lors de la suppression");
      setFeedbacks(feedbacks.filter(f => f.id !== id));
    } catch (err) {
      console.error(err);
      alert("Impossible de supprimer le feedback : " + err.message);
    }
  };

  return (
    <div className="p-8">
      <h1 className="text-3xl font-bold mb-6">Tous les Feedbacks</h1>

      {loading ? (
        <p>Chargement...</p>
      ) : feedbacks.length === 0 ? (
        <p>Aucun feedback disponible</p>
      ) : (
        <table className="min-w-full border">
          <thead>
            <tr className="bg-gray-200">
              <th className="px-4 py-2 text-left">Type</th>
              <th className="px-4 py-2 text-left">Prompt</th>
              <th className="px-4 py-2 text-left">Résultat</th>
              <th className="px-4 py-2 text-left">Note</th>
              <th className="px-4 py-2 text-left"></th>
            </tr>
          </thead>
          <tbody>
            {feedbacks.map(fb => (
              <tr key={fb.id} className="border-t">
                <td className="px-4 py-2">{fb.feedback_type}</td>
                <td className="px-4 py-2">{fb.prompt_text}</td>
                <td className="px-4 py-2">{fb.result_text}</td>
                <td className="px-4 py-2">{fb.rating}/⭐️</td>
                <td className="px-4 py-2">
                  <button
                    className="bg-red-500 hover:bg-red-600 text-white px-3 py-1 rounded"
                    onClick={() => handleDelete(fb.id)}
                  >
                    Supprimer
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
