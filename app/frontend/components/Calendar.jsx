import React from "react";
import DatePicker from "react-datepicker";
import "react-datepicker/dist/react-datepicker.css";

// Professional-looking Calendar input using Tailwind and a custom input element
const CalendarInput = React.forwardRef(({ value, onClick, placeholder, compact }, ref) => {
  const baseClasses = compact
    ? "flex items-center justify-center bg-white border border-gray-200 rounded-full shadow-sm hover:shadow-md transition-shadow duration-150 focus:outline-none focus:ring-2 focus:ring-[#cabb90]"
    : "flex items-center justify-between px-4 py-3 bg-white border border-gray-200 rounded-full shadow-sm hover:shadow-md transition-shadow duration-150 text-left focus:outline-none focus:ring-2 focus:ring-[#cabb90]";

  return (
    <div className={`flex ${compact ? 'items-center' : 'justify-end'}`}>
      <button
        type="button"
        ref={ref}
        onClick={onClick}
        className={baseClasses + (compact ? ' h-9 w-9 sm:h-10 sm:w-10 p-0' : '')}
        aria-label="Ouvrir le sélecteur de date"
      >
        {compact ? (
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-[#cabb90]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3M3 11h18M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
          </svg>
        ) : (
          <>
            <span className={`${value ? 'text-gray-900' : 'text-gray-400'} truncate`}>{value || placeholder}</span>
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-[#cabb90]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3M3 11h18M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
          </>
        )}
      </button>
    </div>
  );
});

CalendarInput.displayName = 'CalendarInput';

// Calendar now receives `selected` and `onChange` props so parent can control the date
export default function Calendar({ selected, onChange, placeholder = 'Choisir une date', compact = false }) {
  return (
    <div className="flex justify-end">
      <DatePicker
        selected={selected}
        onChange={onChange}
        dateFormat="yyyy-MM-dd"
        minDate={new Date()}
        customInput={<CalendarInput placeholder={placeholder} compact={compact} />}
        showPopperArrow={false}
        popperPlacement="bottom-end"
      />
    </div>
  );
}
