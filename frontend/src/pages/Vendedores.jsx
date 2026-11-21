// Vendedores: desempeño (vista vw_desempeno_vendedores + fn_tasa_conversion)
// y clientes asignados a cada uno

import { useEffect, useMemo, useState } from 'react'
import { obtenerDesempenoVendedores, obtenerClientesDeVendedor } from '../services/api'
import { BarrasHorizontales, Indicador, TablaDatos } from '../components/Graficos'
import { formatoCompacto, formatoPesos, formatoPorcentaje } from '../utils/formato'
import './modulos.css'

export default function Vendedores() {
  const [vendedores, setVendedores] = useState([])
  const [seleccionado, setSeleccionado] = useState(null)
  const [clientes, setClientes] = useState([])
  const [busqueda, setBusqueda] = useState('')
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(true)

  useEffect(() => {
    obtenerDesempenoVendedores()
      .then((r) => setVendedores(r.vendedores))
      .catch((err) => setError(err.message))
      .finally(() => setCargando(false))
  }, [])

  useEffect(() => {
    if (!seleccionado) return
    obtenerClientesDeVendedor(seleccionado.id_vendedor)
      .then((r) => setClientes(r.clientes))
      .catch((err) => setError(err.message))
  }, [seleccionado])

  const filtrados = useMemo(() => {
    const texto = busqueda.toLowerCase()
    return vendedores.filter((v) => [v.vendedor, v.codigo, v.especialidad].some((x) => (x ?? '').toLowerCase().includes(texto)))
  }, [vendedores, busqueda])

  const activos = vendedores.filter((v) => Number(v.estado) === 1)
  const conCierres = vendedores.filter((v) => v.oportunidades_ganadas + v.oportunidades_perdidas > 0)
  const conversionMedia = conCierres.length
    ? conCierres.reduce((s, v) => s + Number(v.tasa_conversion), 0) / conCierres.length
    : 0

  // Ranking de conversión: solo quienes tienen 2+ oportunidades cerradas
  const ranking = [...conCierres]
    .filter((v) => v.oportunidades_ganadas + v.oportunidades_perdidas >= 2)
    .sort((a, b) => b.tasa_conversion - a.tasa_conversion || b.total_vendido - a.total_vendido)
    .slice(0, 8)

  return (
    <>
      <header className="encabezado">
        <div>
          <span className="ruta">Gestión comercial / Vendedores</span>
          <h1>Vendedores</h1>
          <p>Desempeño del equipo comercial y su cartera de clientes.</p>
        </div>
      </header>

      {error && <div className="mensaje-error">{error}</div>}

      <section className="indicadores">
        <Indicador etiqueta="Vendedores activos" valor={activos.length} detalle={`${vendedores.length - activos.length} retirados`} />
        <Indicador etiqueta="Conversión promedio" valor={`${formatoPorcentaje(conversionMedia)}`} detalle="Entre quienes tienen cierres" />
        <Indicador etiqueta="Total vendido por el equipo" valor={formatoCompacto(vendedores.reduce((s, v) => s + Number(v.total_vendido), 0))} />
      </section>

      {ranking.length > 0 && (
        <section className="panel">
          <h2>Mejor tasa de conversión</h2>
          <p className="panel-subtitulo">Porcentaje de oportunidades cerradas que terminaron ganadas (fn_tasa_conversion). Solo vendedores con 2 o más cierres.</p>
          <BarrasHorizontales
            datos={ranking.map((v) => ({ etiqueta: v.vendedor, valor: Number(v.tasa_conversion), ganadas: v.oportunidades_ganadas, perdidas: v.oportunidades_perdidas }))}
            formatoValor={formatoPorcentaje}
            formatoDetalle={(d) => `${d.ganadas} ganadas · ${d.perdidas} perdidas`}
          />
          <TablaDatos
            columnas={['Vendedor', 'Conversión', 'Ganadas', 'Perdidas']}
            filas={ranking.map((v) => [v.vendedor, `${formatoPorcentaje(v.tasa_conversion)}`, v.oportunidades_ganadas, v.oportunidades_perdidas])}
          />
        </section>
      )}

      {seleccionado && (
        <section className="panel">
          <div className="detalle-cabecera">
            <div>
              <span className="ruta">{seleccionado.codigo}</span>
              <h2>{seleccionado.vendedor}</h2>
              <p className="panel-subtitulo">{seleccionado.especialidad} · {clientes.length} clientes asignados</p>
            </div>
            <button className="boton-cerrar" type="button" onClick={() => setSeleccionado(null)} aria-label="Cerrar">×</button>
          </div>
          <div className="tabla-scroll">
            <table>
              <thead><tr><th>Cliente</th><th>Tipo</th><th>Categorías</th><th>Asignado desde</th></tr></thead>
              <tbody>
                {clientes.map((c) => (
                  <tr key={c.id_cliente}>
                    <td><strong>{c.cliente}</strong></td>
                    <td>{c.tipo_cliente}</td>
                    <td>{c.categorias ?? '—'}</td>
                    <td>{new Date(c.fecha_asignacion).toLocaleDateString('es-CO')}</td>
                  </tr>
                ))}
                {clientes.length === 0 && <tr><td colSpan="4" className="sin-resultados">Sin clientes asignados.</td></tr>}
              </tbody>
            </table>
          </div>
        </section>
      )}

      <section className="tabla-contenedor">
        <div className="tabla-encabezado">
          <div>
            <h2>Desempeño por vendedor</h2>
            <p>Seleccione un vendedor para ver sus clientes.</p>
          </div>
          <input className="buscador" value={busqueda} onChange={(e) => setBusqueda(e.target.value)} placeholder="Buscar vendedor..." />
        </div>
        {cargando ? <p className="estado-carga">Cargando vendedores...</p> : (
          <div className="tabla-scroll">
            <table>
              <thead>
                <tr>
                  <th>Código</th><th>Vendedor</th><th>Estado</th>
                  <th className="numero">Clientes</th><th className="numero">Abiertas</th><th className="numero">Ganadas</th><th className="numero">Perdidas</th>
                  <th className="numero">Conversión</th><th className="numero">Vendido</th><th className="numero">Recaudado</th>
                </tr>
              </thead>
              <tbody>
                {filtrados.map((v) => (
                  <tr key={v.id_vendedor}
                    className={`clicable ${seleccionado?.id_vendedor === v.id_vendedor ? 'fila-seleccionada' : ''}`}
                    onClick={() => setSeleccionado(v)}>
                    <td>{v.codigo}</td>
                    <td><strong>{v.vendedor}</strong></td>
                    <td><span className={Number(v.estado) === 1 ? 'estado-activo' : 'estado-inactivo'}>{Number(v.estado) === 1 ? 'Activo' : 'Retirado'}</span></td>
                    <td className="numero">{v.clientes_asignados}</td>
                    <td className="numero">{v.oportunidades_abiertas}</td>
                    <td className="numero">{v.oportunidades_ganadas}</td>
                    <td className="numero">{v.oportunidades_perdidas}</td>
                    <td className="numero">{formatoPorcentaje(v.tasa_conversion)}</td>
                    <td className="numero">{formatoPesos(v.total_vendido)}</td>
                    <td className="numero">{formatoPesos(v.total_recaudado)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </>
  )
}
