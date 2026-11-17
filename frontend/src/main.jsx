import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'
import { SignupCardCombined } from './pages/register/register'

// Sin router instalado: /register muestra el registro y el resto el panel.
const esRegistro = window.location.pathname.replace(/\/$/, '') === '/register'

createRoot(document.getElementById('root')).render(
  <StrictMode>
    {esRegistro ? <SignupCardCombined /> : <App />}
  </StrictMode>,
)
