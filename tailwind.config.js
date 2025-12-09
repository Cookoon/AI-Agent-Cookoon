module.exports = {
  content: [
  './app/frontend/**/*.{js,jsx,ts,tsx,html}',
  './app/views/**/*'
]
  ,
  theme: { extend: {} },
  plugins: [],

  theme: {
    extend: {
      fontFamily: {
        avenir: ['"AvenirRegular"', 'sans-serif'],
      },
    },
  },


}
