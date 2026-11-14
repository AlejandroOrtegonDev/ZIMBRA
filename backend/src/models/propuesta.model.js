// Propuestas comerciales y su detalle

import { crearModelo } from './base.model.js'

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
