// Fábrica de modelos: genera el CRUD básico de una tabla
// Los nombres de tabla/columna vienen del código, nunca del cliente,
// y se validan antes de interpolarse en el SQL.

import pool from '../config/database.js'

const IDENTIFICADOR = /^[a-z][a-z0-9_]*$/

function validar(nombre) {
  if (!IDENTIFICADOR.test(nombre)) {
    throw new Error(`Identificador SQL inválido: ${nombre}`)
  }
  return nombre
}

function limpiar(datos, campos) {
  const limpio = {}

  for (const campo of campos) {
    if (datos[campo] !== undefined) {
      limpio[campo] = datos[campo]
    }
  }

  return limpio
}

function construirPaginacion(limite, offset) {
  let sql = ''
  const valores = []

  if (Number.isInteger(limite) && limite > 0) {
    sql += ' LIMIT ?'
    valores.push(limite)

    if (Number.isInteger(offset) && offset >= 0) {
      sql += ' OFFSET ?'
      valores.push(offset)
    }
  }

  return { sql, valores }
}

// Tablas con clave primaria simple (auto_increment)
export function crearModelo(tabla, columnaId, campos) {
  const t = validar(tabla)
  const id = validar(columnaId)
  const columnas = campos.map(validar).filter((campo) => campo !== id)

  async function obtenerPorId(valor) {
    const [filas] = await pool.query(
      `SELECT * FROM \`${t}\` WHERE \`${id}\` = ? LIMIT 1`,
      [valor]
    )
    return filas[0] ?? null
  }

  async function obtenerTodos({ limite, offset } = {}) {
    const paginacion = construirPaginacion(limite, offset)
    const [filas] = await pool.query(
      `SELECT * FROM \`${t}\`${paginacion.sql}`,
      paginacion.valores
    )
    return filas
  }

  async function obtenerPor(campo, valor, { limite, offset } = {}) {
    const columna = validar(campo)

    if (!columnas.includes(columna)) {
      throw new Error(`Columna no disponible para filtrar en ${t}: ${campo}`)
    }

    const paginacion = construirPaginacion(limite, offset)
    const [filas] = await pool.query(
      `SELECT * FROM \`${t}\` WHERE \`${columna}\` = ?${paginacion.sql}`,
      [valor, ...paginacion.valores]
    )
    return filas
  }

  async function contar() {
    const [filas] = await pool.query(`SELECT COUNT(*) AS total FROM \`${t}\``)
    return Number(filas[0].total)
  }

  async function crear(datos) {
    const limpio = limpiar(datos, columnas)

    if (Object.keys(limpio).length === 0) {
      throw new Error(`No hay datos para insertar en ${t}`)
    }

    const [resultado] = await pool.query(`INSERT INTO \`${t}\` SET ?`, [limpio])
    return obtenerPorId(resultado.insertId)
  }

  async function actualizar(valor, datos) {
    const limpio = limpiar(datos, columnas)

    if (Object.keys(limpio).length === 0) {
      return obtenerPorId(valor)
    }

    await pool.query(`UPDATE \`${t}\` SET ? WHERE \`${id}\` = ?`, [limpio, valor])
    return obtenerPorId(valor)
  }

  async function eliminar(valor) {
    const [resultado] = await pool.query(
      `DELETE FROM \`${t}\` WHERE \`${id}\` = ?`,
      [valor]
    )
    return resultado.affectedRows > 0
  }

  return {
    tabla: t,
    columnaId: id,
    campos: columnas,
    obtenerTodos,
    obtenerPorId,
    obtenerPor,
    contar,
    crear,
    actualizar,
    eliminar,
  }
}

// Tablas de relación con clave primaria compuesta
export function crearModeloRelacion(tabla, claves, campos = []) {
  const t = validar(tabla)
  const columnasClave = claves.map(validar)
  const columnas = campos.map(validar)

  function condicionesClave(datos) {
    const valores = []
    let sql = ''

    for (const columna of columnasClave) {
      if (datos[columna] === undefined) {
        throw new Error(`Falta la clave ${columna} en ${t}`)
      }

      sql += `${sql ? ' AND ' : ''}\`${columna}\` = ?`
      valores.push(datos[columna])
    }

    return { sql, valores }
  }

  async function obtenerTodos() {
    const [filas] = await pool.query(`SELECT * FROM \`${t}\``)
    return filas
  }

  async function obtenerPorClave(clave) {
    const condicion = condicionesClave(clave)
    const [filas] = await pool.query(
      `SELECT * FROM \`${t}\` WHERE ${condicion.sql} LIMIT 1`,
      condicion.valores
    )
    return filas[0] ?? null
  }

  async function listarPor(campo, valor) {
    const columna = validar(campo)

    if (!columnasClave.includes(columna) && !columnas.includes(columna)) {
      throw new Error(`Columna no disponible para filtrar en ${t}: ${campo}`)
    }

    const [filas] = await pool.query(
      `SELECT * FROM \`${t}\` WHERE \`${columna}\` = ?`,
      [valor]
    )
    return filas
  }

  async function crear(datos) {
    const limpio = limpiar(datos, [...columnasClave, ...columnas])
    condicionesClave(limpio)

    await pool.query(`INSERT INTO \`${t}\` SET ?`, [limpio])
    return obtenerPorClave(limpio)
  }

  async function eliminar(clave) {
    const condicion = condicionesClave(clave)
    const [resultado] = await pool.query(
      `DELETE FROM \`${t}\` WHERE ${condicion.sql}`,
      condicion.valores
    )
    return resultado.affectedRows > 0
  }

  async function existe(clave) {
    return (await obtenerPorClave(clave)) !== null
  }

  return {
    tabla: t,
    claves: columnasClave,
    campos: columnas,
    obtenerTodos,
    obtenerPorClave,
    listarPor,
    crear,
    eliminar,
    existe,
  }
}
