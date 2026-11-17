// Configuración por usuario

import { crearModelo } from './base.model.js'

export const ConfiguracionUsuario = crearModelo('configuracion_usuario', 'id_configuracion', [
  'id_usuario',
  'zona_horaria',
  'idioma',
  'notificaciones',
])
