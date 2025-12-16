// src/components/UserContext.jsx
import React, { createContext, useState, useEffect } from "react";

export const UserContext = createContext();

export function UserProvider({ children }) {
  const [currentUser, setCurrentUser] = useState(null);
  const [checkingAuth, setCheckingAuth] = useState(true);

  // Détermine l'URL de l'API selon l'environnement
  const API_URL = import.meta.env.VITE_API_URL || window.location.origin;

  useEffect(() => {
    fetch(`${API_URL}/api/me`, { credentials: "include" })
      .then(res => res.ok ? res.json() : null)
      .then(data => {
        if (data?.name) setCurrentUser(data.name);
      })
      .catch(err => console.error("Erreur fetch /api/me :", err))
      .finally(() => setCheckingAuth(false));
  }, []);

  return (
    <UserContext.Provider value={{ currentUser, setCurrentUser, checkingAuth }}>
      {children}
    </UserContext.Provider>
  );
}
