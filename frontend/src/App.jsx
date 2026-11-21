
import { useCallback, useEffect, useState } from 'react'
import { obtenerClientes, crearCliente, actualizarCliente, desactivarCliente, obtenerProspectos, obtenerVendedores, crearProspecto, obtenerSesion, cerrarSesion, tienePermiso } from './services/api'
import './App.css'
import './pages/modulos.css'
import SeguimientoProspecto from './SeguimientoProspecto'
import Dashboard from './pages/Dashboard'
import Propuestas from './pages/Propuestas'
import Ventas from './pages/Ventas'
import Vendedores from './pages/Vendedores'
import Reportes from './pages/Reportes'

// Menú lateral: cada opción se muestra solo si el rol tiene el permiso
const MENU = [
  { vista: 'dashboard', icono: '◧', texto: 'Tablero', permiso: 'reportes.ver' },
  { vista: 'clientes', icono: '▦', texto: 'Clientes', permiso: 'clientes.ver' },
  { vista: 'prospectos', icono: '◉', texto: 'Prospectos', permiso: 'prospectos.ver' },
  { vista: 'propuestas', icono: '▣', texto: 'Propuestas', permiso: 'propuestas.ver' },
  { vista: 'ventas', icono: '▤', texto: 'Ventas y pagos', permiso: 'ventas.ver' },
  { vista: 'vendedores', icono: '♙', texto: 'Vendedores', permiso: 'vendedores.ver' },
  { vista: 'reportes', icono: '▥', texto: 'Reportes', permiso: 'reportes.ver' },
]

const NOMBRE_ROL = { admin: 'Administrador', user: 'Comercial', user_demo: 'Solo lectura' }

const formularioInicial = {
  tipo_cliente: 'empresa',
  nombre: '',
  apellido: '',
  documento: '',
  correo: '',
  telefono: '',
  direccion: '',
}

function App() {
  const [clientes, setClientes] = useState([])
  const [busqueda, setBusqueda] = useState('')
  const [mostrarFormulario, setMostrarFormulario] = useState(false)
  const [formulario, setFormulario] = useState(formularioInicial)
  const [cargando, setCargando] = useState(true)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')
  const [mensaje, setMensaje] = useState('')
  const [clienteEditando, setClienteEditando] = useState(null)
  const menuVisible = MENU.filter((opcion) => tienePermiso(opcion.permiso))
  const [vista, setVista] = useState(() => {
    const inicial = window.location.hash.replace('#', '')
    return menuVisible.some((o) => o.vista === inicial) ? inicial : menuVisible[0]?.vista ?? 'clientes'
  })
  const usuario = obtenerSesion()?.usuario

  function irA(nuevaVista) {
    setVista(nuevaVista)
    window.history.replaceState(null, '', `#${nuevaVista}`)
  }

  // Consultar clientes en el backend
  const cargarClientes = useCallback(async () => {
    try {
      setCargando(true)
      setError('')

      const respuesta = await obtenerClientes()
      setClientes(respuesta.clientes || [])
    } catch (err) {
      setError(err.message)
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
  let cancelado = false

  async function iniciarCarga() {
    try {
      setCargando(true)
      setError('')

      const respuesta = await obtenerClientes()

      if (!cancelado) {
        setClientes(respuesta.clientes || [])
      }
    } catch (err) {
      if (!cancelado) {
        setError(err.message)
      }
    } finally {
      if (!cancelado) {
        setCargando(false)
      }
    }
  }

  iniciarCarga()

  return () => {
    cancelado = true
  }
}, [])

  // Actualizar campos del formulario
  function cambiarCampo(evento) {
    const { name, value } = evento.target

    setFormulario((anterior) => ({
      ...anterior,
      [name]: value,
    }))
  }

  // Registrar o actualizar cliente
async function guardarCliente(evento) {
  evento.preventDefault()

  try {
    setGuardando(true)
    setError('')
    setMensaje('')

    if (clienteEditando) {
      await actualizarCliente(clienteEditando, formulario)
      setMensaje('Cliente actualizado correctamente')
    } else {
      await crearCliente(formulario)
      setMensaje('Cliente registrado correctamente')
    }

    setFormulario(formularioInicial)
    setClienteEditando(null)
    setMostrarFormulario(false)

    await cargarClientes()
  } catch (err) {
    setError(err.message)
  } finally {
    setGuardando(false)
  }
}

// Cargar los datos del cliente seleccionado
function editarCliente(cliente) {
  setFormulario({
    tipo_cliente: cliente.tipo_cliente || 'persona',
    nombre: cliente.nombre || '',
    apellido: cliente.apellido || '',
    documento: cliente.documento || '',
    correo: cliente.correo || '',
    telefono: cliente.telefono || '',
    direccion: cliente.direccion || '',
  })

  setClienteEditando(cliente.id_cliente)
  setMostrarFormulario(true)
  setError('')
  setMensaje('')
}

// Desactivar cliente
async function manejarDesactivacion(cliente) {
  const confirmar = window.confirm(
    `¿Estás seguro de que deseas desactivar a ${cliente.nombre}?`,
  )

  if (!confirmar) return

  try {
    setError('')
    setMensaje('')

    await desactivarCliente(cliente.id_cliente)

    setMensaje('Cliente desactivado correctamente')
    await cargarClientes()
  } catch (err) {
    setError(err.message)
  }
}

  // Buscar clientes
  const clientesFiltrados = clientes.filter((cliente) => {
    const texto = busqueda.toLowerCase()

    return (
      (cliente.nombre || '').toLowerCase().includes(texto) ||
      (cliente.apellido || '').toLowerCase().includes(texto) ||
      (cliente.documento || '').toLowerCase().includes(texto) ||
      (cliente.correo || '').toLowerCase().includes(texto)
    )
  })

  const clientesActivos = clientes.filter(
    (cliente) => Number(cliente.estado) === 1,
  ).length

  return (
    <div className="aplicacion">
      <aside className="sidebar">
        <div className="marca">
          <div className="marca-icono">Z</div>
          <div>
            <strong>Zimbra CRM</strong>
            <span>Gestión comercial</span>
          </div>
        </div>

        <p className="menu-titulo">MENÚ PRINCIPAL</p>

        <nav className="menu">
          {menuVisible.map((opcion) => (
            <a
              key={opcion.vista}
              className={`menu-item ${vista === opcion.vista ? 'activo' : ''}`}
              href={`#${opcion.vista}`}
              onClick={(evento) => {
                evento.preventDefault()
                irA(opcion.vista)
              }}
            >
              <span>{opcion.icono}</span>
              {opcion.texto}
            </a>
          ))}
        </nav>

        <div className="sidebar-pie">
          <span>{NOMBRE_ROL[usuario?.rol] ?? usuario?.rol}</span>
          <strong>{usuario?.nombre}</strong>
          <div className="usuario-sesion">
            <span>{usuario?.correo}</span>
          </div>
          <div className="usuario-sesion">
            <button type="button" onClick={cerrarSesion}>Cerrar sesión</button>
          </div>
        </div>
      </aside>

      <main className="contenido">
        {vista === 'dashboard' && <Dashboard />}
        {vista === 'propuestas' && <Propuestas />}
        {vista === 'ventas' && <Ventas />}
        {vista === 'vendedores' && <Vendedores />}
        {vista === 'reportes' && <Reportes />}
        {vista === 'prospectos' && <VistaProspectos />}
        {vista === 'clientes' && (
  <>
        <header className="encabezado">
          <div>
            <span className="ruta">Gestión comercial / Clientes</span>
            <h1>Clientes</h1>
            <p>Administra la información de tus clientes.</p>
          </div>

          {tienePermiso('clientes.crear') && (
          <button
            className="boton-principal"
              onClick={() => {
                setMensaje('')
                setError('')
                setFormulario(formularioInicial)
                setClienteEditando(null)
                setMostrarFormulario(!mostrarFormulario)
              }}
          >
            + Nuevo cliente
          </button>
          )}
        </header>

        <section className="indicadores">
          <article className="indicador">
            <span>Total de clientes</span>
            <strong>{clientes.length}</strong>
            <small>Registros encontrados</small>
          </article>

          <article className="indicador">
            <span>Clientes activos</span>
            <strong>{clientesActivos}</strong>
            <small>Disponibles en el sistema</small>
          </article>

          <article className="indicador">
            <span>Clientes inactivos</span>
            <strong>{clientes.length - clientesActivos}</strong>
            <small>Registros desactivados</small>
          </article>
        </section>

        {mostrarFormulario && (
          <section className="formulario-contenedor">
            <div className="formulario-titulo">
              <div>
                <h2>
                {clienteEditando ? 'Editar cliente' : 'Registrar nuevo cliente'}
                </h2>
               <p>
                {clienteEditando
                  ? 'Modifica la información del cliente seleccionado.'
                  : 'Completa la información del cliente.'}
                </p>
              </div>

              <button
                className="boton-cerrar"
                onClick={() => setMostrarFormulario(false)}
                type="button"
              >
                ×
              </button>
            </div>

            <form onSubmit={guardarCliente}>
              <div className="campos-grid">
                <label>
                  Tipo de cliente *
                  <select
                    name="tipo_cliente"
                    value={formulario.tipo_cliente}
                    onChange={cambiarCampo}
                    required
                  >
                    <option value="empresa">Empresa</option>
                    <option value="persona">Persona</option>
                  </select>
                </label>

                <label>
                  Nombre *
                  <input
                    name="nombre"
                    value={formulario.nombre}
                    onChange={cambiarCampo}
                    placeholder="Nombre o razón social"
                    required
                  />
                </label>

                <label>
                  Apellido
                  <input
                    name="apellido"
                    value={formulario.apellido}
                    onChange={cambiarCampo}
                    placeholder="Apellido"
                  />
                </label>

                <label>
                  Documento
                  <input
                    name="documento"
                    value={formulario.documento}
                    onChange={cambiarCampo}
                    placeholder="Número de documento o NIT"
                  />
                </label>

                <label>
                  Correo electrónico
                  <input
                    type="email"
                    name="correo"
                    value={formulario.correo}
                    onChange={cambiarCampo}
                    placeholder="correo@empresa.com"
                  />
                </label>

                <label>
                  Teléfono
                  <input
                    name="telefono"
                    value={formulario.telefono}
                    onChange={cambiarCampo}
                    placeholder="Número de contacto"
                  />
                </label>

                <label className="campo-completo">
                  Dirección
                  <input
                    name="direccion"
                    value={formulario.direccion}
                    onChange={cambiarCampo}
                    placeholder="Dirección del cliente"
                  />
                </label>
              </div>

              <div className="acciones-formulario">
                <button
                  type="button"
                  className="boton-secundario"
                  onClick={() => setMostrarFormulario(false)}
                >
                  Cancelar
                </button>

                <button
                  type="submit"
                  className="boton-principal"
                  disabled={guardando}
                >
                  {guardando ? 'Guardando...' : clienteEditando ? 'Guardar cambios' : 'Guardar cliente'}
                </button>
              </div>
            </form>
          </section>
        )}

        {mensaje && <div className="mensaje-exito">{mensaje}</div>}
        {error && <div className="mensaje-error">{error}</div>}

        <section className="tabla-contenedor" id="clientes">
          <div className="tabla-encabezado">
            <div>
              <h2>Listado de clientes</h2>
              <p>Consulta los clientes registrados en MySQL.</p>
            </div>

            <input
              className="buscador"
              value={busqueda}
              onChange={(evento) => setBusqueda(evento.target.value)}
              placeholder="Buscar cliente..."
            />
          </div>

          {cargando ? (
            <p className="estado-carga">Cargando clientes...</p>
          ) : (
            <div className="tabla-scroll">
              <table>
                <thead>
                  <tr>
                    <th>Cliente</th>
                    <th>Tipo</th>
                    <th>Documento</th>
                    <th>Correo</th>
                    <th>Teléfono</th>
                    <th>Estado</th>
                    <th>Acciones</th>
                  </tr>
                </thead>

                <tbody>
                  {clientesFiltrados.map((cliente) => (
                    <tr key={cliente.id_cliente}>
                      <td>
                        <strong>
                          {cliente.nombre} {cliente.apellido || ''}
                        </strong>
                      </td>
                      <td>{cliente.tipo_cliente}</td>
                      <td>{cliente.documento || '—'}</td>
                      <td>{cliente.correo || '—'}</td>
                      <td>{cliente.telefono || '—'}</td>
                      <td>
                        <span
                          className={
                            Number(cliente.estado) === 1
                              ? 'estado-activo'
                              : 'estado-inactivo'
                          }
                        >
                          {Number(cliente.estado) === 1
                            ? 'Activo'
                            : 'Inactivo'}
                        </span>
                      </td>
                      <td>
  <div className="acciones-tabla">
    {tienePermiso('clientes.editar') && (
    <button
      type="button"
      className="boton-editar"
      onClick={() => editarCliente(cliente)}
    >
      Editar
    </button>
    )}

    {Number(cliente.estado) === 1 && tienePermiso('clientes.desactivar') && (
      <button
        type="button"
        className="boton-desactivar"
        onClick={() => manejarDesactivacion(cliente)}
      >
        Desactivar
      </button>
    )}
  </div>
</td>
                    </tr>
                  ))}

                  {clientesFiltrados.length === 0 && (
                    <tr>
                      <td colSpan="7" className="sin-resultados">
                        No se encontraron clientes.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          )}

          <div className="tabla-pie">
            Mostrando {clientesFiltrados.length} de {clientes.length} clientes
            <button className="boton-recargar" onClick={cargarClientes}>
              Actualizar listado
            </button>
          </div>
        </section>
            </>
  )}
      </main>
    </div>
  )
}


function VistaProspectos() {
  const formularioInicial = {
    tipo_cliente: 'empresa',
    nombre: '',
    apellido: '',
    documento: '',
    correo: '',
    telefono: '',
    direccion: '',
    id_vendedor: '',
  }

  const [prospectos, setProspectos] = useState([])
  const [vendedores, setVendedores] = useState([])
  const [formulario, setFormulario] = useState(formularioInicial)
  const [busqueda, setBusqueda] = useState('')
  const [mostrarFormulario, setMostrarFormulario] = useState(false)
  const [cargando, setCargando] = useState(true)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')
  const [mensaje, setMensaje] = useState('')
  const [prospectoSeleccionado, setProspectoSeleccionado] = useState(null)

  // Consultar prospectos y vendedores
  async function cargarDatos() {
    try {
      setCargando(true)
      setError('')

      const [respuestaProspectos, respuestaVendedores] =
        await Promise.all([
          obtenerProspectos(),
          obtenerVendedores(),
        ])

      setProspectos(respuestaProspectos.prospectos || [])
      setVendedores(respuestaVendedores.vendedores || [])
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
        const [respuestaProspectos, respuestaVendedores] =
          await Promise.all([
            obtenerProspectos(),
            obtenerVendedores(),
          ])

        if (!cancelado) {
          setProspectos(respuestaProspectos.prospectos || [])
          setVendedores(respuestaVendedores.vendedores || [])
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
  }, [])

  function cambiarCampo(evento) {
    const { name, value } = evento.target

    setFormulario((anterior) => ({
      ...anterior,
      [name]: value,
    }))
  }

  async function guardarProspecto(evento) {
    evento.preventDefault()

    try {
      setGuardando(true)
      setError('')
      setMensaje('')

      await crearProspecto({
        ...formulario,
        id_vendedor: Number(formulario.id_vendedor),
      })

      setMensaje('Prospecto registrado y vendedor asignado correctamente')
      setFormulario(formularioInicial)
      setMostrarFormulario(false)

      await cargarDatos()
    } catch (err) {
      setError(err.message)
    } finally {
      setGuardando(false)
    }
  }

  const prospectosFiltrados = prospectos.filter((prospecto) => {
    const texto = busqueda.toLowerCase()

    return (
      (prospecto.nombre || '').toLowerCase().includes(texto) ||
      (prospecto.apellido || '').toLowerCase().includes(texto) ||
      (prospecto.documento || '').toLowerCase().includes(texto) ||
      (prospecto.correo || '').toLowerCase().includes(texto) ||
      (prospecto.vendedor_nombre || '').toLowerCase().includes(texto)
    )
  })

if (prospectoSeleccionado) {
  return (
    <SeguimientoProspecto
      prospecto={prospectoSeleccionado}
      onCerrar={() => setProspectoSeleccionado(null)}
    />
  )
}

  return (
    <>
      <header className="encabezado">
        <div>
          <span className="ruta">Gestión comercial / Prospectos</span>
          <h1>Prospectos</h1>
          <p>Administra los posibles clientes y sus vendedores responsables.</p>
        </div>

        {tienePermiso('prospectos.crear') && (
        <button
          className="boton-principal"
          onClick={() => {
            setFormulario(formularioInicial)
            setError('')
            setMensaje('')
            setMostrarFormulario(!mostrarFormulario)
          }}
        >
          + Nuevo prospecto
        </button>
        )}
      </header>

      <section className="indicadores">
        <article className="indicador">
          <span>Total de prospectos</span>
          <strong>{prospectos.length}</strong>
          <small>Registros encontrados</small>
        </article>

        <article className="indicador">
          <span>Prospectos potenciales</span>
          <strong>{prospectos.filter((p) => Boolean(p.es_potencial)).length}</strong>
          <small>Alta interacción en 30 días (evento programado)</small>
        </article>

        <article className="indicador">
          <span>Vendedores disponibles</span>
          <strong>{vendedores.length}</strong>
          <small>Personal activo</small>
        </article>
      </section>

      {mostrarFormulario && (
        <section className="formulario-contenedor">
          <div className="formulario-titulo">
            <div>
              <h2>Registrar nuevo prospecto</h2>
              <p>Completa sus datos y asigna un vendedor.</p>
            </div>

            <button
              className="boton-cerrar"
              type="button"
              onClick={() => setMostrarFormulario(false)}
            >
              ×
            </button>
          </div>

          <form onSubmit={guardarProspecto}>
            <div className="campos-grid">
              <label>
                Tipo de prospecto *
                <select
                  name="tipo_cliente"
                  value={formulario.tipo_cliente}
                  onChange={cambiarCampo}
                  required
                >
                  <option value="empresa">Empresa</option>
                  <option value="persona">Persona</option>
                </select>
              </label>

              <label>
                Nombre o razón social *
                <input
                  name="nombre"
                  value={formulario.nombre}
                  onChange={cambiarCampo}
                  required
                />
              </label>

              <label>
                Apellido
                <input
                  name="apellido"
                  value={formulario.apellido}
                  onChange={cambiarCampo}
                />
              </label>

              <label>
                Documento o NIT
                <input
                  name="documento"
                  value={formulario.documento}
                  onChange={cambiarCampo}
                />
              </label>

              <label>
                Correo electrónico
                <input
                  type="email"
                  name="correo"
                  value={formulario.correo}
                  onChange={cambiarCampo}
                />
              </label>

              <label>
                Teléfono
                <input
                  name="telefono"
                  value={formulario.telefono}
                  onChange={cambiarCampo}
                />
              </label>

              <label className="campo-completo">
                Dirección
                <input
                  name="direccion"
                  value={formulario.direccion}
                  onChange={cambiarCampo}
                />
              </label>

              <label className="campo-completo">
                Vendedor responsable *
                <select
                  name="id_vendedor"
                  value={formulario.id_vendedor}
                  onChange={cambiarCampo}
                  required
                >
                  <option value="">Selecciona un vendedor</option>
                  {vendedores.map((vendedor) => (
                    <option
                      key={vendedor.id_vendedor}
                      value={vendedor.id_vendedor}
                    >
                      {vendedor.nombre} - {vendedor.especialidad}
                    </option>
                  ))}
                </select>
              </label>
            </div>

            <div className="acciones-formulario">
              <button
                type="button"
                className="boton-secundario"
                onClick={() => setMostrarFormulario(false)}
              >
                Cancelar
              </button>

              <button
                type="submit"
                className="boton-principal"
                disabled={guardando || vendedores.length === 0}
              >
                {guardando ? 'Guardando...' : 'Guardar prospecto'}
              </button>
            </div>
          </form>
        </section>
      )}

      {mensaje && <div className="mensaje-exito">{mensaje}</div>}
      {error && <div className="mensaje-error">{error}</div>}

      <section className="tabla-contenedor" id="prospectos">
        <div className="tabla-encabezado">
          <div>
            <h2>Listado de prospectos</h2>
            <p>Prospectos registrados y vendedores asignados.</p>
          </div>

          <input
            className="buscador"
            value={busqueda}
            onChange={(evento) => setBusqueda(evento.target.value)}
            placeholder="Buscar prospecto..."
          />
        </div>

        {cargando ? (
          <p className="estado-carga">Cargando prospectos...</p>
        ) : (
          <div className="tabla-scroll">
            <table>
              <thead>
                <tr>
                  <th>Prospecto</th>
                  <th>Tipo</th>
                  <th>Documento</th>
                  <th>Correo</th>
                  <th>Teléfono</th>
                  <th>Vendedor asignado</th>
                  <th>Acciones</th>
                </tr>
              </thead>

              <tbody>
                {prospectosFiltrados.map((prospecto) => (
                  <tr key={prospecto.id_cliente}>
                    <td>
                      <strong>
                        {prospecto.nombre} {prospecto.apellido || ''}
                      </strong>
                      {Boolean(prospecto.es_potencial) && (
                        <span className="etiqueta-potencial" title={`Puntaje de interés: ${prospecto.puntaje}`}>
                          Potencial · {prospecto.puntaje} pts
                        </span>
                      )}
                    </td>
                    <td>{prospecto.tipo_cliente}</td>
                    <td>{prospecto.documento || '—'}</td>
                    <td>{prospecto.correo || '—'}</td>
                    <td>{prospecto.telefono || '—'}</td>
                    <td>{prospecto.vendedor_nombre || 'Sin asignar'}</td>
                    <td>
  <button
    type="button"
    className="boton-editar"
    onClick={() => setProspectoSeleccionado(prospecto)}
  >
    Ver seguimiento
  </button>
</td>
                  </tr>
                ))}

                {prospectosFiltrados.length === 0 && (
                  <tr>
                    <td colSpan="7" className="sin-resultados">
                      No se encontraron prospectos.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        )}

        <div className="tabla-pie">
          Mostrando {prospectosFiltrados.length} de {prospectos.length} prospectos

          <button className="boton-recargar" onClick={cargarDatos}>
            Actualizar listado
          </button>
        </div>
      </section>
    </>
  )
}


export default App
