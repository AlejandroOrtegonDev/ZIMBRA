// Ventas, productos vendidos y pagos

import { crearModelo } from './base.model.js'

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
