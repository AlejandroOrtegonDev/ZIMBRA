// Reportes generados y auditoría

import { crearModelo } from './base.model.js'

export const Reporte = crearModelo('reportes_generados', 'id_reporte', [
  'id_usuario',
  'nombre',
  'tipo',
  'archivo',
])

export const Auditoria = crearModelo('auditoria', 'id_auditoria', [
  'id_usuario',
  'tabla_afectada',
  'operacion',
  'registro_id',
  'descripcion',
  'fecha',
])
