import React from 'react';



  export default function NavBar() {

    return (
      <nav
      className="fixed top-0 left-0 h-screen w-48 text-white flex flex-col p-6 space-y-6 bg-[#cabb90]"
      >
      <a href="/" className="px-3 py-2 rounded transition-colors duration-200 hover:bg-white hover:text-[#cabb90]">Accueil</a>
      <a href="/feedback" className="px-3 py-2 rounded transition-colors duration-200 hover:bg-white hover:text-[#cabb90]">Feedbacks</a>
      <a href="/historic" className="px-3 py-2 rounded transition-colors duration-200 hover:bg-white hover:text-[#cabb90]">Historique</a>
      </nav>
    );
  }
