// src/components/Identification.jsx
import React, { useState, useContext, useEffect } from "react";
import { UserContext } from "./UserContext";

const ONE_HOUR = 2 * 60 * 60 * 1000;

export default function Identification() {
  const { currentUser, setCurrentUser, checkingAuth } = useContext(UserContext);
  const [name, setName] = useState("");
  const [password, setPassword] = useState("");
  const [isLocked, setIsLocked] = useState(false);

  // On attend la vérification de session
  useEffect(() => {
    const lastAuth = localStorage.getItem("ai_last_auth");
    if (
      !currentUser ||
      !lastAuth ||
      Date.now() - Number(lastAuth) > ONE_HOUR
    ) {
      setIsLocked(true);
    } else {
      setIsLocked(false);
    }
  }, [currentUser]);

const handleSubmit = async () => {
  if (!name || !password) {
    return alert("Veuillez remplir le nom et le mot de passe");
  }



  const res = await fetch(`/api/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    credentials: "include",
    body: JSON.stringify({ name, password }),
  });

  if (res.ok) {
    const data = await res.json();
    setCurrentUser(data.name);
    localStorage.setItem("ai_last_auth", Date.now().toString());
    setPassword("");
    setIsLocked(false);
  } else if (res.status === 422 || res.status === 401) {
    alert("Nom ou mot de passe incorrect");
  }

};


  // On ne rend rien tant que la session n’est pas vérifiée
  if (checkingAuth) return null;

  // Si pas verrouillé, rien à afficher
  if (!isLocked) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
      <div className="w-full max-w-md p-8 bg-white rounded-lg shadow-xl">
        <h2 className="text-2xl font-semibold mb-4">Identification</h2>

        <input
          type="text"
          placeholder="Nom"
          value={name}
          onChange={(e) => setName(e.target.value)}
          className="w-full px-4 py-2 border rounded mb-4 focus:outline-none focus:ring-2 focus:ring-[#cabb90]"
        />

        <input
          type="password"
          placeholder="Mot de passe"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && handleSubmit()}
          className="w-full px-4 py-2 border rounded mb-4 focus:outline-none focus:ring-2 focus:ring-[#cabb90]"
        />

        <div className="flex justify-end">
          <button
            onClick={handleSubmit}
            className="px-4 py-2 bg-[#cabb90] text-white rounded hover:bg-[#b5b083]"
          >
            Se connecter
          </button>
        </div>
      </div>
    </div>
  );
}
