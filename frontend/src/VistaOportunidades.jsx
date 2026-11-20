
import { useEffect, useState } from 'react'
import {
  obtenerOportunidades,
  obtenerEtapasOportunidades,
  obtenerClientes,
  obtenerVendedores,
  crearOportunidad,
  actualizarOportunidad,
} from './services/api'

const formularioInicial = {
  id_cliente: '',
  id_vendedor: '',
  id_etapa: '',
  titulo: '',
  descripcion: '',
  valor_estimado: '',
  estado: 'abierta',
  fecha_cierre: '',
}

function VistaOportunidades() {
  const [oportunidades, setOportunidades] = useState([])
  const [etapas, setEtapas] = useState([])
  const [clientes, setClientes] = useState([])
  const [vendedores, setVendedores] = useState([])

  const [formulario, setFormulario] = useState(formularioInicial)
  const [oportunidadEditando, setOportunidadEditando] = useState(null)

  const [mostrarFormulario, setMostrarFormulario] = useState(false)
  const [busqueda, setBusqueda] = useState('')
  const [cargando, setCargando] = useState(true)
  const [guardando, setGuardando] = useState(false)

  const [error, setError] = useState('')
  const [mensaje, setMensaje] = useState('')

  // Cargar oportunidades, etapas, clientes y vendedores
  async function cargarDatos() {
    try {
      setCargando(true)
      setError('')

      const [
        respuestaOportunidades,
        respuestaEtapas,
        respuestaClientes,
        respuestaVendedores,
      ] = await Promise.all([
        obtenerOportunidades(),
        obtenerEtapasOportunidades(),
        obtenerClientes(),
        obtenerVendedores(),
      ])

      setOportunidades(respuestaOportunidades.oportunidades || [])
      setEtapas(respuestaEtapas.etapas || [])
      setClientes(respuestaClientes.clientes || [])
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
        const [
          respuestaOportunidades,
          respuestaEtapas,
          respuestaClientes,
          respuestaVendedores,
        ] = await Promise.all([
          obtenerOportunidades(),
          obtenerEtapasOportunidades(),
          obtenerClientes(),
          obtenerVendedores(),
        ])

        if (!cancelado) {
          setOportunidades(respuestaOportunidades.oportunidades || [])
          setEtapas(respuestaEtapas.etapas || [])
          setClientes(respuestaClientes.clientes || [])
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

  // Actualizar campos del formulario
  function cambiarCampo(evento) {
    const { name, value } = evento.target

    setFormulario((anterior) => ({
      ...anterior,
      [name]: value,
    }))
  }

  // Abrir formulario para registrar
  function nuevaOportunidad() {
    setFormulario(formularioInicial)
    setOportunidadEditando(null)
    setMostrarFormulario(true)
    setError('')
    setMensaje('')
  }

  // Abrir formulario para editar
  function editarOportunidad(oportunidad) {
    setFormulario({
      id_cliente: String(oportunidad.id_cliente),
      id_vendedor: oportunidad.id_vendedor
        ? String(oportunidad.id_vendedor)
        : '',
      id_etapa: oportunidad.id_etapa
        ? String(oportunidad.id_etapa)
        : '',
      titulo: oportunidad.titulo || '',
      descripcion: oportunidad.descripcion || '',
      valor_estimado: oportunidad.valor_estimado || '',
      estado: oportunidad.estado || 'abierta',
      fecha_cierre: oportunidad.fecha_cierre
        ? String(oportunidad.fecha_cierre).slice(0, 10)
        : '',
    })

    setOportunidadEditando(oportunidad.id_oportunidad)
    setMostrarFormulario(true)
    setError('')
    setMensaje('')
  }

  // Registrar o actualizar oportunidad
  async function guardarOportunidad(evento) {
    evento.preventDefault()

    try {
      setGuardando(true)
      setError('')
      setMensaje('')

      const datos = {
        ...formulario,
        id_cliente: Number(formulario.id_cliente),
        id_vendedor: formulario.id_vendedor
          ? Number(formulario.id_vendedor)
          : null,
        id_etapa: formulario.id_etapa
          ? Number(formulario.id_etapa)
          : null,
        valor_estimado: Number(formulario.valor_estimado || 0),
        fecha_cierre: formulario.fecha_cierre || null,
      }

      if (oportunidadEditando) {
        await actualizarOportunidad(oportunidadEditando, datos)
        setMensaje('Oportunidad actualizada correctamente')
      } else {
        await crearOportunidad(datos)
        setMensaje('Oportunidad registrada correctamente')
      }

      setFormulario(formularioInicial)
      setOportunidadEditando(null)
      setMostrarFormulario(false)

      await cargarDatos()
    } catch (err) {
      setError(err.message)
    } finally {
      setGuardando(false)
    }
  }

  // Filtrar oportunidades
  const oportunidadesFiltradas = oportunidades.filter((oportunidad) => {
    const texto = busqueda.toLowerCase()

    return (
      (oportunidad.titulo || '').toLowerCase().includes(texto) ||
      (oportunidad.cliente_nombre || '').toLowerCase().includes(texto) ||
      (oportunidad.vendedor_nombre || '').toLowerCase().includes(texto) ||
      (oportunidad.etapa_nombre || '').toLowerCase().includes(texto)
    )
  })

  // Calcular indicadores
  const valorTotal = oportunidades.reduce(
    (total, oportunidad) =>
      total + Number(oportunidad.valor_estimado || 0),
    0,
  )

  const oportunidadesAbiertas = oportunidades.filter(
    (oportunidad) => oportunidad.estado === 'abierta',
  ).length

  const formatoMoneda = (valor) =>
    new Intl.NumberFormat('es-CO', {
      style: 'currency',
      currency: 'COP',
      maximumFractionDigits: 0,
    }).format(Number(valor || 0))

  return (
    <>
      <header className="encabezado">
        <div>
          <span className="ruta">
            Gestión comercial / Oportunidades
          </span>
          <h1>Oportunidades</h1>
          <p>Administra las oportunidades y el proceso comercial.</p>
        </div>

        <button
          className="boton-principal"
          onClick={nuevaOportunidad}
        >
          + Nueva oportunidad
        </button>
      </header>

      <section className="indicadores">
        <article className="indicador">
          <span>Total de oportunidades</span>
          <strong>{oportunidades.length}</strong>
          <small>Registros encontrados</small>
        </article>

        <article className="indicador">
          <span>Oportunidades abiertas</span>
          <strong>{oportunidadesAbiertas}</strong>
          <small>En proceso comercial</small>
        </article>

        <article className="indicador">
          <span>Valor estimado total</span>
          <strong>{formatoMoneda(valorTotal)}</strong>
          <small>Valor de todas las oportunidades</small>
        </article>
      </section>

      {mostrarFormulario && (
        <section className="formulario-contenedor">
          <div className="formulario-titulo">
            <div>
              <h2>
                {oportunidadEditando
                  ? 'Editar oportunidad'
                  : 'Registrar nueva oportunidad'}
              </h2>
              <p>Completa la información comercial.</p>
            </div>

            <button
              type="button"
              className="boton-cerrar"
              onClick={() => setMostrarFormulario(false)}
            >
              ×
            </button>
          </div>

          <form onSubmit={guardarOportunidad}>
            <div className="campos-grid">
              <label>
                Cliente *
                <select
                  name="id_cliente"
                  value={formulario.id_cliente}
                  onChange={cambiarCampo}
                  required
                >
                  <option value="">Selecciona un cliente</option>
                  {clientes.map((cliente) => (
                    <option
                      key={cliente.id_cliente}
                      value={cliente.id_cliente}
                    >
                      {cliente.nombre} {cliente.apellido || ''}
                    </option>
                  ))}
                </select>
              </label>

              <label>
                Vendedor responsable
                <select
                  name="id_vendedor"
                  value={formulario.id_vendedor}
                  onChange={cambiarCampo}
                >
                  <option value="">Sin asignar</option>
                  {vendedores.map((vendedor) => (
                    <option
                      key={vendedor.id_vendedor}
                      value={vendedor.id_vendedor}
                    >
                      {vendedor.nombre}
                    </option>
                  ))}
                </select>
              </label>

              <label>
                Etapa comercial
                <select
                  name="id_etapa"
                  value={formulario.id_etapa}
                  onChange={cambiarCampo}
                >
                  <option value="">Selecciona una etapa</option>
                  {etapas.map((etapa) => (
                    <option
                      key={etapa.id_etapa}
                      value={etapa.id_etapa}
                    >
                      {etapa.nombre}
                    </option>
                  ))}
                </select>
              </label>

              <label>
                Título de la oportunidad *
                <input
                  name="titulo"
                  value={formulario.titulo}
                  onChange={cambiarCampo}
                  placeholder="Ej. Venta de software empresarial"
                  required
                />
              </label>

              <label>
                Valor estimado
                <input
                  type="number"
                  name="valor_estimado"
                  value={formulario.valor_estimado}
                  onChange={cambiarCampo}
                  min="0"
                  step="0.01"
                  placeholder="Ej. 8500000"
                />
              </label>

              <label>
                Fecha estimada de cierre
                <input
                  type="date"
                  name="fecha_cierre"
                  value={formulario.fecha_cierre}
                  onChange={cambiarCampo}
                />
              </label>

              <label>
                Estado
                <select
                  name="estado"
                  value={formulario.estado}
                  onChange={cambiarCampo}
                >
                  <option value="abierta">Abierta</option>
                  <option value="ganada">Ganada</option>
                  <option value="perdida">Perdida</option>
                </select>
              </label>

              <label className="campo-completo">
                Descripción
                <textarea
                  name="descripcion"
                  value={formulario.descripcion}
                  onChange={cambiarCampo}
                  placeholder="Describe los detalles de la oportunidad..."
                  rows="3"
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
                {guardando
                  ? 'Guardando...'
                  : oportunidadEditando
                    ? 'Guardar cambios'
                    : 'Guardar oportunidad'}
              </button>
            </div>
          </form>
        </section>
      )}

      {mensaje && <div className="mensaje-exito">{mensaje}</div>}
      {error && <div className="mensaje-error">{error}</div>}

      <section className="tabla-contenedor">
        <div className="tabla-encabezado">
          <div>
            <h2>Listado de oportunidades</h2>
            <p>Consulta las oportunidades registradas en MySQL.</p>
          </div>

          <input
            className="buscador"
            value={busqueda}
            onChange={(evento) => setBusqueda(evento.target.value)}
            placeholder="Buscar oportunidad..."
          />
        </div>

        {cargando ? (
          <p className="estado-carga">Cargando oportunidades...</p>
        ) : (
          <div className="tabla-scroll">
            <table>
              <thead>
                <tr>
                  <th>Oportunidad</th>
                  <th>Cliente</th>
                  <th>Vendedor</th>
                  <th>Etapa</th>
                  <th>Valor estimado</th>
                  <th>Estado</th>
                  <th>Acciones</th>
                </tr>
              </thead>

              <tbody>
                {oportunidadesFiltradas.map((oportunidad) => (
                  <tr key={oportunidad.id_oportunidad}>
                    <td>
                      <strong>{oportunidad.titulo}</strong>
                    </td>
                    <td>
                      {oportunidad.cliente_nombre}{' '}
                      {oportunidad.cliente_apellido || ''}
                    </td>
                    <td>{oportunidad.vendedor_nombre || 'Sin asignar'}</td>
                    <td>{oportunidad.etapa_nombre || 'Sin etapa'}</td>
                    <td>{formatoMoneda(oportunidad.valor_estimado)}</td>
                    <td>
                      <span
                        className={
                          oportunidad.estado === 'ganada'
                            ? 'estado-activo'
                            : oportunidad.estado === 'perdida'
                              ? 'estado-inactivo'
                              : 'estado-pendiente'
                        }
                      >
                        {oportunidad.estado}
                      </span>
                    </td>
                    <td>
                      <button
                        type="button"
                        className="boton-editar"
                        onClick={() => editarOportunidad(oportunidad)}
                      >
                        Editar
                      </button>
                    </td>
                  </tr>
                ))}

                {oportunidadesFiltradas.length === 0 && (
                  <tr>
                    <td colSpan="7" className="sin-resultados">
                      No se encontraron oportunidades.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        )}

        <div className="tabla-pie">
          Mostrando {oportunidadesFiltradas.length} de{' '}
          {oportunidades.length} oportunidades

          <button className="boton-recargar" onClick={cargarDatos}>
            Actualizar listado
          </button>
        </div>
      </section>
    </>
  )
}

export default VistaOportunidades
