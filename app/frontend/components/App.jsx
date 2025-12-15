import { useState, useEffect } from "react";
import NavBar from "./NavBar";
import ChatInput from "./ChatInput";
import Identification from "./Identification";

export default function AiApp() {
  const [prompt, setPrompt] = useState("");
  const [resultText, setResultText] = useState("");
  const [loading, setLoading] = useState(false);
  const [rating, setRating] = useState(0);
  const [feedbackSent, setFeedbackSent] = useState(false);
  const [chefs, setChefs] = useState([]);
  const [lieux, setLieux] = useState([]);

  // Reset historique au refresh
  useEffect(() => localStorage.removeItem("prompt_history"), []);

  const handleSubmit = async () => {
    if (!prompt) return;
    setLoading(true);
    localStorage.setItem("prompt_history", JSON.stringify([prompt]));

    try {
      const res = await fetch("/api/ai/recommend", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ prompt }),
      });

      const data = await res.json();
      const text = data.resultText || "Aucun résultat";
      setResultText(text);

      // --- Parse CHEFS / LIEUX ---
      const chefsMatch = text.match(/CHEFS\s*:(.*?)(?=LIEUX\s*:|$)/s);
      const lieuxMatch = text.match(/LIEUX\s*:(.*)/s);

      setChefs(
        chefsMatch
          ? chefsMatch[1].trim().split(/\n\n+/).map((c) => c.split("\n"))
          : []
      );
      setLieux(
        lieuxMatch
          ? lieuxMatch[1].trim().split(/\n\n+/).map((l) => l.split("\n"))
          : []
      );
    } catch (e) {
      setResultText("Erreur : " + e.message);
      setChefs([]);
      setLieux([]);
    } finally {
      setLoading(false);
    }
  };

  const submitFeedback = async () => {
    if (!rating) {
      alert("Veuillez sélectionner une note avant d'envoyer le feedback.");
      return;
    }

    try {
      const res = await fetch("/api/feedbacks", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          prompt_text: prompt,
          result_text: resultText,
          rating,
        }),
      });

      const data = await res.json().catch(() => {
        throw new Error("Réponse du serveur invalide (non JSON)");
      });

      if (!res.ok) {
        throw new Error(data.error || `Erreur HTTP ${res.status}`);
      }

      setFeedbackSent(true);
      setTimeout(() => setFeedbackSent(false), 3000);
    } catch (e) {
      console.error("Erreur submitFeedback:", e);
      alert("Erreur lors de l'envoi du feedback : " + e.message);
    }
  };

  const StarRating = () => (
    <div className="flex gap-1">
      {[1, 2, 3, 4, 5].map((n) => (
        <button
          key={n}
          onClick={() => setRating(n)}
          className={`text-2xl transition ${
            n <= rating ? "text-yellow-400 scale-110" : "text-gray-300"
          }`}
        >
          ★
        </button>
      ))}
    </div>
  );

  const saveProposal = async () => {
    if (!resultText || !prompt) return;

    try {
      await fetch("/api/saved_proposals", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          last_prompt: prompt,
          proposal_text: resultText,
        }),
      });

      alert("💾 Proposition sauvegardée !");
    } catch {
      alert("Erreur lors de la sauvegarde");
    }
  };

  return (
    <div className="content AvenirRegular">
      <Identification />
      <NavBar />
      <div className="p-4 sm:p-6 min-h-screen bg-gray-100 flex justify-center">
        <div className="w-full sm:w-[90%] md:w-[80%] lg:w-[70%] space-y-6 pt-32">
          <h1 className="text-2xl sm:text-3xl font-bold text-center">
            Assistant AI
          </h1>

          {/* --- Résultat --- */}
          {resultText && (
            <div className="bg-white p-5 rounded-lg shadow-md space-y-4">
              <h3 className="font-semibold text-lg text-gray-800">Propostions</h3>

              <div className="flex flex-col md:flex-row gap-6">
                {/* --- CHEFS --- */}
                <div className="md:w-1/2 bg-gray-50 p-3 rounded-md overflow-y-auto max-h-96">
                  <h4 className="font-semibold mb-2">Chefs</h4>
                  {chefs.length > 0 ? (
                    chefs.map((c, i) => (
                      <div key={i} className="mb-3 p-2 border rounded">
                        {c.map((line, idx) => (
                          <p key={idx}>{line}</p>
                        ))}
                      </div>
                    ))
                  ) : (
                    <p>Aucun chef trouvé</p>
                  )}
                </div>

                {/* --- LIEUX --- */}
                <div className="md:w-1/2 bg-gray-50 p-3 rounded-md overflow-y-auto max-h-96">
                  <h4 className="font-semibold mb-2">Lieux</h4>
                  {lieux.length > 0 ? (
                    lieux.map((l, i) => (
                      <div key={i} className="mb-3 p-2 border rounded">
                        {l.map((line, idx) => (
                          <p key={idx}>{line}</p>
                        ))}
                      </div>
                    ))
                  ) : (
                    <p>Aucun lieu trouvé</p>
                  )}
                </div>
              </div>

              {/* --- Feedback / Sauvegarde --- */}
              <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
                <div className="flex items-center gap-2">
                  <StarRating />
                  <button
                    onClick={submitFeedback}
                    disabled={!rating}
                    className="bg-green-600 text-white px-3 py-1 rounded hover:bg-green-700 disabled:opacity-40 transition text-sm"
                  >
                    Envoyer
                  </button>
                  {feedbackSent && (
                    <div className="flex items-center ml-2">
                      <p className="text-gray-600 text-sm">Feedback envoyé</p>
                    </div>
                  )}
                </div>

                <button
                  onClick={saveProposal}
                  disabled={!resultText}
                  className="bg-blue-600 text-white px-3 py-1 rounded hover:bg-blue-700 disabled:opacity-40 transition text-sm"
                >
                  💾 Sauvegarder
                </button>
              </div>
            </div>
          )}

          {/* --- Formulaire prompt --- */}
          <div className="text-area-container">
            <div className="flex flex-col bg-gray-100 p-3 sm:p-4 rounded-full">
              <textarea
                className="w-full px-4 py-2 border rounded-full resize-none focus:border-[#cabb90] focus:outline-none text-sm sm:text-base"
                placeholder="Entrez votre demande la plus détaillée possible : chefs, types de cuisine, lieu, type de lieu, budget, nombre de guests, occasion..."
                value={prompt}
                style={{ height: "auto", maxHeight: "7.5rem", overflowY: "auto" }}
                rows={1}
                onChange={(e) => {
                  setPrompt(e.target.value);
                  e.target.style.height = "auto";
                  const newHeight = Math.min(e.target.scrollHeight, 7.5 * 16) + "px";
                  e.target.style.height = newHeight;
                }}
                onKeyDown={(e) => {
                  const isSubmit = e.key === "Enter" && (e.metaKey || e.ctrlKey);
                  if (isSubmit) {
                    e.preventDefault();
                    handleSubmit();
                  } else {
                    setTimeout(() => {
                      e.target.style.height = "auto";
                      const newHeight = Math.min(e.target.scrollHeight, 7.5 * 16) + "px";
                      e.target.style.height = newHeight;
                    }, 0);
                  }
                }}
              />

              <button
                onClick={handleSubmit}
                disabled={loading}
                className="mt-2 self-end h-10 sm:h-12 w-24 sm:w-32 bg-[#cabb90] text-white px-3 rounded-full hover:brightness-90 disabled:opacity-40 text-sm sm:text-base"
              >
                {loading ? "Chargement..." : "Envoyer"}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
