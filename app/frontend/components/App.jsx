import { useState, useEffect } from "react";
import NavBar from "./NavBar";
import ChatInput from "./ChatInput";

export default function AiApp() {
  const [prompt, setPrompt] = useState("");
  const [resultText, setResultText] = useState("");
  const [loading, setLoading] = useState(false);
  const [rating, setRating] = useState(0);
  const [feedbackSent, setFeedbackSent] = useState(false);

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
      setResultText(data.resultText || "Aucun résultat");
    } catch (e) {
      setResultText("Erreur : " + e.message);
    } finally {
      setLoading(false);
    }
  };

  const submitFeedback = async () => {
    if (!rating) return;

    try {
      await fetch("/api/ai/feedback", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          type: "global",
          prompt_text: prompt,
          result_text: resultText,
          rating,
        }),
      });

      setFeedbackSent(true);
      setTimeout(() => setFeedbackSent(false), 3000);
    } catch (e) {
      alert("Erreur lors de l'envoi du feedback");
    }
  };

  const StarRating = () => (
    <div className="flex gap-1">
      {[1,2,3,4,5].map((n) => (
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
    <div className="content">
      <NavBar />
      <div className="p-10 min-h-screen bg-gray-100 flex justify-center">
        <div className="w-[70%] space-y-6"> {/* <-- largeur 70% */}

          <h1 className="text-3xl font-bold text-center">Assistant AI</h1>

          {/* --- Résultat --- */}
          {resultText && (
            <div className="bg-white p-5 rounded shadow space-y-4">
              <h3 className="font-semibold">Résultat</h3>
              <pre className="whitespace-pre-wrap">{resultText}</pre>

              <div>
                <p className="mb-1">Notez le résultat :</p>
                <StarRating />
                <button
                  onClick={submitFeedback}
                  disabled={!rating}
                  className="mt-2 bg-green-600 text-white px-4 py-1 rounded hover:bg-green-700 disabled:opacity-40"
                >
                  Envoyer feedback
                </button>
                {feedbackSent && (
                  <p className="text-green-600 text-sm mt-1">Merci pour votre retour ❤️</p>
                )}
              </div>

              <button
                onClick={saveProposal}
                disabled={!resultText}
                className="ml-2 mt-2 bg-blue-600 text-white px-4 py-1 rounded hover:bg-blue-700 disabled:opacity-40"
              >
                💾 Sauvegarder
              </button>
            </div>
          )}

          {/* --- Formulaire prompt --- */}
          <div className="text-area-container">
        <div className="flex flex-col bg-gray-100 p-4 rounded-full">
         <textarea
            className="px-4 py-2 border rounded-full resize-none focus:border-[#cabb90] focus:outline-none"

            placeholder="Votre demande..."
            value={prompt}
            style={{ height: "auto", maxHeight: '7.5rem', overflowY: 'auto' }}
            rows={1}
            onChange={(e) => {
              setPrompt(e.target.value);
              // reset height and expand up to maxHeight (5 lines)
              e.target.style.height = "auto";
              const newHeight = Math.min(e.target.scrollHeight, 7.5 * 16 / 1) + "px"; // 7.5rem approximated in px
              e.target.style.height = newHeight;
            }}
            onKeyDown={(e) => {
              // Enter should insert a newline and let the textarea grow.
              // Use Cmd/Ctrl+Enter to submit the prompt from the keyboard.
              const isSubmit = (e.key === "Enter") && (e.metaKey || e.ctrlKey);
              if (isSubmit) {
                e.preventDefault();
                handleSubmit();
              } else {
                // Schedule a resize after the new line is applied, but cap to maxHeight
                setTimeout(() => {
                  e.target.style.height = "auto";
                  const newHeight = Math.min(e.target.scrollHeight, 7.5 * 16 / 1) + "px";
                  e.target.style.height = newHeight;
                }, 0);
              }
            }}
          />



  <button
    onClick={handleSubmit}
    disabled={loading}
    className="mt-2 h-12 w-32 bg-[#cabb90] text-white px-4 rounded-full hover:brightness-90 disabled:opacity-40 self-end"
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
