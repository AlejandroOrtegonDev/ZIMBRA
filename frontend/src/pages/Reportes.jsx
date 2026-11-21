// Reportes: procedimiento sp_reporte_ventas_mensual, vistas de campañas
// y cartera, auditoría y simulación de errores con ROLLBACK (admin)

import { useEffect, useState } from 'react'
import {
  obtenerAniosReporte, obtenerReporteMensual, obtenerCampanas, obtenerCartera,
  obtenerAuditoria, simularError, tienePermiso,
} from '../services/api'
import { BarrasHorizontales, Indicador, TablaDatos } from '../components/Graficos'
import { formatoCompacto, formatoFecha, formatoNumero, formatoPesos, MESES, formatoPorcentaje } from '../utils/formato'
import './modulos.css'

function ReporteMensual() {
  const [anios, setAnios] = useState([])
  const [anio, setAnio] = useState('')
  const [mes, setMes] = useState(new Date().getMonth() + 1)
  const [reporte, setReporte] = useState(null)
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(false)

  useEffect(() => {
    obtenerAniosReporte()
      .then((r) => { setAnios(r.anios); setAnio(r.anios[0] ?? new Date().getFullYear()) })
      .catch((err) => setError(err.message))
  }, [])

  async function generar() {
    setError('')
    try {
      setCargando(true)
      setReporte(await obtenerReporteMensual(anio, mes))
    } catch (err) {
      setError(err.message)
    } finally {
      setCargando(false)
    }
  }

  const r = reporte?.resumen
  const variacion = r?.variacion_pct

  return (
    <section className="panel">
      <div className="detalle-cabecera">
        <div>
          <h2>Reporte mensual de ventas</h2>
          <p className="panel-subtitulo">Ejecuta el procedimiento almacenado sp_reporte_ventas_mensual y queda registrado en reportes_generados.</p>
        </div>
        <div className="filtros no-imprimir">
          <select value={mes} onChange={(e) => setMes(Number(e.target.value))} aria-label="Mes">
            {MESES.map((m, i) => <option key={m} value={i + 1}>{m}</option>)}
          </select>
          <select value={anio} onChange={(e) => setAnio(Number(e.target.value))} aria-label="Año">
            {anios.map((a) => <option key={a} value={a}>{a}</option>)}
          </select>
          <button className="boton-principal" onClick={generar} disabled={cargando || !anio}>
            {cargando ? 'Generando...' : 'Generar'}
          </button>
          {reporte && <button className="boton-secundario" onClick={() => window.print()}>Imprimir</button>}
        </div>
      </div>

      {error && <div className="mensaje-error">{error}</div>}

      {r && (
        <>
          <section className="indicadores indicadores-4">
            <Indicador principal etiqueta={`Vendido en ${r.mes_nombre} ${r.anio}`} valor={formatoCompacto(r.total_vendido)} detalle={formatoPesos(r.total_vendido)} />
            <Indicador etiqueta="Ventas" valor={formatoNumero(r.ventas)} detalle={`${r.pagadas} pagadas · ${r.pendientes} pendientes · ${r.canceladas} canceladas`} />
            <Indicador etiqueta="Recaudado" valor={formatoCompacto(r.total_recaudado)} detalle={`Por cobrar: ${formatoCompacto(r.cartera_pendiente)}`} />
            <Indicador
              etiqueta="Frente al mes anterior"
              valor={variacion === null ? 'Sin datos' : `${variacion > 0 ? '▲ +' : variacion < 0 ? '▼ ' : ''}${formatoPorcentaje(variacion)}`}
              detalle={`Mes anterior: ${formatoCompacto(r.total_mes_anterior)}`}
            />
          </section>

          <div className="rejilla-2">
            <div>
              <h3 style={{ fontSize: 14 }}>Vendedores del mes</h3>
              <div className="tabla-scroll">
                <table>
                  <thead>
                    <tr><th>Vendedor</th><th className="numero">Ventas</th><th className="numero">Vendido</th><th className="numero">Comisión</th><th className="numero">Conversión</th></tr>
                  </thead>
                  <tbody>
                    {reporte.vendedores.map((v) => (
                      <tr key={v.id_vendedor}>
                        <td><strong>{v.vendedor}</strong> <span className="ruta">{v.codigo}</span></td>
                        <td className="numero">{v.ventas}</td>
                        <td className="numero">{formatoPesos(v.total_vendido)}</td>
                        <td className="numero">{formatoPesos(v.comision)}</td>
                        <td className="numero">{formatoPorcentaje(v.tasa_conversion)}</td>
                      </tr>
                    ))}
                    {reporte.vendedores.length === 0 && <tr><td colSpan="5" className="sin-resultados">Sin ventas en el mes.</td></tr>}
                  </tbody>
                </table>
              </div>
              <p className="nota">Comisión: fn_comision_vendedor (5 % de ventas pagadas). Conversión: fn_tasa_conversion.</p>
            </div>

            <div>
              <h3 style={{ fontSize: 14 }}>Productos más vendidos</h3>
              {reporte.productos.length > 0 ? (
                <>
                  <BarrasHorizontales
                    datos={reporte.productos.map((p) => ({ etiqueta: p.producto, valor: p.total, unidades: p.unidades }))}
                    formatoValor={formatoCompacto}
                    formatoDetalle={(d) => `${formatoNumero(d.unidades)} unidades · ${formatoPesos(d.valor)}`}
                  />
                  <TablaDatos
                    columnas={['Producto', 'Unidades', 'Total']}
                    filas={reporte.productos.map((p) => [p.producto, formatoNumero(p.unidades), formatoPesos(p.total)])}
                  />
                </>
              ) : <p className="sin-resultados">Sin productos vendidos en el mes.</p>}
            </div>
          </div>
        </>
      )}
      {!reporte && !error && <p className="nota">Elija el mes y pulse Generar.</p>}
    </section>
  )
}

function Campanas() {
  const [campanas, setCampanas] = useState([])
  const [error, setError] = useState('')

  useEffect(() => {
    obtenerCampanas().then((r) => setCampanas(r.campanas)).catch((err) => setError(err.message))
  }, [])

  return (
    <section className="tabla-contenedor" style={{ marginBottom: 24 }}>
      <div className="tabla-encabezado">
        <div>
          <h2>Efectividad de campañas</h2>
          <p>Vista vw_efectividad_campanas: alcance, interacciones y clientes que compraron después de iniciar la campaña.</p>
        </div>
      </div>
      {error && <div className="mensaje-error">{error}</div>}
      <div className="tabla-scroll">
        <table>
          <thead>
            <tr>
              <th>Campaña</th><th>Estado</th><th>Inicio</th>
              <th className="numero">Presupuesto</th><th className="numero">Clientes</th><th className="numero">Interacciones</th>
              <th className="numero">Con compra</th><th className="numero">Costo / interacción</th>
            </tr>
          </thead>
          <tbody>
            {campanas.map((c) => (
              <tr key={c.id_campana}>
                <td><strong>{c.nombre}</strong></td>
                <td><span className={`etiqueta-estado ${c.estado === 'activa' ? 'enviada' : c.estado === 'finalizada' ? 'aceptada' : c.estado === 'cancelada' ? 'cancelada' : 'borrador'}`}>{c.estado}</span></td>
                <td>{formatoFecha(c.fecha_inicio)}</td>
                <td className="numero">{formatoPesos(c.presupuesto)}</td>
                <td className="numero">{c.clientes_impactados}</td>
                <td className="numero">{c.interacciones}</td>
                <td className="numero">{c.clientes_con_compra}</td>
                <td className="numero">{c.costo_por_interaccion === null ? '—' : formatoPesos(c.costo_por_interaccion)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  )
}

function Cartera() {
  const [cartera, setCartera] = useState([])

  useEffect(() => {
    obtenerCartera().then((r) => setCartera(r.cartera)).catch(() => {})
  }, [])

  const total = cartera.reduce((s, c) => s + Number(c.por_recaudar), 0)

  return (
    <section className="tabla-contenedor" style={{ marginBottom: 24 }}>
      <div className="tabla-encabezado">
        <div>
          <h2>Cartera por cobrar</h2>
          <p>Vista vw_cartera_pendiente · {cartera.length} ventas · {formatoPesos(total)} por recaudar.</p>
        </div>
      </div>
      <div className="tabla-scroll">
        <table>
          <thead>
            <tr><th>Venta</th><th>Fecha</th><th>Cliente</th><th>Vendedor</th><th className="numero">Total</th><th className="numero">Pagado</th><th className="numero">Por cobrar</th><th className="numero">Días</th></tr>
          </thead>
          <tbody>
            {cartera.map((c) => (
              <tr key={c.id_venta}>
                <td>#{c.id_venta}</td>
                <td>{formatoFecha(c.fecha)}</td>
                <td><strong>{c.cliente}</strong></td>
                <td>{c.vendedor ?? '—'}</td>
                <td className="numero">{formatoPesos(c.total)}</td>
                <td className="numero">{formatoPesos(c.pagado)}</td>
                <td className="numero"><strong>{formatoPesos(c.por_recaudar)}</strong></td>
                <td className="numero">{c.dias_desde_venta}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  )
}

const SIMULACIONES = [
  ['llave_foranea', 'Llave foránea'],
  ['duplicado', 'Documento duplicado'],
  ['restriccion', 'Restricción CHECK'],
  ['stock', 'Stock insuficiente'],
  ['sobrepago', 'Pago mayor al saldo'],
  ['propuesta_rechazada', 'Vender propuesta rechazada'],
]

function BaseDeDatos() {
  const [resultado, setResultado] = useState(null)
  const [auditoria, setAuditoria] = useState([])
  const [error, setError] = useState('')
  const [ocupado, setOcupado] = useState(false)

  const cargarAuditoria = () => obtenerAuditoria().then((r) => setAuditoria(r.auditoria)).catch((err) => setError(err.message))
  useEffect(() => { cargarAuditoria() }, [])

  async function simular(tipo) {
    setError('')
    try {
      setOcupado(true)
      const r = await simularError(tipo)
      setResultado(r.resultado)
      cargarAuditoria()
    } catch (err) {
      setError(err.message)
    } finally {
      setOcupado(false)
    }
  }

  return (
    <div>
      <section className="panel">
        <h2>Simulación de errores y recuperación</h2>
        <p className="panel-subtitulo">
          Procedimiento sp_simular_error: abre una transacción, registra un cliente temporal y provoca el error elegido.
          El manejador captura el error, hace ROLLBACK y compara los conteos.
        </p>
        <div className="botones-simulacion">
          {SIMULACIONES.map(([tipo, texto]) => (
            <button key={tipo} className="boton-secundario" disabled={ocupado} onClick={() => simular(tipo)}>{texto}</button>
          ))}
        </div>
        {error && <div className="mensaje-error" style={{ marginTop: 14 }}>{error}</div>}
        {resultado && (
          <div className="resultado-simulacion">
            <strong>{resultado.resultado}</strong><br />
            Error MySQL {resultado.codigo_error}: {resultado.error_capturado}<br />
            Clientes: {resultado.clientes_antes} → {resultado.clientes_despues} ·
            Ventas: {resultado.ventas_antes} → {resultado.ventas_despues} ·
            Pagos: {resultado.pagos_antes} → {resultado.pagos_despues}
          </div>
        )}
      </section>

      <section className="panel">
        <h2>Auditoría reciente</h2>
        <p className="panel-subtitulo">Registrada por los triggers; el autor sale de @usuario_actual que fija el backend.</p>
        <div className="tabla-scroll" style={{ maxHeight: 360, overflowY: 'auto' }}>
          <table>
            <thead><tr><th>Fecha</th><th>Usuario</th><th>Tabla</th><th>Operación</th><th>Descripción</th></tr></thead>
            <tbody>
              {auditoria.map((a) => (
                <tr key={a.id_auditoria}>
                  <td>{formatoFecha(a.fecha, true)}</td>
                  <td>{a.usuario ?? 'Sistema'}</td>
                  <td>{a.tabla_afectada}</td>
                  <td>{a.operacion}</td>
                  <td>{a.descripcion}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  )
}

export default function Reportes() {
  return (
    <>
      <header className="encabezado">
        <div>
          <span className="ruta">Gestión comercial / Reportes</span>
          <h1>Reportes</h1>
          <p>Reportes construidos con procedimientos almacenados y vistas de la base de datos.</p>
        </div>
      </header>

      <ReporteMensual />
      <Campanas />
      <Cartera />
      {tienePermiso('auditoria.ver') && <BaseDeDatos />}
    </>
  )
}
