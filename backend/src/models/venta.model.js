// Ventas, productos vendidos y pagos

import { crearModelo } from './base.model.js'
import pool, { ejecutarComoUsuario, resultadosDeCall } from '../config/database.js'

export const Venta = crearModelo('ventas', 'id_venta', [
  'id_cliente',
  'id_vendedor',
  'id_propuesta',
  'fecha',
  'total',
  'estado',
])

export const VentaProducto = crearModelo('ventas_productos', 'id_detalle', [
  'id_venta',
  'id_producto',
  'cantidad',
  'precio_unitario',
  'subtotal',
])

export const Pago = crearModelo('pagos', 'id_pago', [
  'id_venta',
  'metodo_pago',
  'valor',
  'fecha',
  'estado',
])

// Listado con pagado y saldo (vista vw_ventas_detalle, usa las UDF)
export async function listar({ estado } = {}) {
  const [filas] = await pool.query(
    `SELECT * FROM vw_ventas_detalle
     ${estado ? 'WHERE estado = ?' : ''}
     ORDER BY fecha DESC, id_venta DESC`,
    estado ? [estado] : [],
  )
  return filas
}

export async function obtenerDetalle(idVenta) {
  const [ventas] = await pool.query('SELECT * FROM vw_ventas_detalle WHERE id_venta = ?', [idVenta])
  if (ventas.length === 0) return null

  const [productos] = await pool.query(
    `SELECT vp.id_detalle, vp.id_producto, p.nombre AS producto, vp.cantidad, vp.precio_unitario, vp.subtotal
     FROM ventas_productos vp
     JOIN productos p ON p.id_producto = vp.id_producto
     WHERE vp.id_venta = ?
     ORDER BY vp.id_detalle`,
    [idVenta],
  )

  const [pagos] = await pool.query(
    `SELECT id_pago, metodo_pago, valor, fecha, estado
     FROM pagos
     WHERE id_venta = ?
     ORDER BY fecha, id_pago`,
    [idVenta],
  )

  return { ...ventas[0], productos, pagos }
}

// Procedimiento almacenado procesar_pago_venta (valor null = todo el saldo)
export async function registrarPago(idVenta, { metodo_pago, valor }, idUsuario) {
  return ejecutarComoUsuario(idUsuario, async (conexion) => {
    const [filas] = await conexion.query('CALL procesar_pago_venta(?, ?, ?)', [idVenta, metodo_pago, valor ?? null])
    return resultadosDeCall(filas)[0]?.[0] ?? null
  })
}

// Aprobar o rechazar un pago pendiente: el trigger recalcula la venta
export async function cambiarEstadoPago(idPago, estado, idUsuario) {
  return ejecutarComoUsuario(idUsuario, async (conexion) => {
    const [resultado] = await conexion.execute('UPDATE pagos SET estado = ? WHERE id_pago = ?', [estado, idPago])
    if (resultado.affectedRows === 0) return null

    const [pagos] = await conexion.execute('SELECT id_pago, id_venta, estado FROM pagos WHERE id_pago = ?', [idPago])
    return pagos[0]
  })
}

// Cancelar: el trigger valida que no tenga pagos aprobados y devuelve el stock
export async function cancelar(idVenta, idUsuario) {
  return ejecutarComoUsuario(idUsuario, async (conexion) => {
    const [resultado] = await conexion.execute(
      "UPDATE ventas SET estado = 'cancelada' WHERE id_venta = ?",
      [idVenta],
    )
    return resultado.affectedRows > 0
  })
}
