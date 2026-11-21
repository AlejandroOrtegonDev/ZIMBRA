// Ventas y pagos
// - Registrar pago: procedimiento procesar_pago_venta (transacción + FOR UPDATE)
// - Aprobar/rechazar pago pendiente: trigger recalcula el estado de la venta
// - Cancelar: trigger valida que no haya pagos aprobados y devuelve el stock

import { useCallback, useEffect, useMemo, useState } from 'react'
import { obtenerVentas, obtenerVenta, registrarPago, cambiarEstadoPago, cancelarVenta, tienePermiso } from '../services/api'
import { Indicador } from '../components/Graficos'
import { formatoCompacto, formatoFecha, formatoPesos } from '../utils/formato'
import './modulos.css'

function DetalleVenta({ id, onCambio, onCerrar }) {
  const [venta, setVenta] = useState(null)
  const [pago, setPago] = useState({ metodo_pago: 'transferencia', valor: '' })
  const [error, setError] = useState('')
  const [mensaje, setMensaje] = useState('')
  const [ocupado, setOcupado] = useState(false)

  useEffect(() => {
    obtenerVenta(id).then((r) => setVenta(r.venta)).catch((err) => setError(err.message))
  }, [id])

  async function ejecutar(accion) {
    setError('')
    setMensaje('')
    try {
      setOcupado(true)
      const r = await accion()
      setMensaje(r.mensaje)
      setVenta(r.venta)
      setPago((p) => ({ ...p, valor: '' }))
      onCambio()
    } catch (err) {
      setError(err.message)
    } finally {
      setOcupado(false)
    }
  }

  if (!venta) return error ? <div className="mensaje-error">{error}</div> : <p className="estado-carga">Cargando venta...</p>

  const puedePagar = tienePermiso('pagos.registrar')
  const aprobado = venta.pagos.filter((p) => p.estado === 'aprobado').reduce((s, p) => s + Number(p.valor), 0)

  return (
    <section className="panel">
      <div className="detalle-cabecera">
        <div>
          <span className="ruta">Venta #{venta.id_venta} · {formatoFecha(venta.fecha, true)}</span>
          <h2>{venta.cliente}</h2>
          <p className="panel-subtitulo">
            Vendedor: {venta.vendedor ?? '—'}
            {venta.id_propuesta ? ` · Generada desde la propuesta #${venta.id_propuesta}` : ' · Venta directa'}
          </p>
        </div>
        <button className="boton-cerrar" type="button" onClick={onCerrar} aria-label="Cerrar">×</button>
      </div>

      {mensaje && <div className="mensaje-exito">{mensaje}</div>}
      {error && <div className="mensaje-error">{error}</div>}

      <dl className="detalle-datos">
        <div><dt>Estado</dt><dd><span className={`etiqueta-estado ${venta.estado}`}>{venta.estado}</span></dd></div>
        <div><dt>Total</dt><dd>{formatoPesos(venta.total)}</dd></div>
        <div><dt>Pagado (fn_total_pagado)</dt><dd>{formatoPesos(venta.pagado)}</dd></div>
        <div><dt>Saldo cobrable (fn_saldo_venta)</dt><dd>{formatoPesos(venta.saldo)}</dd></div>
      </dl>

      <div className="rejilla-2" style={{ marginBottom: 0 }}>
        <div>
          <h3 style={{ fontSize: 14 }}>Productos</h3>
          <div className="tabla-scroll">
            <table>
              <thead><tr><th>Producto</th><th className="numero">Cant.</th><th className="numero">Subtotal</th></tr></thead>
              <tbody>
                {venta.productos.map((p) => (
                  <tr key={p.id_detalle}>
                    <td>{p.producto}</td>
                    <td className="numero">{p.cantidad}</td>
                    <td className="numero">{formatoPesos(p.subtotal)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div>
          <h3 style={{ fontSize: 14 }}>Pagos</h3>
          <div className="tabla-scroll">
            <table>
              <thead><tr><th>Fecha</th><th>Método</th><th className="numero">Valor</th><th>Estado</th><th></th></tr></thead>
              <tbody>
                {venta.pagos.map((p) => (
                  <tr key={p.id_pago}>
                    <td>{formatoFecha(p.fecha)}</td>
                    <td>{p.metodo_pago}</td>
                    <td className="numero">{formatoPesos(p.valor)}</td>
                    <td><span className={`etiqueta-estado ${p.estado}`}>{p.estado}</span></td>
                    <td>
                      {puedePagar && p.estado === 'pendiente' && (
                        <div className="acciones-tabla">
                          <button className="boton-editar" disabled={ocupado}
                            onClick={() => ejecutar(() => cambiarEstadoPago(p.id_pago, 'aprobado'))}>Aprobar</button>
                          <button className="boton-desactivar" disabled={ocupado}
                            onClick={() => ejecutar(() => cambiarEstadoPago(p.id_pago, 'rechazado'))}>Rechazar</button>
                        </div>
                      )}
                    </td>
                  </tr>
                ))}
                {venta.pagos.length === 0 && <tr><td colSpan="5" className="sin-resultados">Sin pagos registrados.</td></tr>}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {puedePagar && venta.estado === 'pendiente' && (
        <form className="formulario-contenedor" style={{ marginTop: 20, marginBottom: 0 }}
          onSubmit={(e) => { e.preventDefault(); ejecutar(() => registrarPago(id, { metodo_pago: pago.metodo_pago, valor: pago.valor || null })) }}>
          <div className="formulario-titulo">
            <div>
              <h2>Registrar pago</h2>
              <p>Lo procesa el procedimiento procesar_pago_venta: bloquea la venta, valida el saldo y confirma o deshace todo.</p>
            </div>
          </div>
          <div className="campos-grid">
            <label>
              Método de pago
              <select value={pago.metodo_pago} onChange={(e) => setPago({ ...pago, metodo_pago: e.target.value })}>
                <option value="transferencia">Transferencia</option>
                <option value="tarjeta">Tarjeta</option>
                <option value="pse">PSE</option>
                <option value="efectivo">Efectivo</option>
              </select>
            </label>
            <label>
              Valor (vacío = todo el saldo de {formatoPesos(venta.saldo)})
              <input type="number" min="1" step="1" value={pago.valor} onChange={(e) => setPago({ ...pago, valor: e.target.value })} />
            </label>
          </div>
          <div className="acciones-formulario">
            {tienePermiso('ventas.registrar') && aprobado === 0 && (
              <button type="button" className="boton-peligro" disabled={ocupado}
                onClick={() => window.confirm('¿Cancelar la venta? Los productos vuelven al inventario.') && ejecutar(() => cancelarVenta(id))}>
                Cancelar venta
              </button>
            )}
            <button type="submit" className="boton-principal" disabled={ocupado || Number(venta.saldo) <= 0}>
              {ocupado ? 'Procesando...' : 'Registrar pago'}
            </button>
          </div>
          {Number(venta.saldo) <= 0 && (
            <p className="nota">No hay saldo cobrable: hay pagos pendientes de aprobación que cubren el total.</p>
          )}
        </form>
      )}
    </section>
  )
}

export default function Ventas() {
  const [ventas, setVentas] = useState([])
  const [estado, setEstado] = useState('')
  const [busqueda, setBusqueda] = useState('')
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [seleccionada, setSeleccionada] = useState(null)

  const cargar = useCallback(async () => {
    try {
      setError('')
      const r = await obtenerVentas(estado)
      setVentas(r.ventas)
    } catch (err) {
      setError(err.message)
    } finally {
      setCargando(false)
    }
  }, [estado])

  useEffect(() => {
    let cancelado = false
    obtenerVentas(estado)
      .then((r) => { if (!cancelado) setVentas(r.ventas) })
      .catch((err) => { if (!cancelado) setError(err.message) })
      .finally(() => { if (!cancelado) setCargando(false) })
    return () => { cancelado = true }
  }, [estado])

  const filtradas = useMemo(() => {
    const texto = busqueda.toLowerCase()
    return ventas.filter((v) => [v.cliente, v.vendedor, String(v.id_venta)].some((x) => (x ?? '').toLowerCase().includes(texto)))
  }, [ventas, busqueda])

  const activas = ventas.filter((v) => v.estado !== 'cancelada')
  const totalVendido = activas.reduce((s, v) => s + Number(v.total), 0)
  const totalPagado = activas.reduce((s, v) => s + Number(v.pagado), 0)

  return (
    <>
      <header className="encabezado">
        <div>
          <span className="ruta">Gestión comercial / Ventas</span>
          <h1>Ventas y pagos</h1>
          <p>Ventas registradas, su recaudo y el saldo por cobrar.</p>
        </div>
      </header>

      <section className="indicadores">
        <Indicador etiqueta="Vendido (lista actual)" valor={formatoCompacto(totalVendido)} detalle={`${activas.length} ventas no canceladas`} />
        <Indicador etiqueta="Recaudado" valor={formatoCompacto(totalPagado)} detalle="Pagos aprobados" />
        <Indicador etiqueta="Por cobrar" valor={formatoCompacto(totalVendido - totalPagado)} detalle={`${ventas.filter((v) => v.estado === 'pendiente').length} ventas pendientes`} />
      </section>

      {error && <div className="mensaje-error">{error}</div>}

      {seleccionada && (
        <DetalleVenta key={seleccionada} id={seleccionada} onCambio={cargar} onCerrar={() => setSeleccionada(null)} />
      )}

      <section className="tabla-contenedor">
        <div className="tabla-encabezado">
          <div>
            <h2>Listado de ventas</h2>
            <p>Seleccione una venta para registrar pagos. Las ventas desde propuestas se crean en el módulo Propuestas.</p>
          </div>
          <div className="filtros">
            <select value={estado} onChange={(e) => setEstado(e.target.value)} aria-label="Filtrar por estado">
              <option value="">Todos los estados</option>
              <option value="pendiente">Pendiente</option>
              <option value="pagada">Pagada</option>
              <option value="cancelada">Cancelada</option>
            </select>
            <input className="buscador" value={busqueda} onChange={(e) => setBusqueda(e.target.value)} placeholder="Buscar..." />
          </div>
        </div>

        {cargando ? <p className="estado-carga">Cargando ventas...</p> : (
          <div className="tabla-scroll">
            <table>
              <thead>
                <tr>
                  <th>#</th><th>Fecha</th><th>Cliente</th><th>Vendedor</th>
                  <th className="numero">Total</th><th className="numero">Pagado</th><th className="numero">Saldo</th><th>Estado</th>
                </tr>
              </thead>
              <tbody>
                {filtradas.map((v) => (
                  <tr key={v.id_venta}
                    className={`clicable ${seleccionada === v.id_venta ? 'fila-seleccionada' : ''}`}
                    onClick={() => setSeleccionada(v.id_venta)}>
                    <td>{v.id_venta}</td>
                    <td>{formatoFecha(v.fecha)}</td>
                    <td><strong>{v.cliente}</strong></td>
                    <td>{v.vendedor ?? '—'}</td>
                    <td className="numero">{formatoPesos(v.total)}</td>
                    <td className="numero">{formatoPesos(v.pagado)}</td>
                    <td className="numero">{formatoPesos(v.saldo)}</td>
                    <td><span className={`etiqueta-estado ${v.estado}`}>{v.estado}</span></td>
                  </tr>
                ))}
                {filtradas.length === 0 && <tr><td colSpan="8" className="sin-resultados">No se encontraron ventas.</td></tr>}
              </tbody>
            </table>
          </div>
        )}
        <div className="tabla-pie">Mostrando {filtradas.length} de {ventas.length} ventas</div>
      </section>
    </>
  )
}
