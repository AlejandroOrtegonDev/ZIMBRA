// Propuestas comerciales: registro con líneas de productos y ciclo de estados
// borrador -> enviada -> aceptada | rechazada  (triggers en la BD)
// Aceptada/enviada -> venta  (procedimiento sp_registrar_venta_desde_propuesta)

import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  obtenerPropuestas, obtenerPropuesta, crearPropuesta, cambiarEstadoPropuesta,
  convertirPropuestaEnVenta, obtenerOportunidades, crearOportunidad, obtenerProductos,
  obtenerClientes, tienePermiso,
} from '../services/api'
import { formatoFecha, formatoPesos } from '../utils/formato'
import './modulos.css'

const lineaVacia = () => ({ clave: crypto.randomUUID(), id_producto: '', cantidad: 1 })

function FormularioPropuesta({ onCreada, onCerrar }) {
  const [oportunidades, setOportunidades] = useState([])
  const [productos, setProductos] = useState([])
  const [clientes, setClientes] = useState([])
  const [idOportunidad, setIdOportunidad] = useState('')
  const [nuevaOportunidad, setNuevaOportunidad] = useState(false)
  const [oportunidad, setOportunidad] = useState({ id_cliente: '', titulo: '' })
  const [lineas, setLineas] = useState([lineaVacia()])
  const [observaciones, setObservaciones] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    Promise.all([obtenerOportunidades({ estado: 'abierta' }), obtenerProductos(), obtenerClientes()])
      .then(([o, p, c]) => {
        setOportunidades(o.oportunidades)
        setProductos(p.productos)
        setClientes(c.clientes.filter((x) => Number(x.estado) === 1))
      })
      .catch((err) => setError(err.message))
  }, [])

  const precioDe = (id) => Number(productos.find((p) => p.id_producto === Number(id))?.precio ?? 0)
  const total = lineas.reduce((s, l) => s + precioDe(l.id_producto) * (Number(l.cantidad) || 0), 0)

  function cambiarLinea(clave, campo, valor) {
    setLineas((actual) => actual.map((l) => (l.clave === clave ? { ...l, [campo]: valor } : l)))
  }

  async function guardar(enviar) {
    setError('')

    try {
      setGuardando(true)
      let id = Number(idOportunidad)

      if (nuevaOportunidad) {
        if (!oportunidad.id_cliente || oportunidad.titulo.trim().length < 3) {
          throw new Error('Seleccione el cliente y escriba el título de la oportunidad')
        }
        const creada = await crearOportunidad({
          id_cliente: Number(oportunidad.id_cliente),
          titulo: oportunidad.titulo.trim(),
          valor_estimado: total,
        })
        id = creada.id_oportunidad
      }

      if (!id) throw new Error('Seleccione una oportunidad')

      const respuesta = await crearPropuesta({
        id_oportunidad: id,
        observaciones,
        enviar,
        lineas: lineas
          .filter((l) => l.id_producto)
          .map((l) => ({ id_producto: Number(l.id_producto), cantidad: Number(l.cantidad) })),
      })

      onCreada(respuesta)
    } catch (err) {
      setError(err.message)
    } finally {
      setGuardando(false)
    }
  }

  return (
    <section className="formulario-contenedor">
      <div className="formulario-titulo">
        <div>
          <h2>Nueva propuesta</h2>
          <p>El precio sale del catálogo y el total lo calcula un trigger en la base de datos.</p>
        </div>
        <button className="boton-cerrar" type="button" onClick={onCerrar} aria-label="Cerrar">×</button>
      </div>

      {error && <div className="mensaje-error">{error}</div>}

      <div className="campos-grid">
        {!nuevaOportunidad ? (
          <label className="campo-completo">
            Oportunidad abierta *
            <select value={idOportunidad} onChange={(e) => setIdOportunidad(e.target.value)}>
              <option value="">Seleccione una oportunidad</option>
              {oportunidades.map((o) => (
                <option key={o.id_oportunidad} value={o.id_oportunidad}>
                  #{o.id_oportunidad} · {o.cliente} · {o.titulo} ({o.etapa})
                </option>
              ))}
            </select>
          </label>
        ) : (
          <>
            <label>
              Cliente *
              <select value={oportunidad.id_cliente} onChange={(e) => setOportunidad({ ...oportunidad, id_cliente: e.target.value })}>
                <option value="">Seleccione un cliente</option>
                {clientes.map((c) => (
                  <option key={c.id_cliente} value={c.id_cliente}>{c.nombre} {c.apellido ?? ''}</option>
                ))}
              </select>
            </label>
            <label>
              Título de la oportunidad *
              <input value={oportunidad.titulo} onChange={(e) => setOportunidad({ ...oportunidad, titulo: e.target.value })} placeholder="Ej. Correo corporativo para 50 usuarios" />
            </label>
          </>
        )}
      </div>
      <button type="button" className="boton-recargar" style={{ padding: '8px 0' }} onClick={() => setNuevaOportunidad(!nuevaOportunidad)}>
        {nuevaOportunidad ? 'Usar una oportunidad existente' : '+ Crear una oportunidad nueva para un cliente'}
      </button>

      <h3 style={{ fontSize: 14, margin: '16px 0 4px' }}>Productos</h3>
      <div className="lineas">
        {lineas.map((l) => (
          <div className="linea" key={l.clave}>
            <select value={l.id_producto} onChange={(e) => cambiarLinea(l.clave, 'id_producto', e.target.value)} aria-label="Producto">
              <option value="">Seleccione un producto</option>
              {productos.map((p) => (
                <option key={p.id_producto} value={p.id_producto}
                  disabled={lineas.some((o) => o.clave !== l.clave && Number(o.id_producto) === p.id_producto)}>
                  {p.nombre} · {formatoPesos(p.precio)}
                </option>
              ))}
            </select>
            <input type="number" min="1" max="100000" value={l.cantidad} aria-label="Cantidad"
              onChange={(e) => cambiarLinea(l.clave, 'cantidad', e.target.value)} />
            <span className="linea-subtotal">{formatoPesos(precioDe(l.id_producto) * (Number(l.cantidad) || 0))}</span>
            <button type="button" className="boton-cerrar" aria-label="Quitar producto"
              disabled={lineas.length === 1}
              onClick={() => setLineas(lineas.filter((x) => x.clave !== l.clave))}>×</button>
          </div>
        ))}
      </div>
      <button type="button" className="boton-recargar" style={{ padding: '10px 0' }} onClick={() => setLineas([...lineas, lineaVacia()])}>
        + Agregar producto
      </button>

      <div className="campos-grid" style={{ marginTop: 10 }}>
        <label className="campo-completo">
          Observaciones
          <textarea rows="2" value={observaciones} onChange={(e) => setObservaciones(e.target.value)} />
        </label>
      </div>

      <div className="total-propuesta">
        <span>Valor total estimado</span>
        <strong>{formatoPesos(total)}</strong>
      </div>

      <div className="acciones-formulario">
        <button type="button" className="boton-secundario" onClick={() => guardar(false)} disabled={guardando}>
          Guardar como borrador
        </button>
        <button type="button" className="boton-principal" onClick={() => guardar(true)} disabled={guardando}>
          {guardando ? 'Guardando...' : 'Guardar y enviar'}
        </button>
      </div>
    </section>
  )
}

function DetallePropuesta({ id, onCambio, onCerrar }) {
  const [propuesta, setPropuesta] = useState(null)
  const [error, setError] = useState('')
  const [mensaje, setMensaje] = useState('')
  const [ocupado, setOcupado] = useState(false)

  useEffect(() => {
    obtenerPropuesta(id).then((r) => setPropuesta(r.propuesta)).catch((err) => setError(err.message))
  }, [id])

  async function ejecutar(accion, textoExito) {
    setError('')
    setMensaje('')
    try {
      setOcupado(true)
      const r = await accion()
      setMensaje(r.mensaje ?? textoExito)
      const actualizada = await obtenerPropuesta(id)
      setPropuesta(actualizada.propuesta)
      onCambio()
    } catch (err) {
      setError(err.message)
    } finally {
      setOcupado(false)
    }
  }

  if (!propuesta) return error ? <div className="mensaje-error">{error}</div> : <p className="estado-carga">Cargando propuesta...</p>

  const puedeAprobar = tienePermiso('propuestas.aprobar')
  const puedeVender = tienePermiso('ventas.registrar')

  return (
    <section className="panel">
      <div className="detalle-cabecera">
        <div>
          <span className="ruta">Propuesta #{propuesta.id_propuesta} · {formatoFecha(propuesta.fecha)}</span>
          <h2>{propuesta.oportunidad}</h2>
          <p className="panel-subtitulo">{propuesta.cliente} · Vendedor: {propuesta.vendedor ?? 'sin asignar'}</p>
        </div>
        <button className="boton-cerrar" type="button" onClick={onCerrar} aria-label="Cerrar">×</button>
      </div>

      {mensaje && <div className="mensaje-exito">{mensaje}</div>}
      {error && <div className="mensaje-error">{error}</div>}

      <dl className="detalle-datos">
        <div><dt>Estado</dt><dd><span className={`etiqueta-estado ${propuesta.estado}`}>{propuesta.estado}</span></dd></div>
        <div><dt>Valor total</dt><dd>{formatoPesos(propuesta.valor_total)}</dd></div>
        <div><dt>Oportunidad</dt><dd><span className={`etiqueta-estado ${propuesta.estado_oportunidad}`}>{propuesta.estado_oportunidad}</span></dd></div>
        <div><dt>Venta</dt><dd>{propuesta.id_venta ? `#${propuesta.id_venta}` : '—'}</dd></div>
      </dl>

      <div className="tabla-scroll">
        <table>
          <thead>
            <tr><th>Producto</th><th className="numero">Cantidad</th><th className="numero">Precio</th><th className="numero">Subtotal</th></tr>
          </thead>
          <tbody>
            {propuesta.lineas.map((l) => (
              <tr key={l.id_detalle}>
                <td>{l.producto}</td>
                <td className="numero">{l.cantidad}</td>
                <td className="numero">{formatoPesos(l.precio_unitario)}</td>
                <td className="numero"><strong>{formatoPesos(l.subtotal)}</strong></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {propuesta.observaciones && <p className="nota">Observaciones: {propuesta.observaciones}</p>}

      <div className="acciones-detalle">
        {puedeAprobar && propuesta.estado === 'borrador' && (
          <button className="boton-principal" disabled={ocupado}
            onClick={() => ejecutar(() => cambiarEstadoPropuesta(id, 'enviada'))}>Enviar al cliente</button>
        )}
        {puedeAprobar && propuesta.estado === 'enviada' && (
          <button className="boton-exito" disabled={ocupado}
            onClick={() => ejecutar(() => cambiarEstadoPropuesta(id, 'aceptada'))}>Marcar como aceptada</button>
        )}
        {puedeVender && ['enviada', 'aceptada'].includes(propuesta.estado) && !propuesta.id_venta && (
          <button className="boton-principal" disabled={ocupado}
            onClick={() => ejecutar(() => convertirPropuestaEnVenta(id))}>Registrar venta</button>
        )}
        {puedeAprobar && ['borrador', 'enviada'].includes(propuesta.estado) && (
          <button className="boton-peligro" disabled={ocupado}
            onClick={() => window.confirm('¿Rechazar la propuesta? La oportunidad quedará perdida si no tiene otras propuestas abiertas.') &&
              ejecutar(() => cambiarEstadoPropuesta(id, 'rechazada'))}>Rechazar</button>
        )}
      </div>
      {['aceptada', 'rechazada'].includes(propuesta.estado) && (
        <p className="nota">La propuesta está cerrada: la base de datos no permite cambiar su estado ni sus productos.</p>
      )}
    </section>
  )
}

export default function Propuestas() {
  const [propuestas, setPropuestas] = useState([])
  const [estado, setEstado] = useState('')
  const [busqueda, setBusqueda] = useState('')
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [mensaje, setMensaje] = useState('')
  const [mostrarFormulario, setMostrarFormulario] = useState(false)
  const [seleccionada, setSeleccionada] = useState(null)

  const cargar = useCallback(async () => {
    try {
      setError('')
      const r = await obtenerPropuestas(estado)
      setPropuestas(r.propuestas)
    } catch (err) {
      setError(err.message)
    } finally {
      setCargando(false)
    }
  }, [estado])

  useEffect(() => {
    let cancelado = false
    obtenerPropuestas(estado)
      .then((r) => { if (!cancelado) setPropuestas(r.propuestas) })
      .catch((err) => { if (!cancelado) setError(err.message) })
      .finally(() => { if (!cancelado) setCargando(false) })
    return () => { cancelado = true }
  }, [estado])

  const filtradas = useMemo(() => {
    const texto = busqueda.toLowerCase()
    return propuestas.filter((p) =>
      [p.cliente, p.oportunidad, p.vendedor, String(p.id_propuesta)].some((v) => (v ?? '').toLowerCase().includes(texto)))
  }, [propuestas, busqueda])

  return (
    <>
      <header className="encabezado">
        <div>
          <span className="ruta">Gestión comercial / Propuestas</span>
          <h1>Propuestas</h1>
          <p>Cotizaciones enviadas a clientes y prospectos.</p>
        </div>
        {tienePermiso('propuestas.crear') && (
          <button className="boton-principal" onClick={() => { setMostrarFormulario(!mostrarFormulario); setMensaje('') }}>
            + Nueva propuesta
          </button>
        )}
      </header>

      {mensaje && <div className="mensaje-exito">{mensaje}</div>}
      {error && <div className="mensaje-error">{error}</div>}

      {mostrarFormulario && (
        <FormularioPropuesta
          onCerrar={() => setMostrarFormulario(false)}
          onCreada={(r) => {
            setMostrarFormulario(false)
            setMensaje(`${r.mensaje} (#${r.propuesta.id_propuesta} por ${formatoPesos(r.propuesta.valor_total)})`)
            setSeleccionada(r.propuesta.id_propuesta)
            cargar()
          }}
        />
      )}

      {seleccionada && (
        <DetallePropuesta key={seleccionada} id={seleccionada} onCambio={cargar} onCerrar={() => setSeleccionada(null)} />
      )}

      <section className="tabla-contenedor">
        <div className="tabla-encabezado">
          <div>
            <h2>Listado de propuestas</h2>
            <p>Seleccione una fila para ver el detalle y cambiar su estado.</p>
          </div>
          <div className="filtros">
            <select value={estado} onChange={(e) => setEstado(e.target.value)} aria-label="Filtrar por estado">
              <option value="">Todos los estados</option>
              <option value="borrador">Borrador</option>
              <option value="enviada">Enviada</option>
              <option value="aceptada">Aceptada</option>
              <option value="rechazada">Rechazada</option>
            </select>
            <input className="buscador" value={busqueda} onChange={(e) => setBusqueda(e.target.value)} placeholder="Buscar..." />
          </div>
        </div>

        {cargando ? <p className="estado-carga">Cargando propuestas...</p> : (
          <div className="tabla-scroll">
            <table>
              <thead>
                <tr>
                  <th>#</th><th>Fecha</th><th>Cliente</th><th>Oportunidad</th><th>Vendedor</th>
                  <th className="numero">Valor</th><th>Estado</th>
                </tr>
              </thead>
              <tbody>
                {filtradas.map((p) => (
                  <tr key={p.id_propuesta}
                    className={`clicable ${seleccionada === p.id_propuesta ? 'fila-seleccionada' : ''}`}
                    onClick={() => setSeleccionada(p.id_propuesta)}>
                    <td>{p.id_propuesta}</td>
                    <td>{formatoFecha(p.fecha)}</td>
                    <td><strong>{p.cliente}</strong></td>
                    <td className="texto-largo">{p.oportunidad}</td>
                    <td>{p.vendedor ?? '—'}</td>
                    <td className="numero">{formatoPesos(p.valor_total)}</td>
                    <td><span className={`etiqueta-estado ${p.estado}`}>{p.estado}</span></td>
                  </tr>
                ))}
                {filtradas.length === 0 && (
                  <tr><td colSpan="7" className="sin-resultados">No se encontraron propuestas.</td></tr>
                )}
              </tbody>
            </table>
          </div>
        )}
        <div className="tabla-pie">Mostrando {filtradas.length} de {propuestas.length} propuestas</div>
      </section>
    </>
  )
}
