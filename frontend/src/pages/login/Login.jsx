import { useState } from 'react'
import { iniciarSesion } from '../../services/api'
import '../register/register.css'

export default function Login() {
  const [correo, setCorreo] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [enviando, setEnviando] = useState(false)

  async function manejarEnvio(evento) {
    evento.preventDefault()
    setError('')

    try {
      setEnviando(true)
      await iniciarSesion(correo.trim(), password)
      window.location.href = '/'
    } catch (err) {
      setError(err.message)
    } finally {
      setEnviando(false)
    }
  }

  return (
    <section className="registro">
      <div className="registro-tarjeta">
        <div className="registro-encabezado">
          <div className="registro-logo">Z</div>
          <div className="registro-titulos">
            <h1>Zimbra CRM</h1>
            <p>Inicie sesión para continuar.</p>
          </div>
        </div>

        {error && <div className="registro-error">{error}</div>}

        <form className="registro-formulario" onSubmit={manejarEnvio}>
          <div className="registro-campos">
            <label>
              Correo electrónico
              <input
                className="registro-input"
                type="email"
                value={correo}
                onChange={(e) => setCorreo(e.target.value)}
                autoComplete="username"
                required
              />
            </label>
            <label>
              Contraseña
              <input
                className="registro-input"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password"
                required
              />
            </label>
          </div>

          <button className="registro-boton" type="submit" disabled={enviando}>
            {enviando ? 'Ingresando...' : 'Iniciar sesión'}
          </button>
        </form>

        <div className="registro-demo">
          <strong>Cuentas de prueba</strong><br />
          Administrador: ana.rodriguez@zimbra-demo.com / admin123<br />
          Vendedor: carlos.gomez@zimbra-demo.com / 123456<br />
          Solo lectura: demo@zimbra-demo.com / 123456
        </div>

        <div className="registro-pie">
          <span>¿No tiene cuenta?</span>
          <a href="/register">Crear cuenta</a>
        </div>
      </div>
    </section>
  )
}
