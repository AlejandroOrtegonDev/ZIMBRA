// Correos y destinatarios

import { crearModelo } from './base.model.js'

export const Correo = crearModelo('correos', 'id_correo', [
  'id_usuario',
  'asunto',
  'contenido',
  'fecha_envio',
  'estado',
])

export const CorreoDestinatario = crearModelo('correos_destinatarios', 'id_destinatario', [
  'id_correo',
  'correo',
  'tipo',
])
