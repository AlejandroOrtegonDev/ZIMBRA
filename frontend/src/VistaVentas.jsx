
import { useEffect, useState } from 'react'
import {
  obtenerVentas,
  obtenerPropuestasDisponibles,
  obtenerProductosDisponibles,
  crearVenta,
} from './services/api'

function VistaVentas() {
  const [ventas, setVentas] = useState([])
  const [propuestas, setPropuestas] = useState([])
  const [productos, setProductos] = useState([])
  const [idPropuesta, setIdPropuesta] = useState('')
  const [cantidades, setCantidades] = useState({})
  const [busqueda, setBusqueda] = useState('')
  const [mostrarFormulario, setMostrarFormulario] = useState(false)
  const [cargando, setCargando] = useState(true)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')
  const [mensaje, setMensaje] = useState('')

  // Cargar información del módulo
  async function cargarDatos() {
    try {
      setError('')

      const [respuestaVentas, respuestaPropuestas, respuestaProductos] =
        await Promise.all([
          obtenerVentas(),
          obtenerPropuestasDisponibles(),
          obtenerProductosDisponibles(),
        ])

      setVentas(respuestaVentas.ventas || [])
      setPropuestas(respuestaPropuestas.propuestas || [])
      setProductos(respuestaProductos.productos || [])
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
        const [respuestaVentas, respuestaPropuestas, respuestaProductos] =
          await Promise.all([
            obtenerVentas(),
            obtenerPropuestasDisponibles(),
            obtenerProductosDisponibles(),
          ])

        if (!cancelado) {
          setVentas(respuestaVentas.ventas || [])
          setPropuestas(respuestaPropuestas.propuestas || [])
          setProductos(respuestaProductos.productos || [])
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

  // Formato de moneda colombiana
  const formatoMoneda = (valor) =>
    new Intl.NumberFormat('es-CO', {
      style: 'currency',
      currency: 'COP',
      maximumFractionDigits: 0,
    }).format(Number(valor || 0))

  // Actualizar cantidades de productos
  function cambiarCantidad(idProducto, valor) {
    setCantidades((anterior) => ({
      ...anterior,
      [idProducto]: valor,
    }))
  }

  // Calcular total de la venta
  const totalVenta = productos.reduce((total, producto) => {
    const cantidad = Number(cantidades[producto.id_producto] || 0)
    return total + cantidad * Number(producto.precio)
  }, 0)

  // Abrir formulario
  function nuevaVenta() {
    setIdPropuesta('')
    setCantidades({})
    setError('')
    setMensaje('')
    setMostrarFormulario(true)
  }

  // Registrar venta
  async function guardarVenta(evento) {
    evento.preventDefault()

    const productosSeleccionados = productos
      .filter((producto) => Number(cantidades[producto.id_producto]) > 0)
      .map((producto) => ({
        id_producto: producto.id_producto,
        cantidad: Number(cantidades[producto.id_producto]),
      }))

    if (!idPropuesta) {
      setError('Debes seleccionar una propuesta.')
      return
    }

    if (productosSeleccionados.length === 0) {
      setError('Debes seleccionar al menos un producto.')
      return
    }

    try {
      setGuardando(true)
      setError('')
      setMensaje('')

      const respuesta = await crearVenta({
        id_propuesta: Number(idPropuesta),
        productos: productosSeleccionados,
      })

      setMensaje(
        respuesta.mensaje || 'Venta registrada correctamente.',
      )

      setMostrarFormulario(false)
      setIdPropuesta('')
      setCantidades({})

      await cargarDatos()
    } catch (err) {
      setError(err.message)
    } finally {
      setGuardando(false)
    }
  }

  // Filtrar ventas
  const ventasFiltradas = ventas.filter((venta) => {
    const texto = busqueda.toLowerCase()

    return (
      String(venta.id_venta).includes(texto) ||
      (venta.cliente_nombre || '').toLowerCase().includes(texto) ||
      (venta.vendedor_nombre || '').toLowerCase().includes(texto) ||
      String(venta.id_propuesta || '').includes(texto)
    )
  })

  // Indicadores
  const valorTotal = ventas.reduce(
    (total, venta) => total + Number(venta.total || 0),
    0,
  )

  const ventasPendientes = ventas.filter(
    (venta) => venta.estado === 'pendiente',
  ).length

  return (
    <>
      <header className="encabezado">
        <div>
          <span className="ruta">Gestión comercial / Ventas</span>
          <h1>Ventas</h1>
          <p>Administra las ventas y los productos comercializados.</p>
        </div>

        <button
          className="boton-principal"
          onClick={nuevaVenta}
        >
          + Registrar venta
        </button>
      </header>

      <section className="indicadores">
        <article className="indicador">
          <span>Total de ventas</span>
          <strong>{ventas.length}</strong>
          <small>Registros encontrados</small>
        </article>

        <article className="indicador">
          <span>Ventas pendientes</span>
          <strong>{ventasPendientes}</strong>
          <small>Por gestionar</small>
        </article>

        <article className="indicador">
          <span>Valor total vendido</span>
          <strong>{formatoMoneda(valorTotal)}</strong>
          <small>Valor acumulado de ventas</small>
        </article>
      </section>

      {mostrarFormulario && (
        <section className="formulario-contenedor">
          <div className="formulario-titulo">
            <div>
              <h2>Registrar nueva venta</h2>
              <p>Selecciona una propuesta y los productos vendidos.</p>
            </div>

            <button
              type="button"
              className="boton-cerrar"
              onClick={() => setMostrarFormulario(false)}
            >
              ×
            </button>
          </div>

          <form onSubmit={guardarVenta}>
            <div className="campos-grid">
              <label className="campo-completo">
                Propuesta aceptada *
                <select
                  value={idPropuesta}
                  onChange={(evento) => setIdPropuesta(evento.target.value)}
                  required
                >
                  <option value="">Selecciona una propuesta</option>

                  {propuestas.map((propuesta) => (
                    <option
                      key={propuesta.id_propuesta}
                      value={propuesta.id_propuesta}
                    >
                      Propuesta #{propuesta.id_propuesta} -{' '}
                      {propuesta.titulo || propuesta.oportunidad_titulo ||
                        propuesta.cliente_nombre}
                    </option>
                  ))}
                </select>
              </label>
            </div>

            <h3>Productos disponibles</h3>

            {productos.length === 0 ? (
              <p>No hay productos disponibles en inventario.</p>
            ) : (
              <div className="tabla-scroll">
                <table>
                  <thead>
                    <tr>
                      <th>Producto</th>
                      <th>Precio</th>
                      <th>Existencias</th>
                      <th>Cantidad</th>
                      <th>Subtotal</th>
                    </tr>
                  </thead>

                  <tbody>
                    {productos.map((producto) => {
                      const cantidad = Number(
                        cantidades[producto.id_producto] || 0,
                      )

                      return (
                        <tr key={producto.id_producto}>
                          <td>
                            <strong>{producto.nombre}</strong>
                          </td>
                          <td>{formatoMoneda(producto.precio)}</td>
                          <td>{producto.stock}</td>
                          <td>
                            <input
                              type="number"
                              min="0"
                              max={producto.stock}
                              step="1"
                              value={cantidades[producto.id_producto] || ''}
                              onChange={(evento) =>
                                cambiarCantidad(
                                  producto.id_producto,
                                  evento.target.value,
                                )
                              }
                              placeholder="0"
                            />
                          </td>
                          <td>
                            {formatoMoneda(cantidad * Number(producto.precio))}
                          </td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            )}

            <div className="acciones-formulario">
              <h3>Total de la venta: {formatoMoneda(totalVenta)}</h3>

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
                disabled={guardando || productos.length === 0}
              >
                {guardando ? 'Registrando...' : 'Registrar venta'}
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
            <h2>Listado de ventas</h2>
            <p>Consulta las ventas registradas en MySQL.</p>
          </div>

          <input
            className="buscador"
            value={busqueda}
            onChange={(evento) => setBusqueda(evento.target.value)}
            placeholder="Buscar venta..."
          />
        </div>

        {cargando ? (
          <p className="estado-carga">Cargando ventas...</p>
        ) : (
          <div className="tabla-scroll">
            <table>
              <thead>
                <tr>
                  <th>N.º venta</th>
                  <th>Cliente</th>
                  <th>Vendedor</th>
                  <th>Propuesta</th>
                  <th>Fecha</th>
                  <th>Total</th>
                  <th>Estado</th>
                </tr>
              </thead>

              <tbody>
                {ventasFiltradas.map((venta) => (
                  <tr key={venta.id_venta}>
                    <td>#{venta.id_venta}</td>
                    <td>{venta.cliente_nombre || 'Sin cliente'}</td>
                    <td>{venta.vendedor_nombre || 'Sin asignar'}</td>
                    <td>
                      {venta.id_propuesta
                        ? `#${venta.id_propuesta}`
                        : 'Sin propuesta'}
                    </td>
                    <td>
                      {venta.fecha
                        ? new Date(venta.fecha).toLocaleDateString('es-CO')
                        : 'Sin fecha'}
                    </td>
                    <td>{formatoMoneda(venta.total)}</td>
                    <td>
                      <span
                        className={
                          venta.estado === 'pagada'
                            ? 'estado-activo'
                            : venta.estado === 'cancelada'
                              ? 'estado-inactivo'
                              : 'estado-pendiente'
                        }
                      >
                        {venta.estado}
                      </span>
                    </td>
                  </tr>
                ))}

                {ventasFiltradas.length === 0 && (
                  <tr>
                    <td colSpan="7" className="sin-resultados">
                      No se encontraron ventas.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        )}

        <div className="tabla-pie">
          Mostrando {ventasFiltradas.length} de {ventas.length} ventas

          <button className="boton-recargar" onClick={cargarDatos}>
            Actualizar listado
          </button>
        </div>
      </section>
    </>
  )
}

export default VistaVentas
