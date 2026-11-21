// Autenticación (token) y autorización (permisos de la tabla roles_permisos)

import ApiError from '../utils/ApiError.js'
import { verificarToken } from '../utils/token.js'

// Exige un token válido en la cabecera  Authorization: Bearer <token>
export function autenticar(req, res, next) {
  const [tipo, token] = (req.headers.authorization ?? '').split(' ')
  const datos = tipo === 'Bearer' ? verificarToken(token) : null

  if (!datos) {
    throw new ApiError(401, 'Sesión no válida o expirada. Inicie sesión nuevamente.')
  }

  req.usuario = datos
  next()
}

// Exige que el usuario tenga al menos uno de los permisos indicados.
// Los permisos se leen de la BD al iniciar sesión y viajan en el token.
export function requierePermiso(...permisos) {
  return (req, res, next) => {
    const propios = req.usuario?.permisos ?? []

    if (!permisos.some((permiso) => propios.includes(permiso))) {
      throw new ApiError(403, `No tiene permiso para esta acción (${permisos.join(' o ')})`)
    }

    next()
  }
}
