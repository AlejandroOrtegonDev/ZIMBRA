// Oportunidades, etapas, seguimientos y tareas

import { crearModelo } from './base.model.js'

export const EtapaVenta = crearModelo('etapas_ventas', 'id_etapa', ['nombre', 'orden'])

export const Oportunidad = crearModelo('oportunidades', 'id_oportunidad', [
  'id_cliente',
  'id_vendedor',
  'id_etapa',
  'titulo',
  'descripcion',
  'valor_estimado',
  'estado',
  'fecha_cierre',
])

export const OportunidadDetalle = crearModelo('oportunidades_detalle', 'id_detalle', [
  'id_oportunidad',
  'descripcion',
  'fecha',
])

export const Seguimiento = crearModelo('seguimientos', 'id_seguimiento', [
  'id_oportunidad',
  'id_usuario',
  'tipo',
  'descripcion',
  'fecha',
])

export const Tarea = crearModelo('tareas', 'id_tarea', [
  'id_usuario',
  'id_cliente',
  'id_oportunidad',
  'titulo',
  'descripcion',
  'fecha_limite',
  'estado',
])
