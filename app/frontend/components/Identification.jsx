import React, { useState, useEffect } from 'react';

const ONE_HOUR = 60 * 60 * 1000;

export default function Identification() {
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

  const handleSubmit = () => {
    if (password === import.meta.env.VITE_AI_PASSWORD) {
      localStorage.setItem('ai_last_auth', Date.now().toString());
      setIsLocked(false);
      setPassword('');
    } else {
      alert('Wrong password');
    }
  };

  if (!isLocked) return null;

  return (
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
            if (e.key === 'Enter') {
              handleSubmit();
            }
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
  );
}
