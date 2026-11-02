import { useEffect, useState } from 'react'
import { obtenerBaseDatos, obtenerEstado } from './services/api'
import './App.css'

function App() {
  const [estado, setEstado] = useState(null)
  const [error, setError] = useState('')
  const [baseDatos, setBaseDatos] = useState(null)
  const [errorDb, setErrorDb] = useState('')

  useEffect(() => {
    obtenerEstado()
      .then((datos) => {
        setEstado(datos)
      })
      .catch(() => {
        setError(
          'No se pudo conectar con el backend. Revisa que esté encendido en el puerto 3001.',
        )
      })

    obtenerBaseDatos()
      .then((datos) => {
        setBaseDatos(datos)
      })
      .catch(() => {
        setErrorDb('No se pudo conectar con la base de datos.')
      })
  }, [])

  return (
    <main className="panel">
      <p className="etiqueta">Configuración inicial</p>
      <h1>Sistema de Gestión Comercial Zimbra</h1>
      <p>
        Esta pantalla solo comprueba que React puede consultar la API de
        Express. Los módulos de prospectos, vendedores y ventas todavía no
        están construidos.
      </p>

      <section className="estado" aria-live="polite">
        {!estado && !error && <p>Consultando el backend...</p>}
        {error && <p className="error">{error}</p>}
        {estado && <p className="ok">{estado.mensaje}</p>}
        {!baseDatos && !errorDb && <p>Consultando la base de datos...</p>}
        {errorDb && <p className="error">{errorDb}</p>}
        {baseDatos && <p className="ok">{baseDatos.mensaje}</p>}
      </section>
    </main>
  )
}

export default App
