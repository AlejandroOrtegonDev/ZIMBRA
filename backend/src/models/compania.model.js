// Información de la compañía

import { crearModelo } from './base.model.js'

export const Compania = crearModelo('info_companie', 'id_compania', [
  'nombre',
  'nit',
  'direccion',
  'telefono',
  'correo',
  'logo',
])
