import { useState } from 'react'
import { registrarUsuario } from '../../services/api'
import './register.css'

// Registro de cuenta nueva. El backend la crea con el rol de solo
// lectura (user_demo) y devuelve la sesión iniciada.
export const SignupCardCombined = () => {
  const [formulario, setFormulario] = useState({ nombre: '', correo: '', password: '', confirmar: '' })
  const [error, setError] = useState('')
  const [guardando, setGuardando] = useState(false)

  function cambiarCampo(evento) {
    const { name, value } = evento.target
    setFormulario((anterior) => ({ ...anterior, [name]: value }))
  }

  async function manejarEnvio(evento) {
    evento.preventDefault()
    setError('')

    if (formulario.password !== formulario.confirmar) {
      setError('Las contraseñas no coinciden')
      return
    }

    try {
      setGuardando(true)
      await registrarUsuario({
        nombre: formulario.nombre.trim(),
        correo: formulario.correo.trim(),
        password: formulario.password,
      })
      window.location.href = '/'
    } catch (err) {
      setError(err.message)
    } finally {
      setGuardando(false)
    }
  }

  return (
    <section className="registro">
      <div className="registro-tarjeta">
        <div className="registro-encabezado">
          <div className="registro-logo">Z</div>
          <div className="registro-titulos">
            <h1>Crear cuenta</h1>
            <p>Regístrese para consultar el CRM comercial de Zimbra.</p>
          </div>
        </div>

        {error && <div className="registro-error">{error}</div>}

        <form className="registro-formulario" onSubmit={manejarEnvio}>
          <div className="registro-campos">
            <label>
              Nombre completo
              <input
                className="registro-input"
                name="nombre"
                value={formulario.nombre}
                onChange={cambiarCampo}
                placeholder="Su nombre"
                minLength={3}
                autoComplete="name"
                required
              />
            </label>
            <label>
              Correo electrónico
              <input
                className="registro-input"
                type="email"
                name="correo"
                value={formulario.correo}
                onChange={cambiarCampo}
                placeholder="correo@empresa.com"
                autoComplete="email"
                required
              />
            </label>
            <label>
              Contraseña
              <input
                className="registro-input"
                type="password"
                name="password"
                value={formulario.password}
                onChange={cambiarCampo}
                minLength={8}
                autoComplete="new-password"
                required
              />
              <p className="registro-ayuda">Mínimo 8 caracteres.</p>
            </label>
            <label>
              Confirmar contraseña
              <input
                className="registro-input"
                type="password"
                name="confirmar"
                value={formulario.confirmar}
                onChange={cambiarCampo}
                minLength={8}
                autoComplete="new-password"
                required
              />
            </label>
          </div>

          <button className="registro-boton" type="submit" disabled={guardando}>
            {guardando ? 'Creando cuenta...' : 'Crear cuenta'}
          </button>
        </form>

        <p className="registro-ayuda" style={{ textAlign: 'center' }}>
          Las cuentas nuevas tienen acceso de solo lectura. Un administrador puede ampliar sus permisos.
        </p>

        <div className="registro-pie">
          <span>¿Ya tiene cuenta?</span>
          <a href="/login">Iniciar sesión</a>
        </div>
      </div>
    </section>
  )
}
