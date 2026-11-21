// Ventas y pagos

import * as VentaModel from '../models/venta.model.js'
import ApiError from '../utils/ApiError.js'
import { validarId, validarMonto, validarOpcion } from '../utils/validar.js'

const METODOS = ['transferencia', 'tarjeta', 'pse', 'efectivo']

export async function listarVentas(req, res) {
  const estado = req.query.estado
    ? validarOpcion(req.query.estado, ['pendiente', 'pagada', 'cancelada'], 'Estado')
    : undefined
  const ventas = await VentaModel.listar({ estado })

  res.json({ ok: true, total: ventas.length, ventas })
}

export async function obtenerVenta(req, res) {
  const venta = await VentaModel.obtenerDetalle(validarId(req.params.id, 'ID de la venta'))

  if (!venta) throw new ApiError(404, 'Venta no encontrada')

  res.json({ ok: true, venta })
}

// Llama al procedimiento procesar_pago_venta (transacción + FOR UPDATE)
export async function registrarPago(req, res) {
  const id = validarId(req.params.id, 'ID de la venta')
  const metodo = validarOpcion(req.body.metodo_pago, METODOS, 'Método de pago')
  const valor = req.body.valor === undefined || req.body.valor === null || req.body.valor === ''
    ? null
    : validarMonto(req.body.valor, 'valor del pago')

  const resultado = await VentaModel.registrarPago(id, { metodo_pago: metodo, valor }, req.usuario.id_usuario)

  res.status(201).json({
    ok: true,
    mensaje: resultado?.estado === 'pagada'
      ? 'Pago registrado. La venta quedó pagada.'
      : 'Pago registrado.',
    resultado,
    venta: await VentaModel.obtenerDetalle(id),
  })
}

export async function cambiarEstadoPago(req, res) {
  const idPago = validarId(req.params.idPago, 'ID del pago')
  const estado = validarOpcion(req.body.estado, ['aprobado', 'rechazado'], 'Estado')

  const pago = await VentaModel.cambiarEstadoPago(idPago, estado, req.usuario.id_usuario)
  if (!pago) throw new ApiError(404, 'Pago no encontrado')

  res.json({
    ok: true,
    mensaje: `Pago ${estado}`,
    venta: await VentaModel.obtenerDetalle(pago.id_venta),
  })
}

export async function cancelarVenta(req, res) {
  const id = validarId(req.params.id, 'ID de la venta')

  const cancelada = await VentaModel.cancelar(id, req.usuario.id_usuario)
  if (!cancelada) throw new ApiError(404, 'Venta no encontrada')

  res.json({
    ok: true,
    mensaje: 'Venta cancelada; el stock volvió al inventario',
    venta: await VentaModel.obtenerDetalle(id),
  })
}
