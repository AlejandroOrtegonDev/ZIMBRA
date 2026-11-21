// Tablero principal: indicadores y gráficos a partir de las vistas de la BD

import { useEffect, useState } from 'react'
import { obtenerAniosReporte, obtenerDashboard } from '../services/api'
import { ColumnasAgrupadas, BarrasHorizontales, Indicador, TablaDatos } from '../components/Graficos'
import { SERIES } from '../utils/colores'
import { formatoCompacto, formatoNumero, formatoPesos, MESES, MESES_CORTOS, formatoPorcentaje } from '../utils/formato'
import './modulos.css'

export default function Dashboard() {
  const [anios, setAnios] = useState([])
  const [anio, setAnio] = useState(null)
  const [datos, setDatos] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    obtenerAniosReporte()
      .then((r) => {
        setAnios(r.anios)
        setAnio(r.anios[0] ?? new Date().getFullYear())
      })
      .catch((err) => setError(err.message))
  }, [])

  useEffect(() => {
    if (!anio) return
    let cancelado = false
    obtenerDashboard(anio)
      .then((r) => { if (!cancelado) setDatos(r) })
      .catch((err) => { if (!cancelado) setError(err.message) })
    return () => { cancelado = true }
  }, [anio])

  const ind = datos?.indicadores

  // Doce meses aunque alguno no tenga ventas
  const meses = MESES_CORTOS.map((corto, i) => {
    const fila = datos?.ventasMensuales.find((v) => v.mes === i + 1)
    return {
      etiqueta: corto,
      detalle: `${MESES[i]} ${anio}`,
      valores: [Number(fila?.total_vendido ?? 0), Number(fila?.total_recaudado ?? 0)],
      ventas: fila?.ventas ?? 0,
    }
  })

  return (
    <>
      <header className="encabezado">
        <div>
          <span className="ruta">Gestión comercial / Tablero</span>
          <h1>Tablero comercial</h1>
          <p>Indicadores calculados con las vistas y funciones de la base de datos.</p>
        </div>
        <div className="filtros">
          <label htmlFor="anio-tablero" className="ruta">Año</label>
          <select id="anio-tablero" value={anio ?? ''} onChange={(e) => setAnio(Number(e.target.value))}>
            {anios.map((a) => <option key={a} value={a}>{a}</option>)}
          </select>
        </div>
      </header>

      {error && <div className="mensaje-error">{error}</div>}
      {!datos && !error && <p className="estado-carga">Cargando indicadores...</p>}

      {datos && (
        <>
          <section className="indicadores indicadores-4">
            <Indicador principal etiqueta="Total vendido" valor={formatoCompacto(ind.total_vendido)} detalle={formatoPesos(ind.total_vendido)} />
            <Indicador etiqueta="Recaudado" valor={formatoCompacto(ind.total_recaudado)} detalle="Pagos aprobados" />
            <Indicador etiqueta="Cartera por cobrar" valor={formatoCompacto(ind.cartera_pendiente)} detalle="Ventas pendientes" />
            <Indicador etiqueta="Tasa de conversión" valor={`${formatoPorcentaje(ind.tasa_conversion ?? 0)}`} detalle="Oportunidades ganadas / cerradas" />
          </section>

          <section className="indicadores indicadores-4">
            <Indicador etiqueta="Clientes activos" valor={formatoNumero(ind.clientes_activos)} />
            <Indicador etiqueta="Prospectos" valor={formatoNumero(ind.prospectos)} detalle={`${ind.potenciales} marcados como potenciales`} />
            <Indicador etiqueta="Oportunidades abiertas" valor={formatoNumero(ind.oportunidades_abiertas)} detalle={`${formatoCompacto(ind.valor_en_embudo)} en el embudo`} />
            <Indicador etiqueta="Propuestas abiertas" valor={formatoNumero(ind.propuestas_abiertas)} detalle="Borradores y enviadas" />
          </section>

          <section className="panel">
            <h2>Ventas por mes · {anio}</h2>
            <p className="panel-subtitulo">Facturado frente a recaudado (vista vw_ventas_mensuales). Pase el cursor sobre un mes para ver el detalle.</p>
            <ColumnasAgrupadas
              titulo={`Ventas por mes ${anio}`}
              datos={meses}
              series={[{ nombre: 'Facturado', color: SERIES[0] }, { nombre: 'Recaudado', color: SERIES[1] }]}
              formatoEje={formatoCompacto}
              formatoValor={formatoPesos}
            />
            <TablaDatos
              columnas={['Mes', 'Ventas', 'Facturado', 'Recaudado']}
              filas={meses.map((m) => [m.detalle, m.ventas, formatoPesos(m.valores[0]), formatoPesos(m.valores[1])])}
            />
          </section>

          <section className="rejilla-2">
            <div className="panel">
              <h2>Embudo de oportunidades</h2>
              <p className="panel-subtitulo">Oportunidades por etapa (vista vw_embudo_oportunidades).</p>
              <BarrasHorizontales
                datos={datos.embudo.map((e) => ({ etiqueta: e.etapa, valor: e.oportunidades, monto: e.valor_total }))}
                formatoValor={formatoNumero}
                formatoDetalle={(d) => `Valor: ${formatoPesos(d.monto)}`}
              />
              <TablaDatos
                columnas={['Etapa', 'Oportunidades', 'Valor']}
                filas={datos.embudo.map((e) => [e.etapa, e.oportunidades, formatoPesos(e.valor_total)])}
              />
            </div>

            <div className="panel">
              <h2>Vendedores con más ventas</h2>
              <p className="panel-subtitulo">Total vendido (vista vw_desempeno_vendedores + fn_tasa_conversion).</p>
              <BarrasHorizontales
                datos={datos.vendedores.map((v) => ({ etiqueta: v.vendedor, valor: v.total_vendido, tasa: v.tasa_conversion, recaudado: v.total_recaudado }))}
                formatoValor={formatoCompacto}
                formatoDetalle={(d) => `Conversión ${formatoPorcentaje(d.tasa)} · recaudado ${formatoCompacto(d.recaudado)}`}
              />
              <TablaDatos
                columnas={['Vendedor', 'Vendido', 'Recaudado', 'Conversión']}
                filas={datos.vendedores.map((v) => [v.vendedor, formatoPesos(v.total_vendido), formatoPesos(v.total_recaudado), `${formatoPorcentaje(v.tasa_conversion)}`])}
              />
            </div>
          </section>

          <section className="tabla-contenedor">
            <div className="tabla-encabezado">
              <div>
                <h2>Cartera por cobrar</h2>
                <p>Ventas pendientes con mayor saldo (vista vw_cartera_pendiente).</p>
              </div>
            </div>
            <div className="tabla-scroll">
              <table>
                <thead>
                  <tr>
                    <th>Venta</th><th>Cliente</th><th>Vendedor</th>
                    <th className="numero">Total</th><th className="numero">Pagado</th><th className="numero">Por cobrar</th><th className="numero">Días</th>
                  </tr>
                </thead>
                <tbody>
                  {datos.cartera.map((c) => (
                    <tr key={c.id_venta}>
                      <td>#{c.id_venta}</td>
                      <td><strong>{c.cliente}</strong></td>
                      <td>{c.vendedor ?? '—'}</td>
                      <td className="numero">{formatoPesos(c.total)}</td>
                      <td className="numero">{formatoPesos(c.pagado)}</td>
                      <td className="numero"><strong>{formatoPesos(c.por_recaudar)}</strong></td>
                      <td className="numero">{c.dias_desde_venta}</td>
                    </tr>
                  ))}
                  {datos.cartera.length === 0 && (
                    <tr><td colSpan="7" className="sin-resultados">No hay cartera pendiente.</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </section>
        </>
      )}
    </>
  )
}
