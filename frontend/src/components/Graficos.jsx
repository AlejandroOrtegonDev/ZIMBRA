// Gráficos del tablero y de los reportes (SVG/HTML, sin librerías).
// Especificación visual: columnas de máximo 24px con extremo redondeado
// de 4px y base recta, 2px de separación entre columnas vecinas,
// cuadrícula de 1px recesiva, leyenda para 2+ series, tooltip al pasar
// el cursor y tabla con los mismos datos.

import { useEffect, useRef, useState } from 'react'
import { SERIES } from '../utils/colores'
import './graficos.css'

// Escala "redonda" para el eje Y
function maximoRedondo(valor) {
  if (valor <= 0) return 1
  const potencia = 10 ** Math.floor(Math.log10(valor))
  const paso = [1, 2, 2.5, 5, 10].find((m) => m * potencia >= valor / 4) * potencia
  return Math.ceil(valor / paso) * paso
}

// Rectángulo con las dos esquinas superiores redondeadas (base recta)
function columnaRedondeada(x, y, ancho, alto, radio = 4) {
  if (alto <= 0) return ''
  const r = Math.min(radio, ancho / 2, alto)
  return `M${x},${y + alto} V${y + r} Q${x},${y} ${x + r},${y} H${x + ancho - r} Q${x + ancho},${y} ${x + ancho},${y + r} V${y + alto} Z`
}

function Tooltip({ visible, x, y, children }) {
  if (!visible) return null
  return (
    <div className="grafico-tooltip" style={{ left: x, top: y }} role="status">
      {children}
    </div>
  )
}

export function Leyenda({ series }) {
  if (series.length < 2) return null
  return (
    <div className="grafico-leyenda">
      {series.map((s) => (
        <span key={s.nombre}>
          <i style={{ background: s.color }} aria-hidden="true" />
          {s.nombre}
        </span>
      ))}
    </div>
  )
}

export function TablaDatos({ columnas, filas }) {
  return (
    <details className="grafico-tabla">
      <summary>Ver datos en tabla</summary>
      <div className="tabla-scroll">
        <table>
          <thead>
            <tr>{columnas.map((c) => <th key={c}>{c}</th>)}</tr>
          </thead>
          <tbody>
            {filas.map((fila, i) => (
              <tr key={i}>{fila.map((celda, j) => <td key={j}>{celda}</td>)}</tr>
            ))}
          </tbody>
        </table>
      </div>
    </details>
  )
}

// ---------------------------------------------------------------
// Columnas agrupadas: categorías en X, 1 o 2 series de la misma unidad
//   datos:  [{ etiqueta, detalle, valores: [n1, n2] }]
//   series: [{ nombre, color }]
// ---------------------------------------------------------------
export function ColumnasAgrupadas({ datos, series, formatoEje, formatoValor, titulo }) {
  const [activo, setActivo] = useState(null)
  const lienzo = useRef(null)
  const [ancho, setAncho] = useState(720)

  // El SVG usa el ancho real del contenedor: el texto de los ejes se
  // dibuja a su tamaño (11px) en lugar de escalarse con el gráfico.
  useEffect(() => {
    if (!lienzo.current) return undefined
    const observador = new ResizeObserver(([entrada]) => setAncho(Math.max(320, Math.round(entrada.contentRect.width))))
    observador.observe(lienzo.current)
    return () => observador.disconnect()
  }, [])

  const alto = 280
  const margen = { arriba: 22, derecha: 8, abajo: 26, izquierda: 58 }
  const areaAncho = ancho - margen.izquierda - margen.derecha
  const areaAlto = alto - margen.arriba - margen.abajo

  const maximo = maximoRedondo(Math.max(0, ...datos.flatMap((d) => d.valores)))
  const marcas = [0, 0.25, 0.5, 0.75, 1].map((f) => f * maximo)
  const y = (v) => margen.arriba + areaAlto - (v / maximo) * areaAlto

  const banda = areaAncho / Math.max(datos.length, 1)
  const separacion = 2
  const columna = Math.min(24, (banda * 0.7 - separacion * (series.length - 1)) / series.length)
  const grupo = columna * series.length + separacion * (series.length - 1)

  // Etiqueta directa selectiva: solo el valor más alto de la primera serie
  const indiceMaximo = datos.reduce((m, d, i) => (d.valores[0] > (datos[m]?.valores[0] ?? -1) ? i : m), 0)

  return (
    <div className="grafico">
      <Leyenda series={series} />
      <div className="grafico-lienzo" ref={lienzo}>
        <svg viewBox={`0 0 ${ancho} ${alto}`} width={ancho} height={alto} role="img" aria-label={titulo}>
          {marcas.map((m) => (
            <g key={m}>
              <line x1={margen.izquierda} x2={ancho - margen.derecha} y1={y(m)} y2={y(m)}
                className={m === 0 ? 'grafico-base' : 'grafico-rejilla'} />
              <text x={margen.izquierda - 8} y={y(m)} className="grafico-eje" textAnchor="end" dominantBaseline="middle">
                {formatoEje(m)}
              </text>
            </g>
          ))}

          {datos.map((d, i) => {
            const inicio = margen.izquierda + i * banda + (banda - grupo) / 2
            return (
              <g key={d.etiqueta}>
                {activo === i && (
                  <rect x={margen.izquierda + i * banda} y={margen.arriba} width={banda} height={areaAlto} className="grafico-resalte" />
                )}
                {d.valores.map((v, s) => (
                  <path key={s}
                    d={columnaRedondeada(inicio + s * (columna + separacion), y(v), columna, y(0) - y(v))}
                    fill={series[s].color} />
                ))}
                {i === indiceMaximo && d.valores[0] > 0 && (
                  <text x={inicio + columna / 2} y={y(d.valores[0]) - 6} className="grafico-valor" textAnchor="middle">
                    {formatoEje(d.valores[0])}
                  </text>
                )}
                <text x={margen.izquierda + i * banda + banda / 2} y={alto - 8} className="grafico-eje" textAnchor="middle">
                  {d.etiqueta}
                </text>
                {/* Zona de hover más grande que la marca */}
                <rect x={margen.izquierda + i * banda} y={margen.arriba} width={banda} height={areaAlto + margen.abajo}
                  fill="transparent" tabIndex={0} aria-label={`${d.detalle ?? d.etiqueta}: ${d.valores.map((v, s) => `${series[s].nombre} ${formatoValor(v)}`).join(', ')}`}
                  onMouseEnter={() => setActivo(i)} onMouseLeave={() => setActivo(null)}
                  onFocus={() => setActivo(i)} onBlur={() => setActivo(null)} />
              </g>
            )
          })}
        </svg>

        <Tooltip
          visible={activo !== null}
          x={`${((margen.izquierda + (activo ?? 0) * banda + banda / 2) / ancho) * 100}%`}
          y={0}
        >
          {activo !== null && (
            <>
              <strong>{datos[activo].detalle ?? datos[activo].etiqueta}</strong>
              {datos[activo].valores.map((v, s) => (
                <span key={s}><i style={{ background: series[s].color }} />{series[s].nombre}: {formatoValor(v)}</span>
              ))}
            </>
          )}
        </Tooltip>
      </div>
    </div>
  )
}

// ---------------------------------------------------------------
// Barras horizontales de una serie (embudo, ranking)
//   datos: [{ etiqueta, valor, detalle }]
// ---------------------------------------------------------------
export function BarrasHorizontales({ datos, color = SERIES[0], formatoValor, formatoDetalle }) {
  const [activo, setActivo] = useState(null)
  const maximo = Math.max(1, ...datos.map((d) => d.valor))

  return (
    <div className="barras-h">
      {datos.map((d, i) => (
        <div key={d.etiqueta} className={`barras-h-fila ${activo === i ? 'activa' : ''}`}
          tabIndex={0}
          onMouseEnter={() => setActivo(i)} onMouseLeave={() => setActivo(null)}
          onFocus={() => setActivo(i)} onBlur={() => setActivo(null)}
          aria-label={`${d.etiqueta}: ${formatoValor(d.valor)}${formatoDetalle ? `, ${formatoDetalle(d)}` : ''}`}>
          <span className="barras-h-etiqueta" title={d.etiqueta}>{d.etiqueta}</span>
          <div className="barras-h-pista">
            <div className="barras-h-barra" style={{ width: `${(d.valor / maximo) * 100}%`, background: color }} />
            <span className="barras-h-valor">{formatoValor(d.valor)}</span>
          </div>
          {activo === i && formatoDetalle && (
            <div className="grafico-tooltip barras-h-tooltip" role="status">
              <strong>{d.etiqueta}</strong>
              <span>{formatoDetalle(d)}</span>
            </div>
          )}
        </div>
      ))}
    </div>
  )
}

// ---------------------------------------------------------------
// Tarjeta de indicador (una cifra)
// ---------------------------------------------------------------
export function Indicador({ etiqueta, valor, detalle, principal = false }) {
  return (
    <article className={`indicador ${principal ? 'indicador-principal' : ''}`}>
      <span>{etiqueta}</span>
      <strong>{valor}</strong>
      {detalle && <small>{detalle}</small>}
    </article>
  )
}
