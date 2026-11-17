// Eventos y calendario

import { crearModelo } from './base.model.js'

export const Evento = crearModelo('eventos', 'id_evento', [
  'id_usuario',
  'titulo',
  'descripcion',
  'fecha_inicio',
  'fecha_fin',
  'ubicacion',
  'tipo',
  'estado',
])
