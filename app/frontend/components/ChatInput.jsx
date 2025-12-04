import { useState, useRef, useEffect } from "react";

export default function ChatInput({ handleSubmit }) {
  const [prompt, setPrompt] = useState("");
  const textareaRef = useRef();

  // Ajuste la hauteur à chaque changement de prompt
  useEffect(() => {
    const textarea = textareaRef.current;
    if (!textarea) return;

    textarea.style.height = "auto";
    textarea.style.height = textarea.scrollHeight + "px";
  }, [prompt]);

  return (
    <textarea
      ref={textareaRef}
      className="flex-1 px-4 py-2 border rounded-lg focus:ring-2 focus:ring-[#cabb90] resize-none overflow-hidden"
      placeholder="Votre demande..."
      value={prompt}
      rows={1}
      style={{ height: "auto" }}
      onChange={(e) => setPrompt(e.target.value)}
      onKeyDown={(e) => {
        if (e.key === "Enter" && !e.shiftKey) {
          e.preventDefault();
          handleSubmit(prompt);
          setPrompt(""); // reset après envoi
        }
      }}
    />
  );
}
