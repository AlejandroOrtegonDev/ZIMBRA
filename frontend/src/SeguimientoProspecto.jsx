
import { useEffect, useState } from 'react'
import {
  obtenerActividades,
  crearTarea,
  crearEvento,
} from './services/api'

function SeguimientoProspecto({ prospecto, onCerrar }) {
  const [actividades, setActividades] = useState([])
  const [tipoFormulario, setTipoFormulario] = useState('tarea')
  const [cargando, setCargando] = useState(true)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')
  const [mensaje, setMensaje] = useState('')

  const [formulario, setFormulario] = useState({
    titulo: '',
    descripcion: '',
    fecha_limite: '',
    fecha_inicio: '',
    fecha_fin: '',
    ubicacion: '',
    tipo: 'llamada',
  })

  async function cargarActividades() {
    try {
      setError('')
      const respuesta = await obtenerActividades(prospecto.id_cliente)
      setActividades(respuesta.actividades || [])
    } catch (err) {
      setError(err.message)
    } finally {
      setCargando(false)
    }
  }

  useEffect(() => {
    let cancelado = false

    async function iniciarCarga() {
      try {
        const respuesta = await obtenerActividades(prospecto.id_cliente)

        if (!cancelado) {
          setActividades(respuesta.actividades || [])
        }
      } catch (err) {
        if (!cancelado) setError(err.message)
      } finally {
        if (!cancelado) setCargando(false)
      }
    }

    iniciarCarga()

    return () => {
      cancelado = true
    }
  }, [prospecto.id_cliente])

  function cambiarCampo(evento) {
    const { name, value } = evento.target

    setFormulario((anterior) => ({
      ...anterior,
      [name]: value,
    }))
  }

  async function guardarActividad(evento) {
    evento.preventDefault()

    try {
      setGuardando(true)
      setError('')
      setMensaje('')

      if (tipoFormulario === 'tarea') {
        await crearTarea(prospecto.id_cliente, {
          titulo: formulario.titulo,
          descripcion: formulario.descripcion,
          fecha_limite: formulario.fecha_limite || null,
        })
      } else {
        await crearEvento(prospecto.id_cliente, {
          titulo: formulario.titulo,
          descripcion: formulario.descripcion,
          fecha_inicio: formulario.fecha_inicio.replace('T', ' ') + ':00',
          fecha_fin: formulario.fecha_fin.replace('T', ' ') + ':00',
          ubicacion: formulario.ubicacion,
          tipo: formulario.tipo,
        })
      }

      setMensaje('Actividad registrada correctamente')
      setFormulario({
        titulo: '',
        descripcion: '',
        fecha_limite: '',
        fecha_inicio: '',
        fecha_fin: '',
        ubicacion: '',
        tipo: 'llamada',
      })

      await cargarActividades()
    } catch (err) {
      setError(err.message)
    } finally {
      setGuardando(false)
    }
  }

  return (
    
      <section className="seguimiento-contenedor">
      <div className="seguimiento-encabezado">
        <div>
          <span>Gestión comercial / Prospectos / Seguimiento</span>
          <h2>Seguimiento comercial</h2>
          <p>
            Prospecto: {prospecto.nombre} {prospecto.apellido || ''}
          </p>
          <p>Vendedor: {prospecto.vendedor_nombre || 'Sin asignar'}</p>
        </div>

        <button type="button" onClick={onCerrar}>
          Volver al listado
        </button>
      </div>

      {mensaje && <div className="mensaje-exito">{mensaje}</div>}
      {error && <div className="mensaje-error">{error}</div>}

      <section className="formulario-contenedor">
        <div className="formulario-titulo">
          <div>
            <h2>Registrar actividad</h2>
            <p>Selecciona el tipo de actividad comercial.</p>
          </div>
        </div>

        <div className="acciones-formulario">
          <button
            type="button"
            className={tipoFormulario === 'tarea' ? 'boton-principal' : 'boton-secundario'}
            onClick={() => setTipoFormulario('tarea')}
          >
            Nueva tarea
          </button>

          <button
            type="button"
            className={tipoFormulario === 'evento' ? 'boton-principal' : 'boton-secundario'}
            onClick={() => setTipoFormulario('evento')}
          >
            Llamada o reunión
          </button>
        </div>

        <form onSubmit={guardarActividad}>
          <div className="campos-grid">
            <label className="campo-completo">
              Título *
              <input
                name="titulo"
                value={formulario.titulo}
                onChange={cambiarCampo}
                placeholder="Ej. Contactar al prospecto"
                required
              />
            </label>

            <label className="campo-completo">
              Descripción
              <textarea
                name="descripcion"
                value={formulario.descripcion}
                onChange={cambiarCampo}
                placeholder="Describe la actividad comercial..."
                rows="3"
              />
            </label>

            {tipoFormulario === 'tarea' ? (
              <label className="campo-completo">
                Fecha límite
                <input
                  type="datetime-local"
                  name="fecha_limite"
                  value={formulario.fecha_limite}
                  onChange={cambiarCampo}
                />
              </label>
            ) : (
              <>
                <label>
                  Tipo de evento *
                  <select
                    name="tipo"
                    value={formulario.tipo}
                    onChange={cambiarCampo}
                    required
                  >
                    <option value="llamada">Llamada</option>
                    <option value="reunion">Reunión</option>
                    <option value="cita">Cita</option>
                    <option value="otro">Otro</option>
                  </select>
                </label>

                <label>
                  Ubicación
                  <input
                    name="ubicacion"
                    value={formulario.ubicacion}
                    onChange={cambiarCampo}
                    placeholder="Ej. Llamada telefónica"
                  />
                </label>

                <label>
                  Fecha y hora de inicio *
                  <input
                    type="datetime-local"
                    name="fecha_inicio"
                    value={formulario.fecha_inicio}
                    onChange={cambiarCampo}
                    required
                  />
                </label>

                <label>
                  Fecha y hora de fin *
                  <input
                    type="datetime-local"
                    name="fecha_fin"
                    value={formulario.fecha_fin}
                    onChange={cambiarCampo}
                    required
                  />
                </label>
              </>
            )}
          </div>

          <div className="acciones-formulario">
            <button
              type="submit"
              className="boton-principal"
              disabled={guardando}
            >
              {guardando ? 'Guardando...' : 'Guardar actividad'}
            </button>
          </div>
        </form>
      </section>

      <section className="tabla-contenedor">
        <div className="tabla-encabezado">
          <div>
            <h2>Historial de actividades</h2>
            <p>Registro de tareas, llamadas y reuniones del prospecto.</p>
          </div>

          <button
            type="button"
            className="boton-recargar"
            onClick={cargarActividades}
          >
            Actualizar historial
          </button>
        </div>

        {cargando ? (
          <p className="estado-carga">Cargando actividades...</p>
        ) : actividades.length === 0 ? (
          <p className="sin-resultados">
            Este prospecto todavía no tiene actividades registradas.
          </p>
        ) : (
          <div className="tabla-scroll">
            <table>
              <thead>
                <tr>
                  <th>Tipo</th>
                  <th>Actividad</th>
                  <th>Descripción</th>
                  <th>Fecha</th>
                  <th>Estado</th>
                </tr>
              </thead>

              <tbody>
                {actividades.map((actividad, indice) => (
                  <tr key={`${actividad.tipo_actividad}-${actividad.id_actividad}-${indice}`}>
                    <td>
                      {actividad.tipo_actividad === 'tarea'
                        ? 'Tarea'
                        : actividad.tipo_actividad === 'llamada'
                          ? 'Llamada'
                          : actividad.tipo_actividad === 'reunion'
                            ? 'Reunión'
                            : actividad.tipo_actividad === 'cita'
                              ? 'Cita'
                              : 'Evento'}
                    </td>

                    <td>
                      <strong>{actividad.titulo}</strong>
                    </td>

                    <td>{actividad.descripcion || '—'}</td>

                    <td>
                      {actividad.fecha_actividad
                        ? new Date(actividad.fecha_actividad).toLocaleString('es-CO')
                        : 'Sin fecha'}
                    </td>

                    <td>{actividad.estado || 'Sin estado'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </section>
  )
}

export default SeguimientoProspecto

