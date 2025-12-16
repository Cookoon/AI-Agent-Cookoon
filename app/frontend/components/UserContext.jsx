// src/components/UserContext.jsx
import React, { createContext, useState, useEffect } from "react";

export const UserContext = createContext();

export function UserProvider({ children }) {
  const [currentUser, setCurrentUser] = useState(null);
  const [checkingAuth, setCheckingAuth] = useState(true); // nouveau

  useEffect(() => {
    fetch("http://localhost:3000/api/me", { credentials: "include" })
      .then(res => {
        if (res.ok) return res.json();
        return null;
      })
      .then(data => {
        if (data?.name) setCurrentUser(data.name);
      })
      .finally(() => setCheckingAuth(false)); // on a fini de vérifier
  }, []);

  return (
    <UserContext.Provider value={{ currentUser, setCurrentUser, checkingAuth }}>
      {children}
    </UserContext.Provider>
  );
}
