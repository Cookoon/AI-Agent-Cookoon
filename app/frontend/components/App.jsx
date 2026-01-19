import React, { useState, useEffect, useContext } from "react";
import NavBar from "./NavBar";
import Identification from "./Identification";
import { UserProvider, UserContext } from "./UserContext";

import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faArrowUp } from "@fortawesome/free-solid-svg-icons";

function AiAppContent() {
  const { currentUser, setCurrentUser } = useContext(UserContext);

  const [prompt, setPrompt] = useState("");
  const [resultText, setResultText] = useState("");
  const [loading, setLoading] = useState(false);
  const [rating, setRating] = useState(0);
  const [feedbackSent, setFeedbackSent] = useState(false);
  const [chefs, setChefs] = useState([]);
  const [lieux, setLieux] = useState([]);
  const [showTitle, setShowTitle] = useState(true);

  // nouvel état pour piloter l'animation d'apparition du bloc résultat
  const [resultVisible, setResultVisible] = useState(false);

  // Vérifie la session au chargement
  useEffect(() => {
    fetch("/api/me", { credentials: "include" })
      .then((res) => (res.ok ? res.json() : Promise.reject()))
      .then((data) => setCurrentUser(data.name))
      .catch(() => setCurrentUser(""));
  }, [setCurrentUser]);

  // Reset historique au refresh
  useEffect(() => localStorage.removeItem("prompt_history"), []);

  const sanitize = (arr) =>
    Array.isArray(arr)
      ? [...new Set(arr.map((s) => (s || "").toString().trim()).filter(Boolean))]
      : [];

  const handleSubmit = async () => {
    if (!prompt) return;
    setLoading(true);
    setResultVisible(false); // masquer le résultat avant la requête (prépare l'animation d'entrée)
    localStorage.setItem("prompt_history", JSON.stringify([prompt]));

    const payload = {
      prompt,
      ban_chefs: sanitize(selectedLinesChefs),
      ban_lieux: sanitize(selectedLinesLieux),
    };

    try {
      const res = await fetch("/api/ai/recommend", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
        credentials: "include",
      });

      const data = await res.json();
      const text = data.resultText || "Aucun résultat";
      setResultText(text);

      // petit délai pour laisser le DOM monter avec l'état initial (opacity-0) puis déclencher la transition vers visible
      setTimeout(() => setResultVisible(true), 20);

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
      setTimeout(() => setResultVisible(true), 20);
    } finally {
      setLoading(false);
      setShowTitle(false); // fait disparaître la nav / titre (animation gérée en CSS/Tailwind)
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
          creator: currentUser,
        }),
        credentials: "include",
      });

      const data = await res.json().catch(() => {
        throw new Error("Réponse du serveur invalide (non JSON)");
      });

      if (!res.ok) throw new Error(data.error || `Erreur HTTP ${res.status}`);

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

  const [buttonText, setButtonText] = useState("💾 Sauvegarder");

  const saveProposal = async () => {
    if (!resultText || !prompt) return;

    try {
      setButtonText("Sauvegarde...");

      const response = await fetch("/api/saved_proposals", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          last_prompt: prompt,
          proposal_text: resultText,
          creator: currentUser,
        }),
        credentials: "include",
      });

      if (!response.ok) throw new Error("Erreur lors de la sauvegarde");

      setButtonText("Sauvegardé !");
      setTimeout(() => setButtonText("💾 Sauvegarder"), 3000); // revient au texte initial
    } catch (error) {
      console.error("Impossible de sauvegarder :", error);
      setButtonText("💾 Sauvegarder"); // remet le texte initial en cas d'erreur
    }
  };

  const phrases = [
    "Que puis-je vous proposer aujourd'hui ?",
    "Avez-vous besoin d'aide pour un projet ?",
    "Un nouveau dîner à organiser ?",
    "Besoin d'idées pour votre prochain événement ?",
    "Laissez-moi vous inspirer !",
    "Prêt à découvrir de nouvelles saveurs ?",
    "Votre assistant culinaire est à votre service.",
    "Explorons ensemble de nouvelles possibilités !",
    "Quel type d'expérience recherchez-vous ?",
    "Je suis là pour vous aider à trouver les meilleures options.",
    "On prépare quelque chose de spécial aujourd'hui ?",
    "Envie d'un événement qui sort de l'ordinaire ?",
    "Je peux vous aider à imaginer le menu parfait.",
    "Prêt à organiser un moment inoubliable ?",
  ];

  // État pour la phrase affichée
  const [phrase, setPhrase] = useState("");

  useEffect(() => {
    // Choisir une phrase aléatoire au montage du composant
    const randomIndex = Math.floor(Math.random() * phrases.length);
    setPhrase(phrases[randomIndex]);
  }, []);

  // classes d'animations pour la nav (disparition) et le bloc résultat (apparition)
  const navWrapperClass = `transform transition-all duration-500 ease-in-out ${
    showTitle ? "opacity-100 translate-y-0" : "opacity-0 -translate-y-6 pointer-events-none"
  }`;

  // Non-responsive result wrapper (same layout for all screen sizes)
const resultWrapperClass = `
  bg-white p-5 rounded-lg shadow-md space-y-4
  w-full max-w-lg
  md:w-[80vw] md:max-w-none
  min-h-[70vh]
  transform transition-all duration-500 ease-out
  ${
    resultVisible
      ? "opacity-100 translate-y-0"
      : "opacity-0 translate-y-4 pointer-events-none"
  }
  md:-translate-x-16
`;



    const [selectedLinesChefs, setSelectedLinesChefs] = useState([]);

  const handleAddFirstLineChefs = (line) => {
    setSelectedLinesChefs((prev) => [...prev, line]);
  };

  const [selectedLinesLieux, setSelectedLinesLieux] = useState([]);

  const handleSelectFirstLineLieux = (lines) => {
    if (lines.length > 0) {

      setSelectedLinesLieux((prev) => [...prev, lines[0]]);
    }
  };

const handleSendBanList = async () => {
  if (selectedLinesChefs.length === 0 && selectedLinesLieux.length === 0) {
    return;
  }

  try {
    const response = await fetch("/api/ai/recommend", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ chefs: selectedLinesChefs, lieux: selectedLinesLieux, prompt: "..." }),
    });

    if (!response.ok) {
      throw new Error(`Erreur: ${response.status}`);
    }

    const data = await response.json();
    console.log("Réponse backend :", data);

  } catch (error) {
    console.error("Erreur lors de l'envoi au backend :", error);

  }
};




  return (
    <div className="content AvenirRegular">
      {/* NavBar with disappearance animation */}
      <div className={navWrapperClass}>
        <NavBar />
      </div>

      <Identification />

      <div className="p-4 sm:p-6 min-h-screen bg-gray-100 flex justify-center">
        <div className="w-full sm:w-[90%] md:w-[80%] lg:w-[70%] space-y-6 pt-16">
          {showTitle && (
            <>
              <h2
                className="pt-16 mx-auto text-center text-2xl sm:text-3xl text-gray-800 italic tracking-wide leading-tight"
                style={{ fontFamily: "NyghtSerif, serif" }}
              >
                Bonjour {currentUser || "Invité"},
              </h2>

              <h3 className="mx-auto text-center text-md sm:text-lg text-gray-600 italic tracking-wide leading-tight">
                {phrase}
              </h3>
            </>
          )}

          {/* --- Résultat --- */}
          {/* Le bloc résultat est monté conditionnellement comme avant,
              mais reçoit maintenant une animation d'apparition via resultVisible */}
          {resultText && (
            <div className={resultWrapperClass}>
              <h3 className="font-semibold text-lg text-gray-800">Propositions :</h3>

              <div className="flex flex-col md:flex-row gap-6">
                {/* CHEFS */}
                <div className="md:w-1/2 bg-gray-50 p-3 rounded-md overflow-y-auto max-h-[70vh]">
                  <h4 className="font-semibold mb-2 text-[#cabb90]">Chefs</h4>
                  <div>
      {/* Liste des chefs */}
                {chefs.length > 0 ? (
                  chefs.map((c, i) => (
                    <div key={i} className="mb-3 p-2 border border-[#cabb90] rounded">
                      {c.map((line, idx) => (
                        <p key={idx}>{line}</p>
                      ))}
                      {/* Bouton qui ajoute la première ligne */}
                      {c.length > 0 && (
                        <button
                          onClick={() => handleAddFirstLineChefs(c[0])}
                          className="mt-2 px-3 py-1 bg-[#cabb90] rounded text-white"
                        >
                          Retirer
                        </button>
                      )}
                    </div>
                  ))
                ) : (
                  "Aucun chef trouvé"
                )}

                {/* Affichage du tableau des lignes sélectionnées */}
                {selectedLinesChefs.length > 0 && (
                  <div className="mt-5">
                     <h3>
      {selectedLinesChefs.length === 1 ? "Chef retiré :" : "Chefs retirés :"}
                    </h3>
                    <ul className="list-disc list-inside">
                       {selectedLinesChefs.map((line, idx) => (
                        <li
                          key={idx}
                          className="flex items-center justify-between"
                        >
                          <span>{line}</span>

                          <button
                            onClick={() =>
                              setSelectedLinesChefs(prev =>
                                prev.filter((_, i) => i !== idx)
                              )
                            }
                            className="ml-3 text-sm text-red-500 hover:text-red-700 transition"
                            aria-label="Retirer ce chef"
                          >
                            ✕
                          </button>
                        </li>
                      ))}
                    </ul>
                  </div>
                )}
                  </div>
                </div>

                {/* LIEUX */}
                <div className="md:w-1/2 bg-gray-50 p-3 rounded-md overflow-y-auto max-h-[70vh]">
                  <h4 className="font-semibold mb-2 text-[#cabb90]">Lieux</h4>
                  {lieux.length > 0 ? (
                      lieux.map((l, i) => (
                        <div key={i} className="mb-3 p-2 border border-[#cabb90] rounded">
                          {l.map((line, idx) => (
                            <p key={idx}>{line}</p>
                          ))}
                          <button
                          onClick={() => handleSelectFirstLineLieux(l)}
                          className="mt-2 px-3 py-1 bg-[#cabb90] rounded text-white"
                        >
                          Retirer
                        </button>
                          </div>
                      ))
                    ) : (
                      "Aucun lieu trouvé"
                    )}

                    {selectedLinesLieux.length > 0 && (
                      <div className="mt-4">
                        {selectedLinesLieux.length === 1 ? "Lieu retiré :" : "Lieux retirés :"}
                        <ul className="list-disc pl-5">
                          {selectedLinesLieux.map((line, idx) => (
                            <li key={idx} className="flex items-center justify-between">
                              <span>{line}</span>

                            <button
                              onClick={() =>
                                setSelectedLinesLieux(prev =>
                                  prev.filter((_, i) => i !== idx)
                                )
                              }
                              className="ml-3 text-sm text-red-500 hover:text-red-700"
                            >
      ✕
    </button>
  </li>
))}
                        </ul>
                      </div>
                    )}
                </div>
              </div>

              <style>{`
                div[class*="min-h-[70vh]"] {
                  transition-duration: 700ms !important;
                }
              `}</style>

              {/* Feedback / Sauvegarde */}
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
                                {feedbackSent && <p className="text-gray-600 text-sm ml-2">Feedback envoyé</p>}
                              </div>

                              <button
                                onClick={saveProposal}
                                disabled={!resultText}
                                className="bg-blue-600 text-white px-3 py-1 rounded hover:bg-blue-700 disabled:opacity-40 transition text-sm"
                              >
                                {buttonText}
                              </button>
                            </div>
                          </div>
                        )}

                        {/* Formulaire prompt - centered and slightly wider textarea */}
          <div className="flex justify-center">

            {/* increased max width slightly to enlarge the textarea */}
            <div className="w-full max-w-2xl mx-auto">
              <div className="bg-gray-100 p-4 rounded-full">
                <div className="relative">
                  <textarea
                    className="
                      w-full px-6 py-2 pr-20
                      border rounded-3xl resize-none
                      focus:border-[#cabb90] focus:outline-none
                      text-sm sm:text-base h-14
                      pb-10
                    "
                    placeholder="Entrez votre demande la plus détaillée possible..."
                    value={prompt}
                    style={{ maxHeight: "8rem", overflowY: "auto" }}
                    rows={1}
                    onChange={(e) => {
                      setPrompt(e.target.value);
                      e.target.style.height = "auto";
                      e.target.style.height =
                        Math.min(e.target.scrollHeight, 8 * 16) + "px";
                    }}
                    onKeyDown={(e) => {
                      const isSubmit = e.key === "Enter" && (e.metaKey || e.ctrlKey);
                      if (isSubmit) {
                        e.preventDefault();
                        handleSubmit();
                      }
                    }}
                  />

                  {/* Bouton aligné en bas à droite de la zone (reste en bas quand la textarea s'agrandit) */}
                  <button
                    onClick={() => {
                        handleSubmit();
                      }}
                    disabled={loading}
                    className={`
                      absolute right-2 bottom-3.5
                      h-9 w-9 sm:h-10 sm:w-10 rounded-full
                      text-white
                      flex items-center justify-center
                      transition-colors hover:brightness-90
                      ${loading ? "bg-transparent" : "bg-[#cabb90]"}
                    `}
                    aria-label="Envoyer la demande"
                  >
                    {loading ? (
                      <svg
                        className="h-5 w-5 animate-spin text-[#cabb90]"
                        viewBox="0 0 24 24"
                        fill="none"
                        role="status"
                        aria-label="Chargement"
                      >
                        <circle
                          className="opacity-25"
                          cx="12"
                          cy="12"
                          r="10"
                          stroke="currentColor"
                          strokeWidth="4"
                        />
                        <path
                          className="opacity-75"
                          fill="none"
                          stroke="currentColor"
                          strokeWidth="4"
                          strokeLinecap="round"
                          d="M12 2 a10 10 0 0 1 10 10"
                        />
                      </svg>
                    ) : (
                      <FontAwesomeIcon icon={faArrowUp} />
                    )}
                  </button>
                </div>
              </div>
            </div>
          </div>

        <section class=" bg-gradient-to-b grid place-items-center px-4 mb-6">
          <div class="max-w-4xl rounded-l bg-white p-6 shadow-lg md:p-8 mb-24">
          <ol class="space-y-4 list-decimal list-inside text-gray-800">
            <p class="pl-1">
              <span class="font-medium">Détaillez votre demande :</span>
            </p>

            <li class="pl-1">
              <span class="font-medium">Chef : </span>
              nombre d’étoiles, type de cuisine (bistronomique, raffiné, gastronomique, végétal, créative, poisson…), nationalité, nombre de followers
            </li>

            <li class="pl-1">
              <span class="font-medium">Lieu : </span>
              style de décor (moderne, classique, œuvres d’art, contemporain, chaleureux…), localisation (arrondissement, triangle d'or), cuisine ouverte
            </li>

            <li class="pl-1">
              Indiquez le type d’événement (dîner assis, cocktail debout, intérieur / extérieur…)
            </li>

            <li class="pl-1">
              Indiquez le nombre de personnes présentes à l’événement
            </li>

            <li class="pl-1">
              Indiquez le budget par personne en €
            </li>
            <li class="pl-1">
              Exemple de prompt : <span class="italic">Je souhaite un chef non étoilé français proposant une cuisine bistronomique raffinée,
                dans un lieu chaleureux avec des œuvres d’art, situé dans le 16ème arrondissement de Paris,
                pour un dîner assis de 8 personnes, avec un budget de 400 € par personne.</span>
              </li>
          </ol>
        </div>
        </section>

        </div>
      </div>
    </div>
  );
}

export default function AiApp() {
  return (
    <UserProvider>
      <AiAppContent />
    </UserProvider>
  );
}
