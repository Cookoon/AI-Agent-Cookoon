import React from 'react'
import { createRoot } from 'react-dom/client'
import App from '../components/App.jsx'
import NavBar from '../components/NavBar.jsx'
import Identification from '../components/Identification.jsx'
import '../styles/application.css'
import FeedbackView from '../components/FeedbacksView.jsx'

import { UserProvider } from '../components/UserContext.jsx'

document.addEventListener('DOMContentLoaded', () => {
  const rootNode = document.getElementById('root')
  if (rootNode) {
    createRoot(rootNode).render(
      <UserProvider>
        <Identification/>
        <NavBar />
        <App />
      </UserProvider>
    )
  }

  const feedbackNode = document.getElementById('feedback')
  if (feedbackNode) {
    createRoot(feedbackNode).render(
      <UserProvider>
        <Identification/>
        <NavBar />
        <FeedbackView />
      </UserProvider>
    )
  }

  const historicNode = document.getElementById('historic')
  if (historicNode) {
    import('../components/Historic.jsx').then(({ default: Historic }) => {
      createRoot(historicNode).render(
        <UserProvider>
          <Identification/>
          <NavBar />
          <Historic />
        </UserProvider>
      )
    })
  }
})
