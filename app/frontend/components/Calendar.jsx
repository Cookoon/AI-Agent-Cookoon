import React from "react";
import DatePicker from "react-datepicker";
import "react-datepicker/dist/react-datepicker.css";



// Calendar now receives `selected` and `onChange` props so parent can control the date
export default function Calendar({ selected, onChange }) {


  
  return (
    <DatePicker
      selected={selected}
      onChange={onChange}
      dateFormat="yyyy-MM-dd"
      placeholderText="Choisir une date"
      minDate={new Date()}
    />
  );
}
