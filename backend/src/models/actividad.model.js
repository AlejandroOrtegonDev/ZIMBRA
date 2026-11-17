// Actividad web y notificaciones

import { crearModelo } from './base.model.js'

export const ActividadWeb = crearModelo('actividad_web', 'id_actividad', [
  'id_usuario',
  'id_cliente',
  'accion',
  'descripcion',
  'fecha',
])

export const Notificacion = crearModelo('notificaciones', 'id_notificacion', [
  'id_usuario',
  'titulo',
  'mensaje',
  'estado',
  'fecha',
])
