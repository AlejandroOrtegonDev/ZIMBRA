import pool from '../src/config/database.js'
import * as usuario from '../src/models/usuario.model.js'
import * as cliente from '../src/models/cliente.model.js'
import * as vendedor from '../src/models/vendedor.model.js'
import * as oportunidad from '../src/models/oportunidad.model.js'
import * as campana from '../src/models/campana.model.js'
import * as producto from '../src/models/producto.model.js'
import * as propuesta from '../src/models/propuesta.model.js'
import * as venta from '../src/models/venta.model.js'
import * as actividad from '../src/models/actividad.model.js'
import * as compania from '../src/models/compania.model.js'
import * as evento from '../src/models/evento.model.js'
import * as etiqueta from '../src/models/etiqueta.model.js'
import * as correo from '../src/models/correo.model.js'
import * as reporte from '../src/models/reporte.model.js'
import * as configuracion from '../src/models/configuracion.model.js'

const modelos = {
  ...usuario,
  ...cliente,
  ...vendedor,
  ...oportunidad,
  ...campana,
  ...producto,
  ...propuesta,
  ...venta,
  ...actividad,
  ...compania,
  ...evento,
  ...etiqueta,
  ...correo,
  ...reporte,
  ...configuracion,
}

const [columnas] = await pool.query(
  `SELECT TABLE_NAME AS tabla, COLUMN_NAME AS columna
   FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = ?`,
  [process.env.DB_NAME]
)

const porTabla = new Map()
for (const { tabla, columna } of columnas) {
  if (!porTabla.has(tabla)) porTabla.set(tabla, new Set())
  porTabla.get(tabla).add(columna)
}

let errores = 0
const cubiertas = []
const modelosUsados = []

for (const [nombre, modelo] of Object.entries(modelos)) {
  if (!modelo?.tabla || typeof modelo !== 'object') continue

  modelosUsados.push(`${nombre} -> ${modelo.tabla}`)
  cubiertas.push(modelo.tabla)

  const reales = porTabla.get(modelo.tabla)
  if (!reales) {
    console.log(`TABLA INEXISTENTE: ${modelo.tabla} (${nombre})`)
    errores++
    continue
  }

  const declaradas = new Set([
    ...(modelo.campos ?? []),
    ...(modelo.claves ?? []),
    modelo.columnaId,
  ].filter(Boolean))

  for (const columna of declaradas) {
    if (!reales.has(columna)) {
      console.log(`COLUMNA INEXISTENTE: ${modelo.tabla}.${columna} (${nombre})`)
      errores++
    }
  }
}

const todas = [...porTabla.keys()]
const sinModelo = todas.filter((tabla) => !cubiertas.includes(tabla))

console.log('---')
console.log(`Tablas en BD: ${todas.length}`)
console.log(`Tablas con modelo: ${new Set(cubiertas).size}`)
console.log(`Modelos definidos: ${modelosUsados.length}`)
console.log(`Sin modelo: ${sinModelo.length ? sinModelo.join(', ') : 'ninguna'}`)
console.log(`Errores: ${errores}`)

await pool.end()
