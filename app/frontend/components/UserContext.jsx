import React, { createContext, useState, useEffect } from "react";

export const UserContext = createContext();

export function UserProvider({ children }) {
  const [currentUser, setCurrentUser] = useState("");
  const [checkingAuth, setCheckingAuth] = useState(true);

  // Vérifie la session au chargement
  useEffect(() => {
    fetch("/api/me", { credentials: "include" })
      .then((res) => {
        if (res.ok) return res.json();
        throw new Error("Non connecté");
      })
      .then((data) => setCurrentUser(data.name))
      .catch(() => setCurrentUser(""))
      .finally(() => setCheckingAuth(false));
  }, []);

  const logout = async () => {
    await fetch("/api/logout", { method: "DELETE", credentials: "include" });
    setCurrentUser("");
    localStorage.removeItem("ai_current_user");
  };

  return (
    <UserContext.Provider value={{ currentUser, setCurrentUser, checkingAuth, logout }}>
      {children}
    </UserContext.Provider>
  );
}
