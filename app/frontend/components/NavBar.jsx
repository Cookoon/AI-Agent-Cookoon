import React from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHouse } from "@fortawesome/free-regular-svg-icons";
import { faClockRotateLeft } from "@fortawesome/free-solid-svg-icons";
import { faComments } from "@fortawesome/free-regular-svg-icons";

export default function NavBar() {
  return (
    <nav className="fixed bottom-0 left-0 w-full h-12 bg-[#cabb90] flex justify-around items-center md:top-0 md:left-0 md:h-screen md:w-20 md:flex-col md:py-6 md:space-y-6 text-white">
      <a
        href="/"
        className="relative group w-10 h-10 rounded-lg transition-colors duration-200 hover:bg-white hover:text-[#cabb90] flex items-center justify-center text-xl md:w-12 md:h-12 md:text-2xl"
        aria-label="Home"
      >
        <FontAwesomeIcon icon={faHouse} />
        <span className="pointer-events-none absolute left-1/2 top-full mt-2 -translate-x-1/2 whitespace-nowrap rounded bg-white px-2 py-1 text-xs font-medium text-[#cabb90] opacity-0 transform scale-95 transition-all duration-150 group-hover:opacity-100 group-hover:scale-100 md:hidden">
          Home
        </span>
      </a>

      <a
        href="/historic"
        className="relative group w-10 h-10 rounded-lg transition-colors duration-200 hover:bg-white hover:text-[#cabb90] flex items-center justify-center text-xl md:w-12 md:h-12 md:text-2xl"
        aria-label="Historique"
      >
        <FontAwesomeIcon icon={faClockRotateLeft} />
        <span className="pointer-events-none absolute left-1/2 top-full mt-2 -translate-x-1/2 whitespace-nowrap rounded bg-white px-2 py-1 text-xs font-medium text-[#cabb90] opacity-0 transform scale-95 transition-all duration-150 group-hover:opacity-100 group-hover:scale-100 md:hidden">
          Historique
        </span>
      </a>

      <a
        href="/feedback"
        className="relative group w-10 h-10 rounded-lg transition-colors duration-200 hover:bg-white hover:text-[#cabb90] flex items-center justify-center text-xl md:w-12 md:h-12 md:text-2xl"
        aria-label="Feedback"
      >
        <FontAwesomeIcon icon={faComments} />
        <span className="pointer-events-none absolute left-1/2 top-full mt-2 -translate-x-1/2 whitespace-nowrap rounded bg-white px-2 py-1 text-xs font-medium text-[#cabb90] opacity-0 transform scale-95 transition-all duration-150 group-hover:opacity-100 group-hover:scale-100 md:hidden">
          Feedback
        </span>
      </a>
    </nav>
  );
}
