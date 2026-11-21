// Propuestas comerciales y su detalle

import { crearModelo } from './base.model.js'
import pool, { ejecutarComoUsuario, transaccionComoUsuario, resultadosDeCall } from '../config/database.js'
import ApiError from '../utils/ApiError.js'

export const Propuesta = crearModelo('propuestas', 'id_propuesta', [
  'id_oportunidad',
  'fecha',
  'valor_total',
  'estado',
  'observaciones',
])

export const PropuestaDetalle = crearModelo('propuestas_detalles', 'id_detalle', [
  'id_propuesta',
  'id_producto',
  'cantidad',
  'precio_unitario',
  'subtotal',
])

// Listado (vista vw_propuestas_resumen)
export async function listar({ estado } = {}) {
  const filtros = []
  const valores = []

  if (estado) {
    filtros.push('estado = ?')
    valores.push(estado)
  }

  const [filas] = await pool.query(
    `SELECT * FROM vw_propuestas_resumen
     ${filtros.length ? `WHERE ${filtros.join(' AND ')}` : ''}
     ORDER BY fecha DESC, id_propuesta DESC`,
    valores,
  )
  return filas
}

export async function obtenerDetalle(idPropuesta) {
  const [propuestas] = await pool.query('SELECT * FROM vw_propuestas_resumen WHERE id_propuesta = ?', [idPropuesta])
  if (propuestas.length === 0) return null

  const [lineas] = await pool.query(
    `SELECT d.id_detalle, d.id_producto, p.nombre AS producto, d.cantidad, d.precio_unitario, d.subtotal
     FROM propuestas_detalles d
     JOIN productos p ON p.id_producto = d.id_producto
     WHERE d.id_propuesta = ?
     ORDER BY d.id_detalle`,
    [idPropuesta],
  )

  return { ...propuestas[0], lineas }
}

// Crea la propuesta con sus líneas en una sola transacción.
// El precio se toma del catálogo (no del navegador) y el valor total
// lo calcula el trigger trg_propuestas_detalles_total_ins.
export async function crear({ id_oportunidad, observaciones, lineas, enviar }, idUsuario) {
  return transaccionComoUsuario(idUsuario, async (conexion) => {
    const [oportunidades] = await conexion.execute(
      'SELECT estado FROM oportunidades WHERE id_oportunidad = ? FOR UPDATE',
      [id_oportunidad],
    )

    if (oportunidades.length === 0) throw new ApiError(404, 'La oportunidad no existe')
    if (oportunidades[0].estado !== 'abierta') {
      throw new ApiError(400, `La oportunidad está ${oportunidades[0].estado}; solo se cotizan oportunidades abiertas`)
    }

    const [resultado] = await conexion.execute(
      "INSERT INTO propuestas (id_oportunidad, fecha, estado, observaciones) VALUES (?, CURDATE(), 'borrador', ?)",
      [id_oportunidad, observaciones || null],
    )
    const idPropuesta = resultado.insertId

    for (const linea of lineas) {
      const [productos] = await conexion.execute(
        'SELECT precio, estado FROM productos WHERE id_producto = ?',
        [linea.id_producto],
      )

      if (productos.length === 0) throw new ApiError(400, `El producto #${linea.id_producto} no existe`)

      const precio = Number(productos[0].precio)

      await conexion.execute(
        `INSERT INTO propuestas_detalles (id_propuesta, id_producto, cantidad, precio_unitario, subtotal)
         VALUES (?, ?, ?, ?, ?)`,
        [idPropuesta, linea.id_producto, linea.cantidad, precio, precio * linea.cantidad],
      )
    }

    if (enviar) {
      await conexion.execute("UPDATE propuestas SET estado = 'enviada' WHERE id_propuesta = ?", [idPropuesta])
    }

    return idPropuesta
  })
}

// Cambia el estado; los triggers validan la transición y mueven la oportunidad
export async function cambiarEstado(idPropuesta, estado, idUsuario) {
  return ejecutarComoUsuario(idUsuario, async (conexion) => {
    const [resultado] = await conexion.execute(
      'UPDATE propuestas SET estado = ? WHERE id_propuesta = ?',
      [estado, idPropuesta],
    )
    return resultado.affectedRows > 0
  })
}

// Procedimiento almacenado sp_registrar_venta_desde_propuesta
export async function convertirEnVenta(idPropuesta, idUsuario) {
  return ejecutarComoUsuario(idUsuario, async (conexion) => {
    const [filas] = await conexion.query('CALL sp_registrar_venta_desde_propuesta(?)', [idPropuesta])
    return resultadosDeCall(filas)[0]?.[0] ?? null
  })
}
