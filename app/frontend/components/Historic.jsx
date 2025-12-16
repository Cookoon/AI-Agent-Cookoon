import React, { useEffect, useState } from "react";
import NavBar from "./NavBar";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCopy } from "@fortawesome/free-regular-svg-icons";
import { faCheck } from "@fortawesome/free-solid-svg-icons";
import Identification from "./Identification";

export default function Historic() {
  const [proposals, setProposals] = useState([]);
  const [loading, setLoading] = useState(false);
  const [copiedId, setCopiedId] = useState(null);

  // Détermine l'URL de l'API selon l'environnement


  // ------------------- Fetch Proposals -------------------
  const fetchProposals = async () => {
    setLoading(true);
    try {
      const res = await fetch(`/api/saved_proposals`);
      if (!res.ok) throw new Error("Erreur lors de la récupération des propositions");

      const data = await res.json();
      console.log("Données reçues :", data);
      setProposals(data.saved_proposals || data);
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

  // ------------------- Delete Proposal -------------------
const handleDelete = async (id) => {
  if (!confirm("Voulez-vous vraiment supprimer cette proposition ?")) return;

  try {
    const res = await fetch(`/api/saved_proposals/${id}`, {
      method: "DELETE",
      credentials: "include",
    });

    if (!res.ok) throw new Error("Erreur lors de la suppression");

    setProposals((prev) => prev.filter((p) => p.id !== id));
  } catch (err) {
    console.error(err);
    alert("Impossible de supprimer la proposition : " + err.message);
  }
};


  // ------------------- Copy to Clipboard -------------------
  const handleCopy = (id, text) => {
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text);
      setCopiedId(id);
      setTimeout(() => setCopiedId(null), 2000);
    }
  };

  // ------------------- Download PDF -------------------
  const handleDownloadPDF = (id) => {
    window.open(`/api/saved_proposals/${id}/pdf`, "_blank");

  };

  // ------------------- Render -------------------
  return (
    <div className="min-h-screen bg-gray-50">


      <div className="w-[70%] mx-auto pb-32">
        <h1 className="text-2xl font-bold mb-6 pt-16">Propositions Sauvegardées</h1>

        {loading ? (
          <p className="text-gray-600">Chargement...</p>
        ) : proposals.length === 0 ? (
          <p className="text-gray-600">Aucune proposition sauvegardée</p>
        ) : (
          <div className="space-y-6">
            {proposals.map((p) => (
              <div key={p.id} className="bg-white shadow-lg rounded-lg p-6">
                <div className="mb-3">
                  <span className="font-semibold text-gray-600">Prompt :</span>
                  <div className="text-gray-700 truncate">{p.last_prompt}</div>
                </div>

                <div className="mb-3">
                  <span className="font-semibold text-gray-600">Proposition :</span>
                  <pre className="whitespace-pre-wrap font-avenir max-h-40 overflow-auto text-sm text-gray-700 bg-gray-50 p-3 rounded mt-1">
                    {p.proposal_text}
                  </pre>
                </div>

                <div className="mb-3 text-sm text-gray-500">
                  {new Date(p.created_at).toLocaleString()}
                </div>

                <div className="flex flex-wrap gap-2">
                  <button
                    className="bg-red-500 hover:bg-red-600 text-white px-3 py-1 rounded-md"
                    onClick={() => handleDelete(p.id)}
                  >
                    Supprimer
                  </button>

                  <button
                    className="bg-gray-200 hover:bg-gray-300 text-gray-800 px-3 py-1 rounded-md flex items-center gap-2"
                    onClick={() => handleCopy(p.id, p.proposal_text)}
                  >
                    <FontAwesomeIcon icon={copiedId === p.id ? faCheck : faCopy} />
                    {copiedId === p.id ? "Copié !" : "Copier"}
                  </button>

                  <button
                    className="bg-blue-500 hover:bg-blue-600 text-white px-3 py-1 rounded-md"
                    onClick={() => handleDownloadPDF(p.id)}
                  >
                    Télécharger PDF
                  </button>
               <div className="w-full">
                <p className="text-gray-500 text-right">
                  Sauvegardé par <span className="italic">{p.creator}</span>
                </p>
              </div>

                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
