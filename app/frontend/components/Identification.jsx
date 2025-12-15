import React, { useState, useEffect, use } from 'react';

const ONE_HOUR = 60 * 60 * 1000; // 1 heure en ms

export default function Identification({ setCurrentUser, currentUser }) {
  const [isLocked, setIsLocked] = useState(false);
  const [password, setPassword] = useState('');

  useEffect(() => {
    const lastAuth = localStorage.getItem('ai_last_auth');

    if (!lastAuth) {
      setIsLocked(true);
      return;
    }

    const elapsed = Date.now() - Number(lastAuth);

    if (elapsed > ONE_HOUR) {
      setIsLocked(true);
    }
  }, []);

  useEffect(() => {
    if (currentUser === '') {
      setIsLocked(true);
    }
  }, [currentUser]);

  const handleSubmit = () => {
    let user = null;

    if (password === import.meta.env.VITE_AI_PASSWORD_ADMIN) user = 'Valentin';
    else if (password === import.meta.env.VITE_AI_PASSWORD_ALEX) user = 'Alex';
    else if (password === import.meta.env.VITE_AI_PASSWORD_AUDE) user = 'Aude';
    else if (password === import.meta.env.VITE_AI_PASSWORD_MARGOT) user = 'Margot';
    else if (password === import.meta.env.VITE_AI_PASSWORD_GREGORY) user = 'Grégory';
    else if (password === import.meta.env.VITE_AI_PASSWORD_CLARA) user = 'Clara';
    else if (password === import.meta.env.VITE_AI_PASSWORD_LOANN) user = 'Loann';

    if (user) {
      localStorage.setItem('ai_last_auth', Date.now().toString());
      setIsLocked(false);
      setPassword('');
      setCurrentUser(user);
      localStorage.setItem('ai_current_user', user);
    } else {
      alert('Wrong password');
    }
  };

  if (!isLocked) return null;

  return (
    <>

    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
      <div className="w-full max-w-md p-8 bg-white rounded-lg shadow-xl">
        <h2 className="text-2xl font-semibold mb-4">Session verrouillée</h2>

        <input
          type="password"
          placeholder="Entrer le mot de passe"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="w-full px-4 py-2 border rounded mb-4 focus:outline-none focus:ring-2 focus:ring-[#cabb90]"
          onKeyDown={(e) => {
            if (e.key === 'Enter') handleSubmit();
          }}
        />

        <div className="flex justify-end">
          <button
            onClick={handleSubmit}
            className="px-4 py-2 bg-[#cabb90] text-white rounded hover:bg-[#b5b083]"
          >
            Déverrouiller
          </button>
        </div>
      </div>
    </div>
    </>
  );
}
