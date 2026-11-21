// Token de sesión firmado con HMAC-SHA256 (mismo formato que un JWT HS256).
// Se usa el módulo crypto de Node: no hace falta otra dependencia.

import crypto from 'node:crypto'

const DURACION_SEGUNDOS = 8 * 60 * 60 // una jornada de trabajo

const base64url = (texto) => Buffer.from(texto).toString('base64url')

function firmar(contenido) {
  return crypto.createHmac('sha256', process.env.AUTH_SECRET).update(contenido).digest('base64url')
}

export function crearToken(datos) {
  const ahora = Math.floor(Date.now() / 1000)
  const cabecera = base64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
  const cuerpo = base64url(JSON.stringify({ ...datos, iat: ahora, exp: ahora + DURACION_SEGUNDOS }))
  return `${cabecera}.${cuerpo}.${firmar(`${cabecera}.${cuerpo}`)}`
}

// Devuelve el contenido del token o null si es inválido o expiró
export function verificarToken(token) {
  const partes = String(token ?? '').split('.')
  if (partes.length !== 3) return null

  const [cabecera, cuerpo, firma] = partes
  const esperada = firmar(`${cabecera}.${cuerpo}`)

  const a = Buffer.from(firma)
  const b = Buffer.from(esperada)
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null

  try {
    const datos = JSON.parse(Buffer.from(cuerpo, 'base64url').toString('utf8'))
    if (!datos.exp || datos.exp < Math.floor(Date.now() / 1000)) return null
    return datos
  } catch {
    return null
  }
}
