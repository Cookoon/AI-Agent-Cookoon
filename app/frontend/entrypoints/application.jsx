import React from 'react'
import { createRoot } from 'react-dom/client'
import App from '../components/App.jsx'
import '../styles/application.css'
import FeedbackView from '../components/FeedbacksView.jsx'

// Rend React accessible globalement
window.React = React
document.addEventListener('DOMContentLoaded', () => {
  const rootNode = document.getElementById('root')
  if (rootNode) {
    createRoot(rootNode).render(<App />)
  }

  const feedbackNode = document.getElementById('feedback')
  if (feedbackNode) {
    createRoot(feedbackNode).render(<FeedbackView />)
  }

  const historicNode = document.getElementById('historic')
  if (historicNode) {
    import('../components/Historic.jsx').then(({ default: Historic }) => {
      createRoot(historicNode).render(<Historic />)
    })
  }
})
