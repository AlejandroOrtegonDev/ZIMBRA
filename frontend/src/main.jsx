import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'
import Login from './pages/login/Login'
import { SignupCardCombined } from './pages/register/register'
import { obtenerSesion } from './services/api'

// Sin router instalado: la ruta del navegador decide la vista.
//   /register -> registro, /login -> inicio de sesión, resto -> panel
// El panel exige sesión; sin ella se muestra el inicio de sesión.
const ruta = window.location.pathname.replace(/\/$/, '')
const sesion = obtenerSesion()

let vista
if (ruta === '/register') {
  vista = <SignupCardCombined />
} else if (ruta === '/login' || !sesion) {
  if (ruta !== '/login') window.history.replaceState(null, '', '/login')
  vista = <Login />
} else {
  vista = <App />
}

createRoot(document.getElementById('root')).render(
  <StrictMode>
    {vista}
  </StrictMode>,
)
