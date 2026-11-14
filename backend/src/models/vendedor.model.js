// Vendedores y asignación de clientes

import { crearModelo } from './base.model.js'

export const Vendedor = crearModelo('vendedores', 'id_vendedor', [
  'id_usuario',
  'codigo',
  'especialidad',
  'estado',
])

export const AsignacionCliente = crearModelo('asignaciones_clientes', 'id_asignacion', [
  'id_cliente',
  'id_vendedor',
])
