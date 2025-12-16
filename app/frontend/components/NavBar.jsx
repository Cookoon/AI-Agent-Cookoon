import React from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHouse } from "@fortawesome/free-regular-svg-icons";
import { faClockRotateLeft } from "@fortawesome/free-solid-svg-icons";
import { faComments } from "@fortawesome/free-regular-svg-icons";
import { faRightFromBracket } from "@fortawesome/free-solid-svg-icons";


export default function NavBar() {
  const handleLogout = async () => {
  try {
    await fetch("/logout", {
      method: "DELETE",
      credentials: "include",
    });

    localStorage.removeItem("ai_last_auth");
    window.location.href = "/";
  } catch (err) {
    console.error("Erreur logout", err);
  }
};

  return (
    <>
      {/* NAVBAR DESKTOP (verticale) */}
      <nav className="hidden md:flex fixed top-0 left-0 h-screen w-20 text-white flex-col items-center py-6 space-y-10 bg-[#cabb90]">
        <a
          href="/"
          className="relative group w-12 h-12 mt-16 rounded-lg transition-colors duration-200 hover:bg-white hover:text-[#cabb90] flex items-center justify-center text-2xl"
          aria-label="Home"
        >
          <FontAwesomeIcon icon={faHouse} />
          <span className="pointer-events-none absolute left-1/2 top-full mt-2 -translate-x-1/2 whitespace-nowrap rounded px-2 py-1 text-xs font-medium text-white opacity-0 transform scale-95 transition-all duration-150 group-hover:opacity-100 group-hover:scale-100">
            Home
          </span>
        </a>

        <a
          href="/historic"
          className="relative group w-12 h-12 rounded-lg transition-colors duration-200 hover:bg-white hover:text-[#cabb90] flex items-center justify-center text-2xl"
          aria-label="Historique"
        >
          <FontAwesomeIcon icon={faClockRotateLeft} />
          <span className="pointer-events-none absolute left-1/2 top-full mt-2 -translate-x-1/2 whitespace-nowrap rounded px-2 py-1 text-xs font-medium text-white opacity-0 transform scale-95 transition-all duration-150 group-hover:opacity-100 group-hover:scale-100">
            Historique
          </span>
        </a>

        <a
          href="/feedback"
          className="relative group w-12 h-12 rounded-lg transition-colors duration-200 hover:bg-white hover:text-[#cabb90] flex items-center justify-center text-2xl"
          aria-label="Feedback"
        >
          <FontAwesomeIcon icon={faComments} />
          <span className="pointer-events-none absolute left-1/2 top-full mt-2 -translate-x-1/2 whitespace-nowrap rounded px-2 py-1 text-xs font-medium text-white opacity-0 transform scale-95 transition-all duration-150 group-hover:opacity-100 group-hover:scale-100">
            Feedback
          </span>
        </a>
                <button
  onClick={handleLogout}
  className="relative group w-12 h-12 rounded-lg transition-colors duration-200 hover:bg-white hover:text-[#cabb90] flex items-center justify-center text-2xl mt-auto mb-6"
  aria-label="Déconnexion"
>
  <FontAwesomeIcon icon={faRightFromBracket} />
  <span className="pointer-events-none absolute left-1/2 top-full mt-2 -translate-x-1/2 whitespace-nowrap rounded px-2 py-1 text-xs font-medium text-white opacity-0 transform scale-95 transition-all duration-150 group-hover:opacity-100 group-hover:scale-100">
    Déconnexion
  </span>
</button>

      </nav>

      {/* NAVBAR MOBILE (horizontale en bas) */}
      <nav className="md:hidden fixed bottom-0 left-0 w-full bg-[#cabb90] text-white flex justify-around items-center py-3 z-50 shadow-lg">

        <a
          href="/"
          className="relative group flex flex-col items-center"
        >
          <div className="w-12 h-12 rounded-lg flex items-center justify-center text-2xl transition duration-200 hover:bg-white hover:text-[#cabb90]">
            <FontAwesomeIcon icon={faHouse} />
          </div>
        </a>

        <a
          href="/historic"
          className="relative group flex flex-col items-center"
        >
          <div className="w-12 h-12 rounded-lg flex items-center justify-center text-2xl transition duration-200 hover:bg-white hover:text-[#cabb90]">
            <FontAwesomeIcon icon={faClockRotateLeft} />
          </div>
        </a>

        <a
          href="/feedback"
          className="relative group flex flex-col items-center"
        >
          <div className="w-12 h-12 rounded-lg flex items-center justify-center text-2xl transition duration-200 hover:bg-white hover:text-[#cabb90]">
            <FontAwesomeIcon icon={faComments} />
          </div>
        </a>



      </nav>
    </>
  );
}
