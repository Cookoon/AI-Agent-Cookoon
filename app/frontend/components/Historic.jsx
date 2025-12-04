import { useEffect, useState } from "react";
import NavBar from "./NavBar";

export default function Historic() {
  const [proposals, setProposals] = useState([]);
  const [loading, setLoading] = useState(false);

  // Récupérer toutes les propositions sauvegardées
  const fetchProposals = async () => {
    setLoading(true);
    try {
      const res = await fetch("/api/saved_proposals");
      if (!res.ok) throw new Error("Erreur lors de la récupération des propositions");
      const data = await res.json();
      setProposals(data);
    } catch (err) {
      console.error(err);
      alert("Impossible de récupérer les propositions : " + err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchProposals();
  }, []);

  // Supprimer une proposition
  const handleDelete = async (id) => {
    if (!confirm("Voulez-vous vraiment supprimer cette proposition ?")) return;
    try {
      const res = await fetch(`/api/saved_proposals/${id}`, { method: "DELETE" });
      if (!res.ok) throw new Error("Erreur lors de la suppression");
      setProposals(proposals.filter(p => p.id !== id));
    } catch (err) {
      console.error(err);
      alert("Impossible de supprimer la proposition : " + err.message);
    }
  };

  return (
    <div className="p-8">
      
      <h1 className="text-3xl font-bold mb-6">Historique des Propositions</h1>

      {loading ? (
        <p>Chargement...</p>
      ) : proposals.length === 0 ? (
        <p>Aucune proposition sauvegardée</p>
      ) : (
        <table className="min-w-full border">
          <thead>
            <tr className="bg-gray-200">
              <th className="px-4 py-2 text-left">Prompt</th>
              <th className="px-4 py-2 text-left">Proposition</th>
              <th className="px-4 py-2 text-left">Date</th>
              <th className="px-4 py-2 text-left">Actions</th>
            </tr>
          </thead>
          <tbody>
            {proposals.map(p => (
              <tr key={p.id} className="border-t">
                <td className="px-4 py-2">{p.last_prompt}</td>
                <td className="px-4 py-2"><pre className="whitespace-pre-wrap">{p.proposal_text}</pre></td>
                <td className="px-4 py-2">{new Date(p.created_at).toLocaleString()}</td>
                <td className="px-4 py-2">
                  <button
                    className="bg-red-500 hover:bg-red-600 text-white px-3 py-1 rounded"
                    onClick={() => handleDelete(p.id)}
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
