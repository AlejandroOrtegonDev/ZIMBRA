// Usuarios, roles y permisos

import { crearModelo, crearModeloRelacion } from './base.model.js'

export const Usuario = crearModelo('usuarios', 'id_usuario', [
  'nombre',
  'correo',
  'password',
  'estado',
])

export const Rol = crearModelo('roles', 'id_rol', ['nombre', 'descripcion'])

export const Permiso = crearModelo('permisos', 'id_permiso', ['nombre', 'descripcion'])

export const UsuarioRol = crearModeloRelacion('usuarios_roles', [
  'id_usuario',
  'id_rol',
])

export const RolPermiso = crearModeloRelacion('roles_permisos', [
  'id_rol',
  'id_permiso',
])
