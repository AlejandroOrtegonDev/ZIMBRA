// Campañas de marketing, clientes asignados e interacciones

import { crearModelo, crearModeloRelacion } from './base.model.js'

export const Campana = crearModelo('campanas_marketing', 'id_campana', [
  'nombre',
  'descripcion',
  'fecha_inicio',
  'fecha_fin',
  'presupuesto',
  'estado',
])

export const CampanaCliente = crearModeloRelacion(
  'campanas_clientes',
  ['id_campana', 'id_cliente'],
  ['fecha_asignacion']
)

export const CampanaInteraccion = crearModelo('campanas_interacciones', 'id_interaccion', [
  'id_campana',
  'id_cliente',
  'tipo',
  'resultado',
  'fecha',
])
