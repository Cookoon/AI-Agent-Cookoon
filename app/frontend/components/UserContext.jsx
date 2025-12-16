import React, { createContext, useState, useEffect } from "react";

export const UserContext = createContext();

export function UserProvider({ children }) {
  const [currentUser, setCurrentUser] = useState("");
  const [checkingAuth, setCheckingAuth] = useState(true);

  useEffect(() => {
    fetch("/api/me", { credentials: "include" })
      .then(res => res.ok ? res.json() : Promise.reject())
      .then(data => setCurrentUser(data.name))
      .catch(() => setCurrentUser(""))
      .finally(() => setCheckingAuth(false));
  }, []);

  const logout = async () => {
    await fetch("/api/logout", { method: "DELETE", credentials: "include" });
    setCurrentUser("");
  };

  return (
    <UserContext.Provider value={{ currentUser, setCurrentUser, checkingAuth, logout }}>
      {children}
    </UserContext.Provider>
  );
}
